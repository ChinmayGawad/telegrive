import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../telegram/secure_store.dart';

/// Runtime API credentials entered by the user at first launch.
/// Stored in the device keychain; never committed to source.
class ApiCredentials {
  const ApiCredentials({required this.apiId, required this.apiHash});

  final int apiId;
  final String apiHash;

  bool get isValid => apiId > 0 && apiHash.length == 32;
}

/// Reads and writes the user-entered Telegram API credentials to the device
/// keychain alongside the existing TDLib database key.
extension ApiCredentialStore on SecureStore {
  static const _apiIdKey = 'telegram_api_id';
  static const _apiHashKey = 'telegram_api_hash';

  Future<ApiCredentials?> readApiCredentials() async {
    final idStr = await readKey(_apiIdKey);
    final hash = await readKey(_apiHashKey);
    if (idStr == null || hash == null) return null;
    final id = int.tryParse(idStr);
    if (id == null || id <= 0 || hash.length != 32) return null;
    return ApiCredentials(apiId: id, apiHash: hash);
  }

  Future<void> writeApiCredentials(ApiCredentials creds) async {
    await writeKey(_apiIdKey, creds.apiId.toString());
    await writeKey(_apiHashKey, creds.apiHash);
  }

  Future<void> clearApiCredentials() async {
    await deleteKey(_apiIdKey);
    await deleteKey(_apiHashKey);
  }
}

/// Notifier that holds the credentials once loaded.
/// A null means they have not been entered yet → show setup screen.
class ApiCredentialsNotifier extends AsyncNotifier<ApiCredentials?> {
  @override
  Future<ApiCredentials?> build() async {
    // 1. Check if built-in credentials were provided at compile time (dart-define or telegram_api.dart)
    if (AppConfig.telegramApiId > 0 && AppConfig.telegramApiHash.isNotEmpty) {
      return const ApiCredentials(
        apiId: AppConfig.telegramApiId,
        apiHash: AppConfig.telegramApiHash,
      );
    }
    // 2. Otherwise load user-entered credentials from the device Keychain
    final store = ref.watch(secureStoreProvider);
    return store.readApiCredentials();
  }

  Future<void> save(ApiCredentials creds) async {
    final store = ref.read(secureStoreProvider);
    await store.writeApiCredentials(creds);
    state = AsyncData(creds);
  }

  Future<void> clear() async {
    final store = ref.read(secureStoreProvider);
    await store.clearApiCredentials();
    state = const AsyncData(null);
  }
}

final apiCredentialsProvider =
    AsyncNotifierProvider<ApiCredentialsNotifier, ApiCredentials?>(
      ApiCredentialsNotifier.new,
    );
