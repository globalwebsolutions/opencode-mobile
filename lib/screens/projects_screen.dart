import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/l10n.dart';
import '../state/app_state.dart';
import '../state/sessions_state.dart';
import '../widgets/session_tile.dart';
import 'chat_screen.dart';

/// Projects & history hub, opened from the "المشاريع" button on home:
/// every project with its conversations, plus the full history list.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionsState>();
    final app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(L.tr('المشاريع والمحادثات', 'Projects & chats')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: L.tr('تحديث', 'Refresh'),
            onPressed: () => sessions.refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => sessions.refresh(),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // Projects section (from the server's project registry).
            _FutureProjects(
              onLoaded: null,
              builder: (context, projects) {
                if (projects.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                        title: L.tr('مشاريعك', 'Your projects'), count: projects.length),
                    for (final project in projects)
                      _ProjectRow(
                        project: project,
                        sessions: _sessionsFor(sessions.sessions, project),
                        onNewChat: () => _newChatInProject(context, app, sessions, project),
                      ),
                    const Divider(indent: 20, endIndent: 20, height: 32),
                  ],
                );
              },
            ),
            // Full history.
            _SectionHeader(
                title: L.tr('كل المحادثات', 'All chats'), count: sessions.sessions.length),
            if (sessions.loading && sessions.sessions.isEmpty)
              Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (sessions.sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    L.tr('مفيش محادثات بعد', 'No conversations yet'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (final session in sessions.sessions)
                    SessionTile(
                      session: session,
                      busy: sessions.busySessions[session.id] ?? false,
                      onTap: () => _openChat(context, session),
                      onLongPress: () =>
                          _showSessionActions(context, sessions, session),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<OcSession> _sessionsFor(List<OcSession> all, OcProject project) {
    return all
        .where((s) =>
            s.directory != null &&
            (s.directory == project.canonical ||
                (s.directory!.startsWith('${project.canonical}/'))))
        .toList();
  }

  void _openChat(BuildContext context, OcSession session) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(sessionID: session.id)),
    );
  }

  Future<void> _newChatInProject(BuildContext context, AppState app,
      SessionsState sessions, OcProject project) async {
    Navigator.of(context).pop(); // close projects screen
    try {
      final session =
          await sessions.createSession(directory: project.canonical);
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(sessionID: session.id),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(app.friendlyErrorText(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showSessionActions(
      BuildContext context, SessionsState sessions, OcSession session) {
    final controller = TextEditingController(text: session.title ?? '');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: Text(L.tr('إعادة تسمية', 'Rename')),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final title = await showDialog<String>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(L.tr('اسم الجلسة', 'Session name')),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        onSubmitted: (value) =>
                            Navigator.pop(dialogContext, value),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(L.tr('إلغاء', 'Cancel')),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.pop(dialogContext, controller.text),
                          child: Text(L.tr('حفظ', 'Save')),
                        ),
                      ],
                    ),
                  );
                  if (title != null && title.trim().isNotEmpty) {
                    await sessions.renameSession(session.id, title.trim());
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(L.tr('حذف الجلسة', 'Delete chat')),
                textColor: Theme.of(context).colorScheme.error,
                iconColor: Theme.of(context).colorScheme.error,
                onTap: () {
                  Navigator.pop(sheetContext);
                  sessions.deleteSession(session.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.project,
    required this.sessions,
    required this.onNewChat,
  });

  final OcProject project;
  final List<OcSession> sessions;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primary.withValues(alpha: 0.12),
        child: Icon(
          project.vcs != null
              ? Icons.folder_special_outlined
              : Icons.folder_outlined,
          size: 20,
          color: scheme.primary,
        ),
      ),
      title: Text(
        project.name,
        style: theme.textTheme.bodyLarge
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        L.tr('${project.canonical}  ·  ${sessions.length} محادثة', '${project.canonical}  ·  ${sessions.length} chats'),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.add_comment_outlined),
        tooltip: L.tr('محادثة جديدة هنا', 'New chat here'),
        onPressed: onNewChat,
      ),
      onTap: () => _showProjectSessions(context),
    );
  }

  void _showProjectSessions(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Text(
                      L.tr('محادثات ${project.name}', 'Chats in ${project.name}'),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (sessions.isEmpty)
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(L.tr('مفيش محادثات في المشروع ده بعد', 'No chats in this project yet')),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final s in sessions)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.chat_bubble_outline,
                              size: 18),
                          title: Text(
                            s.title?.trim().isNotEmpty == true
                                ? s.title!
                                : L.tr('بدون عنوان', 'Untitled'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ChatScreen(sessionID: s.id),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loads the server's project list once and rebuilds with it.
class _FutureProjects extends StatefulWidget {
  const _FutureProjects({required this.builder, this.onLoaded});

  final Widget Function(BuildContext context, List<OcProject> projects) builder;
  final void Function(List<OcProject>)? onLoaded;

  @override
  State<_FutureProjects> createState() => _FutureProjectsState();
}

class _FutureProjectsState extends State<_FutureProjects> {
  List<OcProject>? _projects;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = context.read<AppState>().client;
    if (client == null) {
      setState(() => _projects = []);
      return;
    }
    try {
      final projects = await client.listProjects();
      if (!mounted) return;
      setState(() => _projects = projects);
      widget.onLoaded?.call(projects);
    } catch (_) {
      if (mounted) setState(() => _projects = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_projects == null) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return widget.builder(context, _projects!);
  }
}
