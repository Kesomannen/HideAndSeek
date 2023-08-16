import 'dart:collection';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hide_and_seek/location.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'message.dart';

const Duration _posUpdateInterval = Duration(seconds: 5);

enum GameConnectionState {
  disconnected,
  connected,
  inGame
}

class Connection extends ChangeNotifier {
  final BuildContext _context;

  GameConnectionState _state = GameConnectionState.disconnected;

  int? _playerId;
  String? _playerName;
  double _currentDistance = 0;

  WebSocketChannel? _channel;
  Game? _gameState;

  int? get playerId => _playerId;
  String? get playerName => _playerName;
  bool get isHost => _gameState?.host == _playerId;

  GameConnectionState get state => _state;
  Game? get game => _gameState;
  double get currentDistance => _currentDistance;

  Connection(this._context);

  _setState(GameConnectionState newState) {
    _state = newState;
    notifyListeners();
  }

  _chat(String message, {String? sender}) {
    _gameState?.messages.add((sender, message));
    notifyListeners();
  }

  send(ClientMessage message) {
    _channel?.sink.add(jsonEncode(message));
  }

  connect(String name) {
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
    final json = jsonDecode(event);
    final message = json is String ? ServerMessage.fromString(json) : ServerMessage.fromJson(json);
  
    switch (message.event) {
      case ServerEvent.Connected:
        _playerId = message.data['id'];
        _setState(GameConnectionState.connected);
        break;

      case ServerEvent.Chat:
        if (_gameState == null) break;
        final sender = game!.players[message.data['sender']]?.name ?? "Unknown";
        _chat(message.data['message'], sender: sender);
        break;
      
      case ServerEvent.Error:
        _snackBarMessage(message.data['message']);
        break;
      
      case ServerEvent.JoinedGame:
        final players = message.data['players'];
        
        _gameState = Game(
          HashMap.fromIterable(players, key: (p) => p[0], value: (p) => PlayerData(p[1])),
          message.data['id'],
          message.data['x'],
          message.data['y'],
          message.data['host']
        );

        _gameState!.players[_playerId!] = PlayerData(_playerName!);

        _setState(GameConnectionState.inGame);
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
        _setState(GameConnectionState.connected);
        break;

      case ServerEvent.GameStarted:
        _gameState?.players[message.data['seeker']]?.isSeeker = true;
        _gameState?.state = GameState.playing;

        _updatePositionLoop();
        notifyListeners();
        break;
      
      case ServerEvent.GameEnded:
        _gameState?.state = GameState.ended;
        _gameState?.winner = message.data['winner'];

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
    while (_gameState != null && _gameState!.state == GameState.playing) {
      try {
        final pos = await determinePosition(); 
        send(ClientMessage.updatePosition(pos.latitude, pos.longitude));
        _currentDistance = Geolocator.distanceBetween(pos.latitude, pos.longitude, _gameState!.x, _gameState!.y);
        print(_currentDistance);
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
      .then((_) => _setState(GameConnectionState.disconnected));
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}

class Game {
  Map<int, PlayerData> players;
  int id;
  double x, y;

  int host; 
  int secondsLeft;
  GameState state;

  int? winner;

  List<(String?, String)> messages;

  Game(this.players, this.id, this.x, this.y, this.host) : state = GameState.waiting, messages = [], secondsLeft = 0;
}

enum GameState {
  waiting,
  playing,
  ended
}

class PlayerData {
  String name;
  double score;
  bool isSeeker;

  PlayerData(this.name) : score = 0, isSeeker = false;
}