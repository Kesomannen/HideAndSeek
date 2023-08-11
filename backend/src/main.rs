use actix::prelude::*;
use actix_files::NamedFile;
use actix_web::{web, App, HttpResponse, HttpServer, HttpRequest, Error, Responder, get};
use actix_web_actors::ws;

mod server;
mod session;

#[get("/ws")]
async fn join_route(
    req_body: String,
    req: HttpRequest,
    stream: web::Payload,
    srv: web::Data<Addr<server::GameServer>>,
) -> Result<HttpResponse, Error> {
    println!("Incoming connection from: {:?}", req.connection_info());

    let game = match usize::from_str_radix(&req_body, 10) {
        Ok(game) => game,
        Err(_) => {
            return Ok(HttpResponse::BadRequest().finish());
        }
    };

    ws::start(
        session::PlayerSession::new(
            game,
            srv.get_ref().clone()
        ),
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
            .service(join_route)
    })
    .bind(("127.0.0.1", 8080))?
    .run()
    .await
}