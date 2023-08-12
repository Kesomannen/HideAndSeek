import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connection.dart';

class ConnectedPage extends StatefulWidget {
  const ConnectedPage({super.key});

  @override
  State<ConnectedPage> createState() => _ConnectedPageState();
}

class _ConnectedPageState extends State<ConnectedPage> {
  bool _isCreating = false;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            TextButton(
              child: const Text('Create'),
              onPressed: () => setState(() => _isCreating = true),
            ),
            TextButton(
              child: const Text('Join'),
              onPressed: () => setState(() => _isCreating = false),
            )
          ],
        ),
        Builder(builder: (context) {
          if (_isCreating) {
            return const CreateGamePage();
          } else {
            return const JoinGamePage();
          }
        })
      ],
    );
  }
}

class CreateGamePage extends StatelessWidget {
  const CreateGamePage({super.key});

  @override
  Widget build(BuildContext context) {
    var connection = Provider.of<Connection>(context);

    return ElevatedButton(
      onPressed: () => connection.createGame(),
      child: const Text('Create Game')
    );
  }
}

class JoinGamePage extends StatefulWidget {
  const JoinGamePage({super.key});

  @override
  State<JoinGamePage> createState() => _JoinGamePageState();
}

class _JoinGamePageState extends State<JoinGamePage> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var connection = Provider.of<Connection>(context);

    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _controller,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a game code';
              }

              if (int.tryParse(value) == null) {
                return 'Please enter a valid game code';
              }

              return null;
            },
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                connection.joinGame(int.parse(_controller.text));
              }
            }, 
            child: const Text('Join Game')
          )
        ]
      ),
    );
  }
}