use actix::prelude::*;
use uuid::Uuid;

#[derive(Message)]
#[rtype(result = "()")]
pub struct LogMessage(pub String);

#[derive(Message)]
#[rtype(Uuid)]
pub struct Connect {
    pub name: String,
    pub recipient: Recipient<LogMessage>,
}

#[derive(Message)]
#[rtype(JoinGameResponse)]
pub struct JoinGame {
    pub game_id: u32,
    pub id: Uuid,
}

pub enum JoinGameResponse {
    DoesNotExist,
    InProgress,
    Ended,
    Success
}

#[derive(Message)]
#[rtype(result = "()")]
pub struct Disconnect {
    pub id: Uuid,
}

#[derive(Message)]
#[rtype(u32)]
pub struct CreateGame {
    pub host_id: Uuid,
}

#[derive(Message)]
#[rtype(StartGameResponse)]
pub struct StartGame {
    pub game: u32,
    pub id: Uuid,
}

pub enum StartGameResponse {
    NoPermission,
    NotEnoughPlayers,
    Success,
    DoesNotExist,
}