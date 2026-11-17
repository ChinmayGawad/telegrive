import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../app/app_phase.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/files/file_kind.dart';
import '../../../core/format/formatters.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/common.dart';
import '../../../infrastructure/database/app_database.dart'
    show TransferOrigin, TransferStatus;
import '../../../infrastructure/storage/preferences.dart';
import '../../../infrastructure/telegram/telegram_client.dart';
import '../../backup/data/background_health.dart';
import '../../backup/data/backup_controller.dart';
import '../../backup/data/free_up_space.dart';
import '../../backup/presentation/backup_card.dart';
import '../../backup/presentation/free_up_space_sheet.dart';
import '../../drive/data/drive_repository.dart';
import '../../drive/data/drive_session.dart';
import '../../drive/data/drive_sync.dart';
import '../../drive/data/edit_outbox.dart';
import '../../drive/data/forward_filer.dart';
import '../../drive/domain/drive_models.dart';
import '../../files/presentation/file_actions.dart';
import '../../files/presentation/file_tiles.dart';
import '../../network/data/connection_health.dart';
import '../../network/data/mobile_data.dart';
import '../../network/data/proxies.dart';
import '../../network/presentation/proxy_sheet.dart';
import '../../offline/data/offline_sync.dart';
import '../../player/data/play_positions.dart';
import '../../setup/data/drive_setup.dart';
import '../../takeout/data/takeout_import.dart';
import '../../takeout/presentation/takeout_status.dart';
import '../../transfers/data/transfer_queue.dart';
import 'drive_health.dart';
import 'home_storage.dart';
import '../../../l10n/mobile_strings.dart';
import '../../backup/presentation/backup_foreground_guidance.dart';

/// What is in the drive and what is happening to it. What this phone was
/// partway through playing first, when there is anything; then where the
/// recent files are; then starred folders and a compact storage summary.
/// Continue Playing and Recent stay off Home while
/// Settings says not to show Recent there.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(storageSummaryProvider).value;
    final showsRecent = ref.watch(
      preferencesProvider.select((p) => p.homeShowsRecent),
    );
    final recent = showsRecent ? ref.watch(recentActivityProvider(12)) : null;
    final starredFolders =
        ref.watch(starredFoldersProvider).value ?? const <DriveFolder>[];
    final starredSizes = ref.watch(starredFolderSizesProvider).value;
    final starred =
        (ref.watch(starredFilesProvider).value?.length ?? 0) +
        starredFolders.length;
    final pinned = ref.watch(offlinePinsProvider).value?.isNotEmpty ?? false;
    final offline = ref.watch(offlineUsageProvider).value;
    final starredRow = starred > 0
        ? ListTile(
            leading: const Icon(Icons.star_outline_rounded),
            title: Text(MobileStrings.of(context).starred),
            trailing: Text(
              Formatters.number(starred),
              style: context.text.bodyMedium?.copyWith(
                fontFeatures: tabularFigures,
              ),
            ),
            onTap: () => context.push('/starred'),
          )
        : null;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'home-fab',
        onPressed: () => FileActions.showCreateSheet(context, ref),
        tooltip: MobileStrings.of(context).newItem,
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(driveSyncProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverSafeArea(
              bottom: false,
              sliver: SliverToBoxAdapter(child: _Header()),
            ),
            const SliverToBoxAdapter(child: _Activity()),
            if (showsRecent)
              const SliverToBoxAdapter(child: _ContinuePlaying()),
            if (recent == null)
              SliverToBoxAdapter(
                child: switch (summary) {
                  StorageSummary(fileCount: 0) => const _NothingYet(),
                  _ when starredRow != null => Padding(
                    padding: const EdgeInsets.only(top: Space.l),
                    child: ListGroup(children: [starredRow]),
                  ),
                  _ => const SizedBox.shrink(),
                },
              )
            else ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  MobileStrings.of(context).recent,
                  trailing: _SeeAll(onPressed: () => context.push('/recent')),
                ),
              ),
              SliverToBoxAdapter(
                child: switch (recent) {
                  // Until the drive has been counted it isn't known to be
                  // empty, so nothing is said yet.
                  AsyncData(value: final entries) when entries.isEmpty =>
                    switch (summary) {
                      null => const SizedBox.shrink(),
                      StorageSummary(fileCount: 0) => const _NothingYet(),
                      _ => Column(
                        children: [
                          EmptyState(
                            title: MobileStrings.of(context).nothingOpenedYet,
                            message: MobileStrings.of(context).recentEmptyMessage,
                            compact: true,
                          ),
                          if (starredRow != null)
                            ListGroup(children: [starredRow]),
                        ],
                      ),
                    },
                  AsyncData(value: final entries) => ListGroup(
                    children: [
                      for (final entry in entries.take(5))
                        FileListTile(
                          file: entry.file,
                          subtitle:
                              '${Formatters.bytes(entry.file.size)} · '
                              '${entry.verb} ${Formatters.date(entry.at)}',
                          onTap: () => FileActions.open(context, ref, entry.file),
                          onLongPress: () =>
                              FileActions.showFileSheet(context, ref, entry.file),
                          onMore: () =>
                              FileActions.showFileSheet(context, ref, entry.file),
                        ),
                      ?starredRow,
                    ],
                  ),
                  _ => const Padding(
                    padding: EdgeInsets.all(Space.x3),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                },
              ),
            ],
            if (starredFolders.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  MobileStrings.of(context).starred,
                  trailing: _SeeAll(onPressed: () => context.push('/starred')),
                ),
              ),
              SliverToBoxAdapter(
                child: ListGroup(
                  children: [
                    for (final folder in starredFolders.take(5))
                      FolderListTile(
                        folder: folder,
                        subtitle: folderContentsLine(starredSizes?[folder.id]),
                        onTap: () => context.go('/files/${folder.id}'),
                        onLongPress: () =>
                            FileActions.showFolderSheet(context, ref, folder),
                        onMore: () =>
                            FileActions.showFolderSheet(context, ref, folder),
                      ),
                  ],
                ),
              ),
            ],
            if (summary != null && summary.fileCount > 0) ...[
              SliverToBoxAdapter(child: SectionHeader(MobileStrings.of(context).storage)),
              SliverToBoxAdapter(
                child: HomeStorage(
                  summary: summary,
                  offline: pinned ? offline ?? (0, 0) : null,
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 112)),
          ],
        ),
      ),
    );
  }
}

