import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'app_model.dart';
import 'data/library.dart';
import 'playback/controller.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) {
    JustAudioMediaKit.ensureInitialized(windows: true, linux: false);
    JustAudioMediaKit.title = 'OPTIMUM';
    JustAudioMediaKit.bufferSize = 8 * 1024 * 1024;
  }
  try {
    final store = await LibraryStore.open();
    final model = AppModel(store);
    await model.refresh();
    runApp(OptimumApp(model: model, player: PlaybackController(store)));
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF050507),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: SelectableText(
                'OPTIMUM не удалось открыть локальную библиотеку.\nДанные не удалены.\n\n$error',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
