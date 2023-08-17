import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hide_and_seek/pages/in_game.dart';

CameraDescription? mainCamera;

void initializeCameras() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  mainCamera = cameras.first;
}

class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({
    super.key,
    required this.camera,
    this.onPictureTaken
  });

  final CameraDescription camera;
  final Function(Uint8List)? onPictureTaken;

  @override
  State<TakePictureScreen> createState() => _TakePictureScreenState();
}

class _TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();

    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium
    );

    _initializeControllerFuture = _controller.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Stack(children: [
            CameraPreview(_controller),
            Positioned(
              bottom: 0.2,
              left: 0.2,
              right: 0.2,
              child: FilledGameButton(
                'Capture',
                onPressed: () async {
                  await _initializeControllerFuture;
                  final image = await _controller.takePicture();
                  
                  if (widget.onPictureTaken != null) {
                    final bytes = await image.readAsBytes();
                    widget.onPictureTaken!(bytes);
                  }
                },
              ),
            ),
          ]);
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      }
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}