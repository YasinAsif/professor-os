import 'package:web/web.dart' as web;

/// Web device inspector using modern `package:web` and `dart:js_interop` in Flutter 3.24+.
///
/// Detects mobile phones and handheld tablets while properly permitting
/// desktop computers and touchscreen laptops (e.g. Surface, 2-in-1s, Yoga, HP Touch).
bool checkIsMobileWeb() {
  try {
    final nav = web.window.navigator;
    final ua = nav.userAgent.toLowerCase();
    final platform = nav.platform.toLowerCase();

    // 1. Explicit Mobile OS check
    final isMobileOS = ua.contains('android') ||
        ua.contains('iphone') ||
        ua.contains('ipod') ||
        (ua.contains('ipad') || (platform.contains('mac') && nav.maxTouchPoints > 1 && !ua.contains('safari')));

    // 2. Hardware pointer physics:
    // Laptops and desktops (including touchscreen laptops) have a trackpad, mouse, or fine pointer.
    final hasFinePointer = web.window.matchMedia('(any-pointer: fine)').matches;
    final hasHoverCapability = web.window.matchMedia('(any-hover: hover)').matches;

    // 3. Desktop Operating System signature (Windows, macOS, Desktop Linux)
    final isDesktopOS = platform.contains('win') ||
        (platform.contains('mac') && !isMobileOS) ||
        (platform.contains('linux') && !ua.contains('android'));

    // If it's a desktop OS with precision pointing or hover capability,
    // it is a desktop or touchscreen laptop (NOT a mobile browser),
    // even if it has a physical touchscreen (maxTouchPoints > 0).
    if (isDesktopOS && (hasFinePointer || hasHoverCapability)) {
      return false;
    }

    // Handheld mobile phones and pure tablets:
    if (isMobileOS) {
      return true;
    }

    // Fallback for edge cases: coarse-only pointer and no hover capability
    final isCoarse = web.window.matchMedia('(pointer: coarse)').matches;
    final isHoverNone = web.window.matchMedia('(hover: none)').matches;
    return isCoarse && isHoverNone;
  } catch (_) {
    return false;
  }
}
