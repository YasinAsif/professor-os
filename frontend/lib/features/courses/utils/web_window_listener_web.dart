// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:html' as html;
import 'dart:js_util' as js_util;

typedef VoidCallback = void Function();

html.EventListener? _visibilityHandler;
html.EventListener? _blurHandler;
html.EventListener? _fullscreenHandler;
html.EventListener? _contextMenuHandler;
html.EventListener? _copyHandler;
html.EventListener? _cutHandler;
html.EventListener? _pasteHandler;
html.EventListener? _keyDownHandler;
html.EventListener? _pointerDownHandler;

/// Standard list of keys intercepted by Keyboard Lock API during proctored focus mode.
const List<String> _kProctoredLockKeys = [
  'Escape',
  'MetaLeft',
  'MetaRight',
  'OSLeft',
  'OSRight',
  'ContextMenu',
  'AltLeft',
  'AltRight',
  'Tab',
  'F1',
  'F3',
  'F5',
  'F6',
  'F7',
  'F10',
  'F11',
  'F12',
  'KeyW',
  'KeyN',
  'KeyT',
  'KeyR',
  'KeyI',
  'KeyJ',
  'KeyU',
];

/// Detect if HTML5 Fullscreen API is available on this browser/device.
bool isBrowserFullscreenSupported() {
  try {
    return html.document.fullscreenEnabled == true;
  } catch (e) {
    developer.log('Error querying document.fullscreenEnabled: $e', name: 'ProctoringWeb');
    return false;
  }
}

/// Request native HTML5 browser fullscreen on document.documentElement.
/// MUST be called synchronously inside a user gesture handler.
Future<bool> requestBrowserFullscreen() async {
  try {
    final docEl = html.document.documentElement;
    if (html.document.fullscreenElement != null) {
      await lockBrowserKeyboard();
      return true;
    }
    if (docEl == null) {
      developer.log('document.documentElement is null', name: 'ProctoringWeb');
      return false;
    }
    await docEl.requestFullscreen();
    final isFullscreen = html.document.fullscreenElement != null;
    if (isFullscreen) {
      await lockBrowserKeyboard();
    }
    return isFullscreen;
  } catch (e) {
    developer.log('requestBrowserFullscreen rejected/failed: $e', name: 'ProctoringWeb');
    return false;
  }
}

/// Exit browser fullscreen mode.
void exitBrowserFullscreen() {
  try {
    unlockBrowserKeyboard();
    if (html.document.fullscreenElement != null) {
      html.document.exitFullscreen();
    }
  } catch (e) {
    developer.log('exitBrowserFullscreen error: $e', name: 'ProctoringWeb');
  }
}

/// Lock keyboard via the W3C Keyboard Lock API (Chromium / Chrome / Edge).
/// Prevents Windows / Meta keys, Alt+Tab, Escape, and Function keys from escaping fullscreen.
Future<void> lockBrowserKeyboard() async {
  try {
    final nav = html.window.navigator;
    if (js_util.hasProperty(nav, 'keyboard')) {
      final keyboard = js_util.getProperty(nav, 'keyboard');
      if (keyboard != null && js_util.hasProperty(keyboard, 'lock')) {
        try {
          // Calling lock without arguments locks all keys captured by user agent
          await js_util.promiseToFuture(
            js_util.callMethod(keyboard, 'lock', [])
          );
          developer.log('Full keyboard lock engaged successfully.', name: 'ProctoringWeb');
          return;
        } catch (_) {
          // Fallback to explicit list of system keys
          await js_util.promiseToFuture(
            js_util.callMethod(keyboard, 'lock', [_kProctoredLockKeys])
          );
          developer.log('Key-targeted keyboard lock engaged successfully.', name: 'ProctoringWeb');
        }
      }
    }
  } catch (e) {
    developer.log('navigator.keyboard.lock unsupported or denied: $e', name: 'ProctoringWeb');
  }
}

/// Release keyboard lock when focus mode or exam ends.
void unlockBrowserKeyboard() {
  try {
    final nav = html.window.navigator;
    if (js_util.hasProperty(nav, 'keyboard')) {
      final keyboard = js_util.getProperty(nav, 'keyboard');
      if (keyboard != null && js_util.hasProperty(keyboard, 'unlock')) {
        js_util.callMethod(keyboard, 'unlock', []);
        developer.log('Keyboard lock released.', name: 'ProctoringWeb');
      }
    }
  } catch (e) {
    developer.log('unlockBrowserKeyboard error: $e', name: 'ProctoringWeb');
  }
}

