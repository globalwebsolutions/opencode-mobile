import 'package:flutter/material.dart';

import '../app.dart';
import '../core/l10n.dart';
import '../core/models.dart';

/// One conversation row in the sessions list.
class SessionTile extends StatelessWidget {
  const SessionTile({
    super.key,
    required this.session,
    required this.busy,
    required this.onTap,
    this.onLongPress,
  });

  final OcSession session;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final title = session.title?.trim().isNotEmpty == true
        ? session.title!
        : L.tr('جلسة بدون عنوان', 'Untitled session');
    final dir = _shortDir(session.directory);

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: scheme.primary.withValues(alpha: 0.12),
        child: busy
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              )
            : Text(
                title.isNotEmpty ? title.characters.first : '?',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      // Only the project name flexes; the time is always short. The model
      // badge used to live here too, but the row is far too narrow for three
      // items on a phone (it overflowed), and the model is already shown in
      // the chat's own header.
      subtitle: Row(
        children: [
          if (dir != null) ...[
            Icon(Icons.folder_outlined,
                size: 13, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                dir,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            relativeTime(session.updatedMs ?? session.createdMs),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      trailing: busy
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                L.tr('شغال', 'busy'),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : session.cost != null
              ? Text(
                  '\$${session.cost!.toStringAsFixed(session.cost! < 1 ? 3 : 2)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    fontFeatures: [],
                  ),
                )
              : null,
    );
  }

  /// Last path segment only — a full path never fits a phone row. Truncation
  /// is left to the Text's own ellipsis.
  String? _shortDir(String? directory) {
    if (directory == null || directory.isEmpty) return null;
    final parts = directory.split(RegExp(r'[\\/]'));
    return parts.isEmpty || parts.last.isEmpty ? directory : parts.last;
  }
}
