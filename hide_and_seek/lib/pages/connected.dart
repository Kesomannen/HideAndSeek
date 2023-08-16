import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map_location_picker/map_location_picker.dart';
import 'package:provider/provider.dart';

import '../connection.dart';
import '../message.dart';

const apiKey = 'AIzaSyDo8iUvm80BGrDOipC1VJjvQ8cR4mEV0PA';
const maxGameLength = 60;
const minGameLength = 5;

class ConnectedPage extends StatefulWidget {
  const ConnectedPage({super.key});

  @override
  State<ConnectedPage> createState() => _ConnectedPageState();
}

enum _Page {
  create,
  join
}

class _ConnectedPageState extends State<ConnectedPage> {
  _Page _page = _Page.join;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton(
                segments: const [
                  ButtonSegment(value: _Page.join, label: Text('Join')),
                  ButtonSegment(value: _Page.create, label: Text('Create')),
                ], 
                selected: { _page },
                onSelectionChanged: (Set<_Page> newSelection) {
                  setState(() => _page = newSelection.first);
                }
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Builder(builder: (context) {
          if (_page == _Page.create) {
            return const CreateGamePage();
          } else {
            return const JoinGamePage();
          }
        })
      ],
    );
  }
}

class CreateGamePage extends StatefulWidget {
  const CreateGamePage({super.key});

  @override
  State<CreateGamePage> createState() => _CreateGamePageState();
}

class _CreateGamePageState extends State<CreateGamePage> {
  PlaceDetails? _selectedPlace;

  final _placeController = TextEditingController();
  final _gameLengthController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final connection = Provider.of<Connection>(context);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TextFormField(
            controller: _gameLengthController,
            decoration: const InputDecoration(
              labelText: 'Game Length (minutes)'
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3)
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a game length';
              }

              final length = int.tryParse(value);
              if (length == null || length < 1) {
                return 'Please enter a valid game length';
              }

              if (length > maxGameLength) {
                return 'Game length must be less than $maxGameLength minutes';
              }

              if (length < minGameLength) {
                return 'Game length must be greater than $minGameLength minutes';
              }

              return null;
            },
          ),
          const SizedBox(height: 8),
          PlacesAutocomplete(
            searchController: _placeController,
            apiKey: apiKey,
            mounted: mounted,
            showClearButton: false,
            hideBackButton: true,
            searchHintText: 'Search for a location',
            onGetDetailsByPlaceId: (result) {
              if (result != null) {
                setState(() => _selectedPlace = result.result);
              }
            },
            onReset: () {
              setState(() => _selectedPlace = null);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _submit(connection), 
            child: const Text('Create Game')
          )
        ],
      ),
    );
  }

  void _submit(Connection connection) async {
    if (!_formKey.currentState!.validate() || _selectedPlace == null) {
      return;
    }

    final location = _selectedPlace!.geometry!.location;
    final length = int.parse(_gameLengthController.text);
    connection.send(ClientMessage.createGame(location.lat, location.lng, length));
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
            decoration: const InputDecoration(
              labelText: 'Game Code',
              hintText: '12345'
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5)
            ],
            validator: (input) {
              if (input == null || input.isEmpty) {
                return 'Please enter a game code';
              }

              final value = int.tryParse(input);

              if (value == null || value > 65535 || value < 0) {
                return 'Please enter a valid game code';
              }

              return null;
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                connection.send(ClientMessage.joinGame(int.parse(_controller.text)));
              }
            }, 
            child: const Text('Join Game')
          )
        ]
      ),
    );
  }
}