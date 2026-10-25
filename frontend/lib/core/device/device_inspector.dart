import 'device_inspector_stub.dart'
    if (dart.library.js_interop) 'device_inspector_web.dart';

/// Cross-platform device detection utility for ProfessorOS.
class DeviceInspector {
  const DeviceInspector._();

  /// Returns `true` if the application is running inside a mobile web browser
  /// (including when disguised using "Request Desktop Site").
  ///
  /// On native platforms (Android / iOS / desktop OS), always returns `false`.
  static bool isMobileBrowser() {
    return checkIsMobileWeb();
  }
}
