import 'package:flutter/foundation.dart';

/// The start button's run while the preferred regions are measured and the
/// nodes picked, before the listener takes traffic.
class ConnectionStart {
  ConnectionStart._();

  static final ValueNotifier<bool> running = ValueNotifier<bool>(false);

  static void begin() {
    running.value = true;
  }

  static void end() {
    running.value = false;
  }
}
