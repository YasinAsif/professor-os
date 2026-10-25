import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/features/courses/utils/mobile_proctor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MobileProctorService Unit Tests', () {
    test('isAndroidNative evaluates safely in test/VM environment', () {
      // In flutter test (desktop host VM), Platform.isAndroid may be false
      // This test ensures it doesn't crash or throw unsupported errors
      expect(MobileProctorService.isAndroidNative, isA<bool>());
    });

    test('startExamLock and releaseExamLock complete without unhandled exception', () async {
      await expectLater(MobileProctorService.startExamLock(), completes);
      await expectLater(MobileProctorService.releaseExamLock(), completes);
    });
  });
}
