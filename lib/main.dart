import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:social_media_app/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://rfkivmxezjerwwusfbji.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJma2l2bXhlemplcnd3dXNmYmppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTgwOTI0MjEsImV4cCI6MjAzMzY2ODQyMX0.sJw9DmLLtpmSgS_7j4YYAXn6ZidAqSAhEy2J6FSYTs0',
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anonim',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginScreen(),
    );
  }
}
