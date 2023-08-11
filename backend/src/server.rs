use std::collections::{HashMap, HashSet};
use actix::prelude::*;
use rand::{rngs::ThreadRng, Rng};

#[derive(Message)]
#[rtype(result = "()")]
pub struct Message(pub String);

#[derive(Message)]
#[rtype(usize)]
pub struct Connect {
    pub recipient: Recipient<Message>,
    pub game: usize,
}

#[derive(Message)]
#[rtype(result = "()")]
pub struct Disconnect {
    pub id: usize,
}

pub struct ListPlayers {
    pub game: usize,
}

impl actix::Message for ListPlayers {
    type Result = Vec<usize>;
}

#[derive(Debug)]
pub struct GameServer {
    sessions: HashMap<usize, Recipient<Message>>,
    games: HashMap<usize, HashSet<usize>>,
    rng: ThreadRng,
}

impl GameServer {
    pub fn new() -> Self {
        Self {
            sessions: HashMap::new(),
            games: HashMap::new(),
            rng: rand::thread_rng(),
        }
    }

    fn send_message(&self, game: usize, message: &str) {
        if let Some(ids) = self.games.get(&game) {
            for id in ids {
                if let Some(recipient) = self.sessions.get(id) {
                    recipient.do_send(Message(message.to_owned()));
                }
            }
        }
    }
}

impl Actor for GameServer {
    type Context = Context<Self>;
}

impl Handler<Connect> for GameServer {
    type Result = usize;

    fn handle(&mut self, msg: Connect, _: &mut Context<Self>) -> Self::Result {
        println!("A player joined game {}", msg.game);
        self.send_message(msg.game, "A player joined the game");

        let id = self.rng.gen();
        self.sessions.insert(id, msg.recipient);

        self.games
            .entry(msg.game)
            .or_insert_with(HashSet::new)
            .insert(id);

        id
    }
}

impl Handler<Disconnect> for GameServer {
    type Result = ();

    fn handle(&mut self, msg: Disconnect, _: &mut Context<Self>) -> Self::Result {
        println!("Player {} left", msg.id);

        if self.sessions.remove(&msg.id).is_some() {
            let mut game = None;
            for (game_id, session_ids) in &mut self.games {
                if session_ids.remove(&msg.id) {
                    game = Some(*game_id);
                }
            }

            if let Some(game_id) = game {
                self.send_message(game_id, "A player left the game");
            }
        }
    }
}

impl Handler<ListPlayers> for GameServer {
    type Result = MessageResult<ListPlayers>;

    fn handle(&mut self, msg: ListPlayers, _: &mut Context<Self>) -> Self::Result {
        println!("Listing players in game {}", msg.game);

        if let Some(ids) = self.games.get(&msg.game) {
            return MessageResult(ids.iter().cloned().collect());
        }

        MessageResult(Vec::new())
    }
}