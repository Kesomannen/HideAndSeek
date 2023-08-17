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
  Game? _game;

  int? get playerId => _playerId;
  String? get playerName => _playerName;
  bool get isHost => _game?.host == _playerId;

  GameConnectionState get state => _state;
  Game? get game => _game;
  double get currentDistance => _currentDistance;

  Connection(this._context);

  _setState(GameConnectionState newState) {
    _state = newState;
    notifyListeners();
  }

  _serverMessage(String message) {
    _game?.messages.add(ChatMessage.server(message));
    notifyListeners();
  }

  _chat(ChatMessage message) {
    _game?.messages.add(message);
    notifyListeners();
  }

  send(ClientMessage message) {
    _channel?.sink.add(jsonEncode(message));
  }

  Future<void> connect(String name) async {
    _channel?.sink.close();
    _playerName = name;

    _channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.1.27:8080/'),
    );

    await _channel!.ready;

    send(ClientMessage.connect(name));

    _channel!.stream.listen(_handleEvent);

    while (_state == GameConnectionState.disconnected) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
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
        if (_game == null) break;
        final sender = game!.players[message.data['sender']]?.name ?? "Unknown";
        _chat(ChatMessage(text: message.data['message'], sender: sender));
        break;
      
      case ServerEvent.Error:
        _snackBarMessage(message.data['message']);
        break;
      
      case ServerEvent.JoinedGame:
        final players = message.data['players'];
        
        _game = Game(
          HashMap.fromIterable(players, key: (p) => p[0], value: (p) => PlayerData(p[1])),
          message.data['id'],
          message.data['x'],
          message.data['y'],
          message.data['host']
        );

        _game!.players[_playerId!] = PlayerData(_playerName!);

        _setState(GameConnectionState.inGame);
        break;

      case ServerEvent.PlayerJoined:
        final name = message.data['name'];
        
        _game?.players[message.data['id']] = PlayerData(name);
        _serverMessage("$name joined the game");

        notifyListeners();
        break;

      case ServerEvent.PlayerLeft:
        if (_game == null) break;

        final name = _game!.players[message.data['id']]?.name ?? "Unknown";

        _game?.players.remove(message.data['id']);
        _game?.host = message.data['new_host'];
        _serverMessage("$name left the game");

        notifyListeners();
        break;

      case ServerEvent.LeftGame:
        _game = null;
        _setState(GameConnectionState.connected);
        break;

      case ServerEvent.GameStarted:
        _game?.seeker = message.data['seeker'];
        _game?.state = GameState.playing;

        _updatePositionLoop();
        notifyListeners();
        break;
      
      case ServerEvent.GameEnded:
        _game?.state = GameState.ended;
        _game?.winner = message.data['winner'];

        notifyListeners();
        break;

      case ServerEvent.ScoreUpdate:
        if (_game == null) break;

        _game!.secondsLeft = message.data['seconds_left'];

        final scores = message.data['scores'];
        for (final player in _game!.players.keys) {
          _game!.players[player]!.score = scores[player.toString()];
        }

        notifyListeners();
        break;
      
      case ServerEvent.PlayerTagged:
        if (_game == null) break;

        _game!.seeker = message.data['tagged'];
        final tagger = _game!.players[message.data['tagger']]?.name ?? "Unknown";
        final tagged = _game!.players[message.data['tagged']]?.name ?? "Unknown";
        
        _chat(ChatMessage(text: "$tagger tagged $tagged", image: message.data['photo']));
        notifyListeners();
        break;
    }
  }

  void _updatePositionLoop() async {
    while (_game != null && _game!.state == GameState.playing) {
      try {
        final pos = await determinePosition(); 
        send(ClientMessage.updatePosition(pos.latitude, pos.longitude));
        _currentDistance = Geolocator.distanceBetween(pos.latitude, pos.longitude, _game!.x, _game!.y);
      } on ServiceDisabled {
        _snackBarMessage("Location service disabled");
      } on PermissionDenied {
        _snackBarMessage("No location permission");
      } on PermissionDeniedForever {
        _snackBarMessage("Location permission denied forever");
      }

      await Future.delayed(_posUpdateInterval);
    }
  }

  void _snackBarMessage(String text) {
    ScaffoldMessenger.of(_context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
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
  int? seeker;
  int id;
  double x, y;

  int host; 
  int secondsLeft;
  GameState state;

  int? winner;

  List<ChatMessage> messages;

  Game(this.players, this.id, this.x, this.y, this.host) : state = GameState.waiting, messages = [], secondsLeft = 0;
}

class ChatMessage {
  String? sender;
  String? text;
  String? image;

  ChatMessage({this.sender, this.text, this.image});

  ChatMessage.server(this.text) : sender = null, image = null;
}

class PlayerData {
  String name;
  double score;

  PlayerData(this.name) : score = 0;
}

enum GameState {
  waiting,
  playing,
  ended
}