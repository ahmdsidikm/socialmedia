import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://rfkivmxezjerwwusfbji.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJma2l2bXhlemplcnd3dXNmYmppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTgwOTI0MjEsImV4cCI6MjAzMzY2ODQyMX0.sJw9DmLLtpmSgS_7j4YYAXn6ZidAqSAhEy2J6FSYTs0';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}
