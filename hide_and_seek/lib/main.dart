import 'package:flutter/material.dart';
import 'package:hide_and_seek/camera.dart';
import 'package:provider/provider.dart';

import 'package:hide_and_seek/connection.dart';
import 'package:hide_and_seek/pages/connected.dart';
import 'package:hide_and_seek/pages/disconnected.dart';
import 'package:hide_and_seek/pages/in_game.dart';

void main() {
  initializeCameras();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hide and Seek',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple, brightness: Brightness.dark),
        useMaterial3: true
      ),
      home: ChangeNotifierProvider(
        create: (context) => Connection(context),
        child: const Scaffold(
          body: PageHandler(),
        )
      )
    );
  }
}

class PageHandler extends StatelessWidget {
  const PageHandler({super.key});

  @override
  Widget build(BuildContext context) {
    var state = Provider.of<Connection>(context);

    return SafeArea(
      child: Center(
        child: Builder(
          builder: (context) {
            switch (state.state) {
              case GameConnectionState.disconnected:
                return const DisconnectedPage();
              case GameConnectionState.connected:
                return const ConnectedPage();
              case GameConnectionState.inGame:
                return const InGamePage();
            }
          }
        )
      ),
    );
  }
}