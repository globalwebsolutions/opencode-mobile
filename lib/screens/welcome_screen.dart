import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../state/app_state.dart';

/// First-run screen: pair the app with an OpenCode server.
///
/// Pairing is the "sign in" of this app: the user runs `opencode pair` on
/// their computer, then scans or pastes the one-time link here.
///
/// [addMode] reuses the same UI from settings to pair an additional server.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.addMode = false});

  final bool addMode;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _linkController = TextEditingController();
  bool _working = false;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pair(String link) async {
    final app = context.read<AppState>();
    setState(() => _working = true);
    try {
      await app.pairWithLink(link);
    } catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      final message = app.friendlyErrorText(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (!mounted) return;
    if (widget.addMode && app.phase == AppPhase.ready) {
      // Added from settings: go back to the server list.
      Navigator.of(context).pop();
      return;
    }
    setState(() => _working = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.addMode
          ? AppBar(title: const Text('وصّل سيرفر جديد'))
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  const AppLogo(size: 84),
                  const SizedBox(height: 16),
                  Text(
                    'OpenCode Mobile',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'استخدم OpenCode من موبايلك — جلساتك، رسائلك، وتحديث لحظي زي تطبيقات المحادثة.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 32),
                  _StepsCard(scheme: scheme),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _working
                        ? null
                        : () async {
                            final link = await pushScannerScreen(context);
                            if (link != null && link.isNotEmpty) {
                              _pair(link);
                            }
                          },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('امسح كود الـ QR'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'أو الصق اللينك',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _linkController,
                    enabled: !_working,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) _pair(value);
                    },
                    keyboardType: TextInputType.url,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      hintText: 'http://192.168.x.x:PORT/auth/connect/...',
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: _linkController.text.trim().isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.paste),
                              tooltip: 'لصق',
                              onPressed: () async {
                                final data = await Clipboard.getData(
                                    Clipboard.kTextPlain);
                                if (data != null &&
                                    data.text != null &&
                                    data.text!.trim().isNotEmpty) {
                                  _linkController.text = data.text!.trim();
                                  setState(() {});
                                }
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _working ||
                            _linkController.text.trim().isEmpty
                        ? null
                        : () => _pair(_linkController.text),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _working
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('اتصال'),
                  ),
                  if (app.error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorCard(message: app.error!, scheme: scheme),
                  ],
                  const SizedBox(height: 32),
                  Text(
                    'مشروع مجتمعي غير رسمي — مش مبني من فريق OpenCode '
                    'ومنتابعش لأوبن كود بأي شكل. OpenCode نفسه مفتوح المصدر.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
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
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'خطوات التوصيل (مرة واحدة بس):',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _Step(
            number: '1',
            scheme: scheme,
            title: 'على الكمبيوتر، خلّي السيرفر يسمح بالاتصال:',
            code: 'opencode service set hostname 0.0.0.0',
          ),
          const SizedBox(height: 10),
          _Step(
            number: '2',
            scheme: scheme,
            title: 'اطلب لينك pairing جديد (بيطلع معاه QR):',
            code: 'opencode pair --url http://<IP-الكمبيوتر>:<PORT>',
          ),
          const SizedBox(height: 10),
          _Step(
            number: '3',
            scheme: scheme,
            title: 'امسح الـ QR من هنا — وخلاص، إنت داخل! 🎉',
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.scheme,
    required this.title,
    this.code,
  });

  final String number;
  final ColorScheme scheme;
  final String title;
  final String? code;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: scheme.primary.withValues(alpha: 0.15),
          child: Text(
            number,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyMedium),
              if (code != null) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    code!,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.scheme});

  final String message;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final localhostHint = message.contains('127.0.0.1') ||
        message.contains('localhost') ||
        message.contains('connection refused') ||
        message.contains('Connection refused');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: scheme.error, size: 20),
              const SizedBox(width: 8),
              Text(
                'فشل الاتصال',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: scheme.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (localhostHint) ...[
            const SizedBox(height: 8),
            Text(
              '💡 اللينك بيشاور على 127.0.0.1 — من جهاز الموبايل ده مش بيوصل للكمبيوتر. '
              'اطلب لينك جديد بعنوان الكمبيوتر على الشبكة: '
              'opencode pair --url http://<IP-الكمبيوتر>:<PORT>',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
