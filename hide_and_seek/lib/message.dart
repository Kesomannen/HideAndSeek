class Message {
  MessageType type;
  Map<String, dynamic> data;

  Message(this.type, this.data);

  Message.fromJson(Map<String, dynamic> json) :
    type = MessageType.values[json[0]],
    data = json;

  Map<String, dynamic> toJson() => {
    type.toString().split('.')[1] : data.isEmpty ? null : data
  };

  Message.joinGame(int gameId) :
    type = MessageType.JoinGame,
    data = {
      'game': gameId
    };

  Message.startGame() :
    type = MessageType.StartGame,
    data = {};

  Message.createGame() :
    type = MessageType.CreateGame,
    data = {};

  Message.connect(String name) :
    type = MessageType.Connect,
    data = {
      'name': name
    };
}

enum MessageType {
  Info,
  Error,
  JoinGame,
  JoinedGame,
  Connect,
  StartGame,
  CreateGame
}