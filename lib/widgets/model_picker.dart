import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/l10n.dart';
import '../state/chat_state.dart';

/// Opens the model picker sheet for [chat]; switches the session model on
/// selection. [current] is the session's active model (highlighted).
Future<void> showModelPicker(BuildContext context, ChatState chat,
    {ModelRef? current}) {
  chat.loadModels();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ModelPickerSheet(chat: chat, current: current),
  );
}

/// Friendly provider label: "opencode-go" -> "Opencode Go".
String providerLabel(String providerID) {
  return providerID
      .split(RegExp(r'[-_]'))
      .map((w) => w.isEmpty
          ? w
          : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

class _ModelPickerSheet extends StatefulWidget {
  const _ModelPickerSheet({required this.chat, this.current});

  final ChatState chat;
  final ModelRef? current;

  @override
  State<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends State<_ModelPickerSheet> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _isCurrent(ModelOption m) {
    final cur = widget.current;
    return cur != null &&
        cur.id == m.id &&
        cur.providerID == m.providerID;
  }

  List<ModelOption> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.chat.models;
    return widget.chat.models
        .where((m) =>
            m.label.toLowerCase().contains(q) ||
            m.id.toLowerCase().contains(q) ||
            m.providerID.toLowerCase().contains(q))
        .toList();
  }

  /// Providers grouped, sorted: current model's provider first.
  Map<String, List<ModelOption>> _grouped(List<ModelOption> models) {
    final byProvider = <String, List<ModelOption>>{};
    for (final m in models) {
      byProvider.putIfAbsent(m.providerID, () => []).add(m);
    }
    for (final list in byProvider.values) {
      list.sort((a, b) => a.label.compareTo(b.label));
    }
    final keys = byProvider.keys.toList()
      ..sort((a, b) {
        final cur = widget.current?.providerID;
        if (a == cur) return -1;
        if (b == cur) return 1;
        return a.compareTo(b);
      });
    return {for (final k in keys) k: byProvider[k]!};
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final models = _filtered;
    final grouped = _grouped(models);

    return Padding(
      // Keep the list above the keyboard when searching.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                    L.tr('اختيار الموديل', 'Choose model'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (!(chat.loadingModels && chat.models.isEmpty))
                    Text(
                      L.tr('${models.length} من ${chat.models.length}', '${models.length} of ${chat.models.length}'),
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
                    hintText: L.tr('دوّر على موديل...', 'Search models...'),
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
              child: AnimatedBuilder(
                animation: chat,
                builder: (context, _) {
                  if (chat.loadingModels && chat.models.isEmpty) {
                    return const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (chat.models.isEmpty) {
                    return SizedBox(
                      height: 160,
                      child: Center(
                        child: Text(
                          chat.error ?? L.tr('مفيش موديلات متاحة على السيرفر ده', 'No models available on this server'),
                        ),
                      ),
                    );
                  }
                  if (models.isEmpty) {
                    return SizedBox(
                      height: 140,
                      child: Center(child: Text(L.tr('مفيش نتائج للبحث 🤷', 'No results'))),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                          child: Text(
                            providerLabel(entry.key),
                            textDirection: TextDirection.ltr,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        for (final model in entry.value)
                          _ModelTile(
                            model: model,
                            isCurrent: _isCurrent(model),
                            onTap: () {
                              if (_isCurrent(model)) {
                                Navigator.of(context).pop();
                                return;
                              }
                              Navigator.of(context).pop();
                              chat.switchModel(model);
                            },
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.model,
    required this.isCurrent,
    required this.onTap,
  });

  final ModelOption model;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      dense: true,
      onTap: onTap,
      selected: isCurrent,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.25),
      title: Row(
        children: [
          Flexible(
            child: Text(
              model.label,
              textDirection: TextDirection.ltr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                color: isCurrent ? scheme.primary : null,
              ),
            ),
          ),
          if (isCurrent) ...[
            const SizedBox(width: 8),
            Text(
              L.tr('الحالي', 'current'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        model.id,
        textDirection: TextDirection.ltr,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          fontSize: 11,
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: isCurrent
          ? Icon(Icons.check_circle_rounded, size: 20, color: scheme.primary)
          : null,
    );
  }
}
