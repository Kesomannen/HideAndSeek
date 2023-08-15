import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connection.dart';

class DisconnectedPage extends StatefulWidget {
  const DisconnectedPage({super.key});

  @override
  State<DisconnectedPage> createState() => _DisconnectedPageState();
}

class _DisconnectedPageState extends State<DisconnectedPage> {
  final controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  @override
  Widget build(BuildContext context) {
    var connection = Provider.of<Connection>(context);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Name'
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: () {
              if (_formKey.currentState!.validate()) {
                connection.connect(controller.text);
              }
            }, 
            child: const Text('Connect')
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}