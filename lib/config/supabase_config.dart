import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Ganti kedua nilai ini dengan yang ada di:
  // Supabase Dashboard -> Settings -> API
  static const String supabaseUrl = '';
  static const String supabaseAnonKey =
      '';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}
