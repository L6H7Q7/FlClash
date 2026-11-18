import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void _openRegionPreferenceEditor(BuildContext context) {
  showSheet<void>(
    context: context,
    builder: (_) => const _RegionPreferenceSheet(),
  );
}

/// Shows the preferred regions and, for the first proxy group, the node the
/// feature picked with its live delay.
class RegionPreferenceCard extends ConsumerWidget {
  const RegionPreferenceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<bool>(
      valueListenable: RegionPreferenceStore.enabled,
      builder: (context, enabled, _) {
        return ValueListenableBuilder<List<String>>(
          valueListenable: RegionPreferenceStore.regions,
          builder: (context, regions, _) {
            return DashboardCard(
              onTap: () => _openRegionPreferenceEditor(context),
              semanticLabel: '地区偏好',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  DashboardCardHeader(
                    glyph: AppGlyphs.target,
                    title: '地区偏好',
                    trailing: [
                      DashboardChip(
                        label: enabled ? '已开启' : '已关闭',
                        tone: enabled
                            ? DashboardChipTone.ok
                            : DashboardChipTone.idle,
                        dot: true,
                      ),
                    ],
                  ),
                  Text(
                    regions.isEmpty ? '未设置' : regions.join(' → '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DashboardText.rowTitle(context),
                  ),
                  const _CurrentNode(),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CurrentNode extends ConsumerWidget {
  const _CurrentNode();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    final group = groups.isEmpty ? null : groups.first;
    final name = group == null
        ? ''
        : (ref.watch(selectedProxyNameProvider(group.name)) ?? '');
    final delay = group == null || name.isEmpty
        ? null
        : ref.watch(
            delayProvider(proxyName: name, testUrl: group.testUrl),
          );
    final colorScheme = context.colorScheme;
    return Row(
      spacing: 8,
      children: [
        Text('当前节点', style: DashboardText.label(context)),
        Expanded(
          child: Text(
            name.isEmpty ? '—' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardText.rowTitle(context),
          ),
        ),
        if (delay == null)
          Text('—', style: DashboardText.label(context))
        else if (delay < 0)
          const DashboardChip(label: '超时', tone: DashboardChipTone.warn)
        else
          Text(
            '${delay}ms',
            style: DashboardText.label(context).copyWith(
              color: delay <= 400
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _RegionPreferenceSheet extends StatefulWidget {
  const _RegionPreferenceSheet();

  @override
  State<_RegionPreferenceSheet> createState() => _RegionPreferenceSheetState();
}

class _RegionPreferenceSheetState extends State<_RegionPreferenceSheet> {
  late final List<String> _selected = [
    ...RegionPreferenceStore.regions.value,
  ];

  void _toggle(String region) {
    setState(() {
      if (_selected.contains(region)) {
        _selected.remove(region);
      } else {
        _selected.add(region);
      }
    });
  }

  Future<void> _save() async {
    await RegionPreferenceStore.setRegions(_selected);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Widget _buildRegionChip(String region) {
    final index = _selected.indexOf(region);
    final selected = index >= 0;
    final colorScheme = context.colorScheme;
    return GestureDetector(
      onTap: () => _toggle(region),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: ShapeDecoration(
          color: selected
              ? colorScheme.primary
              : context.raisedSurfaceLevel.colorOf(colorScheme),
          shape: AppShape.full,
        ),
        child: Text(
          selected ? '${index + 1}. $region' : region,
          style: AppTextStyle.caption1.of(context).copyWith(
            color: selected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Scaffold(
      title: '地区偏好',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.check,
          tooltip: appLocalizations.save,
          onPressed: _save,
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
          top: context.sectionsTopPadding,
          bottom: 32 + context.bottomInset,
        ),
        children: [
          Text(
            '点选地区，顺序即优先级。启动后按顺序选第一个有可用节点的地区里延迟最低的节点，'
            '该地区全挂时自动顺延到下一个；一个都不选则不干预。',
            style: AppTextStyle.subheadline
                .of(context)
                .copyWith(color: context.colorScheme.onSurfaceVariant, height: 1.6),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final region in commonRegionOrder) _buildRegionChip(region),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            _selected.isEmpty ? '未设置' : _selected.join(' → '),
            style: AppTextStyle.title2.of(context, emphasized: true),
          ),
          const SizedBox(height: 8),
          Text(
            '偏好：${_selected.isEmpty ? '未设置，全部节点里挑延迟最低' : _selected.join(' → ')}',
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(color: context.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
