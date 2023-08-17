// ignore_for_file: constant_identifier_names

import 'dart:convert';

import 'package:flutter/services.dart';

class ClientMessage {
    ClientEvent event;
    Map<String, dynamic> data;

    ClientMessage(this.event, this.data);

    Map<String, dynamic> toJson() {
      return {
        event.toString().split('.')[1] : data.isEmpty ? null : data
      };
    }

    ClientMessage.connect(String name) :
      event = ClientEvent.Connect,
      data = {
        'name': name
      };
    
    ClientMessage.chat(String message) :
        event = ClientEvent.Chat,
        data = {
            'message': message
        };

    ClientMessage.joinGame(int gameId) :
        event = ClientEvent.JoinGame,
        data = {
            'game': gameId
        };

    ClientMessage.leaveGame() :
        event = ClientEvent.LeaveGame,
        data = {};

    ClientMessage.createGame(double x, double y, int minutes) :
        event = ClientEvent.CreateGame,
        data = {
            'x' : x,
            'y' : y,
            'minutes': minutes
        };

    ClientMessage.startGame() :
        event = ClientEvent.StartGame,
        data = {};

    ClientMessage.updatePosition(double x, double y) :
        event = ClientEvent.UpdatePosition,
        data = {
            'x': x,
            'y': y
        };

    ClientMessage.tagPlayer(int playerId, Uint8List photo) :
        event = ClientEvent.TagPlayer,
        data = {
            'player': playerId,
            'photo': base64Encode(photo)
        };
}

enum ClientEvent {
    Connect,
    Chat,
    JoinGame,
    LeaveGame,
    CreateGame,
    StartGame,
    UpdatePosition,
    TagPlayer,
}

class ServerMessage {
    ServerEvent event;
    Map<String, dynamic> data;

    ServerMessage(this.event, this.data);

    ServerMessage.fromJson(Map<String, dynamic> json) :
        event = _getType(json.keys.first),
        data = json.values.isEmpty ? {} : json.values.first;

    ServerMessage.fromString(String type) :
        event = _getType(type),
        data = {};

    static ServerEvent _getType(String type) {
        return ServerEvent.values.firstWhere((e) => e.toString() == 'ServerEvent.$type');
    }
}

enum ServerEvent {
    Connected,
    Chat,
    Error,
    JoinedGame,
    PlayerJoined,
    PlayerLeft,
    LeftGame,
    GameStarted,
    PlayerTagged,
    ScoreUpdate,
    GameEnded,
}