use std::time::{Duration, Instant};

use actix::prelude::*;
use actix_web_actors::ws;
use uuid::Uuid;

use crate::server::GameServer;
use crate::message::*;
use crate::socket_message::{ServerMessage, ClientMessage};

const HEARTBEAT_INTERVAL: Duration = Duration::from_secs(5);
const CLIENT_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Debug)]
pub struct Session {
    hb: Instant,
    name: Option<String>,
    id: Option<Uuid>,
    game: Option<u32>,
    server: Addr<GameServer>,
}

impl Session {
    pub fn new(server_addr: Addr<GameServer>) -> Self {
        Self {
            id: None,
            hb: Instant::now(),
            name: None,
            game: None,
            server: server_addr,
        }
    }

    fn heartbeat(&self, ctx: &mut ws::WebsocketContext<Self>) {
        ctx.run_interval(HEARTBEAT_INTERVAL, |actor, ctx| {
            if Instant::now().duration_since(actor.hb) > CLIENT_TIMEOUT {
                actor.send_error(ctx, "Disconnected: Heartbeat failed");

                if let Some(id) = actor.id {
                    actor.server.do_send(Disconnect { id });
                }

                ctx.stop();
                return;
            }

            ctx.ping(b"");
        });
    }

    fn join_game(&mut self, game: u32, ctx: &mut ws::WebsocketContext<Self>) {
        if let None = self.id {
            self.send_error(ctx, "Could not join game: Not connected");
            return;
        }

        self.server
            .send(JoinGame {
                game_id: game,
                id: self.id.unwrap(),
            })
            .into_actor(self)
            .then(move |res, actor, ctx| {
                if let Ok(res) = res {
                    match res {
                        JoinGameResponse::DoesNotExist => {
                            actor.send_error(ctx, "Could not join game: Game does not exist");
                        },
                        JoinGameResponse::InProgress => {
                            actor.send_error(ctx, "Could not join game: Game is already in progress");
                        },
                        JoinGameResponse::Ended => {
                            actor.send_error(ctx, "Could not join game: Game has already ended");
                        },
                        JoinGameResponse::Success => {
                            actor.game = Some(game);
                            ctx.text(ServerMessage::JoinedGame{game}.to_string());
                        },
                    }
                } else {
                    actor.send_error(ctx, "Could not join game: Server error");
                }

                fut::ready(())
            })
            .wait(ctx);
    }

    fn create_game(&mut self, ctx: &mut ws::WebsocketContext<Self>) {
        if let None = self.id {
            self.send_error(ctx, "Could not create game: Not connected");
            return;
        }

        self.server
            .send(CreateGame { host_id: self.id.unwrap() })
            .into_actor(self)
            .then(|res, actor, ctx| {
                match res {
                    Ok(game) => {
                        actor.game = Some(game);
                        ctx.text(ServerMessage::JoinedGame{game}.to_string());
                    },
                    Err(_) => {
                        actor.send_error(ctx, "Could not create game: Server error");
                    }
                }

                fut::ready(())
            })
            .wait(ctx);
    }

    fn start_game(&mut self, ctx: &mut ws::WebsocketContext<Self>) {
        if let None = self.id {
            self.send_error(ctx, "Could not start game: Not connected");
            return;
        }

        if let None = self.game {
            self.send_error(ctx, "Could not start game: Not in a game");
            return;
        }

        self.server
            .send(StartGame { id: self.id.unwrap(), game: self.game.unwrap() })
            .into_actor(self)
            .then(|res, actor, ctx| {
                match res {
                    Ok(response) => match response {
                        StartGameResponse::NoPermission => {
                            actor.send_error(ctx, "Could not start game: No permission");
                        },
                        StartGameResponse::NotEnoughPlayers => {
                            actor.send_error(ctx, "Could not start game: Not enough players");
                        },
                        StartGameResponse::DoesNotExist => {
                            actor.send_error(ctx, "Could not start game: Game does not exist");
                        }
                        StartGameResponse::Success => (),
                    }
                    Err(_) => actor.send_error(ctx, "Could not start game: Server error")
                }

                fut::ready(())
            })
            .wait(ctx);
    }

    fn connect_to_server(&mut self, name: String, ctx: &mut ws::WebsocketContext<Self>) {
        self.name = Some(name);
        self.server
            .send(Connect {
                recipient: ctx.address().recipient(),
                name: self.name.clone().unwrap()
            })
            .into_actor(self)
            .then(|res, actor, ctx| {
                match res {
                    Ok(id) => actor.id = Some(id),
                    Err(_) => {
                        actor.send_error(ctx, "Could not connect to server");
                        ctx.stop();
                    }
                }

                fut::ready(())
            })
            .wait(ctx);
    }

    fn send_error(&self, ctx: &mut ws::WebsocketContext<Self>, msg: &str) {
        println!("Sending error to socket: {}", msg);
        ctx.text(ServerMessage::Error{message: msg.to_owned()}.to_string() );
    }

    fn send_info(&self, ctx: &mut ws::WebsocketContext<Self>, msg: &str) {
        println!("Sending info to socket: {}", msg);
        ctx.text(ServerMessage::Info{message: msg.to_owned()}.to_string());
    }
}

impl Actor for Session {
    type Context = ws::WebsocketContext<Self>;

    fn started(&mut self, ctx: &mut Self::Context) {
        self.heartbeat(ctx);
    }

    fn stopping(&mut self, _: &mut Self::Context) -> Running {
        if let Some(id) = self.id {
            self.server.do_send(Disconnect { id });
        }

        Running::Stop
    }
}

impl Handler<LogMessage> for Session {
    type Result = ();

    fn handle(&mut self, msg: LogMessage, ctx: &mut Self::Context) -> Self::Result {
        self.send_info(ctx, msg.0.as_str());
    }
}

impl StreamHandler<Result<ws::Message, ws::ProtocolError>> for Session {
    fn handle(&mut self, message: Result<ws::Message, ws::ProtocolError>, ctx: &mut Self::Context) {
        let message = match message {
            Err(_) => {
                ctx.stop();
                return;
            },
            Ok(m) => m,
        };

        match message {
            ws::Message::Ping(msg) => {
                self.hb = Instant::now();
                ctx.pong(&msg);
            },
            ws::Message::Pong(_) => {
                self.hb = Instant::now();
            },
            ws::Message::Text(text) => {
                let message: ClientMessage = match serde_json::from_str(&text) {
                    Ok(m) => m,
                    Err(_) => {
                        self.send_error(ctx, format!("Invalid message: {:?}", text).as_str());
                        return;
                    },
                };

                println!("Received message from socket: {:?}", message);

                match message {
                    ClientMessage::JoinGame { game } => self.join_game(game, ctx),
                    ClientMessage::CreateGame => self.create_game(ctx),
                    ClientMessage::StartGame => self.start_game(ctx),
                    ClientMessage::Connect { name } => self.connect_to_server(name, ctx),
                }
            },
            ws::Message::Close(reason) => {
                ctx.close(reason);
                ctx.stop();
            },
            _ => self.send_error(ctx, format!("Invalid message: {:?}", message).as_str())
        }
    }
}