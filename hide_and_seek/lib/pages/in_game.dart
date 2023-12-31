import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hide_and_seek/chat.dart';
import 'package:hide_and_seek/message.dart';
import 'package:hide_and_seek/util.dart';
import 'package:provider/provider.dart';

import '../connection.dart';

class InGamePage extends StatefulWidget {
  const InGamePage({super.key});

  @override
  State<InGamePage> createState() => _InGamePageState();
}

class _InGamePageState extends State<InGamePage> {
  int _currentPageIndex = 1;

  @override
  Widget build(BuildContext context) {
    final connection = Provider.of<Connection>(context);
    final theme = Theme.of(context);

    if (connection.game == null) {
      return const Text('Waiting for game state...');
    }
    
    switch (connection.game!.state) {
      case GameState.waiting:
        return lobby(theme, context, connection);

      case GameState.playing:
        return playing(theme, context, connection);

      case GameState.ended:
        return ended(theme, context, connection);
    }
  }

  Widget lobby(ThemeData theme, BuildContext context, Connection connection) {
    final onBackground = theme.colorScheme.onBackground;
    final id = connection.game?.id.toString();
  
    return EdgePadding(
      child: Center(
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
      ),
    );
  }

  Widget lobbyButtons(Connection connection) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilledGameButton('Start', onPressed: connection.isHost ? () {
          return connection.send(ClientMessage.startGame());
        } : null),
        const SizedBox(width: 16.0),
        OutlinedGameButton('Leave', onPressed: () {
          return connection.send(ClientMessage.leaveGame());
        }),
      ],
    );
  }

  Widget playerList(Connection connection, ThemeData theme, Color textColor) {
    return ListView(
      children: [
        for (var player in connection.game!.players.entries) 
          ListTile(
            title: Text(
              player.value.name + (player.key == connection.playerId ? ' (you)' : ''),
              style: theme.textTheme.labelLarge!.copyWith(
                color: textColor
              ),
            ),
            leading: Icon(
              connection.game!.host == player.key ? Icons.star : Icons.person,
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
                showCloseIcon: true,
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
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: EdgePadding(
            child: switch (_currentPageIndex) {
              0 => settings(theme, connection),
              1 => leaderboardPage(theme, connection),
              2 => const Chat(),
              _ => throw Exception('Invalid page index $_currentPageIndex')
            }
          ),
        ),
        NavigationBar(destinations: const [
            NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
            NavigationDestination(icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
            NavigationDestination(icon: Icon(Icons.chat), label: 'Chat'),
          ],
          selectedIndex: _currentPageIndex,
          onDestinationSelected: (int index) => setState(() =>_currentPageIndex = index ),
        )
      ],
    );
  }
 
  Widget settings(ThemeData theme, Connection connection) {
    return Column(
      children: [
        OutlinedGameButton('Leave', onPressed: () {
          return connection.send(ClientMessage.leaveGame());
        }),
      ],
    );
  }

  Widget leaderboardPage(ThemeData theme, Connection connection) {
    final gameState = connection.game!;
    final durationLeft = Duration(seconds: gameState.secondsLeft);

    final playerData = gameState.players[connection.playerId]!;
    final isSeeker = gameState.seeker == connection.playerId;
    final score = playerData.score;

    final navigator = Navigator.of(context);

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
          isSeeker ? 'Seek!' : 'Hide! (distance: ${connection.currentDistance.toInt()}m)',
          style: theme.textTheme.labelLarge
        ),
        const SizedBox(height: 16),
        Expanded(
          flex: 1,
          child: scoreList(gameState, connection, theme, (id, _) {
            return id == gameState.seeker ? Icons.remove_red_eye : Icons.person;
          }, (id, _) {
            return id == gameState.seeker ? Colors.red : theme.colorScheme.onBackground;
          }),
        ),
        if (isSeeker) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton.large(
                onPressed: () {
                  showTagModal(theme, connection, navigator);
                },
                child: const Icon(Icons.camera),
              ),
            ],
          ),
        ]
      ],
    );
  }

  Future<dynamic> showTagModal(ThemeData theme, Connection connection, NavigatorState navigator) {
    return showModalBottomSheet(
      context: context,
      builder: (context) => EdgePadding(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text('Who did you find?', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Expanded(
              flex: 1,
              child: ListView(
                children: [
                  // exclude self
                  for (var player in connection.game!.players.entries.where((player) => player.key != connection.playerId))
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(player.value.name),
                      onTap: () {
                        navigator.pop();
                        connection.send(ClientMessage.tagPlayer(player.key));
                      },
                    ),
                ],
              ),
            ),        
          ],
        ),
      )
    );
  }

  ListView scoreList(Game gameState, Connection connection, ThemeData theme, Function(int, PlayerData) getIconData, Function(int, PlayerData) getColor) {
    final sorted = gameState.players.entries.toList()
      ..sort((a, b) => b.value.score.compareTo(a.value.score));

    return ListView(
      children: [
        for (var player in sorted)
          ListTile(
            title: Text(
              player.value.name + (player.key == connection.playerId ? ' (you)' : ''),
              style: theme.textTheme.labelLarge!.copyWith(
                color: getColor(player.key, player.value)
              ),
            ),
            leading: Icon(
              getIconData(player.key, player.value),
              color: getColor(player.key, player.value),
            ),
            trailing: Text(
              player.value.score.toInt().toString(),
              style: theme.textTheme.labelLarge!.copyWith(
                color: getColor(player.key, player.value)
              ),
            )
          ),
      ],
    );
  }

  Widget ended(ThemeData theme, BuildContext context, Connection connection) {
    final winner = connection.game!.winner;

    return EdgePadding(
      child: Column(
        children: [
          Text('Game over', style: theme.textTheme.headlineLarge),
          Text(
            connection.game!.winner == connection.playerId ? 'You won!' : 'You lost!',
            style: theme.textTheme.labelLarge
          ),
          Expanded(
            flex: 1,
            child: scoreList(connection.game!, connection, theme, (id, _) {
              return winner == id ? Icons.star : Icons.person;
            }, (id, _) {
              return winner == id ? Colors.amber : theme.colorScheme.onBackground;
            }),
          ),
          const Expanded(flex: 2, child: Chat()),
          const SizedBox(height: 16,),
          OutlinedGameButton('Leave', onPressed: () {
            return connection.send(ClientMessage.leaveGame());
          }),
        ],
      ),
    );
  }
}

class FilledGameButton extends StatelessWidget {
  final Function()? onPressed;
  final String text;

  const FilledGameButton(
    this.text,
    {
      super.key,
      this.onPressed,
    }
  );

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8.0),
        child: Text(text),
      )
    );
  }
}

class OutlinedGameButton extends StatelessWidget {
  final Function()? onPressed;
  final String text;

  const OutlinedGameButton(
    this.text,
    {
      super.key,
      this.onPressed,
    }
  );

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8.0),
        child: Text(text),
      )
    );
  }
}