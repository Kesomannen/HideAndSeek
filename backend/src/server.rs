use std::{cmp::Ordering, collections::HashMap, time::{Duration, Instant}};
use actix::prelude::*;
use geo::{Point, GeodesicDistance};
use rand::{seq::SliceRandom, rngs::ThreadRng};

use crate::message::*;
use crate::util::generate_id;

const UPDATE_INTERVAL: Duration = Duration::from_secs(1);

enum GameState {
    Waiting,
    Playing {
        seeker: i64, 
        handle: SpawnHandle,
        start: Instant,
        scores: HashMap<i64, f32>,
    },
    Ended
}

struct Player {
    name: String,
    addr: Recipient<ServerMessage>,
    pos: Option<Point<f64>>,
}

pub struct GameServer {
    players: HashMap<i64, Player>,
    games: HashMap<u16, Game>,
    rng: ThreadRng,
}

impl Actor for GameServer {
    type Context = Context<Self>;
}

struct Game {
    host: i64,
    players: Vec<i64>,
    pos: Point<f64>,
    state: GameState,
    length: Duration,
}

impl Game {
    pub fn new(host: i64, pos: Point<f64>, length: Duration) -> Self {
        let players = vec![host];

        Self {
            host, pos, players, length,
            state: GameState::Waiting,
        }
    }
}

impl GameServer {
    pub fn new() -> Self {
        Self {
            games: HashMap::new(),
            players: HashMap::new(),
            rng: rand::thread_rng(),
        }
    }

    fn error(message: &str) -> Option<ServerEvent> {
        Some(ServerEvent::error(message))
    }

    fn get_player_mut(&mut self, player_id: i64) -> Result<&mut Player, Option<ServerEvent>> {
        match self.players.get_mut(&player_id) {
            Some(player) => return Ok(player),
            None => return Err(Self::error("Player not found")),
        }
    }

    fn get_player(&self, player_id: i64) -> Result<&Player, Option<ServerEvent>> {
        match self.players.get(&player_id) {
            Some(player) => return Ok(player),
            None => return Err(Self::error("Player not found")),
        }
    }

    fn broadcast_if(&self, game_id: Option<u16>, event: ServerEvent, exclude: Option<i64>) {
        if let Some(game_id) = game_id {
            self.broadcast(game_id, event, exclude);
        }
    }

    fn broadcast(&self, game_id: u16, event: ServerEvent, exclude: Option<i64>) {
        if let Some(game) = self.games.get(&game_id) {
            for id in &game.players {
                if Some(*id) != exclude {
                    if let Some(player) = self.players.get(id) {
                        player.addr.do_send(ServerMessage { event: event.clone() });
                    }
                }
            }
        }
    }

    fn find_game(&self, player_id: i64) -> Option<u16> {
        for (id, game) in &self.games {
            if game.players.contains(&player_id) {
                return Some(*id);
            }
        }

        None
    }

    fn cancel_game(&mut self, ctx: &mut Context<Self>, id: u16) {
        if let Some(game) = self.games.get(&id) {
            println!("Game {} canceled", id);

            if let GameState::Playing { handle, .. } = game.state {
                ctx.cancel_future(handle);
            }
            
            self.broadcast(id, ServerEvent::LeftGame, None);
            self.games.remove(&id);
        }
    }

    fn end_game(&mut self, ctx: &mut Context<Self>, id: u16) {
        if let Some(game) = self.games.get_mut(&id) {
            if let GameState::Playing { handle, scores, .. } = &game.state {
                println!("Game {} ended", id);
                ctx.cancel_future(*handle);

                let winner = match scores.iter().max_by(|a, b| {
                    return a.partial_cmp(b).unwrap_or(Ordering::Equal);
                }) {
                    Some(w) => *w.0,
                    None => {
                        self.cancel_game(ctx, id);
                        return;
                    },
                };

                game.state = GameState::Ended;
                self.broadcast(id, ServerEvent::GameEnded { winner }, None);
            }
        }
    } 

