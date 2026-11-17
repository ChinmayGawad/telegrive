import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../private/data/private_space.dart';
import '../data/app_lock.dart';

final privacySnapshotSupportedProvider = Provider<bool>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
);

/// The native scene covers snapshots; Flutter acknowledges a safe rendered frame.
/// A generation supplied by native code prevents a late acknowledgement from
/// uncovering a newer background/foreground cycle.
class PrivacySnapshotGate extends ConsumerStatefulWidget {
  const PrivacySnapshotGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PrivacySnapshotGate> createState() => _PrivacySnapshotGateState();
}

class _PrivacySnapshotGateState extends ConsumerState<PrivacySnapshotGate> {
  static const _channel = MethodChannel('telegrive/security');
  bool _supported = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _supported = ref.read(privacySnapshotSupportedProvider);
    if (!_supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'privacyActive' && call.arguments is int) {
        await _ready(call.arguments as int);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_configure());
    });
  }

  Future<void> _configure() async {
    if (!_supported || !mounted) return;
    try {
      final enabled = ref.read(appLockProvider).enabled || ref.read(privateSpaceProvider);
      final generation = await _channel.invokeMethod<int>('setPrivateRecents', enabled);
      if (generation != null && mounted) await _ready(generation);
    } on PlatformException catch (e) {
      debugPrint('[PrivacySnapshot] ${e.code}');
    } on MissingPluginException {
      // Isolated widget previews do not have the native scene bridge.
    }
  }

  Future<void> _ready(int generation) async {
    final request = ++_request;
    // Let app lock and Private process resume and build their protected UI.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || request != _request) return;
    // LockGate mutes the navigator's tickers. Its opaque lock screen is
    // already safe, and waiting for a muted exit animation would deadlock.
    if (!ref.read(appLockProvider).locked) {
      await ref.read(privateSpaceProvider.notifier).contentHidden;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || request != _request) return;
    try {
      await _channel.invokeMethod<void>('privacyForegroundReady', generation);
    } on PlatformException catch (e) {
      debugPrint('[PrivacySnapshot] ${e.code}');
    } on MissingPluginException {
      // No native bridge in a widget preview.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<(bool, bool)>(
      appLockProvider.select((lock) => (lock.enabled, lock.locked)),
      (_, _) {
      unawaited(_configure());
      },
    );
    ref.listen<bool>(privateSpaceProvider, (_, _) => unawaited(_configure()));
    return widget.child;
  }

  @override
  void dispose() {
    _request++;
    if (_supported) _channel.setMethodCallHandler(null);
    super.dispose();
  }
}
