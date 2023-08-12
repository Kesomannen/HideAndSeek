use serde::{Deserialize, Serialize};

impl Message {
    pub fn to_string(&self) -> String {
        serde_json::to_string(self).unwrap()
    }
}


#[derive(Serialize, Deserialize)]
pub enum Message {
    Info { message: String },
    Error { message: String },
    JoinGame { game: u32 },
    SetName { name: String },
    StartGame,
    CreateGame,
}