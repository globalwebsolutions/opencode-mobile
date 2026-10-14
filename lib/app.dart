import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/connection_store.dart';
import 'core/l10n.dart';
import 'state/app_state.dart';
import 'state/sessions_state.dart';
import 'state/settings_state.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/settings_screen.dart';

class OpenCodeMobileApp extends StatelessWidget {
  const OpenCodeMobileApp({super.key, this.appState, this.settings});

  /// Test seam: inject a preconfigured app state instead of creating (and
  /// bootstrapping) a fresh one internally.
  final AppState? appState;

  /// Test seam: inject user settings (language & theme).
  final SettingsState? settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => settings ?? SettingsState(ConnectionStore()),
        ),
        ChangeNotifierProvider(
          create: (_) => appState ?? (AppState()..bootstrap()),
        ),
        ChangeNotifierProxyProvider<AppState, SessionsState>(
          create: (context) => SessionsState(app: context.read<AppState>()),
          update: (context, app, previous) =>
              previous ?? SessionsState(app: app),
        ),
      ],
      child: Consumer<SettingsState>(
        builder: (context, settings, _) => MaterialApp(
          title: 'OpenCode Mobile',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: settings.themeMode,
          locale: settings.locale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const _Root(),
        ),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE8710A),
      brightness: brightness,
    );
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF141414) : null,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF141414) : null,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1F1F1F) : const Color(0xFFF2F2F2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      dividerTheme: DividerThemeData(
        color: dark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    // Keep the static effective language in sync on every rebuild (covers
    // system-locale changes too).
    L.lang = context.watch<SettingsState>().effectiveLang;
    switch (app.phase) {
      case AppPhase.boot:
      case AppPhase.connecting:
        return const _Splash();
      case AppPhase.unpaired:
      case AppPhase.pairFailed:
        return const WelcomeScreen();
      case AppPhase.ready:
        return const HomeScreen();
    }
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: 84),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

/// Simple geometric OpenCode-style mark.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(
        child: Text(
          '>_',
          style: TextStyle(
            color: scheme.onPrimary,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Pushes the QR scanner screen; returns the scanned pairing link.
Future<String?> pushScannerScreen(BuildContext context) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );

/// Pushes the settings screen.
Future<void> pushSettingsScreen(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );

/// Formats epoch milliseconds into a short relative time in the active
/// language, e.g. "قبل 5 دقائق" / "5 min ago".
String relativeTime(int? ms) {
  if (ms == null) return '';
  final diff = DateTime.now().millisecondsSinceEpoch - ms;
  if (diff < 0) return L.tr('الآن', 'now');
  final minutes = diff ~/ 60000;
  if (minutes < 1) return L.tr('الآن', 'just now');

  /// Arabic singular/dual/few/many forms: دقيقة / دقيقتين / دقائق / دقيقة
  String ar(int n, String one, String two, String few, String many) {
    if (n == 1) return 'قبل $one';
    if (n == 2) return 'قبل $two';
    if (n >= 3 && n <= 10) return 'قبل $n $few';
    return 'قبل $n $many';
  }

  if (minutes < 60) {
    return L.isAr
        ? ar(minutes, 'دقيقة', 'دقيقتين', 'دقائق', 'دقيقة')
        : '$minutes min ago';
  }
  final hours = minutes ~/ 60;
  if (hours < 24) {
    return L.isAr
        ? ar(hours, 'ساعة', 'ساعتين', 'ساعات', 'ساعة')
        : '${hours}h ago';
  }
  final days = hours ~/ 24;
  if (days < 30) {
    return L.isAr
        ? ar(days, 'يوم', 'يومين', 'أيام', 'يومًا')
        : '${days}d ago';
  }
  final months = days ~/ 30;
  if (months < 12) {
    return L.isAr
        ? ar(months, 'شهر', 'شهرين', 'أشهر', 'شهرًا')
        : '${months}mo ago';
  }
  final years = months ~/ 12;
  return L.isAr
      ? ar(years, 'سنة', 'سنتين', 'سنوات', 'سنة')
      : '${years}y ago';
}

/// Formats a token count compactly, e.g. 12.4K.
String compactCount(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '${(n / 1000000).toStringAsFixed(1)}M';
}
