import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'icecast_flutter_platform_interface.dart';

/// An implementation of [IcecastFlutterPlatform] that uses method channels.
class MethodChannelIcecastFlutter extends IcecastFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('icecast_flutter');

  @override
  Future<void> startStream({
    int? inputDeviceId,
    required int bitrate,
    required int numChannels,
    required int sampleRate,
    required String userName,
    required int port,
    required String password,
    required String mount,
    required String serverAddress,
  }) async {
    try {
      await methodChannel.invokeMethod<String?>('startStreaming', {
        "inputDeviceId": inputDeviceId?.toString(),
        "bitrate": bitrate.toString(),
        "numChannels": numChannels.toString(),
        "sampleRate": sampleRate.toString(),
        "userName": userName,
        "port": port.toString(),
        "mount": mount,
        "password": password,
        "serverAddress": serverAddress,
      });
      return;
    } on PlatformException catch (e) {
      debugPrint("Icecast FLutter Error: ${e.code}, ${e.message}");
    }
  }

  @override
  Future<String?> stopStream() async {
    try {
      await methodChannel.invokeMethod<String?>('stopStreaming');
    } on PlatformException catch (e) {
      debugPrint("Error: ${e.code}, ${e.message}");
      return e.message;
    }
    return null;
  }

  @override
  Future<String?> writeToStream(List<int> byte) async {
    try {
      await methodChannel.invokeMethod<String?>('writeToPipe', {"chunk": byte});
    } on PlatformException catch (e) {
      debugPrint("Sending PCM Error 1: ${e.code}, ${e.message}");
      return e.message;
    }
    return null;
  }
}