/// The small button at the end of a section header that opens the whole
/// list.
class _SeeAll extends StatelessWidget {
  const _SeeAll({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: Space.s),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: Text(MobileStrings.of(context).seeAll),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final session = ref.watch(visibleSessionProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.m, 0),
      child: Column(
        children: [
          Row(
            children: [
              const BrandMark(size: 28),
              const SizedBox(width: Space.m),
              Expanded(
                child: Text('Telegrive', style: context.text.titleLarge),
              ),
              IconButton(
                onPressed: () => context.push('/transfers'),
                icon: const Icon(Icons.swap_vert_rounded),
                tooltip: MobileStrings.of(context).transfers,
              ),
              const SizedBox(width: Space.xs),
              IconButton(
                tooltip: MobileStrings.of(context).settings,
                onPressed: () => context.push('/settings'),
                icon: CircleAvatar(
                  radius: 17,
                  backgroundColor: colors.surface2,
                  child: Text(
                    session?.initials ?? '?',
                    style: context.text.labelMedium?.copyWith(color: colors.text),
                  ),
                ),
              ),
              const SizedBox(width: Space.s),
            ],
          ),
          const SizedBox(height: Space.l),
          Padding(
            padding: const EdgeInsets.only(right: Space.s),
            child: Material(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(Radii.control),
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.control),
                onTap: () => context.push('/search'),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.all(Space.m),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: colors.text2, size: 22),
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: Text(
                            MobileStrings.of(context).searchFilesAndFolders,
                            style: context.text.bodyLarge?.copyWith(color: colors.text2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One line that says whether the drive is safe, always there, plus at most
/// one more for a different concern that needs doing. What they say is
/// worked out in [describeDriveHealth] and [secondaryHealth]; this only
/// draws them, and lets the group grow and shrink as they change, so the
/// line about connecting folds away once the drive opens.
class _Activity extends ConsumerWidget {
  const _Activity();

  /// How far opening the drive has got while Home shows the one this phone
  /// saved, before its session opens, and what went wrong if it failed.
  static (DriveOpening, String?) _opening(WidgetRef ref) {
    if (ref.watch(driveSessionProvider) != null ||
        ref.watch(driveSnapshotProvider) == null) {
      return (DriveOpening.open, null);
    }
    final fatal = ref.watch(fatalErrorProvider);
    if (fatal != null) return (DriveOpening.notStarted, fatal);
    final failed = ref.watch(driveSetupProvider.select((s) => s.error));
    if (failed != null) return (DriveOpening.failed, failed);
    return (DriveOpening.connecting, null);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backup = ref.watch(backupControllerProvider);
    final sync = ref.watch(driveSyncProvider);
    final transfers = ref.watch(transferQueueProvider);
    final chatId = ref.watch(driveSessionProvider)?.chatId;
    final renewDay = ref.watch(mobileDataProvider.select((d) => d.renewDay));
    final connection = ref.watch(connectionHealthProvider);
    final (opening, openingError) = _opening(ref);

    final top = describeDriveHealth(
      backup: backup,
      sync: sync,
      transfers: transfers,
      lastFullSync: chatId == null
          ? null
          : ref.read(preferencesProvider).lastFullSync(chatId),
      backupSpeed: transfers.backupActive.fold<double>(
        0,
        (sum, t) => sum + t.bytesPerSecond,
      ),
      renewDay: renewDay,
      connection: connection,
      // Read only when the line names it, so Home doesn't ask TDLib for
      // the saved proxies on every visit.
      proxy: connection == ConnectionHealth.proxyStuck
          ? ref.watch(enabledProxyProvider)?.label
          : null,
      opening: opening,
      openingError: openingError,
    );
    // What could be freed is only worked out while the phone is low on
    // space, since it reads the whole photo library.
    final lowOnSpace = ref.watch(lowSpaceProvider).value ?? false;
    final second = secondaryHealth(
      top,
      backup: backup,
      transfers: transfers,
      renewDay: renewDay,
      lowOnSpace: lowOnSpace,
      freeableBytes: lowOnSpace
          ? ref.watch(freeUpCandidatesProvider).value?.bytes ?? 0
          : 0,
      changes: ref.watch(editOutboxProvider),
      filed: ref.watch(forwardFilerProvider),
      backgroundBlocked:
          ref.watch(backgroundHealthProvider).value?.needsAttention(backup.enabled) ?? false,
    );

    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Padding(
        padding: const EdgeInsets.only(top: Space.l),
        child: ListGroup(
          children: [
            _line(context, ref, top),
            if (second != null) _line(context, ref, second),
            BackupForegroundGuidance(
              visible: backup.enabled && (backup.isWorking || backup.remaining > 0),
            ),
            if (takeoutWorthShowing(ref.watch(takeoutImportProvider))) const TakeoutStatusLine(),
          ],
        ),
      ),
    );
  }

  static Widget _line(BuildContext context, WidgetRef ref, DriveHealth health) {
    final colors = context.colors;
    final controller = ref.read(backupControllerProvider.notifier);
    final queue = ref.read(transferQueueProvider.notifier);
    return StatusLine(
      icon: health.icon,
      color: switch (health.tone) {
        HealthTone.busy => colors.accent,
        HealthTone.good => colors.success,
        HealthTone.bad => colors.danger,
        HealthTone.neutral => null,
      },
      text: health.text,
      detail: health.detail,
      progress: health.progress,
      progressColor: health.waiting ? colors.text3 : null,
      trailing: switch (health.action) {
        HealthAction.turnOn => TextButton(
          onPressed: () => enableBackup(context, ref),
          child: const Text('Turn on'),
        ),
        HealthAction.allow => TextButton(
          onPressed: () async {
            if (!await controller.enable()) await PhotoManager.openSetting();
          },
          child: const Text('Allow'),
        ),
        HealthAction.useData => TextButton(
          onPressed: () => controller.setMobileData(BackupMobileData.all),
          child: const Text('Use data'),
        ),
        HealthAction.useDataAnyway => TextButton(
          onPressed: controller.useDataAnyway,
          child: const Text('Use data anyway'),
        ),
        HealthAction.retryBackup => TextButton(
          onPressed: () => controller.schedule(immediate: true),
          child: const Text('Retry'),
        ),
        HealthAction.resumeBackup => TextButton(
          onPressed: controller.resume,
          child: const Text('Resume'),
        ),
        HealthAction.retryFailed => TextButton(
          onPressed: controller.retryFailed,
          child: const Text('Retry'),
        ),
        HealthAction.retryTransfers => TextButton(
          onPressed: () => queue.retryAll(
            (r) =>
                r.status == TransferStatus.failed &&
                r.origin != TransferOrigin.backup,
          ),
          child: const Text('Retry'),
        ),
        HealthAction.resumeTransfers => TextButton(
          onPressed: () => queue.resumeAll(
            (r) => r.origin != TransferOrigin.backup && r.origin != TransferOrigin.takeout,
          ),
          child: const Text('Resume'),
        ),
        HealthAction.useDataForTransfers => TextButton(
          onPressed: () => queue.useMobileData(
            transfersWaitingForWifi(ref.read(transferQueueProvider))
                .map((t) => t.id),
          ),
          child: const Text('Use data'),
        ),
        HealthAction.freeUpSpace => TextButton(
          onPressed: () => showFreeUpSpace(context, ref),
          child: const Text('Free up space'),
        ),
        HealthAction.freeUp => TextButton(
          onPressed: () => showFreeUpSpace(context, ref),
          child: const Text('Free up'),
        ),
        HealthAction.useProxy => TextButton(
          onPressed: () => showProxySheet(context),
          child: const Text('Use a proxy'),
        ),
        HealthAction.changeProxy => TextButton(
          onPressed: () => showProxySheet(context),
          child: const Text('Change proxy'),
        ),
        HealthAction.dismissFiling => IconButton(
          onPressed: ref.read(forwardFilerProvider.notifier).clear,
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Dismiss',
        ),
        HealthAction.retryOpening => TextButton(
          onPressed: ref.read(driveSetupProvider.notifier).run,
          child: const Text('Retry'),
        ),
        HealthAction.restartTelegram => TextButton(
          onPressed: () {
            final client = ref.read(telegramClientProvider);
            client.fatalError.value = null;
            // A failure comes back on this line through fatalError.
            client.start().ignore();
          },
          child: const Text('Try again'),
        ),
        HealthAction.none => null,
      },
      onTap: switch (health.target) {
        HealthTarget.backup => () => context.push('/backup'),
        HealthTarget.notBackedUp => () => context.push('/backup/not-backed-up'),
        HealthTarget.transfers => () => context.push('/transfers'),
        HealthTarget.refresh =>
          () => ref.read(driveSyncProvider.notifier).refresh(),
        HealthTarget.proxy => () => showProxySheet(context),
        HealthTarget.changes => () => context.push('/changes'),
        HealthTarget.filed => () {
          // The folder opens in the Files tab, the way a starred folder
          // does from Home; a folder is a place in that tab, not a screen
          // over this one.
          final folderId = ref.read(forwardFilerProvider)?.folderId;
          context.go(folderId == null ? '/files' : '/files/$folderId');
          ref.read(forwardFilerProvider.notifier).clear();
        },
        HealthTarget.none => null,
      },
    );
  }
}

/// Up to three videos or recordings this phone stopped partway through,
/// most recent first, each with how much is left and where it lives. The
/// group is there only while it has rows: nothing is said while they load,
/// when there are none or when they can't be read.
class _ContinuePlaying extends ConsumerWidget {
  const _ContinuePlaying();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = switch (ref.watch(continuePlayingProvider)) {
      AsyncData(value: final items) when items.isNotEmpty => items,
      _ => null,
    };
    if (items == null) return const SizedBox.shrink();
    final allVideo = items.every((i) => i.file.kind == FileKind.video);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(allVideo ? 'Continue watching' : 'Continue playing'),
        ListGroup(
          children: [
            for (final item in items)
              FileListTile(
                file: item.file,
                subtitle: '${Formatters.left(item.left)} · ${item.place}',
                progress: item.progress,
                onTap: () => FileActions.open(
                  context,
                  ref,
                  item.file,
                  from: item.file.kind == FileKind.audio
                      ? 'folder:${item.file.folderId ?? ''}'
                      : null,
                ),
                onLongPress: () => _showSheet(context, ref, item),
                onMore: () => _showSheet(context, ref, item),
              ),
          ],
        ),
      ],
    );
  }

  static Future<void> _showSheet(
    BuildContext context,
    WidgetRef ref,
    ContinueItem item,
  ) => FileActions.showFileSheet(
    context,
    ref,
    item.file,
    onMarkFinished: () async {
      await ref.read(playPositionsProvider).forget(item.file.id);
      if (context.mounted) {
        showSnack(context, '"${item.file.name}" marked as finished');
      }
    },
  );
}

class _NothingYet extends ConsumerWidget {
  const _NothingYet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EmptyState(
      title: 'Your drive is empty',
      message:
          'Upload files here, or forward any file to your Telegrive channel '
          'in Telegram and it will show up.',
      compact: true,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: () => FileActions.upload(context, ref),
            child: const Text('Upload files'),
          ),
          const SizedBox(height: Space.s),
          TextButton(
            onPressed: () => FileActions.saveFromChat(context, ref),
            child: const Text('Save from a Telegram chat'),
          ),
        ],
      ),
    );
  }
}

