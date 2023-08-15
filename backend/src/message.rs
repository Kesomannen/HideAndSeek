use std::collections::HashMap;
use actix::prelude::*;
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum ClientEvent {
    Connect { name: String },
    Chat { message: String },

    JoinGame { game: u16 },
    LeaveGame,
    CreateGame { x: f64, y: f64, minutes: u64 },
    StartGame,

    UpdatePosition { x: f64, y: f64 },
    TagPlayer { player: i64 },
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum ServerEvent {
    Connected { id: i64 },

    Chat { sender: i64, message: String },
    Error { message: String },

    JoinedGame { id: u16, x: f64, y: f64, players: Vec<(i64, String)>, host: i64 },
    PlayerJoined { id: i64, name: String },
    PlayerLeft { id: i64, new_host: i64 },
    LeftGame,

    GameStarted { seeker: i64 },
    GameUpdate { players: HashMap<i64, PlayerData>, time_left: u64, },
    GameEnded { winner: i64 }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct PlayerData {
    pub name: String,
    pub score: f32,
    pub is_seeker: bool,
}

impl ServerEvent {
    pub fn to_string(&self) -> String {
        serde_json::to_string(self).unwrap()
    }

    pub fn error(message: &str) -> Self {
        Self::Error { message: message.to_string() }
    }
}

#[derive(Message)]
#[rtype(i64)]
pub struct Connect {
    pub addr: Recipient<ServerMessage>,
    pub name: String,
}

#[derive(Message)]
#[rtype(result = "()")]
pub struct Disconnect {
    pub id: i64,
}

pub struct ClientMessage {
    pub sender: i64,
    pub event: ClientEvent,
}

impl actix::Message for ClientMessage {
    type Result = Option<ServerEvent>;
}


#[derive(Message)]
#[rtype(result = "()")]
pub struct ServerMessage {
    pub event: ServerEvent,
}