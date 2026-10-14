import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/opencode_client.dart' show SseStatus;
import '../state/app_state.dart';
import '../state/sessions_state.dart';
import 'chat_screen.dart';
import 'connect_guide_screen.dart';
import 'projects_screen.dart';
import 'settings_screen.dart';

/// Chat-first home, like the Claude/ChatGPT apps: a greeting, a composer,
/// project selection, and quick suggestions. Sending the first message
/// creates a new session and opens the conversation.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _textController = TextEditingController();
  List<OcProject> _projects = [];
  OcProject? _selected;
  bool _loadingProjects = true;
  bool _creating = false;
  String? _projectsError;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    final client = context.read<AppState>().client;
    if (client == null) return;
    try {
      final projects = await client.listProjects();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _loadingProjects = false;
        _selected = projects.isEmpty ? null : projects.first;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProjects = false;
        _projectsError = '$e';
      });
    }
  }

  static final _suggestions = [
    L.tr('اشرحلي المشروع ده وإيه بنيته', 'Explain this project and its structure'),
    L.tr('صلّح باج في الكود', 'Fix a bug in the code'),
    L.tr('أضف ميزة جديدة للمشروع', 'Add a new feature to the project'),
    L.tr('راجع التغيرات في الجيت', 'Review my latest git changes'),
  ];

  Future<void> _startChat(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _creating) return;
    final project = _selected;
    if (project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.tr('اختار مشروع الأول من الشرائح فوق', 'Pick a project above first')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final sessions = context.read<SessionsState>();
      final session = await sessions.createSession(
        directory: project.canonical,
      );
      _textController.clear();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(sessionID: session.id, initialMessage: trimmed),
        ),
      );
    } catch (e) {
      if (mounted) {
        final msg = context.read<AppState>().friendlyErrorText(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 28),
            const SizedBox(width: 10),
            Text('OpenCode'),
            const SizedBox(width: 10),
            _StatusDot(app: app),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProjectsScreen()),
            ),
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            label: Text(L.tr('المشاريع', 'Projects')),
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurface,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: L.tr('دليل التوصيل', 'Connection guide'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConnectGuideScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: L.tr('الإعدادات', 'Settings'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    // Greeting.
                    Text(
                      L.tr('إزاي أقدر أساعدك النهاردة؟ 👋', 'How can I help you today? 👋'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      L.tr('هتبدأ محادثة جديدة في المشروع اللي تختاره', 'A new chat starts in the project you pick'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Project picker.
                    _SectionLabel(label: L.tr('المشروع', 'Project')),
                    const SizedBox(height: 8),
                    if (_loadingProjects)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_projectsError != null || _projects.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          L.tr('مفيش مشاريع على السيرفر ده بعد — ابدأ مشروع من جهازك الأول', 'No projects on this server yet — start one on your computer first'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final project in _projects)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: ChoiceChip(
                                  selected:
                                      _selected?.canonical == project.canonical,
                                  onSelected: (_) =>
                                      setState(() => _selected = project),
                                  avatar: Icon(
                                    project.vcs != null
                                        ? Icons.folder_special_outlined
                                        : Icons.folder_outlined,
                                    size: 16,
                                  ),
                                  label: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 160),
                                    child: Text(
                                      project.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Suggestions.
                    _SectionLabel(label: L.tr('مقتراحات سريعة', 'Quick suggestions')),
                    const SizedBox(height: 8),
                    for (final suggestion in _suggestions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              _textController.text = suggestion;
                              setState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 16,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      suggestion,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_back_rounded,
                                    size: 16,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Composer — reuses the chat input bar.
            _HomeComposer(
              controller: _textController,
              busy: _creating,
              onChanged: () => setState(() {}),
              onSend: _startChat,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .labelMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

/// Simple composer with just a send action (no interrupt button).
class _HomeComposer extends StatelessWidget {
  const _HomeComposer({
    required this.controller,
    required this.busy,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onChanged;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !busy,
              minLines: 1,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => onChanged(),
              onSubmitted: (_) => onSend(controller.text),
              decoration: InputDecoration(
                hintText: L.tr('اكتب رسالتك لـ OpenCode...', 'Message OpenCode...'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, TextEditingValue value, _) {
              final ready =
                  value.text.trim().isNotEmpty && !busy;
              return busy
                  ? const SizedBox(
                      width: 46,
                      height: 46,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : IconButton.filled(
                      onPressed:
                          ready ? () => onSend(controller.text) : null,
                      icon: const Icon(Icons.arrow_upward_rounded),
                      tooltip: L.tr('إرسال', 'Send'),
                      style: IconButton.styleFrom(
                        backgroundColor: ready
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                        foregroundColor: ready
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    );
            },
          ),
        ],
      ),
    );
  }
}

/// Small green/yellow/red connectivity pill.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (app.sseStatus) {
      SseStatus.connected => (const Color(0xFF22C55E), L.tr('متصل', 'Connected')),
      SseStatus.connecting => (const Color(0xFFEAB308), L.tr('بيتصل...', 'Connecting...')),
      SseStatus.disconnected => (const Color(0xFFEF4444), L.tr('قاطع', 'Offline')),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
