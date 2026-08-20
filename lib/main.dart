import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'state/theme_state.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await ThemeState.instance.restore();
  runApp(const AlicomApp());
}

class AlicomApp extends StatelessWidget {
  const AlicomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeState.instance,
      builder: (context, _) {
        final isDark = ThemeState.instance.isDark;
        // Matches the system status/nav bar to whichever palette is active
        // — light icons on the near-black Lumina dark surfaces, dark icons
        // on the off-white light surfaces.
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: isDark ? const Color(0xFF0A0A0D) : const Color(0xFFF7F6FB),
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
        );

        // AppColors is read as plain static values (not Theme.of(context))
        // across most screens, so a mode switch needs a full remount for
        // every one of those call sites to re-evaluate against the new
        // palette — hence the key tied to the mode.
        return MaterialApp(
          key: ValueKey(ThemeState.instance.mode),
          title: 'Alicom',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeState.instance.mode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
