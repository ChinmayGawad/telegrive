import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// UI guidance only: scheduling remains owned by the backup worker.
enum BackupCapabilities { foregroundOnly, unattended }

final backupCapabilitiesProvider = Provider<BackupCapabilities>((ref) {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? BackupCapabilities.unattended
      : BackupCapabilities.foregroundOnly;
});
