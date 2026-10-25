import 'package:web/web.dart' as web;

/// Web device inspector using modern `package:web` and `dart:js_interop` in Flutter 3.24+.
///
/// Detects mobile touchscreens even when the user enables "Desktop site" /
/// "Request Desktop Website" in Chrome, Safari, or Edge.
bool checkIsMobileWeb() {
  try {
    // 1. Touch physics: Mobile touchscreens have coarse pointers and no native cursor hover
    final isCoarse = web.window.matchMedia('(pointer: coarse)').matches;

    // 2. Hardware multitouch points (Phones/Tablets report >= 1; desktop monitors report 0)
    final touchPoints = web.window.navigator.maxTouchPoints;

    return isCoarse || touchPoints > 0;
  } catch (_) {
    return false;
  }
}
