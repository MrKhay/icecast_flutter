# Icecast Flutter Plugin 📻

A Flutter plugin for streaming audio to an Icecast server. This plugin allows users to capture audio from input devices, stream to Icecast, and manage the audio stream using method channels for communication with native platform code.

## Features

- Stream audio to an Icecast server.
- Support for writing raw audio data to the stream.
- Start/stop streaming with customizable settings like bitrate, channels, sample rate, etc.

## Installation

To use this plugin, add `icecast_flutter` as a dependency in your `pubspec.yaml` file:

Run the following command to get the plugin:

```dart
flutter pub get icecast_flutter
```

## Usage

### Import the plugin

```dart
import 'package:icecast_flutter/icecast_flutter.dart';
```

## Initialize

Use the startStream method to start streaming to your Icecast server. You can configure the stream by providing details like bitrate, sample rate, number of channels, and Icecast server credentials.

```dart

  _icecastFlutterPlugin =  IcecastFlutter(
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

```

## Start Streaming

```dart
void startIcecastStream() async {

   await _icecastFlutterPlugin.startStream(
          outputStream.stream);
}
```

## Stop Streaming

To stop the ongoing audio stream:

```dart
void stopIcecastStream() async {
  await _icecastFlutterPlugin.stopStream();
}
```

## Writing Audio Data to Stream

```dart
// Write to stream pipe 
outputStream.add(yourPcmByteArray);

```

## Platform Support

- Android: Supported
- iOS: Coming soon
