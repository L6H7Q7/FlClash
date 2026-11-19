import 'package:fl_clash/common/common.dart';
import 'package:flutter/foundation.dart';

/// Retry interval and count of a failed outbound check.
class DetectionRetryStore {
  DetectionRetryStore._();

  static final ValueNotifier<int> intervalSeconds = ValueNotifier<int>(3);

  static final ValueNotifier<int> maxCount = ValueNotifier<int>(10);

  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    intervalSeconds.value = await preferences.getDetectionRetryIntervalSeconds();
    maxCount.value = await preferences.getDetectionRetryMaxCount();
  }

  static Future<void> setIntervalSeconds(int value) async {
    if (intervalSeconds.value == value) {
      return;
    }
    intervalSeconds.value = value;
    await preferences.saveDetectionRetryIntervalSeconds(value);
  }

  static Future<void> setMaxCount(int value) async {
    if (maxCount.value == value) {
      return;
    }
    maxCount.value = value;
    await preferences.saveDetectionRetryMaxCount(value);
  }
}
