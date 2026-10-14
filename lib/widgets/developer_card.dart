import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/l10n.dart';

/// The team behind the app.
const developerName = 'Global Web Solutions';
const developerYear = '2026';
const developerUrl = 'https://Globalweb.Solutions';

/// Opens [developerUrl] in the browser, falling back to copying it when no
/// browser can handle the link (e.g. a bare emulator).
Future<void> openDeveloperSite(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final launched = await launchUrl(
      Uri.parse(developerUrl),
      mode: LaunchMode.externalApplication,
    );
    if (launched) return;
  } catch (_) {
    // Fall through to the clipboard fallback below.
  }
  await Clipboard.setData(const ClipboardData(text: developerUrl));
  messenger.showSnackBar(
    SnackBar(
      content: Text(L.tr(
        'اتنسخ لينك الموقع: $developerUrl',
        'Site link copied: $developerUrl',
      )),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Full credit card: team name, what they did, and a tappable website.
class DeveloperCard extends StatelessWidget {
  const DeveloperCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Material(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => openDeveloperSite(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'GWS',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        developerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        L.tr('طوّر التطبيق · $developerYear',
                            'Built the app · $developerYear'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.public_rounded,
                              size: 15, color: scheme.primary),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Globalweb.Solutions',
                              textDirection: TextDirection.ltr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.open_in_new_rounded,
                    size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact one-line credit for the pairing screen's footer.
class DeveloperCredit extends StatelessWidget {
  const DeveloperCredit({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.code_rounded, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            L.tr('صُنع بواسطة $developerName · $developerYear',
                'Built by $developerName · $developerYear'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
