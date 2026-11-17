import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegrive/app/theme/app_theme.dart';
import 'package:telegrive/core/files/file_kind.dart';
import 'package:telegrive/features/backup/data/backup_capabilities.dart';
import 'package:telegrive/features/backup/presentation/backup_foreground_guidance.dart';
import 'package:telegrive/features/drive/domain/drive_models.dart';
import 'package:telegrive/features/home/presentation/home_storage.dart';
import 'package:telegrive/infrastructure/database/app_database.dart';

const _summary = StorageSummary(totals: [KindTotal(FileKind.video, 12, 1048576)]);
const _guidance = 'Keep Telegrive open while photos back up. '
    'Backup continues when you reopen it.';

void main() {
  for (final capability in BackupCapabilities.values) {
    testWidgets('backup guidance matches $capability', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [backupCapabilitiesProvider.overrideWithValue(capability)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: BackupForegroundGuidance(visible: true)),
        ),
      ));
      expect(find.text(_guidance), capability == BackupCapabilities.foregroundOnly
          ? findsOneWidget : findsNothing);
    });
  }

  testWidgets('storage starts collapsed and retains expansion across remounts', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    Widget page({bool showStorage = true}) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: showStorage
            ? const HomeStorage(summary: _summary, offline: null)
            : const SizedBox.shrink()),
      ),
    );
    await tester.pumpWidget(page());
    expect(find.text('Videos'), findsNothing);
    await tester.tap(find.text('Show storage categories'));
    await tester.pump();
    expect(find.text('Videos'), findsOneWidget);
    await tester.pumpWidget(page(showStorage: false));
    await tester.pumpWidget(page());
    expect(find.text('Videos'), findsOneWidget);
    await tester.tap(find.text('Hide storage categories'));
    await tester.pump();
    expect(find.text('Videos'), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets('storage at large text on a small phone, dark=$dark', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(homeStorageExpandedProvider.notifier).toggle();
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.2)),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: HomeStorage(summary: _summary, offline: (1000000, 1234567890123)),
              ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  }
}
