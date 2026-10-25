import 'package:supabase_flutter/supabase_flutter.dart';

/// Local configuration for the optional social backend.
///
/// Values come from dart-defines supplied by the run script, never from the
/// repository. This keeps the curated map fully usable before social features
/// are configured.
class SocialConfig {
  const SocialConfig._();

  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool _isInitialized = false;

  static bool get isConfigured =>
      Uri.tryParse(_url)?.hasScheme == true && _publishableKey.isNotEmpty;

  static bool get isAvailable => isConfigured && _isInitialized;

  static Future<void> initialize() async {
    if (!isConfigured) return;

    await Supabase.initialize(url: _url, anonKey: _publishableKey);
    _isInitialized = true;
  }

  static SupabaseClient get client {
    if (!isAvailable) {
      throw StateError('Social features have not been configured yet.');
    }
    return Supabase.instance.client;
  }
}
