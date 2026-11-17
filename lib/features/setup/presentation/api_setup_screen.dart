import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/tokens.dart';
import '../../../infrastructure/telegram/api_credentials.dart';
import '../../../infrastructure/telegram/telegram_client.dart';

/// Shown once, before the Telegram sign-in screen, when the user has not yet
/// provided their own Telegram API credentials.
///
/// Every person who builds and sideloads Telegrive obtains free credentials at
/// https://my.telegram.org → API development tools. They are stored in the
/// device Keychain and never leave the device.
class ApiSetupScreen extends ConsumerStatefulWidget {
  const ApiSetupScreen({super.key});

  @override
  ConsumerState<ApiSetupScreen> createState() => _ApiSetupScreenState();
}

class _ApiSetupScreenState extends ConsumerState<ApiSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _hashController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _idController.dispose();
    _hashController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _saving = true; _error = null; });
    try {
      final creds = ApiCredentials(
        apiId: int.parse(_idController.text.trim()),
        apiHash: _hashController.text.trim(),
      );
      await ref.read(apiCredentialsProvider.notifier).save(creds);
      // Invalidate telegramClientProvider so TDLib re-initializes with the fresh credentials
      ref.invalidate(telegramClientProvider);
      // appPhaseProvider rebuilds and the router redirects automatically.
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter, Space.xxl, Space.gutter, Space.xl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: Space.xl),
                Icon(
                  Icons.vpn_key_rounded,
                  size: 48,
                  color: colors.primary,
                ),
                const SizedBox(height: Space.l),
                Text(
                  'Set up your Telegram API',
                  style: text.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.m),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(
                      text:
                          'Telegrive is open-source and does not include API '
                          'credentials. You need to register your own for '
                          'free at ',
                    ),
                    TextSpan(
                      text: 'my.telegram.org',
                      style: TextStyle(
                        color: colors.primary,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => launchUrl(
                              Uri.parse('https://my.telegram.org'),
                              mode: LaunchMode.externalApplication,
                            ),
                    ),
                    const TextSpan(
                      text:
                          ' → API development tools → Create application.\n\n'
                          'Your credentials are stored only on this device '
                          'and are never shared.',
                    ),
                  ]),
                  style: text.bodyMedium?.copyWith(color: colors.text2),
                ),
                const SizedBox(height: Space.xxl),
                TextFormField(
                  controller: _idController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'API ID',
                    hintText: 'e.g. 12345678',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) return 'Enter a valid numeric API ID';
                    return null;
                  },
                ),
                const SizedBox(height: Space.m),
                TextFormField(
                  controller: _hashController,
                  decoration: const InputDecoration(
                    labelText: 'API Hash',
                    hintText: '32-character hex string',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.length != 32) return 'API Hash must be 32 characters';
                    if (!RegExp(r'^[0-9a-f]+$').hasMatch(s)) {
                      return 'API Hash must contain only hex characters (0–9, a–f)';
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: Space.m),
                  Text(
                    _error!,
                    style: text.bodySmall?.copyWith(color: colors.error),
                  ),
                ],
                const SizedBox(height: Space.xl),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
                const SizedBox(height: Space.m),
                Text(
                  'These credentials are yours alone. Never share them.\n'
                  'Telegrive stores them in your device\'s secure keychain.',
                  style: text.bodySmall?.copyWith(color: colors.text3),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
