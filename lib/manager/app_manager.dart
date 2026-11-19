import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/common/system_dns.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppStateManager extends ConsumerStatefulWidget {
  final Widget child;

  const AppStateManager({super.key, required this.child});

  @override
  ConsumerState<AppStateManager> createState() => _AppStateManagerState();
}

class _AppStateManagerState extends ConsumerState<AppStateManager>
    with WidgetsBindingObserver {
  var _connectionNotified = false;
  var _stabilizing = false;
  Timer? _stableCheck10;
  Timer? _stableCheck20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A desktop build started to the tray mounts while hidden, and a paused
    // render never runs a post-frame callback.
    scheduleMicrotask(() {
      if (mounted) {
        _updateVisible(WidgetsBinding.instance.lifecycleState);
      }
    });
    ref.listenManual(configProvider, (prev, next) {
      if (prev != next) {
        ref.read(storeActionProvider.notifier).savePreferencesDebounce();
      }
    });
    ref.listenManual(groupsProvider, (prev, next) {
      if (prev != next) {
        unawaited(precacheTargetIcons(next.map((group) => group.icon)));
      }
    }, fireImmediately: true);
    ref.listenManual(iconSetsProvider, (_, next) {
      if (next.value case final iconSets?) {
        unawaited(
          precacheTargetIcons(iconSets.map((iconSet) => iconSet.cover)),
        );
      }
    }, fireImmediately: true);
    ref.listenManual(needUpdateGroupsProvider, (prev, next) {
      if (prev != next) {
        ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
      }
    });
    ref.listenManual(suspendProvider, (prev, next) {
      if (prev != next) {
        ref.read(setupActionProvider.notifier).syncSuspend();
      }
    });
    final systemDns = systemDnsCoordinator;
    if (systemDns != null) {
      ref.listenManual(shouldPatchSystemDnsProvider, (prev, next) {
        unawaited(systemDns.sync(next));
      }, fireImmediately: true);
    }
    ref.listenManual(isStartProvider, (prev, next) {
      _cancelStability();
      if (next) {
        _connectionNotified = false;
      }
    });
    ref.listenManual(
      outboundIpProbeProvider.select(
        (state) => state.entryOf(routedOutbound),
      ),
      (prev, next) {
        if (!ref.read(isStartProvider)) {
          return;
        }
        if (next.value == null || next.phase != ProbePhase.fresh) {
          return;
        }
        if (next.stamp?.proxied != true) {
          return;
        }
        _onCheckPassed();
      },
    );
  }

  /// The first pass starts the stability window: two rechecks ten and twenty
  /// seconds later must both still see a proxied exit before the run is
  /// announced as connected.
  void _onCheckPassed() {
    if (_stabilizing || _connectionNotified) {
      return;
    }
    _stabilizing = true;
    _stableCheck10 = Timer(const Duration(seconds: 10), () async {
      if (!_stabilizing) {
        return;
      }
      final passed = await _recheckOutbound();
      if (!passed) {
        _cancelStability();
      }
    });
    _stableCheck20 = Timer(const Duration(seconds: 20), () async {
      if (!_stabilizing) {
        return;
      }
      final passed = await _recheckOutbound();
      if (!passed) {
        _cancelStability();
        return;
      }
      _connectionNotified = true;
      _cancelStability();
      unawaited(
        AppNotification.show(
          title: '节点连接成功',
          body: _currentNodeName(),
        ),
      );
    });
  }

  Future<bool> _recheckOutbound() async {
    if (!ref.read(isStartProvider)) {
      return false;
    }
    final notifier = ref.read(outboundIpProbeProvider.notifier);
    notifier.refresh(const [routedOutbound]);
    final deadline = DateTime.now().add(const Duration(seconds: 6));
    while (DateTime.now().isBefore(deadline)) {
      if (!ref.read(isStartProvider)) {
        return false;
      }
      final entry = ref.read(
        outboundIpProbeProvider,
      ).entryOf(routedOutbound);
      if (entry.phase == ProbePhase.failed) {
        return false;
      }
      if (entry.value != null && entry.stamp?.proxied == true) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  void _cancelStability() {
    _stabilizing = false;
    _stableCheck10?.cancel();
    _stableCheck10 = null;
    _stableCheck20?.cancel();
    _stableCheck20 = null;
  }

  String _currentNodeName() {
    final groups = ref.read(groupsProvider);
    if (groups.isEmpty) {
      return '';
    }
    return ref.read(selectedProxyNameProvider(groups.first.name)) ?? '';
  }

  @override
  void dispose() {
    _cancelStability();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _updateVisible(AppLifecycleState? state) {
    ref.read(appVisibleProvider.notifier).value = switch (state) {
      null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached => false,
    };
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    _updateVisible(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(locationPermissionsProvider.notifier).refresh());
      // A certificate removed meanwhile stops decryption before the next start.
      if (mitmFeature && ref.read(patchClashConfigProvider).mitm.enable) {
        unawaited(ref.read(mitmTrustStateProvider.notifier).refresh());
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(routeTrackerProvider.notifier).markResumed();
      });
    }
  }

  @override
  void didChangePlatformBrightness() {
    ref.read(themeActionProvider.notifier).updateBrightness();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class AppEnvManager extends ConsumerWidget {
  final Widget child;

  const AppEnvManager({super.key, required this.child});

  String? _bannerMessage({required bool safeMode}) {
    if (safeMode) {
      return 'SAFE MODE';
    }
    if (!globalState.isPre) {
      return null;
    }
    return kDebugMode ? 'DEBUG' : globalState.appEnv.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = _bannerMessage(safeMode: ref.watch(safeModeProvider));
    if (message == null) {
      return child;
    }
    return Banner(
      message: message,
      location: BannerLocation.topEnd,
      child: child,
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.items,
    required this.currentIndex,
    required this.viewMode,
    required this.onSelected,
  });

  final List<NavigationItem> items;
  final int currentIndex;
  final ViewMode viewMode;
  final void Function(int index) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canExpand = canExpandSidebar(viewMode);
    final sidebarExpanded = ref.watch(
      appSettingProvider.select((state) => state.sidebarExpanded),
    );
    final version = ref.watch(versionProvider);
    return NavigationSidebar(
      destinations: [
        for (final item in items)
          SidebarDestination(glyph: item.glyph, label: item.label.label),
      ],
      selectedIndex: currentIndex,
      expanded: canExpand && sidebarExpanded,
      onSelected: onSelected,
      onToggle: canExpand
          ? () {
              ref
                  .read(appSettingProvider.notifier)
                  .update(
                    (state) =>
                        state.copyWith(sidebarExpanded: !state.sidebarExpanded),
                  );
            }
          : null,
      windowControls: windowControlsOverSidebar(
        isMacOS: system.isMacOS,
        version: version,
      ),
    );
  }
}

class AppSidebarContainer extends ConsumerWidget {
  final Widget child;

  const AppSidebarContainer({super.key, required this.child});

  void _updateSideBarWidth(WidgetRef ref, double contentWidth) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sideWidthProvider.notifier).value =
          ref.read(viewSizeProvider.select((state) => state.width)) -
          contentWidth;
    });
  }

  void _handleToPage(WidgetRef ref, PageLabel pageLabel) {
    final focusNode = FocusManager.instance.primaryFocus;
    final focusContext = focusNode?.context;
    final preserveNavigationFocus =
        focusContext?.findAncestorWidgetOfExactType<NavigationSidebar>() !=
        null;
    ref.read(currentPageLabelProvider.notifier).toPage(pageLabel);
    if (!preserveNavigationFocus || focusNode == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focusNode.context != null && focusNode.canRequestFocus) {
        focusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationState = ref.watch(navigationStateProvider);
    final navigationItems = navigationState.navigationItems;
    final viewMode = navigationState.viewMode;
    final currentIndex = navigationState.currentIndex;
    final backdropOpacity = ref.watch(windowBlurProvider);
    final page = SurfaceLevel.page.colorOf(context.colorScheme);
    final chrome = context.colorScheme.chromeSurface;
    void onSelected(int index) {
      _handleToPage(ref, navigationItems[index].label);
    }

    final hasSidebar = viewMode != ViewMode.mobile;
    final isLtr = Directionality.of(context) == TextDirection.ltr;
    return Container(
      color: backdropOpacity != null ? Colors.transparent : page,
      child: Row(
        children: [
          AnimatedVisibility.sidebar(
            visible: hasSidebar,
            child: Surface(
              color: backdropOpacity != null
                  ? chrome.withValues(alpha: backdropOpacity)
                  : chrome,
              shape: BorderDirectional(end: Divider.createBorderSide(context)),
              child: MediaQuery.removePadding(
                context: context,
                removeLeft: !isLtr,
                removeRight: isLtr,
                child: _Sidebar(
                  items: navigationItems,
                  currentIndex: currentIndex,
                  viewMode: viewMode,
                  onSelected: onSelected,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: ClipRect(
              child: LayoutBuilder(
                builder: (_, constraints) {
                  _updateSideBarWidth(ref, constraints.maxWidth);
                  return MediaQuery.removePadding(
                    context: context,
                    removeLeft: hasSidebar && isLtr,
                    removeRight: hasSidebar && !isLtr,
                    child: child,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
