import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/deep_links.dart';
import 'l10n/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'state/locale_state.dart';
import 'state/theme_state.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Future.wait([
    ThemeState.instance.restore(),
    LocaleState.instance.restore(),
  ]);
  DeepLinks.instance.init();
  runApp(const AlicomApp());
}

class AlicomApp extends StatelessWidget {
  const AlicomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ThemeState.instance, LocaleState.instance]),
      builder: (context, _) {
        final isDark = ThemeState.instance.isDark;
        // Matches the system status/nav bar to whichever palette is active.
        SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlayStyle(isDark));

        // AppColors is read as plain static values (not Theme.of(context))
        // across most screens, so a mode switch needs a full remount for
        // every one of those call sites to re-evaluate against the new
        // palette — hence the key tied to the mode.
        return MaterialApp(
          key: ValueKey(ThemeState.instance.mode),
          navigatorKey: DeepLinks.navigatorKey,
          title: 'Alicom',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeState.instance.mode,
          // English + Bangla (lib/l10n/*.arb). `null` follows the device.
          locale: LocaleState.instance.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const SplashScreen(),
        );
      },
    );
  }
}
