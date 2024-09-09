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

## Initialize and Start Streaming

Use the startStream method to start streaming to your Icecast server. You can configure the stream by providing details like bitrate, sample rate, number of channels, and Icecast server credentials.

```dart
void startIcecastStream() async {
  await IcecastFlutter.instance.startStream(
    bitrate: 128,
    numChannels: 2,
    sampleRate: 44100,
    userName: 'your-username',
    password: 'your-password',
    mount: '/stream',
    serverAddress: 'your.server.com',
    port: 8000,
    onComplete:(){
      // callback 
    },
    onError(String error){
      // callback
    }

  );
}
```

## Stop Streaming

To stop the ongoing audio stream:

```dart
void stopIcecastStream() async {
  await IcecastFlutter.instance.stopStream();
}
```

## Writing Audio Data to Stream

```dart
// Write to stream pipe 1
await IcecastFlutter.instance.writeToStream1(yourPcmByteArray);

// Write to stream pipe 2
await IcecastFlutter.instance.writeToStream2(yourPcmByteArray);
```

## Platform Support

- Android: Supported
- iOS: Coming soon

## Important 🚧

If only one audio stream is required, the plugin supports continuous streaming of silence to the secondary stream (you handle this yourself). This ensures the integrity of the primary stream while maintaining a stable connection with the Icecast server.
