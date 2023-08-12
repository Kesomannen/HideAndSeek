use std::collections::HashMap;
use actix::prelude::*;
use rand::seq::SliceRandom;
use rand::{rngs::ThreadRng, Rng};
use uuid::Uuid;

use crate::message::*;
use crate::message::ServerMessage;

#[derive(Clone)]
pub enum GameState {
    Waiting,
    Playing { seeker: Uuid },
    Ended { winner: Uuid },
}

pub struct Player {
    pub name: String,
    pub addr: Recipient<ServerMessage>,
    pub score: Option<f32>,
    pub game: Option<u32>
}

pub struct Game {
    pub host: Uuid,
    pub players: Vec<Uuid>,
    pub state: GameState,
}

impl Game {
    pub fn new(host: Uuid) -> Self {
        Self {
            host,
            players: vec![host],
            state: GameState::Waiting,
        }
    }
}

pub struct GameServer {
    players: HashMap<Uuid, Player>,
    games: HashMap<u32, Game>,
    rng: ThreadRng,
}

impl GameServer {
    pub fn new() -> Self {
        Self {
            games: HashMap::new(),
            players: HashMap::new(),
            rng: rand::thread_rng(),
        }
    }

    fn send_message(&self, game_id: u32, message: &str) {
        if let Some(game) = self.games.get(&game_id) {
            for id in &game.players {
                if let Some(player) = self.players.get(id) {
                    player.addr.do_send(ServerMessage(message.to_owned()));
                }
            }
        }
    }
}

impl Actor for GameServer {
    type Context = Context<Self>;
}

impl Handler<Connect> for GameServer {
    type Result = MessageResult<Connect>;

    fn handle(&mut self, msg: Connect, _: &mut Self::Context) -> Self::Result {
        let id = Uuid::new_v4();
        
        let player = Player {
            name: msg.name.unwrap_or_else(|| "Anonymous".to_owned()),
            addr: msg.recipient,
            score: None,
            game: None,
        };

        self.players.insert(id, player);

        MessageResult(id)
    }
}

impl Handler<JoinGame> for GameServer {
    type Result = MessageResult<JoinGame>;

    fn handle(&mut self, msg: JoinGame, _: &mut Context<Self>) -> Self::Result {
        if let Some(game) = self.games.get_mut(&msg.game_id) {
            match game.state {
                GameState::Waiting => {
                    game.players.push(msg.id);
                    self.send_message(msg.game_id, &format!("{} joined the game", self.players[&msg.id].name));
                },
                GameState::Playing { seeker: _ } => return MessageResult(JoinGameResponse::InProgress),
                GameState::Ended { winner: _ } => return MessageResult(JoinGameResponse::Ended),
            };
        } else {
            return MessageResult(JoinGameResponse::DoesNotExist);
        }

        MessageResult(JoinGameResponse::Success)
    }
}

impl Handler<Disconnect> for GameServer {
    type Result = ();

    fn handle(&mut self, msg: Disconnect, _: &mut Context<Self>) -> Self::Result {
        if let Some(player) = self.players.remove(&msg.id) {
            if let Some(game_id) = player.game {
                if let Some(game) = self.games.get_mut(&game_id) {
                    game.players.retain(|id| *id != msg.id);
                    
                    if game.players.is_empty() {
                        todo!()
                    } else if game.host == msg.id {
                        game.host = game.players[0];
                        self.send_message(game_id, &format!("{} left the game", player.name))
                    }
                }
            }
        }
    }
}

impl Handler<CreateGame> for GameServer {
    type Result = u32;

    fn handle(&mut self, msg: CreateGame, _: &mut Context<Self>) -> Self::Result {
        let id = self.rng.gen();
        self.games.insert(id, Game::new(msg.host_id));
        id
    }
}

impl Handler<StartGame> for GameServer {
    type Result = MessageResult<StartGame>;

    fn handle(&mut self, msg: StartGame, _: &mut Self::Context) -> Self::Result {
        if let Some(game) = self.games.get_mut(&msg.game) {
            if game.host != msg.id {
                return MessageResult(StartGameResponse::NoPermission);
            }

            if game.players.len() < 2 {
                return MessageResult(StartGameResponse::NotEnoughPlayers);
            }

            let seeker = game.players.choose(&mut self.rng).unwrap();
            game.state = GameState::Playing { seeker: *seeker };
            
            return MessageResult(StartGameResponse::Success);
        }

        MessageResult(StartGameResponse::DoesNotExist)
    }
}