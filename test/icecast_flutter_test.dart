import 'package:flutter_test/flutter_test.dart';
import 'package:icecast_flutter/icecast_flutter.dart';
import 'package:icecast_flutter/icecast_flutter_platform_interface.dart';
import 'package:icecast_flutter/icecast_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockIcecastFlutterPlatform
    with MockPlatformInterfaceMixin
    implements IcecastFlutterPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final IcecastFlutterPlatform initialPlatform = IcecastFlutterPlatform.instance;

  test('$MethodChannelIcecastFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelIcecastFlutter>());
  });

  test('getPlatformVersion', () async {
    IcecastFlutter icecastFlutterPlugin = IcecastFlutter();
    MockIcecastFlutterPlatform fakePlatform = MockIcecastFlutterPlatform();
    IcecastFlutterPlatform.instance = fakePlatform;

    expect(await icecastFlutterPlugin.getPlatformVersion(), '42');
  });
}
