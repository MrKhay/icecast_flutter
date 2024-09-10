import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:icecast_flutter/icecast_flutter.dart';
import 'package:icecast_flutter_example/keys.dart';
import 'package:record/record.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isStreaming = false;
  late AudioRecorder record;
  late StreamController<List<int>> outputStream;
  late final IcecastFlutter _icecastFlutterPlugin;
  final int bitRate = 128;
  final int sampleRate = 44100;
  final int numChannels = 2;

  @override
  void initState() {
    record = AudioRecorder();

    _icecastFlutterPlugin = IcecastFlutter(
      password: password,
      userName: username,
      serverAddress: serverAddress,
      mount: mount,
      port: serverPort,
      bitrate: bitRate,
      sampleRate: sampleRate,
      numChannels: numChannels,
      onError: (error) {
        print("Streaming Error: $error");
      },
      onComplete: () {
        print("Streaming Completed 🟢");
      },
    );
    super.initState();
  }

  @override
  void dispose() {
    record.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: FilledButton.tonal(
              onPressed: () async {
                if (!isStreaming) {
                  outputStream = StreamController.broadcast();

                  await _icecastFlutterPlugin.startStream(
                    outputStream.stream,
                  );

                  startStreaming();

                  setState(() {
                    isStreaming = true;
                  });
                } else {
                  var response = await _icecastFlutterPlugin.stopStream();
                  if (response == null) {
                    stopStream();
                  } else {
                    debugPrint("Stop Error: $response");
                  }

                  setState(() {
                    isStreaming = false;
                  });
                }
              },
              child: Text(isStreaming ? 'Stop streaming' : 'Start streaming')),
        ),
      ),
    );
  }

  void startStreaming() async {
    List<int> byteBuffer = [];
    final bufferSize = ((sampleRate * 16 * numChannels) ~/ 8).toInt();

    var stream = await record.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        bitRate: bitRate,
        numChannels: numChannels,
        sampleRate: sampleRate,
        noiseSuppress: true,
        echoCancel: true,
      ),
    );

    stream.listen((Uint8List bytes) {
      if (!isStreaming) return;

      try {
        List<int> pcm16Chunk = AudioRecorder().convertBytesToInt16(bytes);
        byteBuffer.addAll(pcm16Chunk);
        if (byteBuffer.length >= bufferSize) {
          var currentChunk = byteBuffer.sublist(0, bufferSize);
          // update chunk
          byteBuffer = byteBuffer.sublist(bufferSize, byteBuffer.length);

          outputStream.add(currentChunk);
          // debugPrint("Audio Chunk $currentChunk");

          // debugPrint("Chunk 1 $chunk1");
        }
      } catch (e) {
        List<int> silenceChunk =
            IcecastFlutter.generateSilentBytes(1, 44100, 2);
        outputStream.add(silenceChunk);

        debugPrint('Streaming error: $e');
      }
    });
  }

  void stopStream() {
    outputStream.close();
    record.stop();
  }
}
