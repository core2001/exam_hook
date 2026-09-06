import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart'; // <-- IMPORTANT: this was missing
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';

const supabaseUrl = 'https://fvcstahmzrfxptgeznuk.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ2Y3N0YWhtenJmeHB0Z2V6bnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg2NTU5MDgsImV4cCI6MjEwNDIzMTkwOH0.qBpJhFV4g9obK3RZF2IdbE1AvWozdFLZ5KUvDvuijNw';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch errors during startup so we don't get white screen
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) print('Flutter Error: ${details.exception}');
  };

  try {
    // 1. Initialize Firebase with web config
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 2. Initialize Supabase
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
      debug: kDebugMode,
    );
  } catch (e) {
    if (kDebugMode) print('Initialization error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const ExamHookApp(),
    ),
  );
}

class ExamHookApp extends StatelessWidget {
  const ExamHookApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Pro Green + Blue Theme as you requested
    const Color primaryGreen = Color(0xFF00C896); // Mint Green
    const Color secondaryBlue = Color(0xFF3B82F6); // Pro Blue

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ExamHook',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          secondary: secondaryBlue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          secondary: secondaryBlue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
    );
  }
}