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
  late StreamController<List<int>> outputStream1;
  late StreamController<List<int>> outputStream2;
  late final IcecastFlutter _icecastFlutterPlugin;
  final int bitRate = 128;
  final int sampleRate = 44100;
  final int numChannels = 2;

  @override
  void initState() {
    record = AudioRecorder();
    print("Starting....");

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
                if (!isStreaming) {
                  outputStream1 = StreamController.broadcast();
                  outputStream2 = StreamController.broadcast();

                  await _icecastFlutterPlugin.startStream(
                    outputStream1.stream,
                    outputStream2.stream,
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
        autoGain: true,
      ),
    );

    stream.listen((Uint8List bytes) {
      if (!isStreaming) return;
      List<int> silenceChunk =
          IcecastFlutter.generateSilenceChunk(1, sampleRate, numChannels);
      try {
        List<int> pcm16Chunk = AudioRecorder().convertBytesToInt16(bytes);
        byteBuffer.addAll(pcm16Chunk);
        if (byteBuffer.length >= bufferSize) {
          var currentChunk = byteBuffer.sublist(0, bufferSize);
          // update chunk
          byteBuffer = byteBuffer.sublist(bufferSize, byteBuffer.length);

          outputStream1.add(silenceChunk);
          // debugPrint("Audio Chunk $currentChunk");
          outputStream2.add(currentChunk);
          // debugPrint("Chunk 1 $chunk1");
        }
      } catch (e) {
        List<int> silenceChunk =
            IcecastFlutter.generateSilenceChunk(1, 44100, 2);
        outputStream1.add(silenceChunk);
        outputStream2.add(silenceChunk);
        debugPrint('Streaming error: $e');
      }
    });
  }

  void stopStream() {
    outputStream1.close();
    outputStream2.close();
    record.stop();
  }
}
