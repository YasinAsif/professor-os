// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

typedef VoidCallback = void Function();

html.EventListener? _visibilityHandler;
html.EventListener? _blurHandler;
html.EventListener? _focusHandler;

void attachWebVisibilityListener({
  required VoidCallback onFocusLost,
  required VoidCallback onFocusGained,
}) {
  detachWebVisibilityListener();

  _visibilityHandler = (html.Event event) {
    if (html.document.hidden == true) {
      onFocusLost();
    } else {
      onFocusGained();
    }
  };

  _blurHandler = (html.Event event) {
    onFocusLost();
  };

  _focusHandler = (html.Event event) {
    onFocusGained();
  };

  html.document.addEventListener('visibilitychange', _visibilityHandler);
  html.window.addEventListener('blur', _blurHandler);
  html.window.addEventListener('focus', _focusHandler);
}

void detachWebVisibilityListener() {
  if (_visibilityHandler != null) {
    html.document.removeEventListener('visibilitychange', _visibilityHandler);
    _visibilityHandler = null;
  }
  if (_blurHandler != null) {
    html.window.removeEventListener('blur', _blurHandler);
    _blurHandler = null;
  }
  if (_focusHandler != null) {
    html.window.removeEventListener('focus', _focusHandler);
    _focusHandler = null;
  }
}
