import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegrive/features/lock/data/app_lock.dart';
import 'package:telegrive/features/lock/presentation/privacy_snapshot_gate.dart';
import 'package:telegrive/features/private/data/private_space.dart';

class _Lock extends AppLock {
  @override
  AppLockState build() => const AppLockState(enabled: true);

  void lock() => state = state.copyWith(locked: true);
}

class _Private extends PrivateSpace {
  @override
  bool build() => false;
}

void main() {
  const channel = MethodChannel('telegrive/security');
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<MethodCall> calls;
  late ProviderContainer container;

  setUp(() {
    calls = [];
    container = ProviderContainer(overrides: [
      appLockProvider.overrideWith(_Lock.new),
      privateSpaceProvider.overrideWith(_Private.new),
      privacySnapshotSupportedProvider.overrideWithValue(true),
    ]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'setPrivateRecents' ? 7 : null;
    });
  });

  tearDown(() {
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const PrivacySnapshotGate(child: SizedBox()),
    ),
  );

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  testWidgets('acknowledges native generation only after safe frames', (tester) async {
    await mount(tester);
    expect(calls.where((c) => c.method == 'privacyForegroundReady'), isEmpty);
    await frames(tester);
    expect(calls.last.method, 'privacyForegroundReady');
    expect(calls.last.arguments, 7);
  });

  testWidgets('waits for private viewer dismissal while unlocked', (tester) async {
    final exit = Completer<void>();
    container.read(privateSpaceProvider.notifier).hidingContent([exit.future]);
    await mount(tester);
    await frames(tester);
    expect(calls.where((c) => c.method == 'privacyForegroundReady'), isEmpty);
    exit.complete();
    await frames(tester);
    expect(calls.last.method, 'privacyForegroundReady');
  });

  testWidgets('app lock supersedes a private exit with muted tickers', (tester) async {
    final exit = Completer<void>();
    container.read(privateSpaceProvider.notifier).hidingContent([exit.future]);
    await mount(tester);
    await frames(tester);
    expect(calls.where((c) => c.method == 'privacyForegroundReady'), isEmpty);
    (container.read(appLockProvider.notifier) as _Lock).lock();
    await frames(tester);
    expect(calls.last.method, 'privacyForegroundReady');
    final acknowledgements = calls.where((c) => c.method == 'privacyForegroundReady').length;
    exit.complete();
    await frames(tester);
    expect(calls.where((c) => c.method == 'privacyForegroundReady').length, acknowledgements);
  });
}