/// Feature-detect navigator.keyboard.lock backward compatibility alias.
Future<void> tryKeyboardLockEscape() => lockBrowserKeyboard();

/// Check for multi-monitor setup via Window Management API (Chrome 100+).
Future<int> checkConnectedScreensCount() async {
  try {
    if (js_util.hasProperty(html.window, 'getScreenDetails')) {
      final promise = js_util.callMethod(html.window, 'getScreenDetails', []);
      final screenDetails = await js_util.promiseToFuture(promise);
      if (screenDetails != null && js_util.hasProperty(screenDetails, 'screens')) {
        final screens = js_util.getProperty(screenDetails, 'screens');
        final length = js_util.getProperty(screens, 'length') as int? ?? 1;
        return length;
      }
    }
  } catch (e) {
    developer.log('ScreenDetails API unavailable or permission denied: $e', name: 'ProctoringWeb');
  }
  return 1;
}

/// Attach listeners for tab-switch, blur, fullscreen exit, and keyboard suppression.
void attachWebProctorListeners({
  required void Function(String type) onViolation,
  required VoidCallback onFullscreenExit,
  required void Function(String action) onCopyPasteViolation,
  void Function(String keyReason)? onRestrictedKey,
  bool blockClipboardAndContextMenu = true,
}) {
  detachWebProctorListeners();

  _visibilityHandler = (html.Event event) {
    if (html.document.hidden == true) {
      onViolation('tab_switch');
    }
  };

  _blurHandler = (html.Event event) {
    onViolation('window_blur');
    try {
      if (html.document.fullscreenElement != null) {
        js_util.callMethod(html.window, 'focus', []);
      }
    } catch (_) {}
  };

  _fullscreenHandler = (html.Event event) {
    if (html.document.fullscreenElement == null) {
      onFullscreenExit();
    } else {
      // Re-engage keyboard lock on return to fullscreen
      lockBrowserKeyboard();
    }
  };

  html.document.addEventListener('visibilitychange', _visibilityHandler);
  html.window.addEventListener('blur', _blurHandler);
  html.document.addEventListener('fullscreenchange', _fullscreenHandler);

  // Auto-refocus on pointer interaction
  _pointerDownHandler = (html.Event event) {
    try {
      if (html.document.fullscreenElement != null) {
        js_util.callMethod(html.window, 'focus', []);
      }
    } catch (_) {}
  };
  html.window.addEventListener('pointerdown', _pointerDownHandler, true);

  // Key suppression in DOM capturing phase (runs before browser default handlers)
  _keyDownHandler = (html.Event event) {
    if (event is! html.KeyboardEvent) return;
    final key = event.key;
    final code = event.code ?? '';
    final isAlt = event.altKey;
    final isCtrl = event.ctrlKey;
    final isMeta = event.metaKey || key == 'Meta' || key == 'OS' || code.startsWith('Meta') || code.startsWith('OS');

    bool shouldBlock = false;
    String? reason;

    // 1. Windows / Meta keys
    if (isMeta || code == 'MetaLeft' || code == 'MetaRight') {
      shouldBlock = true;
      reason = 'Windows/Meta system key';
    }
    // 2. Context Menu key
    else if (code == 'ContextMenu' || key == 'ContextMenu') {
      shouldBlock = true;
      reason = 'Context menu key';
    }
    // 3. Alt combinations (Alt+Tab, Alt+F4, Alt+Left/Right navigation, Alt+Esc)
    else if (isAlt && (key == 'Tab' || key == 'F4' || key == 'Escape' || code.startsWith('Arrow') || code.startsWith('Alt'))) {
      shouldBlock = true;
      reason = 'Alt combination shortcut';
    }
    // 4. Function keys (F5 reload, F11 fullscreen bypass, F12 devtools, F1 help, F3 search)
    else if (key == 'F5' || key == 'F11' || key == 'F12' || key == 'F1' || key == 'F3') {
      shouldBlock = true;
      reason = '$key key';
    }
    // 5. Escape key (suppress casual escape key presses in fullscreen)
    else if (key == 'Escape') {
      shouldBlock = true;
      reason = 'Escape key';
    }
    // 6. Browser navigation/tab shortcuts
    else if ((isCtrl || isMeta) && (code == 'KeyW' || code == 'KeyT' || code == 'KeyN' || code == 'KeyR' || code == 'KeyU' || code == 'KeyP' || code == 'KeyH' || code == 'KeyJ')) {
      shouldBlock = true;
      reason = 'Browser action shortcut';
    }
    // 7. Developer tools shortcuts
    else if ((isCtrl || isMeta) && event.shiftKey && (code == 'KeyI' || code == 'KeyJ' || code == 'KeyC')) {
      shouldBlock = true;
      reason = 'Developer tools shortcut';
    }

    if (shouldBlock) {
      event.preventDefault();
      event.stopPropagation();
      event.stopImmediatePropagation();
      if (reason != null && onRestrictedKey != null) {
        onRestrictedKey(reason);
      }
    }
  };
  html.window.addEventListener('keydown', _keyDownHandler, true);

  if (blockClipboardAndContextMenu) {
    _contextMenuHandler = (html.Event event) {
      event.preventDefault();
      onCopyPasteViolation('context_menu');
    };
    _copyHandler = (html.Event event) {
      event.preventDefault();
      onCopyPasteViolation('copy');
    };
    _cutHandler = (html.Event event) {
      event.preventDefault();
      onCopyPasteViolation('cut');
    };
    _pasteHandler = (html.Event event) {
      // NOTE: Stops casual clipboard cheating on exam surface
      event.preventDefault();
      onCopyPasteViolation('paste');
    };

    html.document.addEventListener('contextmenu', _contextMenuHandler);
    html.document.addEventListener('copy', _copyHandler);
    html.document.addEventListener('cut', _cutHandler);
    html.document.addEventListener('paste', _pasteHandler);
  }
}

