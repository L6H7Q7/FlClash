import 'package:fl_clash/common/common.dart';
import 'package:flutter/foundation.dart';

/// Global switch and ordered region list of the region preference feature.
///
/// Deliberately kept out of [AppSettingProps] and in local preferences, so the
/// generated model files stay untouched.
class RegionPreferenceStore {
  RegionPreferenceStore._();

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  static final ValueNotifier<List<String>> regions = ValueNotifier<List<String>>(
    const [],
  );

  static bool _loaded = false;
  static bool _applying = false;

  static bool get isApplying => _applying;

  /// True when the feature is on and at least one region is preferred.
  static bool get usable => enabled.value && regions.value.isNotEmpty;

  static Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    enabled.value = await preferences.getRegionPreferenceEnabled();
    regions.value = await preferences.getRegionPreferences();
  }

  static Future<void> setEnabled(bool value) async {
    if (enabled.value == value) {
      return;
    }
    enabled.value = value;
    await preferences.saveRegionPreferenceEnabled(value);
  }

  static Future<void> setRegions(List<String> value) async {
    final normalized = [
      for (final region in value)
        if (region.isNotEmpty) region,
    ];
    regions.value = normalized;
    await preferences.saveRegionPreferences(normalized);
  }

  /// The node the feature last picked, shown beside the run status.
  static final ValueNotifier<String?> lastNode = ValueNotifier<String?>(null);

  static final ValueNotifier<int?> lastDelay = ValueNotifier<int?>(null);

  static void setLastPick(String? node, int? delay) {
    lastNode.value = node;
    lastDelay.value = delay;
  }

  /// Guards against re-entry while a run is switching proxies.
  static bool tryStartApplying() {
    if (_applying) {
      return false;
    }
    _applying = true;
    return true;
  }

  static void finishApplying() {
    _applying = false;
  }
}
