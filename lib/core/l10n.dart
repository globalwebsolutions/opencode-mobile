/// Lightweight in-code localization: every string carries both languages
/// side by side — `L.tr('عربي', 'English')` — with the active language set
/// from [SettingsState] before every frame.
library;

enum AppLang { system, arabic, english }

class L {
  L._();

  /// Effective language for rendering (never [AppLang.system] itself).
  static AppLang lang = AppLang.arabic;

  static bool get isAr => lang == AppLang.arabic;

  static String tr(String ar, String en) => isAr ? ar : en;
}
