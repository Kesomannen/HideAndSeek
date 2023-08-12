class Message {
  MessageType type;
  Map<String, dynamic> data;  

  Message(this.type, this.data);

  Message.fromJson(Map<String, dynamic> json) :
    type = MessageType.values[json['type']],
    data = json['data'];

  Map<String, dynamic> toJson() => {
    'type': type.toString(),
    'data': data
  };

  Message.joinGame(int gameId) :
    type = MessageType.JoinGame,
    data = {
      'game': gameId
    };

  Message.setName(String name) :
    type = MessageType.SetName,
    data = {
      'name': name
    };

  Message.startGame() :
    type = MessageType.StartGame,
    data = {};

  Message.createGame() :
    type = MessageType.CreateGame,
    data = {};
}

enum MessageType {
  Info,
  Error,
  JoinGame,
  SetName,
  StartGame,
  CreateGame
}