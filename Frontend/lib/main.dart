import 'package:flutter/material.dart';
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
  bool inGame = false;

  void startGame() {
    inGame = true; 
    notifyListeners();
  }

  void endGame() {
    inGame = false;
    notifyListeners();
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
    return Form(
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
                state.startGame();
              }
            }, 
            child: const Text('Join Game')
          ),
        ],
      ),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final _channel = WebSocketChannel.connect(
    Uri.parse('ws://localhost:8080/ws'),
  );
  
  @override
  Widget build(BuildContext context) {
    var state = Provider.of<AppState>(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StreamBuilder(
          stream: _channel.stream,
          builder: (context, snapshot) {
            return Text(snapshot.hasData ? 'Received message: ${snapshot.data}' : '');
          },
        ),
        ElevatedButton( 
          onPressed: () => {
            state.endGame()
          }, 
          child: const Text('Leave Game')
        )
      ]
    );
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }
}