import 'package:fl_clash/common/common.dart';
import 'package:flutter/foundation.dart';

/// Whether the current subscription is refreshed when the app opens.
class SubscriptionAutoUpdateStore {
  SubscriptionAutoUpdateStore._();

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  static bool _loaded = false;

  static bool get usable => enabled.value;

  static Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    enabled.value = await preferences.getSubscriptionAutoUpdate();
  }

  static Future<void> setEnabled(bool value) async {
    if (enabled.value == value) {
      return;
    }
    enabled.value = value;
    await preferences.saveSubscriptionAutoUpdate(value);
  }
}
