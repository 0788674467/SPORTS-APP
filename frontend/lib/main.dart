import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/auth/auth_provider.dart' as auth;
import 'core/auth/role_router.dart';
import 'core/theme/app_theme.dart';
import 'core/api/socket_client.dart';
import 'core/state/match_state.dart';
import 'core/state/app_state.dart';
import 'shared/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure app content never bleeds under the system status bar / nav bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  try {
    await Supabase.initialize(
      url: 'https://wkhidacuzxscaquawzrx.supabase.co',
      anonKey: 'sb_publishable__1RrZOux3u1dT7eCgK_AqA_eP9Fc7Lo',
    );
  } catch (e) {
    debugPrint('Supabase Init Error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => SocketClient()),
        ChangeNotifierProvider(create: (_) => MatchState()),
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const SportsApp(),
    ),
  );
}

class SportsApp extends StatelessWidget {
  const SportsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return MaterialApp(
      title: 'UniLeague',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(
        onComplete: () {
          if (mounted) setState(() => _splashDone = true);
        },
      );
    }
    return const RoleRouter();
  }
}
