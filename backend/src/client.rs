use std::time::{Duration, Instant};

use actix::prelude::*;
use actix_web_actors::ws;

use crate::server::*;
use crate::message::*;

const HEARTBEAT_INTERVAL: Duration = Duration::from_secs(5);
const CLIENT_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Debug)]
pub struct Session {
    hb: Instant,
    id: Option<i64>,
    server: Addr<GameServer>
}

impl Session {
    pub fn new(server_addr: Addr<GameServer>) -> Self {
        Self {
            id: None,
            hb: Instant::now(),
            server: server_addr,
        }
    }

    fn heartbeat(&self, ctx: &mut ws::WebsocketContext<Self>) {
        ctx.run_interval(HEARTBEAT_INTERVAL, |actor, ctx| {
            if Instant::now().duration_since(actor.hb) > CLIENT_TIMEOUT {
                actor.error(ctx, "Disconnected: heartbeat failed");

                if let Some(id) = actor.id {
                    actor.server.do_send(Disconnect { id });
                }

                ctx.stop();
                return;
            }

            ctx.ping(b"");
        });
    }

    fn send_server(
        &mut self,
        ctx: &mut ws::WebsocketContext<Self>,
        event: ClientEvent,
    ) {
        if let Some(id) = self.id {
            self.send_message_server(ctx, ClientMessage { sender: id, event }, |act, ctx, res| {
                if let Some(res) = res {
                    // forward message to client, if any
                    act.send_client(ctx, res);
                }
            })
        } else {
            self.error(ctx, "Not connected");
        }
    }

    fn connect(&mut self, ctx: &mut ws::WebsocketContext<Self>, name: String) {
        if let Some(_) = self.id {
            self.error(ctx, "Already connected");
        }

        self.send_message_server(ctx, 
            Connect { addr: ctx.address().recipient(), name }, 
            |act, ctx, res| {
                act.id = Some(res);
                act.send_client(ctx, ServerEvent::Connected { id: res });
            }
        );
    }

    fn send_message_server<F, M>(
        &mut self,
        ctx: &mut ws::WebsocketContext<Self>,
        message: M,
        handler: F
    ) where 
        F: FnOnce(&mut Self, &mut ws::WebsocketContext<Self>, M::Result) + 'static,
        M: Message + 'static + Send,
        M::Result: Send,
        GameServer: Handler<M>,
    {
        self.server
            .send(message)
            .into_actor(self)
            .then(move |res, act, ctx| {
                match res {
                    Ok(res) => handler(act, ctx, res),
                    Err(err) => {
                        match err {
                            MailboxError::Closed => act.error(ctx, "Server closed"),
                            MailboxError::Timeout => act.error(ctx, "Server timed out")
                        }
                    }
                }

                fut::ready(())
            })
            .wait(ctx);
    }

    fn error(&self, ctx: &mut ws::WebsocketContext<Self>, msg: &str) {
        self.send_client(ctx, ServerEvent::Error { message: msg.to_string() });
    }

    fn send_client(&self, ctx: &mut ws::WebsocketContext<Self>, event: ServerEvent) {
        ctx.text(event.to_string());
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

impl Handler<ServerMessage> for Session {
    type Result = ();

    fn handle(&mut self, msg: ServerMessage, ctx: &mut Self::Context) -> Self::Result {
        self.send_client(ctx, msg.event);
    }
}

impl StreamHandler<Result<ws::Message, ws::ProtocolError>> for Session {
    fn handle(&mut self, message: Result<ws::Message, ws::ProtocolError>, ctx: &mut Self::Context) {
        let message = match message {
            Ok(m) => m,
            Err(error) => {
                println!("Web scoket error: {error:?}");
                ctx.stop();
                return;
            },
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
                if let Ok(event) = serde_json::from_str(&text) {
                    if let ClientEvent::Connect { name } = event {
                        self.connect(ctx, name);
                    } else {
                        self.send_server(ctx, event);
                    }
                } else {
                    self.error(ctx, format!("Invalid event: {:?}", text).as_str());
                }
            },
            ws::Message::Close(reason) => {
                ctx.close(reason);
                ctx.stop();
            },
            _ => self.error(ctx, format!("Invalid message: {:?}", message).as_str())
        }
    }
}