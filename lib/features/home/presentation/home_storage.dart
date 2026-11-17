import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/file_style.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/files/file_kind.dart';
import '../../../core/format/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../infrastructure/database/app_database.dart' show KindTotal;
import '../../../l10n/mobile_strings.dart';
import '../../drive/data/drive_session.dart';
import '../../drive/domain/drive_models.dart';

/// Retained when slivers leave the viewport; reset for a different drive.
class HomeStorageExpanded extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(driveSessionProvider.select((session) => session?.chatId));
    return false;
  }

  void toggle() => state = !state;
}

final homeStorageExpandedProvider = NotifierProvider<HomeStorageExpanded, bool>(
  HomeStorageExpanded.new,
);

/// Total, which opens Space, one proportional bar, then a row per kind that
/// opens it, and the way into what this phone keeps offline.
class HomeStorage extends ConsumerWidget {
  const HomeStorage({super.key, required this.summary, required this.offline});

  final StorageSummary summary;

  /// How many files are kept offline and their size, or null while nothing
  /// is, which leaves the row out.
  final (int, int)? offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(homeStorageExpandedProvider);
    final strings = MobileStrings.of(context);
    final colors = context.colors;
    final kinds = [...summary.totals.where((t) => t.count > 0)]
      ..sort((a, b) => b.bytes.compareTo(a.bytes));

    return ListGroup(
      children: [
        InkWell(
          onTap: () => context.push('/space'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.l,
              Space.gutter,
              Space.l,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: Formatters.bytes(summary.bytes),
                              style: context.text.titleMedium,
                            ),
                            TextSpan(
                              text:
                                  '  in ${Formatters.count(summary.fileCount, 'file')}',
                              style: context.text.bodyMedium,
                            ),
                          ],
                        ),
                        style: const TextStyle(fontFeatures: tabularFigures),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.text3,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: Space.m),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    width: double.infinity,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, total) in kinds.indexed) ...[
                          if (index > 0)
                            SizedBox(
                              width: 2,
                              child: ColoredBox(color: colors.surface),
                            ),
                          Expanded(
                            flex: (total.bytes * 1000 ~/ (summary.bytes == 0 ? 1 : summary.bytes)).clamp(
                              6,
                              1000,
                            ),
                            child: ColoredBox(
                              color: FileStyle.forKind(total.kind)
                                  .resolve(context, colors.text3),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Semantics(
          expanded: expanded,
          child: ListTile(
            title: Text(expanded ? strings.hideStorageCategories : strings.showStorageCategories),
            trailing: Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
            onTap: () => ref.read(homeStorageExpandedProvider.notifier).toggle(),
          ),
        ),
        if (expanded) ...[
          for (final total in kinds) _KindRow(total: total),
        ],
        if (offline case (final count, final bytes)?)
          _OfflineRow(count: count, bytes: bytes),
      ],
    );
  }
}

/// Files kept on this phone for use without a connection, laid out as a
/// kind row is, opening the Offline screen.
class _OfflineRow extends StatelessWidget {
  const _OfflineRow({required this.count, required this.bytes});

  final int count;
  final int bytes;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: () => context.push('/offline'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.gutter,
          vertical: 14,
        ),
        child: Row(
          children: [
            Icon(Icons.offline_pin_outlined, size: 22, color: colors.text2),
            const SizedBox(width: Space.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available offline', style: context.text.titleSmall),
                  Text(
                    '${Formatters.count(count, 'file')} · ${Formatters.bytes(bytes)}',
                    style: context.text.bodyMedium?.copyWith(fontFeatures: tabularFigures),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.xs),
            Icon(Icons.chevron_right_rounded, color: colors.text3, size: 20),
          ],
        ),
      ),
    );
  }
}

class _KindRow extends StatelessWidget {
  const _KindRow({required this.total});

  final KindTotal total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = FileStyle.forKind(total.kind);
    return InkWell(
      onTap: () => context.push('/category/${total.kind.name}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.gutter,
          vertical: 14,
        ),
        child: Row(
          children: [
            Icon(
              style.icon,
              size: 22,
              color: style.resolve(context, colors.text2),
            ),
            const SizedBox(width: Space.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(total.kind.label, style: context.text.titleSmall),
                  Text(
                    '${Formatters.count(total.count, _noun(total.kind))} · '
                    '${Formatters.bytes(total.bytes)}',
                    style: context.text.bodyMedium?.copyWith(fontFeatures: tabularFigures),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.xs),
            Icon(Icons.chevron_right_rounded, color: colors.text3, size: 20),
          ],
        ),
      ),
    );
  }

  static String _noun(FileKind kind) => switch (kind) {
    FileKind.image => 'photo',
    FileKind.video => 'video',
    FileKind.audio => 'track',
    FileKind.app => 'app',
    _ => 'file',
  };
}
