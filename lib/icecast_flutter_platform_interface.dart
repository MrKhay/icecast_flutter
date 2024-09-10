import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'icecast_flutter_method_channel.dart';

abstract class IcecastFlutterPlatform extends PlatformInterface {
  /// Constructs a IcecastFlutterPlatform.
  IcecastFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static IcecastFlutterPlatform _instance = MethodChannelIcecastFlutter();

  /// The default instance of [IcecastFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelIcecastFlutter].
  static IcecastFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [IcecastFlutterPlatform] when
  /// they register themselves.
  static set instance(IcecastFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

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
  }) {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> stopStream() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<List<Map>> getInputDevices() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> writeToStream(List<int> byte) {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
