import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'services/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final themeProvider = ThemeProvider();
  await themeProvider.load();

  runApp(ShareBiteApp(themeProvider: themeProvider));
}

class ShareBiteApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  const ShareBiteApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, themeProvider, __) => MaterialApp(
          title: 'ShareBite',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeProvider.themeMode,
          initialRoute: '/splash',
          routes: {
            '/splash'  : (_) => const SplashScreen(),
            '/login'   : (_) => const LoginScreen(),
            '/register': (_) => const RegisterScreen(),
            '/main'    : (_) => const MainScreen(),
          },
        ),
      ),
    );
  }
}
