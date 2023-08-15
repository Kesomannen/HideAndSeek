import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hide_and_seek/chat.dart';
import 'package:hide_and_seek/message.dart';
import 'package:hide_and_seek/util.dart';
import 'package:provider/provider.dart';

import '../connection.dart';

class InGamePage extends StatelessWidget {
  const InGamePage({super.key});

  @override
  Widget build(BuildContext context) {
    final connection = Provider.of<Connection>(context);
    final theme = Theme.of(context);
    final id = connection.gameState?.id.toString();

    if (connection.gameState != null && connection.gameState!.playing) {
      return playing(theme, context, connection);
    } else {
      return lobby(theme, id, context, connection);
    }
  }

  Center lobby(ThemeData theme, String? id, BuildContext context, Connection connection) {
    final onBackground = theme.colorScheme.onBackground;
  
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Game code',
            style: theme.textTheme.labelMedium,
          ),
          gameCode(id, theme, onBackground, context),
          Expanded(flex: 1, child: playerList(connection, theme, onBackground)),
          const Expanded(flex: 2, child: Chat()),
          const SizedBox(height: 16.0),
          lobbyButtons(connection)
        ],
      ),
    );
  }

  Widget lobbyButtons(Connection connection) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilledButton(
          onPressed: connection.isHost! ? () {
            connection.send(ClientMessage.startGame());
          } : null,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8.0),
            child: Text('Start'),
          )
        ),
        const SizedBox(width: 16.0),
        OutlinedButton(
          onPressed: () => connection.send(ClientMessage.leaveGame()),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('Leave'),
          )
        ),
      ],
    );
  }

  Widget playerList(Connection connection, ThemeData theme, Color textColor) {
    return ListView(
      children: [
        for (var player in connection.gameState!.players.entries) 
          ListTile(
            title: Text(
              player.value.name + (player.key == connection.playerId ? ' (you)' : ''),
              style: theme.textTheme.labelLarge!.copyWith(
                color: textColor
              ),
            ),
            leading: Icon(
              connection.gameState!.host == player.key ? Icons.star : Icons.person,
              color: textColor,
            ),
          ),
      ],
    );
  }

  Widget gameCode(String? id, ThemeData theme, Color textColor, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          id ?? '???', 
          style: theme.textTheme.headlineLarge!.copyWith(
            color: textColor
          )
        ),
        IconButton(onPressed: () async {
            if (id == null) return;
            await Clipboard.setData(ClipboardData(text: id));
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Copied game code to clipboard'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }, icon: Icon(
            Icons.copy,
            size: 20,
            color: textColor,
          )
        )
      ],
    );
  }
  
  Widget playing(ThemeData theme, BuildContext context, Connection connection) {
    final gameState = connection.gameState!;
    final durationLeft = Duration(seconds: gameState.secondsLeft);

    final playerData = gameState.players[connection.playerId]!;
    final isSeeker = playerData.isSeeker;
    final score = playerData.score;
    
    return Column(
      children: [
        Text(
          toTwoDigit(durationLeft), 
          style: theme.textTheme.labelLarge
        ),
        Text(
          score.toInt().toString(),
          style: theme.textTheme.headlineLarge!
        ),
        Text(
          isSeeker ? 'Seek!' : 'Hide!',
          style: theme.textTheme.labelLarge
        ),
        Expanded(
          flex: 1,
          child: ListView(
            children: [
              for (var player in gameState.players.entries) 
                ListTile(
                  title: Text(
                    player.value.name + (player.key == connection.playerId ? ' (you)' : ''),
                    style: theme.textTheme.labelMedium,
                  ),
                  leading: Icon(
                    player.value.isSeeker ? Icons.remove_red_eye : Icons.person,
                  ),
                  trailing: Text(
                    player.value.score.toInt().toString(),
                    style: theme.textTheme.labelLarge,
                  )
                ),
            ],
          ),
        ),
        const Expanded(flex: 2, child: Chat()),
      ],
    );
  }
}