/// Remove all proctoring listeners upon exam completion.
void detachWebProctorListeners() {
  if (_visibilityHandler != null) {
    html.document.removeEventListener('visibilitychange', _visibilityHandler);
    _visibilityHandler = null;
  }
  if (_blurHandler != null) {
    html.window.removeEventListener('blur', _blurHandler);
    _blurHandler = null;
  }
  if (_fullscreenHandler != null) {
    html.document.removeEventListener('fullscreenchange', _fullscreenHandler);
    _fullscreenHandler = null;
  }
  if (_pointerDownHandler != null) {
    html.window.removeEventListener('pointerdown', _pointerDownHandler, true);
    _pointerDownHandler = null;
  }
  if (_keyDownHandler != null) {
    html.window.removeEventListener('keydown', _keyDownHandler, true);
    _keyDownHandler = null;
  }
  if (_contextMenuHandler != null) {
    html.document.removeEventListener('contextmenu', _contextMenuHandler);
    _contextMenuHandler = null;
  }
  if (_copyHandler != null) {
    html.document.removeEventListener('copy', _copyHandler);
    _copyHandler = null;
  }
  if (_cutHandler != null) {
    html.document.removeEventListener('cut', _cutHandler);
    _cutHandler = null;
  }
  if (_pasteHandler != null) {
    html.document.removeEventListener('paste', _pasteHandler);
    _pasteHandler = null;
  }
  unlockBrowserKeyboard();
}

/// Legacy backward compatibility for older quiz callers.
void attachWebVisibilityListener({
  required VoidCallback onFocusLost,
  required VoidCallback onFocusGained,
}) {
  attachWebProctorListeners(
    onViolation: (type) => onFocusLost(),
    onFullscreenExit: () => onFocusLost(),
    onCopyPasteViolation: (action) {},
    blockClipboardAndContextMenu: false,
  );
}

void detachWebVisibilityListener() {
  detachWebProctorListeners();
}

/// Trigger a client-side file download via HTML Blob and invisible AnchorElement.
void triggerBrowserDownload(String content, String filename, {String mimeType = 'text/csv;charset=utf-8'}) {
  try {
    final blob = html.Blob([content], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  } catch (e) {
    developer.log('triggerBrowserDownload failed: $e', name: 'WebDownload');
  }
}
