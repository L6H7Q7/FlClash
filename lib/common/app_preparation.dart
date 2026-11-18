import 'dart:async';

/// Tracks the preparation a start waits for: the profile refresh and the node
/// preselection. A start waits for it so it does not race the config reload.
class AppPreparation {
  AppPreparation._();

  static bool _running = false;
  static Completer<void>? _completer;

  static bool get isRunning => _running;

  static void begin() {
    if (_running) {
      return;
    }
    _running = true;
    _completer = Completer<void>();
  }

  static void complete() {
    _running = false;
    final completer = _completer;
    _completer = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  /// Waits for the running preparation, but never longer than [timeout].
  static Future<void> wait({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final completer = _completer;
    if (completer == null) {
      return;
    }
    try {
      await completer.future.timeout(timeout);
    } on TimeoutException {
      // A slow refresh must not keep the user from connecting.
    }
  }
}
