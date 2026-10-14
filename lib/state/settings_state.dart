/// User preferences: language and theme, persisted via secure storage.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/connection_store.dart';
import '../core/l10n.dart';

class SettingsState extends ChangeNotifier {
  final ConnectionStore _store;

  SettingsState(this._store) {
    _load();
  }

  /// Requested language (may be [AppLang.system]).
  AppLang lang = AppLang.system;

  /// Requested theme mode.
  ThemeMode themeMode = ThemeMode.system;

  Future<void> _load() async {
    final cfg = await _store.readConfig();
    // Only override when explicitly saved, so programmatic changes (tests,
    // early setLang calls) survive a missing/corrupt config read.
    if (cfg['lang'] != null) lang = _langFrom(cfg['lang']);
    if (cfg['theme'] != null) themeMode = _themeFrom(cfg['theme']);
    _apply();
    notifyListeners();
  }

  static AppLang _langFrom(Object? v) {
    for (final lang in AppLang.values) {
      if (lang.name == v) return lang;
    }
    return AppLang.system;
  }

  static ThemeMode _themeFrom(Object? v) {
    for (final mode in ThemeMode.values) {
      if (mode.name == v) return mode;
    }
    return ThemeMode.system;
  }

  /// The concrete language to render with, resolving [AppLang.system].
  AppLang get effectiveLang {
    if (lang != AppLang.system) return lang;
    final code =
        PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    return code == 'ar' ? AppLang.arabic : AppLang.english;
  }

  Locale? get locale => switch (effectiveLang) {
        AppLang.arabic => const Locale('ar'),
        AppLang.english => const Locale('en'),
        AppLang.system => null,
      };

  void setLang(AppLang value) {
    if (value == lang) return;
    lang = value;
    _apply();
    notifyListeners();
    _persist();
  }

  void setThemeMode(ThemeMode value) {
    if (value == themeMode) return;
    themeMode = value;
    notifyListeners();
    _persist();
  }

  void _apply() => L.lang = effectiveLang;

  Future<void> _persist() async {
    await _store.writeConfig({
      'lang': lang.name,
      'theme': themeMode.name,
    });
  }
}
