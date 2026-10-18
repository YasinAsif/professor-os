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
    if (html.document.fullscreenElement != null) return true;
    if (docEl == null) {
      developer.log('document.documentElement is null', name: 'ProctoringWeb');
      return false;
    }
    await docEl.requestFullscreen();
    final isFullscreen = html.document.fullscreenElement != null;
    if (isFullscreen) {
      // Opportunistically try Escape keyboard lock (Chrome/Edge desktop)
      await tryKeyboardLockEscape();
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
    if (html.document.fullscreenElement != null) {
      html.document.exitFullscreen();
    }
  } catch (e) {
    developer.log('exitBrowserFullscreen error: $e', name: 'ProctoringWeb');
  }
}

/// Feature-detect navigator.keyboard.lock(['Escape']) (Chrome/Edge only).
Future<void> tryKeyboardLockEscape() async {
  try {
    final nav = html.window.navigator;
    if (js_util.hasProperty(nav, 'keyboard')) {
      final keyboard = js_util.getProperty(nav, 'keyboard');
      if (keyboard != null && js_util.hasProperty(keyboard, 'lock')) {
        await js_util.promiseToFuture(
          js_util.callMethod(keyboard, 'lock', [['Escape']])
        );
        developer.log('Escape key lock engaged successfully.', name: 'ProctoringWeb');
      }
    }
  } catch (e) {
    developer.log('navigator.keyboard.lock unsupported or denied: $e', name: 'ProctoringWeb');
  }
}

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

/// Attach listeners for tab-switch, blur, fullscreen exit, and clipboard/contextmenu blocking.
void attachWebProctorListeners({
  required void Function(String type) onViolation,
  required VoidCallback onFullscreenExit,
  required void Function(String action) onCopyPasteViolation,
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
  };

  _fullscreenHandler = (html.Event event) {
    if (html.document.fullscreenElement == null) {
      onFullscreenExit();
    }
  };

  html.document.addEventListener('visibilitychange', _visibilityHandler);
  html.window.addEventListener('blur', _blurHandler);
  html.document.addEventListener('fullscreenchange', _fullscreenHandler);

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

