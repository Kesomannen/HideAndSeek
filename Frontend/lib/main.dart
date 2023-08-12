import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hide_and_seek_frontend/json.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() => runApp(const MainApp());

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    const title = 'Hide and Seek';

    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const MaterialApp(
        title: title,
        home: Scaffold(
          body: PageHandler(),
        )
      ),
    );
  }
}

class AppState extends ChangeNotifier {
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://localhost:8080/ws'),
  );
  
  bool inGame = false;

  joinGame(int gameId) {
    var message = Message.joinGame(gameId);
    channel.sink.add(jsonEncode(message));
  }
  
  createGame() {
    var message = Message.createGame();
    channel.sink.add(jsonEncode(message));
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }
}

class PageHandler extends StatelessWidget {
  const PageHandler({super.key});

  @override
  Widget build(BuildContext context) {
    var state = Provider.of<AppState>(context);
    return Padding(
      padding: const EdgeInsets.all(25.0),
      child: Center(child: state.inGame ? const GamePage() : const HomePage()),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _formKey = GlobalKey<FormState>();
  
  @override
  Widget build(BuildContext context) {
    var state = Provider.of<AppState>(context);
    return Column(
      children: [
        Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  hintText: 'Enter game code',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a game code';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    state.joinGame(0);
                  }
                }, 
                child: const Text('Join Game')
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => {
            state.createGame()
          }, 
          child: const Text('Create Game')
        )
      ],
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  @override
  Widget build(BuildContext context) {
    var state = Provider.of<AppState>(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StreamBuilder(
          stream: state.channel.stream,
          builder: (context, snapshot) {
            var text = '';

            if (snapshot.hasData) {
              var map = jsonDecode(snapshot.data.toString());
              var message = Message.fromJson(map);

              switch (message.type) {
                case MessageType.Info:
                  text = '[INFO] ${message.data['message']}';
                  break;

                case MessageType.Error:
                  text = '[ERROR] ${message.data['message']}';
                  break;

                default:
                  text = 'Unknown message type';
                  break;
              }
            }

            return Text(text);
          },
        ),
        ElevatedButton( 
          onPressed: () => {
            // TODO: Implement
          }, 
          child: const Text('Leave Game')
        )
      ]
    );
  }
}