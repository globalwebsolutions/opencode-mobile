import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// "How to connect from anywhere" — three ready methods the user can follow,
/// each with copyable commands. Opened from home, welcome, and settings.
class ConnectGuideScreen extends StatelessWidget {
  const ConnectGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('دليل التوصيل')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'التطبيق بيوصل بسيرفر OpenCode على جهازك — ودي 3 طرق تختار منها حسب وضعك:',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 16),
          _GuideCard(
            icon: Icons.wifi_rounded,
            title: '1) وانت في نفس الواي فاي',
            subtitle: 'الأسهل للاستخدام في البيت أو المكتب',
            steps: const [
              'فعّل الاتصال من الشبكة (مرة واحدة):',
              'اتعرف على عنوان جهازك:',
              'شوف البورت الحالي:',
              'اطلب لينك pairing بالعنوان ده:',
            ],
            commands: const [
              'opencode service set hostname 0.0.0.0',
              'ipconfig getifaddr en0',
              'opencode service status',
              'opencode pair --url http://<IP-بتاعك>:<البورت>',
            ],
          ),
          const SizedBox(height: 14),
          _GuideCard(
            icon: Icons.public_rounded,
            title: '2) من أي مكان في العالم — Tailscale',
            subtitle: 'مجاني وبدون دومين — جهازك يبقى له عنوان ثابت',
            steps: const [
              'سطّب Tailscale على الماك وعلى الموبايل من نفس الحساب:',
              'تأكد إن الجهازين متصلين بتيليسكيل:',
              'فعّل استقبال الشبكة على السيرفر (مرة واحدة):',
              'خد عنوان تيليسكيل بتاع الماك:',
              'اطلب لينك pairing بالعنوان ده:',
            ],
            commands: const [
              'tailscale.com/download',
              'tailscale status',
              'opencode service set hostname 0.0.0.0',
              'tailscale ip -4',
              'opencode pair --url http://<IP-بتاعك>:<البورت>',
            ],
          ),
          const SizedBox(height: 14),
          _GuideCard(
            icon: Icons.link_rounded,
            title: '3) عنوان عام جاهز (نفق مؤقت)',
            subtitle: 'Cloudflare Tunnel أو ngrok — أي HTTPSURL يشتغل',
            steps: const [
              'على الماك، افتح نفق للسيرفر (مثال cloudflared):',
              'انسخ الرابط العام اللي هيظهرلك https://...:',
              'اطلب لينك pairing بنفس الرابط:',
              'أو الصق اللينك الناتج هنا في التطبيق',
            ],
            commands: const [
              'cloudflared tunnel --url http://localhost:<البورت>',
              'مثال: https://xxxx.trycloudflare.com',
              'opencode pair --url https://xxxx.trycloudflare.com',
              '',
            ],
          ),
          const SizedBox(height: 18),
          _NoteCard(
            child: Text(
              '💡 كل لينكات pairing الصلاحية بتاعتها 5 دقايق — لو انتهت اطلب واحد جديد. '
              'لو السيرفر اتعاد تشغيله (بعد update أو restart للماك) البورت ممكن يتغير '
              'والـ pairing القديم باظ — امسحه من الإعدادات واعمل جديد.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.steps,
    required this.commands,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> steps;
  final List<String> commands;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pairs = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      pairs.add(RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '•  ',
              style: TextStyle(color: scheme.primary),
            ),
            TextSpan(text: steps[i]),
          ],
        ),
      ));
      final cmd = i < commands.length ? commands[i] : '';
      if (cmd.isNotEmpty) {
        pairs.add(Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 0, 10),
          child: _CommandRow(command: cmd),
        ));
      } else {
        pairs.add(const SizedBox(height: 8));
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 36),
            child: Text(
              subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          ...pairs,
        ],
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({required this.command});

  final String command;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              command,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: command));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('الأمر اتنسخ ✅'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.copy_rounded,
                  size: 16, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
