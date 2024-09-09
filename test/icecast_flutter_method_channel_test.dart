import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icecast_flutter/icecast_flutter_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelIcecastFlutter platform = MethodChannelIcecastFlutter();
  const MethodChannel channel = MethodChannel('icecast_flutter');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
