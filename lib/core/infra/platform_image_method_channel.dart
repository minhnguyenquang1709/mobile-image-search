import 'package:flutter/services.dart';

class PlatformImageMethodChannel {
  static const String _channelName = 'platform_image';

  // method channel for communicating with native code
  static const MethodChannel _methodChannel = MethodChannel(_channelName);

  Future<int> getBatteryLevel() async {
    try {
      final int result = await _methodChannel.invokeMethod('getBatteryLevel');
      return result;
    } on PlatformException catch (e) {
      print("Failed to get battery level: ${e.message}");
      return -1;
    }
  }
}
