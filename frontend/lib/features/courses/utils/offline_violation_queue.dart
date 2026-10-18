/// Pure Dart offline violation retry queue and network connectivity manager.
class OfflineViolationQueue {
  final List<Map<String, dynamic>> _queue = [];
  bool _isOnline = true;

  bool get isOnline => _isOnline;
  int get pendingCount => _queue.length;

  void setOnline(bool online) {
    _isOnline = online;
  }

  void enqueue({
    required String type,
    String? details,
    required DateTime timestamp,
  }) {
    _queue.add({
      'type': type,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    });
  }

  Map<String, dynamic>? peekFirst() {
    if (_queue.isEmpty) return null;
    return _queue.first;
  }

  Map<String, dynamic>? removeFirst() {
    if (_queue.isEmpty) return null;
    return _queue.removeAt(0);
  }

  List<Map<String, dynamic>> drainQueue() {
    final copy = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();
    return copy;
  }

  void clear() {
    _queue.clear();
  }
}
