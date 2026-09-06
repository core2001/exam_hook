import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';

const supabaseUrl = 'https://fvcstahmzrfxptgeznuk.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ2Y3N0YWhtenJmeHB0Z2V6bnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg2NTU5MDgsImV4cCI6MjEwNDIzMTkwOH0.qBpJhFV4g9obK3RZF2IdbE1AvWozdFLZ5KUvDvuijNw';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const ExamHookApp(),
    )
  );
}

class ExamHookApp extends StatelessWidget {
  const ExamHookApp({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ExamHook',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.primaryColor,
          secondary: Colors.blue.shade600,
          brightness: Brightness.light
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const SplashScreen(),
    );
  }
}
