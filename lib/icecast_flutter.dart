import 'package:flutter/services.dart';
import 'icecast_flutter_platform_interface.dart';

class IcecastFlutter {
  /// Streaming sampleRate `default is 44100 Hz`
  final int _sampleRate;

  /// PCM-16 Chunk Channel (Mono = 1 and Stero = 2) `default is Stero`
  final int _numChannels;

  /// Streaming bitrate `default is 128 kbps`
  final int _bitrate;

  /// Icecast Server address
  final String _serverAddress;

  /// Icecast username
  final String _userName;

  /// Icecast port
  final int _port;

  /// Icecast mount
  final String _mount;

  /// Icecast password
  final String _password;

  /// Error Callback when adding PCM-16 chunk to upload stream
  final void Function(String error)? _onError;

  ///  Callback for when streaming ends with no error
  final void Function()? _onComplete;

  /// PCM-16 bit input stream 1
  late final Stream<List<int>> _inputStream1;

  /// PCM-16 bit input stream 2
  late final Stream<List<int>> _inputStream2;

  static const MethodChannel _channel = MethodChannel('icecast_flutter');

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case "onError":
        String error = call.arguments['error'];
        _onError?.call(error);
        break;
      case "onComplete":
        _onComplete?.call();
        break;
      default:
        throw MissingPluginException(
            'No implementation found for method ${call.method}');
    }
  }

  /// IcecastFlutter Constructor
  IcecastFlutter({
    int bitrate = 128,
    int numChannels = 2,
    int sampleRate = 44100,
    void Function(String)? onError,
    void Function()? onComplete,
    required String serverAddress,
    required int port,
    required String password,
    required String userName,
    required String mount,
  })  : _onComplete = onComplete,
        _onError = onError,
        _password = password,
        _mount = mount,
        _port = port,
        _userName = userName,
        _serverAddress = serverAddress,
        _bitrate = bitrate,
        _numChannels = numChannels,
        _sampleRate = sampleRate {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }

  /// Starts new Stream
  ///
  /// Returns [String] representation of error if any else returns [NULL]
  Future<void> startStream(
    Stream<List<int>> inputStream1,
    Stream<List<int>> inputStream2,
  ) async {
    // init stream 1
    _inputStream1 = inputStream1;
    // init stream 2
    _inputStream2 = inputStream2;

    await IcecastFlutterPlatform.instance.startStream(
      bitrate: _bitrate,
      sampleRate: _sampleRate,
      numChannels: _numChannels,
      userName: _userName,
      port: _port,
      password: _password,
      mount: _mount,
      serverAddress: _serverAddress,
    );

    _listenToPCMBytes();
  }

  void _listenToPCMBytes() {
    // listen and send new bytes to stream 1
    _inputStream1.listen((List<int> byte) async {
      await writeToStream1(byte);
    });

    // listen and send new bytes to stream 2
    _inputStream2.listen((List<int> byte) async {
      await writeToStream2(byte);
    });
  }

  Future<String?> writeToStream1(List<int> byte) async {
    return await IcecastFlutterPlatform.instance.writeToStream1(byte);
  }

  Future<String?> writeToStream2(List<int> byte) async {
    return await IcecastFlutterPlatform.instance.writeToStream2(byte);
  }

  /// Stop stream
  ///
  /// Returns [String] representation of error if any else returns [NULL]
  Future<String?> stopStream() async {
    return await IcecastFlutterPlatform.instance.stopStream();
  }

  /// Generates a silent PCM 16-bit audio byte.
  ///
  /// [durationInSeconds] - Duration of the silence in seconds.
  /// [sampleRate] - Sample rate (e.g., 44100).
  /// [channels] - Number of channels (e.g., 1 for mono, 2 for stereo).
  /// Returns a [Uint8List] containing the silence audio data.
  static List<int> generateSilentBytes(
      int durationInSeconds, int sampleRate, int numChannels) {
    int bytesPerSample = 2; // For PCM 16-bit
    int silenceSize =
        durationInSeconds * sampleRate * numChannels * bytesPerSample;

    // Create a list of bytes initialized to zero for silence
    Uint8List silenceChunk = Uint8List(silenceSize);

    return silenceChunk.toList();
  }
}
