import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/connection_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/call_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/chat/home_screen.dart';
import 'screens/call/call_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'themes/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => CallProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const BMBApp(),
    ),
  );
}

class BMBApp extends StatefulWidget {
  const BMBApp({super.key});

  @override
  State<BMBApp> createState() => _BMBAppState();
}

class _BMBAppState extends State<BMBApp> {
  @override
  void initState() {
    super.initState();
    _checkPairing();
  }

  Future<void> _checkPairing() async {
    final connProv = Provider.of<ConnectionProvider>(context, listen: false);
    await connProv.loadCredentials();
    if (!mounted) return;
    if (connProv.isPaired) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return MaterialApp(
      title: 'BMB Encover Agent',
      debugShowCheckedModeBanner: false,
      theme: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const _SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/home': (context) => const HomeScreen(),
        '/call': (context) => const CallScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initAndRoute();
  }

  Future<void> _initAndRoute() async {
    final connProv = Provider.of<ConnectionProvider>(context, listen: false);
    await connProv.loadCredentials();
    if (!mounted) return;
    final destination = connProv.isPaired ? '/home' : '/onboarding';
    Navigator.of(context).pushReplacementNamed(destination);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BMB',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8300e9),
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ENCOVER AGENT',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF8300e9)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
