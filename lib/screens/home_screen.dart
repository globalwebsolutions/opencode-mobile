import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/opencode_client.dart' show SseStatus;
import '../state/app_state.dart';
import '../state/quota_state.dart';
import '../state/sessions_state.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/quota_card.dart';
import 'chat_screen.dart';
import 'connect_guide_screen.dart';
import 'projects_screen.dart';
import 'settings_screen.dart';

/// Chat-first home, like the Claude/ChatGPT apps: a greeting, a project
/// picker, quick suggestions, the latest conversations, and a composer.
/// Sending the first message creates a new session and opens the conversation.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _textController = TextEditingController();
  final _inputFocus = FocusNode();

  List<OcProject> _projects = [];
  OcProject? _selected;
  bool _loadingProjects = true;
  bool _creating = false;
  String? _projectsError;

  // صورة مرفقة بالمحادثة الجديدة (من الهوم قبل الإرسال)
  final ImagePicker _picker = ImagePicker();
  final List<OcAttachment> _pending = [];

  /// How many recent conversations the home screen surfaces.
  static const _maxRecents = 3;

  static const List<_Suggestion> _suggestions = [
    _Suggestion(
      icon: Icons.account_tree_outlined,
      ar: 'اشرحلي المشروع ده وإيه بنيته',
      en: 'Explain this project and its structure',
    ),
    _Suggestion(
      icon: Icons.bug_report_outlined,
      ar: 'صلّح باج في الكود',
      en: 'Fix a bug in the code',
    ),
    _Suggestion(
      icon: Icons.add_circle_outline_rounded,
      ar: 'أضف ميزة جديدة للمشروع',
      en: 'Add a new feature to the project',
    ),
    _Suggestion(
      icon: Icons.difference_outlined,
      ar: 'راجع التغيرات في الجيت',
      en: 'Review my latest git changes',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadProjects();
    // Plan quota + spend for the header chip. Deferred a frame so the first
    // paint isn't blocked by the network.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<QuotaState>().refresh();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

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

  /// Newest conversations first, preferring the ones the user actually named.
  List<OcSession> _recents(List<OcSession> all) {
    final named = all.where((s) => s.title?.trim().isNotEmpty == true);
    final pool = (named.isEmpty ? all : named).toList()
      ..sort((a, b) => _stamp(b).compareTo(_stamp(a)));
    return pool.take(_maxRecents).toList();
  }

  static int _stamp(OcSession s) => s.updatedMs ?? s.createdMs ?? 0;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// شيت السفلي: كاميرا أو استوديو
  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(L.tr('كاميرا', 'Camera')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(L.tr('من الاستوديو', 'From gallery')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final mime =
          file.mimeType ??
          (file.name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg');
      setState(() {
        _pending.add(
          OcAttachment(
            dataBase64: base64Encode(bytes),
            mime: mime,
            name: file.name,
          ),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L.tr('فشل اختيار الصورة: $e', 'Could not pick image: $e'),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// A quick suggestion prefills the composer (and focuses it) so it can be
  /// tweaked before sending.
  void _applySuggestion(_Suggestion suggestion) {
    _textController.text = suggestion.label;
    _textController.selection = TextSelection.collapsed(
      offset: _textController.text.length,
    );
    _inputFocus.requestFocus();
  }

  Future<void> _showProjectPicker() async {
    final picked = await showModalBottomSheet<OcProject>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          _ProjectPickerSheet(projects: _projects, selected: _selected),
    );
    if (picked != null && mounted) {
      setState(() => _selected = picked);
    }
  }

  Future<void> _startChat(String text) async {
    final trimmed = text.trim();
    if ((trimmed.isEmpty && _pending.isEmpty) || _creating) return;
    final project = _selected;
    if (project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.tr('اختار مشروع الأول', 'Pick a project first')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _inputFocus.unfocus();
    setState(() => _creating = true);
    final attachments = List<OcAttachment>.of(_pending);
    try {
      final sessions = context.read<SessionsState>();
      final session = await sessions.createSession(
        directory: project.canonical,
      );
      _textController.clear();
      if (!mounted) return;
      setState(() => _pending.clear());
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            sessionID: session.id,
            initialMessage: trimmed,
            initialAttachments: attachments,
          ),
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

  void _openChat(OcSession session) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(sessionID: session.id)),
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  /// Bottom sheet behind the status dot on the logo: shows the connection
  /// state, the active server, and a shortcut to manage servers.
  Future<void> _showConnectionSheet() async {
    final app = context.read<AppState>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (color, label) = _statusVisual(app.sseStatus);
    final connection = app.activeConnection;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // The sheet now carries the quota + spend cards, which is taller than a
      // short phone can show at once — let it grow and scroll.
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L.tr('حالة الاتصال', 'Connection status'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (connection != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      connection.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      connection.baseUrl,
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // How much of the plan is left, right where the connection
                  // status already lives.
                  if (!app.demoMode) const QuotaCard(),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _push(const SettingsScreen());
                      },
                      icon: const Icon(Icons.dns_outlined, size: 18),
                      label: Text(L.tr('إدارة السيرفرات', 'Manage servers')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sessions = context.watch<SessionsState>();
    final theme = Theme.of(context);
    final recents = _recents(sessions.sessions);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: _HomeBrand(app: app, onStatusTap: _showConnectionSheet),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_rounded),
            tooltip: L.tr('المشاريع والمحادثات', 'Projects & chats'),
            onPressed: () => _push(const ProjectsScreen()),
          ),
          PopupMenuButton<_HomeMenuAction>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: L.tr('المزيد', 'More'),
            onSelected: (action) {
              switch (action) {
                case _HomeMenuAction.guide:
                  _push(const ConnectGuideScreen());
                case _HomeMenuAction.settings:
                  _push(const SettingsScreen());
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _HomeMenuAction.guide,
                child: _MenuRow(
                  icon: Icons.help_outline_rounded,
                  label: L.tr('دليل التوصيل', 'Connection guide'),
                ),
              ),
              PopupMenuItem(
                value: _HomeMenuAction.settings,
                child: _MenuRow(
                  icon: Icons.settings_outlined,
                  label: L.tr('الإعدادات', 'Settings'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  if (app.demoMode) const _DemoBanner(),
                  const SizedBox(height: 16),
                  const _Greeting(),
                  const SizedBox(height: 28),
                  _SectionLabel(
                    text: L.tr('المشروع', 'Project'),
                    trailing: _projects.length > 1
                        ? L.tr(
                            '${_projects.length} مشروع',
                            '${_projects.length} projects',
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  _ProjectSelector(
                    project: _selected,
                    loading: _loadingProjects,
                    empty:
                        !_loadingProjects &&
                        (_projectsError != null || _projects.isEmpty),
                    onTap: _showProjectPicker,
                  ),
                  const SizedBox(height: 26),
                  _SectionLabel(
                    text: L.tr('مقترحات سريعة', 'Quick suggestions'),
                  ),
                  const SizedBox(height: 10),
                  _SuggestionGrid(
                    suggestions: _suggestions,
                    onSelected: _applySuggestion,
                  ),
                  if (recents.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    _SectionLabel(
                      text: L.tr('آخر المحادثات', 'Recent chats'),
                      action: L.tr('الكل', 'See all'),
                      onAction: () => _push(const ProjectsScreen()),
                    ),
                    const SizedBox(height: 2),
                    for (final session in recents)
                      _RecentChatRow(
                        session: session,
                        busy: sessions.busySessions[session.id] ?? false,
                        onTap: () => _openChat(session),
                      ),
                  ],
                ],
              ),
            ),
            // Composer — same bar as the chat, with the paperclip.
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: ChatInputBar(
                busy: _creating,
                onSend: _startChat,
                onInterrupt: () {},
                onAttach: _pickImage,
                attachments: _pending,
                onRemoveAttachment: (i) => setState(() => _pending.removeAt(i)),
                controller: _textController,
                focusNode: _inputFocus,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Top bar
// -----------------------------------------------------------------------------

/// Actions tucked into the top-bar overflow menu.
enum _HomeMenuAction { guide, settings }

/// Top-bar brand: the app mark with a green/yellow/red connection dot sitting
/// on its corner, next to the wordmark. The status label only appears when
/// something is wrong, so a healthy connection stays quiet.
class _HomeBrand extends StatelessWidget {
  const _HomeBrand({required this.app, this.onStatusTap});

  final AppState app;
  final VoidCallback? onStatusTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, label) = _statusVisual(app.sseStatus);
    final calm = app.sseStatus == SseStatus.connected;
    return Row(
      children: [
        Tooltip(
          message: label,
          child: InkWell(
            onTap: onStatusTap,
            customBorder: const CircleBorder(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const AppLogo(size: 30),
                PositionedDirectional(
                  end: -3,
                  bottom: -3,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // A 360dp bar can't hold the wordmark *and* the quota chip without
        // slicing one of them ("…OpenCo"), so the chip wins while it exists:
        // it is the live number the user came for, and the mark on the left
        // already carries the name. Without a plan the wordmark stays.
        if (!context.watch<QuotaState>().hasQuota)
          Expanded(
            child: Text(
              'OpenCode',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (!calm) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        QuotaChip(onTap: onStatusTap),
      ],
    );
  }
}

/// One row inside the top-bar overflow menu.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}

/// Color + short label for a given SSE connection state.
(Color, String) _statusVisual(SseStatus status) => switch (status) {
  SseStatus.connected => (const Color(0xFF22C55E), L.tr('متصل', 'Connected')),
  SseStatus.connecting => (
    const Color(0xFFEAB308),
    L.tr('بيتصل...', 'Connecting...'),
  ),
  SseStatus.disconnected => (const Color(0xFFEF4444), L.tr('قاطع', 'Offline')),
};

/// Forward-pointing chevron that respects the reading direction.
IconData _forwardChevron(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl
    ? Icons.chevron_left_rounded
    : Icons.chevron_right_rounded;

// -----------------------------------------------------------------------------
// Sections
// -----------------------------------------------------------------------------

/// Shown while the app runs on the built-in demo server, so nobody mistakes
/// the sample chats for real ones.
class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.tertiaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 6, 8),
        child: Row(
          children: [
            Icon(
              Icons.science_outlined,
              size: 18,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L.tr('وضع العرض التجريبي', 'Demo mode'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                  Text(
                    L.tr(
                      'بيانات تجريبية — مفيش سيرفر',
                      'Sample data — no server',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.read<AppState>().exitDemoMode(),
              child: Text(L.tr('خروج', 'Exit')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(
            L.tr(
              'إزاي أقدر أساعدك النهاردة؟ 👋',
              'How can I help you today? 👋',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            L.tr(
              'هتبدأ محادثة جديدة في المشروع اللي تختاره',
              'A new chat starts in the project you pick',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title with an optional trailing counter or action.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.text,
    this.trailing,
    this.action,
    this.onAction,
  });

  final String text;
  final String? trailing;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(action!),
          )
        else if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Rounded card showing the selected project; opens the project picker.
class _ProjectSelector extends StatelessWidget {
  const _ProjectSelector({
    required this.project,
    required this.loading,
    required this.empty,
    required this.onTap,
  });

  final OcProject? project;
  final bool loading;
  final bool empty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = !loading && !empty;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: loading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      )
                    : Icon(
                        project == null
                            ? Icons.help_outline_rounded
                            : (project!.vcs != null
                                  ? Icons.folder_special_outlined
                                  : Icons.folder_outlined),
                        size: 20,
                        color: scheme.primary,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project?.name ??
                          (empty
                              ? L.tr(
                                  'مفيش مشاريع على السيرفر',
                                  'No projects on this server',
                                )
                              : L.tr('اختار مشروع', 'Pick a project')),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      project?.canonical ??
                          L.tr(
                            'ابدأ مشروع من جهازك الأول',
                            'Start one on your computer first',
                          ),
                      textDirection: project == null ? null : TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.unfold_more_rounded,
                size: 20,
                color: scheme.onSurfaceVariant.withValues(
                  alpha: enabled ? 1 : 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quick suggestion prefills the composer.
class _Suggestion {
  const _Suggestion({required this.icon, required this.ar, required this.en});

  final IconData icon;
  final String ar;
  final String en;

  String get label => L.tr(ar, en);
}

/// Two-by-two grid of quick suggestions.
class _SuggestionGrid extends StatelessWidget {
  const _SuggestionGrid({required this.suggestions, required this.onSelected});

  final List<_Suggestion> suggestions;
  final ValueChanged<_Suggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < suggestions.length; i += 2) {
      final first = suggestions[i];
      final second = i + 1 < suggestions.length ? suggestions[i + 1] : null;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SuggestionCard(
                  suggestion: first,
                  onTap: () => onSelected(first),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: second == null
                    ? const SizedBox.shrink()
                    : _SuggestionCard(
                        suggestion: second,
                        onTap: () => onSelected(second),
                      ),
              ),
            ],
          ),
        ),
      );
      if (i + 2 < suggestions.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.onTap});

  final _Suggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(suggestion.icon, size: 18, color: scheme.primary),
              ),
              const SizedBox(height: 10),
              Text(
                suggestion.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One recent conversation: title, project, and when it was last touched.
class _RecentChatRow extends StatelessWidget {
  const _RecentChatRow({
    required this.session,
    required this.busy,
    required this.onTap,
  });

  final OcSession session;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = session.title?.trim().isNotEmpty == true
        ? session.title!.trim()
        : L.tr('جلسة بدون عنوان', 'Untitled session');
    final where = _shortDir(session.directory);
    final when = relativeTime(session.updatedMs ?? session.createdMs);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: busy
                  ? SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 17,
                      color: scheme.primary,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [?where, if (when.isNotEmpty) when].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              _forwardChevron(context),
              size: 20,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  /// Last path segment — a full path is far too long for a phone row.
  static String? _shortDir(String? directory) {
    if (directory == null || directory.isEmpty) return null;
    final parts = directory.split(RegExp(r'[\\/]'));
    final name = parts.isEmpty || parts.last.isEmpty ? directory : parts.last;
    return name.length > 24 ? name.substring(0, 24) : name;
  }
}

// -----------------------------------------------------------------------------
// Project picker
// -----------------------------------------------------------------------------

/// Searchable project list — the server can expose dozens of projects, which
/// horizontal chips handle badly.
class _ProjectPickerSheet extends StatefulWidget {
  const _ProjectPickerSheet({required this.projects, this.selected});

  final List<OcProject> projects;
  final OcProject? selected;

  @override
  State<_ProjectPickerSheet> createState() => _ProjectPickerSheetState();
}

class _ProjectPickerSheetState extends State<_ProjectPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<OcProject> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.projects;
    return widget.projects
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.canonical.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final projects = _filtered;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                children: [
                  Text(
                    L.tr('اختار المشروع', 'Pick a project'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    L.tr(
                      '${projects.length} من ${widget.projects.length}',
                      '${projects.length} of ${widget.projects.length}',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 46,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: L.tr('دوّر على مشروع...', 'Search projects...'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                          ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Flexible(
              child: projects.isEmpty
                  ? SizedBox(
                      height: 140,
                      child: Center(
                        child: Text(L.tr('مفيش نتائج للبحث 🤷', 'No results')),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 12),
                      children: [
                        for (final project in projects)
                          _ProjectTile(
                            project: project,
                            selected:
                                widget.selected?.canonical == project.canonical,
                            onTap: () => Navigator.of(context).pop(project),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.selected,
    required this.onTap,
  });

  final OcProject project;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      dense: true,
      onTap: onTap,
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.25),
      leading: Icon(
        project.vcs != null
            ? Icons.folder_special_outlined
            : Icons.folder_outlined,
        size: 20,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(
        project.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          color: selected ? scheme.primary : null,
        ),
      ),
      subtitle: Text(
        project.canonical,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          fontSize: 11,
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, size: 20, color: scheme.primary)
          : null,
    );
  }
}
