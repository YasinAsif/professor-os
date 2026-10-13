// Conditional web window focus listener.
// In native platforms, stub implementation does nothing.

typedef VoidCallback = void Function();

void attachWebVisibilityListener({
  required VoidCallback onFocusLost,
  required VoidCallback onFocusGained,
}) {}

void detachWebVisibilityListener() {}

void requestBrowserFullscreen() {}

void exitBrowserFullscreen() {}
