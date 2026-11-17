import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../infrastructure/storage/preferences.dart';
import '../../../l10n/mobile_strings.dart';
import '../data/backup_capabilities.dart';
import '../data/backup_controller.dart';

/// Asks once, right after the drive first opens: "Back up your photos?"
Future<void> maybeAskToBackUp(BuildContext context, WidgetRef ref) async {
  final prefs = ref.read(preferencesProvider);
  if (prefs.backupPromptShown || prefs.backupEnabled) return;
  await prefs.setBackupPromptShown();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheetContext) => _BackupPromptSheet(parentContext: context),
  );
}

class _BackupPromptSheet extends ConsumerWidget {
  const _BackupPromptSheet({required this.parentContext});

  final BuildContext parentContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = MobileStrings.of(context);
    final foreground = ref.watch(backupCapabilitiesProvider) == BackupCapabilities.foregroundOnly;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.backupPromptTitle, style: context.text.headlineSmall),
            const SizedBox(height: Space.m),
            Text(
              '${strings.backupPromptBody} '
              '${foreground ? strings.backupForegroundGuidance : strings.backupUnattendedBody}',
              style: context.text.bodyLarge?.copyWith(color: context.colors.text2),
            ),
            const SizedBox(height: Space.xxl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final ok = await ref.read(backupControllerProvider.notifier).enable();
                  if (!ok && parentContext.mounted) {
                    showSnack(
                      parentContext,
                      strings.backupNeedsAccess,
                    );
                  }
                },
                child: Text(strings.turnOnBackup),
              ),
            ),
            const SizedBox(height: Space.s),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(strings.notNow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
