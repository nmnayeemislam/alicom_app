import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// App language: follow the device (`null`), or force English / Bangla.
/// Persisted like [ThemeState] so the choice survives restarts.
class LocaleState extends ChangeNotifier {
  LocaleState._();
  static final LocaleState instance = LocaleState._();

  static const _key = 'app_locale';
  static const supported = [Locale('en'), Locale('bn')];
  final _storage = const FlutterSecureStorage();

  /// `null` = follow the device language.
  Locale? locale;

  Future<void> restore() async {
    try {
      final stored = await _storage.read(key: _key);
      locale = supported.where((l) => l.languageCode == stored).firstOrNull;
    } catch (_) {
      locale = null;
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale? value) async {
    locale = value;
    notifyListeners();
    try {
      if (value == null) {
        await _storage.delete(key: _key);
      } else {
        await _storage.write(key: _key, value: value.languageCode);
      }
    } catch (_) {}
  }
}