    fn update_game(&mut self, ctx: &mut Context<Self>, game_id: u16) {
        let game = match self.games.get_mut(&game_id) {
            Some(game) => game,
            None => return,
        };

        let (seeker, start, scores) = match &mut game.state {
            GameState::Playing { seeker, start, scores, .. } => (*seeker, *start, scores),
            _ => return,
        };

        for (id, score) in &mut *scores {
            if *id == seeker {
                continue;
            }

            if let Some(player) = self.players.get(&id) {
                if let Some(pos) = player.pos {
                    let distance = pos.geodesic_distance(&game.pos);
                    let gain = 1.0 / (distance + 2.0) * 20.0;
                    *score += gain as f32 * UPDATE_INTERVAL.as_secs_f32();
                }
            }
        }

        let ended = Instant::now().duration_since(start) >= game.length;
        let time_left = game.length.as_secs() - Instant::now().duration_since(start).as_secs();

        let update = ServerEvent::ScoreUpdate {
            seconds_left: time_left,
            scores: scores.clone(),
        };

        self.broadcast(game_id, update, None);

        if ended {
            self.end_game(ctx, game_id);
            return;
        }
    }
}

impl Handler<ClientMessage> for GameServer {
    type Result = MessageResult<ClientMessage>;

    fn handle(&mut self, msg: ClientMessage, ctx: &mut Context<Self>) -> Self::Result {
        let response = match msg.event {
            ClientEvent::Connect { .. } => Self::error("Connect should be handled with Handler<Connect>"),
            ClientEvent::Chat { message } => self.chat(msg.sender, message),
            ClientEvent::JoinGame { game } => self.join(msg.sender, game),
            ClientEvent::LeaveGame => self.leave(ctx, msg.sender),
            ClientEvent::CreateGame { x, y, minutes } => self.create(msg.sender, Point::new(x, y), minutes),
            ClientEvent::StartGame => self.start(ctx, msg.sender),
            ClientEvent::UpdatePosition { x, y } => self.set_pos(msg.sender, Point::new(x, y)),
            ClientEvent::TagPlayer { player } => self.tag(msg.sender, player),
        };

        return MessageResult(response);
    }
}

// Message handlers

impl GameServer {
    fn join(&mut self, player_id: i64, game_id: u16) -> Option<ServerEvent> {
        let name = match self.get_player(player_id) {
            Ok(value) => value,
            Err(value) => return value,
        }.name.clone();

        if self.find_game(player_id).is_some() {
            return Self::error("Already in a game");
        }

        if let Some(game) = self.games.get_mut(&game_id) {
            match game.state {
                GameState::Waiting => {
                    let players = game.players.iter().map(|id| {
                        (*id, self.players.get(id).unwrap().name.clone())
                    }).collect();

                    let event = ServerEvent::JoinedGame { 
                        players,
                        id: game_id,
                        x: game.pos.x(),
                        y: game.pos.y(),
                        host: game.host
                    };

                    game.players.push(player_id);

                    self.broadcast(
                        game_id, 
                        ServerEvent::PlayerJoined { 
                            name,
                            id: player_id,
                        }, 
                        Some(player_id)
                    );

                    return Some(event);
                },
                GameState::Playing { .. } => return Self::error("Game already started"),
                GameState::Ended { .. } => return Self::error("Game already ended"),
            };
        }
        
        Self::error("Game does not exist")
    }

    fn create(&mut self, host_id: i64, pos: Point<f64>, minutes: u64) -> Option<ServerEvent> {
        if self.find_game(host_id).is_some() {
            return Self::error("Already in a game");
        }

        let id = generate_id(&mut self.rng, &self.games);

        self.games.insert(id, Game::new(host_id, pos, Duration::from_secs(minutes * 60)));
        println!("Created game with id {} at lat {}, lng {}", id, pos.x(), pos.y());    
        Some(ServerEvent::JoinedGame { id, x: pos.x(), y: pos.y(), players: vec![], host: host_id })
    }

