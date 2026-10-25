import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/core/device/device_inspector.dart';

void main() {
  group('DeviceInspector Unit Tests', () {
    test('isMobileBrowser returns false in non-web environment (VM/Native)', () {
      final isMobile = DeviceInspector.isMobileBrowser();
      expect(isMobile, isFalse);
    });
  });
}
