import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service managing native Android Kiosk Mode (Lock Task) and FLAG_SECURE
/// to prevent screenshots, screen recording, and task switching during exams.
class MobileProctorService {
  static const MethodChannel _channel = MethodChannel('com.professoros/mobile_proctor');

  /// Returns true only on native Android execution (false on Web, iOS, desktop).
  static bool get isAndroidNative {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  /// Engages full mobile exam lock:
  /// 1. Sets WindowManager.LayoutParams.FLAG_SECURE (blocks screenshots/recording)
  /// 2. Starts Lock Task Mode (kiosk pinning, disables home/recents/notifications)
  static Future<void> startExamLock() async {
    if (!isAndroidNative) return;
    try {
      await _channel.invokeMethod('setSecureFlag', {'enabled': true});
      await _channel.invokeMethod('startKioskMode');
    } on PlatformException catch (e) {
      debugPrint('MobileProctorService: Failed to start exam lock: $e');
    } catch (e) {
      debugPrint('MobileProctorService: Unexpected error starting lock: $e');
    }
  }

  /// Releases mobile exam lock:
  /// 1. Stops Lock Task Mode
  /// 2. Clears WindowManager.LayoutParams.FLAG_SECURE
  static Future<void> releaseExamLock() async {
    if (!isAndroidNative) return;
    try {
      await _channel.invokeMethod('stopKioskMode');
      await _channel.invokeMethod('setSecureFlag', {'enabled': false});
    } on PlatformException catch (e) {
      debugPrint('MobileProctorService: Failed to release exam lock: $e');
    } catch (e) {
      debugPrint('MobileProctorService: Unexpected error releasing lock: $e');
    }
  }
}
