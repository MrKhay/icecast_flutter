import 'package:flutter/services.dart';
import 'icecast_flutter_platform_interface.dart';

class IcecastFlutter {
  /// [InputDevice] to stream from ID
  ///
  /// If id is null default stream device is used
  final int? inputDeviceId;

  /// Streaming sampleRate `default is 44100 Hz`
  final int sampleRate;

  /// PCM-16 Chunk Channel (Mono = 1 and Stero = 2) `default is Stero`
  final int numChannels;

  /// Streaming bitrate `default is 128 kbps`
  final int bitrate;

  /// [True] when streaming has started and [False] when not
  late bool isStreaming;

  /// Icecast Server address
  final String serverAddress;

  /// Icecast username
  final String userName;

  /// Icecast port
  final int port;

  /// Icecast mount
  final String mount;

  /// Icecast password
  final String password;

  /// Error Callback when adding PCM-16 chunk to upload stream
  final void Function(String error)? onError;

  ///  Callback for when streaming ends with no error
  final void Function()? onComplete;

  /// PCM-16 bit input stream 1
  late final Stream<List<int>> inputStream1;

  /// PCM-16 bit input stream 2
  late final Stream<List<int>> inputStream2;

  static const MethodChannel _channel = MethodChannel('icecast_flutter');

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case "onError":
        String error = call.arguments['error'];
        onError?.call(error);
        break;
      case "onComplete":
        onComplete?.call();
        break;
      default:
        throw MissingPluginException(
            'No implementation found for method ${call.method}');
    }
  }

  /// IcecastFlutter Constructor
  IcecastFlutter({
    this.inputDeviceId,
    this.bitrate = 128,
    this.numChannels = 2,
    this.sampleRate = 44100,
    this.onError,
    this.onComplete,
    required this.serverAddress,
    required this.port,
    required this.password,
    required this.userName,
    required this.mount,
  }) {
    isStreaming = false;
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
    this.inputStream1 = inputStream1;
    // init stream 2
    this.inputStream2 = inputStream2;

    await IcecastFlutterPlatform.instance.startStream(
      bitrate: bitrate,
      sampleRate: sampleRate,
      numChannels: numChannels,
      userName: userName,
      port: port,
      password: password,
      mount: mount,
      serverAddress: serverAddress,
    );

    _listenToPCMBytes();
  }

  void _listenToPCMBytes() {
    // listen and send new bytes to stream 1
    inputStream1.listen((List<int> byte) async {
      await writeToStream1(byte);
    });

    // listen and send new bytes to stream 2
    inputStream2.listen((List<int> byte) async {
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

  /// Generates a silent PCM 16-bit audio chunk.
  ///
  /// [durationInSeconds] - Duration of the silence in seconds.
  /// [sampleRate] - Sample rate (e.g., 44100).
  /// [channels] - Number of channels (e.g., 1 for mono, 2 for stereo).
  /// Returns a [Uint8List] containing the silence audio data.
  static List<int> generateSilenceChunk(
      int durationInSeconds, int sampleRate, int numChannels) {
    int bytesPerSample = 2; // For PCM 16-bit
    int silenceSize =
        durationInSeconds * sampleRate * numChannels * bytesPerSample;

    // Create a list of bytes initialized to zero for silence
    Uint8List silenceChunk = Uint8List(silenceSize);

    return silenceChunk.toList();
  }
}
