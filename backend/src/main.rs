use actix::prelude::*;
use actix_web::{web, App, HttpResponse, HttpServer, HttpRequest, get};
use actix_web_actors::ws;

use client::Session;

mod server;
mod client;
mod message;
mod util;

#[get("/")]
async fn entry_point(
    req: HttpRequest,
    stream: web::Payload,
    server: web::Data<Addr<server::GameServer>>,
) -> Result<HttpResponse, actix_web::Error> {
    ws::start(
        Session::new(server.get_ref().clone()),
        &req, 
        stream
    )
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init_from_env(env_logger::Env::new().default_filter_or("info"));
    let server = server::GameServer::new().start();

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(server.clone()))
            .service(entry_point)
    })
    .bind(("0.0.0.0", 8080))?
    .run()
    .await
}