import 'package:flutter/material.dart';
import 'package:hide_and_seek/message.dart';
import 'package:provider/provider.dart';

import 'connection.dart';

class Chat extends StatefulWidget {
  const Chat({super.key});

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final connection = Provider.of<Connection>(context);
    final gameState = connection.game;

    if (gameState == null) {
      return const Center(
        child: Text('Waiting for game state...'),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: gameState.messages.length,
            reverse: true,
            itemBuilder: (context, index) {
              final reversedIndex = gameState.messages.length - index - 1;
              final message = gameState.messages[reversedIndex];
              final senderText = message.$1 == null ? null : Text(message.$1!);

              return ListTile(
                title: senderText,
                subtitle: Text(message.$2),
              );
            },
          ),
        ),
        TextField(
          controller: _controller,
          onSubmitted: (value) {
            connection.send(ClientMessage.chat(value));
            _controller.clear();
          },
        ),
      ]
    );
  }
}