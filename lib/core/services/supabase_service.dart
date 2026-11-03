import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String _supabaseUrl =
      String.fromEnvironment('SUPABASE_URL');
  static const String _supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      throw StateError(
        'Supabase configuration is missing. Provide '
        '--dart-define=SUPABASE_URL=... and '
        '--dart-define=SUPABASE_ANON_KEY=... when running or building.',
      );
    }

    final uri = Uri.tryParse(_supabaseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        !uri.host.endsWith('.supabase.co')) {
      throw StateError('SUPABASE_URL is not a valid Supabase project URL.');
    }

    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
  }
}
