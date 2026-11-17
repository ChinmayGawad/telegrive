import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../l10n/mobile_strings.dart';
import '../data/backup_capabilities.dart';

/// An inline explanation, not another competing status banner.
class BackupForegroundGuidance extends ConsumerWidget {
  const BackupForegroundGuidance({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!visible ||
        ref.watch(backupCapabilitiesProvider) != BackupCapabilities.foregroundOnly) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.s),
      child: Text(
        MobileStrings.of(context).backupForegroundGuidance,
        style: context.text.bodyMedium?.copyWith(color: context.colors.text2),
      ),
    );
  }
}
