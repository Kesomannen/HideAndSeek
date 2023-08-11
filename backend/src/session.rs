use std::time::{Duration, Instant};

use actix::prelude::*;
use actix_web_actors::ws;
use crate::server;

const HEARTBEAT_INTERVAL: Duration = Duration::from_secs(5);
const CLIENT_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Debug)]
pub struct PlayerSession {
    pub id: usize,
    pub last_heartbeat: Instant,
    pub game: usize,
    pub name: Option<String>,
    pub server_addr: Addr<server::GameServer>,
}

impl PlayerSession {
    pub fn new(game: usize, server_addr: Addr<server::GameServer>) -> Self {
        Self {
            id: 0,
            last_heartbeat: Instant::now(),
            game,
            name: None,
            server_addr,
        }
    }

    fn heartbeat(&self, ctx: &mut ws::WebsocketContext<Self>) {
        ctx.run_interval(HEARTBEAT_INTERVAL, |session, ctx| {
            if Instant::now().duration_since(session.last_heartbeat) > CLIENT_TIMEOUT {
                println!("Websocket Client timed out, disconnecting.");

                session.server_addr.do_send(server::Disconnect { id: session.id });
                ctx.stop();
                return;
            }

            ctx.ping(b"");
        });
    }

    fn handle_command(&mut self, text: &str, ctx: &mut ws::WebsocketContext<PlayerSession>) {
        let parts: Vec<&str> = text.splitn(2, ' ').collect();
        match parts[0] {
            "/name" => {
                if parts.len() > 1 {
                    self.name = Some(parts[1].to_owned());
                    ctx.text(format!("Your name is now {}", self.name.as_ref().unwrap()));
                } else {
                    ctx.text("!!! please specify a name");
                }
            },
            "/list" => {
                self.server_addr
                    .send(server::ListPlayers { game: self.game })
                    .into_actor(self)
                    .then(|res, _, ctx| {
                        match res {
                            Ok(player_ids) => {
                                for id in player_ids {
                                    ctx.text(format!("Player {} is in the game", id));
                                }
                            },
                            _ => println!("Unable to list players")
                        }

                        fut::ready(())
                    })
                    .wait(ctx)
            }
            _ => ctx.text(format!("!!! unknown command: {text:?}"))
        }
    }
}

impl Actor for PlayerSession {
    type Context = ws::WebsocketContext<Self>;

    fn started(&mut self, ctx: &mut Self::Context) {
        self.heartbeat(ctx);

        let player_addr = ctx.address();
        self.server_addr
            .send(server::Connect {
                recipient: player_addr.recipient(),
                game: self.game,
            })
            .into_actor(self)
            .then(|res, act, ctx| {
                match res {
                    Ok(id) => act.id = id,
                    _ => ctx.stop(),
                }

                fut::ready(())
            })
            .wait(ctx);
    }

    fn stopping(&mut self, _: &mut Self::Context) -> Running {
        self.server_addr.do_send(server::Disconnect { id: self.id });
        Running::Stop
    }
}

impl Handler<server::Message> for PlayerSession {
    type Result = ();

    fn handle(&mut self, msg: server::Message, ctx: &mut Self::Context) -> Self::Result {
        ctx.text(msg.0);
    }
}

impl StreamHandler<Result<ws::Message, ws::ProtocolError>> for PlayerSession {
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
                self.last_heartbeat = Instant::now();
                ctx.pong(&msg);
            },
            ws::Message::Pong(_) => {
                self.last_heartbeat = Instant::now();
            },
            ws::Message::Text(text) => {
                let text = text.trim();

                if text.starts_with('/') {
                    self.handle_command(text, ctx);
                } else {
                    println!("Recieved text: {text:?}");
                }
            },
            ws::Message::Close(reason) => {
                ctx.close(reason);
                ctx.stop();
            },
            _ => println!("Unexpected message: {message:?}"),
        }
    }
}