    fn chat(&mut self, player_id: i64, message: String) -> Option<ServerEvent> {
        self.broadcast_if(self.find_game(player_id), ServerEvent::Chat { message, sender: player_id }, None);
        None
    }

    fn leave(&mut self, ctx: &mut Context<GameServer>, player_id: i64) -> Option<ServerEvent> {
        if let Some(game_id) = self.find_game(player_id) {
            if let Some(game) = self.games.get_mut(&game_id) {
                let mut new_host = game.host;
                game.players.retain(|&id| id != player_id);

                if let GameState::Playing { ref mut seeker, .. } = &mut game.state {
                    if game.players.len() < 2 {
                        self.end_game(ctx, game_id);
                    } else if *seeker == player_id {
                        *seeker = *game.players.choose(&mut self.rng).unwrap();
                    }
                } else if game.players.is_empty() {
                    self.cancel_game(ctx, game_id);
                } else if game.host == player_id {
                    game.host = game.players[0];
                    new_host = game.host;
                }
                
                self.broadcast(game_id, ServerEvent::PlayerLeft { id: player_id, new_host }, Some(player_id));
                return Some(ServerEvent::LeftGame);
            }
        }

        Self::error("Could not leave game")
    }

    fn start(&mut self, ctx: &mut Context<GameServer>, player_id: i64) -> Option<ServerEvent> {
        if let Some(game_id) = self.find_game(player_id) {
            if let Some(game) = self.games.get_mut(&game_id) {
                if game.host != player_id {
                    return Self::error("Only the host can start the game");
                }

                if game.players.len() < 2 {
                    return Self::error("Not enough players to start the game");
                }

                let scores = game.players.iter().map(|&id| (id, 0.0)).collect();
                let seeker = *game.players.choose(&mut self.rng).unwrap();
                game.state = GameState::Playing { 
                    handle: ctx.run_interval(
                        UPDATE_INTERVAL,
                        move |act, ctx| {
                            act.update_game(ctx, game_id);
                        }
                    ),
                    seeker: seeker,
                    start: Instant::now(),
                    scores
                };

                self.broadcast(game_id, ServerEvent::GameStarted { seeker }, None);
                return None;
            }
        }

        Self::error("Could not start game")
    }

    fn set_pos(&mut self, player_id: i64, pos: Point) -> Option<ServerEvent> {
        let player = match self.get_player_mut(player_id) {
            Ok(value) => value,
            Err(value) => return value,
        };

        player.pos = Some(pos);
        println!("{} moved to {:?}", player.name, pos);
        None
    }

    fn tag(&mut self, player_id: i64, other_id: i64) -> Option<ServerEvent> {
        if let Some(game_id) = self.find_game(player_id) {
            if let Some(game) = self.games.get_mut(&game_id) {
                if let GameState::Playing { ref mut seeker, .. } = game.state {
                    if player_id != *seeker {
                        return Self::error("Only the seeker can tag");
                    }

                    if game.players.contains(&other_id) {
                        *seeker = other_id;
                        self.broadcast(game_id, ServerEvent::PlayerTagged { tagger: player_id, tagged: other_id }, None);
                        return None;
                    } 
                }
            }
        }

        Self::error("Could not tag player")
    }
}

impl Handler<Disconnect> for GameServer {
    type Result = ();

    fn handle(&mut self, msg: Disconnect, ctx: &mut Context<Self>) -> Self::Result {
        if let Some(player) = self.players.get_mut(&msg.id) {
            println!("{} disconnected", player.name);

            self.leave(ctx, msg.id);
            self.players.remove(&msg.id);
        }
    }
}

impl Handler<Connect> for GameServer {
    type Result = MessageResult<Connect>;

    fn handle(&mut self, msg: Connect, _: &mut Context<Self>) -> Self::Result {
        let id = generate_id(&mut self.rng, &self.players);
        println!("{} connected", msg.name);
        
        let player = Player {
            name: msg.name,
            addr: msg.addr,
            pos: None,
        };

        self.players.insert(id, player);

        MessageResult(id)
    }
}