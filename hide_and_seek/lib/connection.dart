import 'dart:collection';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hide_and_seek/location.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'message.dart';

const Duration _posUpdateInterval = Duration(seconds: 5);

enum GameConnection {
  disconnected,
  connected,
  inGame
}

class Connection extends ChangeNotifier {
  final BuildContext _context;

  GameConnection _state = GameConnection.disconnected;

  int? _playerId;
  String? _playerName;

  WebSocketChannel? _channel;
  GameState? _gameState;

  int? get playerId => _playerId;
  String? get playerName => _playerName;
  bool? get isHost => _gameState?.host == _playerId;

  GameConnection get state => _state;
  GameState? get gameState => _gameState;

  Connection(this._context);

  _setState(GameConnection newState) {
    _state = newState;
    notifyListeners();
  }

  _chat(String message, {String? sender}) {
    _gameState?.messages.add((sender, message));
    notifyListeners();
  }

  send(ClientMessage message) {
    print("Sending event: ${jsonEncode(message)}");
    _channel?.sink.add(jsonEncode(message));
  }

  connect(String name) {
    print("Connecting...");

    _channel?.sink.close();
    _playerName = name;

    _channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.1.27:8080/'),
    );

    _channel!.ready
      .then((value) {
        send(ClientMessage.connect(name));
      });

    _channel!.stream.listen(_handleEvent);
  }

  void _handleEvent(event) {
    print("Received event: $event");
    final json = jsonDecode(event);
    final message = json is String ? ServerMessage.fromString(json) : ServerMessage.fromJson(json);
  
    switch (message.event) {
      case ServerEvent.Connected:
        _playerId = message.data['id'];
        _setState(GameConnection.connected);
        break;

      case ServerEvent.Chat:
        if (_gameState == null) break;
        final sender = gameState!.players[message.data['sender']]?.name ?? "Unknown";
        _chat(message.data['message'], sender: sender);
        break;
      
      case ServerEvent.Error:
        _snackBarMessage(message.data['message']);
        break;
      
      case ServerEvent.JoinedGame:
        final players = message.data['players'];
        
        _gameState = GameState(
          HashMap.fromIterable(players, key: (p) => p[0], value: (p) => PlayerData(p[1])),
          message.data['id'],
          message.data['x'],
          message.data['y'],
          message.data['host']
        );

        _gameState!.players[_playerId!] = PlayerData(_playerName!);

        _setState(GameConnection.inGame);
        break;

      case ServerEvent.PlayerJoined:
        final name = message.data['name'];
        
        _gameState?.players[message.data['id']] = PlayerData(name);
        _chat("$name joined the game");

        notifyListeners();
        break;

      case ServerEvent.PlayerLeft:
        if (_gameState == null) break;

        final name = _gameState!.players[message.data['id']]?.name ?? "Unknown";

        _gameState?.players.remove(message.data['id']);
        _gameState?.host = message.data['new_host'];
        _chat("$name left the game");

        notifyListeners();
        break;

      case ServerEvent.LeftGame:
        _gameState = null;
        _setState(GameConnection.connected);
        break;

      case ServerEvent.GameStarted:
        _gameState?.players[message.data['seeker']]?.isSeeker = true;
        _gameState?.playing = true;

        _updatePositionLoop();
        notifyListeners();
        break;
      
      case ServerEvent.GameEnded:
        notifyListeners();
        break;

      case ServerEvent.GameUpdate:
        if (_gameState == null) break;

        _gameState!.secondsLeft = message.data['time_left'];

        final players = message.data['players'];
        for (final player in _gameState!.players.entries) {
          final data = players[player.key.toString()]!;
          player.value.score = data['score'];
          player.value.isSeeker = data['is_seeker'];
        }

        notifyListeners();
        break;
    }
  }

  void _updatePositionLoop() async {
    while (_gameState != null && _gameState!.playing) {
      try {
        final pos = await determinePosition();  
        send(ClientMessage.updatePosition(pos.latitude, pos.longitude));      
      } on ServiceDisabled {
        _snackBarMessage("Location service disabled");
      } on PermissionDenied {
        _snackBarMessage("No location permission");
      } on PermissionDeniedForever {
        _snackBarMessage("No location permission");
      }

      await Future.delayed(_posUpdateInterval);
    }
  }

  void _snackBarMessage(String text) {
    ScaffoldMessenger.of(_context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: "Dismiss", onPressed: () {}),
      )
    );
  }

  disconnect() {
    _channel?.sink.close()
      .then((_) => _setState(GameConnection.disconnected));
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}

class GameState {
  Map<int, PlayerData> players;
  int id;
  double x, y;

  int host; 
  int secondsLeft;
  bool playing;

  List<(String?, String)> messages;

  GameState(this.players, this.id, this.x, this.y, this.host) : playing = false, messages = [], secondsLeft = 0;
}

class PlayerData {
  String name;
  double score;
  bool isSeeker;

  PlayerData(this.name) : score = 0, isSeeker = false;
}