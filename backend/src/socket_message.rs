use serde::{Deserialize, Serialize};

impl ServerMessage {
    pub fn to_string(&self) -> String {
        serde_json::to_string(self).unwrap()
    }
}


#[derive(Serialize, Deserialize, Debug)]
pub enum ClientMessage {
    JoinGame { game: u32 },
    Connect { name: String },
    StartGame,
    CreateGame,
}

#[derive(Serialize, Deserialize, Debug)]
pub enum ServerMessage {
    Info { message: String },
    Error { message: String },
    JoinedGame { game: u32 },
}