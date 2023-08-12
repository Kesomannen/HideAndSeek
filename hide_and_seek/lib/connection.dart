import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'message.dart';

enum GameConnectionState {
  disconnected,
  connected,
  inGame
}

class Connection extends ChangeNotifier {
  final BuildContext _context;

  GameConnectionState _state = GameConnectionState.disconnected;
  WebSocketChannel? _channel;

  GameConnectionState get state => _state;

  Connection(this._context);

  _setState(GameConnectionState newState) {
    _state = newState;
    notifyListeners();
  }

  _sendMessage(Message message) {
    _channel?.sink.add(jsonEncode(message));
  }

  connect(String name) async {
    print("Connecting...");

    _channel?.sink.close();

    _channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:8080/'),
    );

    _channel!.ready
      .then((value) {
        final message = Message.connect(name);
        _channel!.sink.add(jsonEncode(message));
        _setState(GameConnectionState.connected);
      });

    _channel!.stream.listen((event) {
      print("Received: $event");

      
      final message = Message.fromJson(jsonDecode(event));

      /*
      switch (message.type) {
        case MessageType.Info:
          ScaffoldMessenger.of(_context).showSnackBar(
            SnackBar(content: Text(message.data['message']))
          );
          break;

        case MessageType.Error:
          ScaffoldMessenger.of(_context).showSnackBar(
            SnackBar(content: Text(message.data["message"]))
          );
          break;

        case MessageType.JoinedGame:
          _setState(GameConnectionState.inGame);
          break;
        
        default:
          print("Unknown message type: ${message.type}");
      }
      */
    });
  }

  disconnect() {
    _channel?.sink.close()
      .then((_) => _setState(GameConnectionState.disconnected));
  }

  joinGame(int gameId) => _sendMessage(Message.joinGame(gameId));
  createGame() => _sendMessage(Message.createGame());

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}