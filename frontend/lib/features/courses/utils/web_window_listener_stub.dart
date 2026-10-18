// Conditional web window focus listener.
// In native platforms, stub implementation provides safe no-op fallbacks.

typedef VoidCallback = void Function();

bool isBrowserFullscreenSupported() => true;

Future<bool> requestBrowserFullscreen() async => true;

void exitBrowserFullscreen() {}

Future<void> tryKeyboardLockEscape() async {}

Future<int> checkConnectedScreensCount() async => 1;

void attachWebProctorListeners({
  required void Function(String type) onViolation,
  required VoidCallback onFullscreenExit,
  required void Function(String action) onCopyPasteViolation,
  bool blockClipboardAndContextMenu = true,
}) {}

void detachWebProctorListeners() {}

void attachWebVisibilityListener({
  required VoidCallback onFocusLost,
  required VoidCallback onFocusGained,
}) {}

void detachWebVisibilityListener() {}

void triggerBrowserDownload(String content, String filename, {String mimeType = 'text/csv;charset=utf-8'}) {}
