import 'package:flutter/material.dart';
import '../core/l10n.dart';
import 'package:flutter/services.dart';

/// "How to connect from anywhere" — three ready methods the user can follow,
/// each with copyable commands. Opened from home, welcome, and settings.
class ConnectGuideScreen extends StatelessWidget {
  const ConnectGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(L.tr('دليل التوصيل', 'Connection guide'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            L.tr(
                'التطبيق بيوصل بسيرفر OpenCode اللي على جهازك. الطريقة الأولى بتغطي 90% من الحالات — والتانية والتالتة لما تكون بعيد عن البيت.',
                'The app connects to the OpenCode server on your machine. Method 1 covers most cases — methods 2 and 3 are for when you are away from home.'),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 16),
          _GuideCard(
            icon: Icons.qr_code_2_rounded,
            title: L.tr('1) أسرع طريقة: امسح الكود', '1) Quickest: scan the code'),
            subtitle: L.tr('نفس الواي فاي — أقل من دقيقة', 'Same Wi-Fi — under a minute'),
            steps: [
              L.tr('على الكمبيوتر — الأمر ده بيطبع QR ولينكين (صالحين 5 دقايق):',
                  'On your computer — this prints a QR and two links (valid 5 minutes):'),
              L.tr('من الموبايل: اضغط «امسح كود الـ QR» وصوّب الكاميرا على الشاشة:',
                  'On your phone: tap "Scan the QR code" and point it at the screen:'),
              L.tr('لو اللينك اللي مسحته فيه 127.0.0.1 — انسخ اللينك التاني اللي فيه 192.168 والصقه في التطبيق:',
                  'If the link you scanned says 127.0.0.1 — copy the other link (192.168…) from the terminal and paste it in the app instead:'),
              L.tr('ولو أول مرة بس، خلّي السيرفر يقبل الاتصال من الشبكة:',
                  'First time only — let the server accept connections from the network:'),
            ],
            commands: [
              'opencode pair',
              '',
              '',
              'opencode service set hostname 0.0.0.0',
            ],
          ),
          const SizedBox(height: 14),
          _GuideCard(
            icon: Icons.public_rounded,
            title: L.tr('2) من أي مكان في العالم — Tailscale', '2) From anywhere in the world — Tailscale'),
            subtitle: L.tr('مجاني وبدون دومين — جهازك يبقى له عنوان ثابت', 'Free, no domain — a stable address for your machine'),
            steps: [
              L.tr('سطّب Tailscale على الماك وعلى الموبايل من نفس الحساب:', 'Install Tailscale on both devices under the same account:'),
              L.tr('تأكد إن الجهازين متصلين بتيليسكيل:', 'Confirm both devices are connected:'),
              L.tr('فعّل استقبال الشبكة على السيرفر (مرة واحدة):', 'Allow LAN on the server (one-time):'),
              L.tr('خد عنوان تيليسكيل بتاع الماك:', 'Get the Tailscale IP of the Mac:'),
              L.tr('اطلب لينك pairing بالعنوان ده:', 'Request a pairing link with that address:'),
            ],
            commands: [
              'tailscale.com/download',
              'tailscale status',
              'opencode service set hostname 0.0.0.0',
              'tailscale ip -4',
              L.tr('opencode pair --url http://<IP-بتاعك>:<البورت>', 'opencode pair --url http://<IP>:<PORT>'),
            ],
          ),
          const SizedBox(height: 14),
          _GuideCard(
            icon: Icons.link_rounded,
            title: L.tr('3) عنوان عام جاهز (نفق مؤقت)', '3) A public URL (temporary tunnel)'),
            subtitle: L.tr('Cloudflare Tunnel أو ngrok — أي HTTPSURL يشتغل', 'Cloudflare Tunnel or ngrok — any HTTPS URL works'),
            steps: [
              L.tr('على الماك، افتح نفق للسيرفر (مثال cloudflared):', 'On the Mac, open a tunnel (cloudflared example):'),
              L.tr('انسخ الرابط العام اللي هيظهرلك https://...:', 'Copy the public https:// URL it prints:'),
              L.tr('اطلب لينك pairing بنفس الرابط:', 'Request a pairing link with it:'),
              L.tr('أو الصق اللينك الناتج هنا في التطبيق', 'or paste the resulting link right in the app'),
            ],
            commands: [
              L.tr('cloudflared tunnel --url http://localhost:<البورت>', 'cloudflared tunnel --url http://localhost:<PORT>'),
              L.tr('مثال: https://xxxx.trycloudflare.com', 'example: https://xxxx.trycloudflare.com'),
              'opencode pair --url https://xxxx.trycloudflare.com',
              '',
            ],
          ),
          const SizedBox(height: 18),
          _NoteCard(
            child: Text(
              L.tr('💡 كل لينكات pairing الصلاحية بتاعتها 5 دقايق — لو انتهت اطلب واحد جديد. ', 'Every pairing link expires in 5 minutes — ask for a new one if it lapses. ') +
                  L.tr('لو السيرفر اتعاد تشغيله (بعد update أو restart للماك) البورت ممكن يتغير ', 'If the server restarts (after an update or reboot) the port may change ') +
                  L.tr('والـ pairing القديم باظ — امسحه من الإعدادات واعمل جديد.', 'and old pairings break — remove it in Settings and pair again.'),
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
                  SnackBar(
                    content: Text(L.tr('الأمر اتنسخ ✅', 'Command copied ✅')),
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
