import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// User's chosen appearance (system / light / dark), persisted alongside
/// the auth token so it survives app restarts.
///
/// [AppColors] reads [isDark] directly (not via `Theme.of(context)`) since
/// most screens use `AppColors.xxx` as plain static values rather than
/// `Theme.of(context).colorScheme`. Toggling [mode] forces a full app
/// remount (see `main.dart`) so every one of those call sites re-evaluates
/// against the new palette.
class ThemeState extends ChangeNotifier with WidgetsBindingObserver {
  ThemeState._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final ThemeState instance = ThemeState._();

  static const _key = 'theme_mode';
  final _storage = const FlutterSecureStorage();

  ThemeMode mode = ThemeMode.light;

  bool get isDark {
    if (mode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return mode == ThemeMode.dark;
  }

  @override
  void didChangePlatformBrightness() {
    if (mode == ThemeMode.system) notifyListeners();
  }

  Future<void> restore() async {
    final stored = await _storage.read(key: _key);
    switch (stored) {
      case 'light':
        mode = ThemeMode.light;
        break;
      case 'system':
        mode = ThemeMode.system;
        break;
      case 'dark':
        mode = ThemeMode.dark;
        break;
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode value) async {
    mode = value;
    notifyListeners();
    await _storage.write(key: _key, value: value.name);
  }
}
