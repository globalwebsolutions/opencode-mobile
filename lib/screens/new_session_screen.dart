import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import '../state/sessions_state.dart';

/// Creates a new session: pick one of the projects the server knows about,
/// optionally name the conversation, and start it.
class NewSessionScreen extends StatefulWidget {
  const NewSessionScreen({super.key});

  @override
  State<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends State<NewSessionScreen> {
  List<OcProject> _projects = [];
  bool _loading = true;
  String? _error;
  OcProject? _selected;
  final _titleController = TextEditingController();
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    final app = context.read<AppState>();
    try {
      final projects = await app.client?.listProjects() ?? const <OcProject>[];
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _loading = false;
        _error = null;
        // Preselect the most recently active project.
        OcProject? mostRecent;
        for (final p in projects) {
          mostRecent ??= p;
        }
        _selected ??= mostRecent;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.read<AppState>().friendlyErrorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    if (_selected == null || _creating) return;
    setState(() => _creating = true);
    final sessions = context.read<SessionsState>();
    try {
      final session = await sessions.createSession(
        directory: _selected!.canonical,
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(session);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.read<AppState>().friendlyErrorText(e);
        _creating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('محادثة جديدة')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorView(
                          message: _error!,
                          onRetry: () {
                            setState(() => _loading = true);
                            _loadProjects();
                          },
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 8, 20, 4),
                              child: Text(
                                'اختار المشروع:',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            for (final project in _projects)
                              ListTile(
                                onTap: () =>
                                    setState(() => _selected = project),
                                selected:
                                    _selected?.canonical == project.canonical,
                                leading: project.vcs != null
                                    ? const Icon(Icons.folder_special_outlined)
                                    : const Icon(Icons.folder_outlined),
                                title: Text(project.name),
                                subtitle: Text(
                                  project.canonical,
                                  textDirection: TextDirection.ltr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                                trailing: _selected?.canonical ==
                                        project.canonical
                                    ? Icon(Icons.check_circle_rounded,
                                        color: scheme.primary)
                                    : null,
                              ),
                          ],
                        ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _titleController,
                    enabled: !_creating,
                    decoration: const InputDecoration(
                      hintText: 'اسم المحادثة (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _selected != null && !_creating
                        ? _create
                        : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _creating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: const Text('ابدأ المحادثة'),
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: const Text('إعادة')),
          ],
        ),
      ),
    );
  }
}
