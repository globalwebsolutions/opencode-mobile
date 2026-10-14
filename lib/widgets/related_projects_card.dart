import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/l10n.dart';

/// A companion project from the same team.
class RelatedProject {
  const RelatedProject({
    required this.badge,
    required this.name,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.url,
    required this.sourceLabel,
  });

  /// Two or three letters shown in the square on the left.
  final String badge;
  final String name;
  final String descriptionAr;
  final String descriptionEn;
  final String url;

  /// Where the link goes, e.g. "GitHub".
  final String sourceLabel;

  String get description => L.tr(descriptionAr, descriptionEn);
}

/// The companion projects worth surfacing inside the app.
const relatedProjects = <RelatedProject>[
  RelatedProject(
    badge: 'VS',
    name: 'OpenCode Chat Sidebar',
    descriptionAr: 'إضافة VS Code — دردشة مع وكلاء OpenCode جوه المحرر',
    descriptionEn: 'VS Code extension — chat with OpenCode agents in your editor',
    // The extension ships as a .vsix on the Releases page.
    url: 'https://github.com/globalwebsolutions/opencode-chat-sidebar/releases',
    sourceLabel: 'GitHub Releases',
  ),
];

/// Opens a related project, falling back to copying the link.
Future<void> openRelatedProject(BuildContext context, RelatedProject project) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (await launchUrl(Uri.parse(project.url),
        mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (_) {
    // Fall through to the clipboard fallback.
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text(L.tr('اتنسخ اللينك: ${project.url}', 'Link copied: ${project.url}')),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Cards for the team's other OpenCode tools.
class RelatedProjectsCard extends StatelessWidget {
  const RelatedProjectsCard({super.key, this.projects = relatedProjects});

  final List<RelatedProject> projects;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        for (final project in projects)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Material(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => openRelatedProject(context, project),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          project.badge,
                          style: TextStyle(
                            color: scheme.onSecondaryContainer,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              textDirection: TextDirection.ltr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              project.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.open_in_new_rounded,
                                    size: 13, color: scheme.primary),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    project.sourceLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
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
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
