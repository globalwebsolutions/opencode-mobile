# بيانات المتجر — انسخ والصق

كل النصوص دي جاهزة للصق في Google Play Console مباشرة. القيم اللي بين ⬅️ تتغير.

---

## 1. اسم التطبيق (30 حرف كحد أقصى)

```
OpenCode Mobile
```

بدائل لو مش متاح: `OpenCode Mobile — unofficial` · `OpenCode for Mobile`

## 2. الوصف القصير (80 حرف كحد أقصى)

**عربي:**
```
عميل غير رسمي لسيرفر OpenCode: محادثاتك وردود الوكيل لحظيًا من موبايلك
```
(69 حرف)

**English:**
```
Unofficial OpenCode client — your sessions and agent replies, live
```
(65 chars)

## 3. الوصف الكامل (4000 حرف كحد أقصى)

**عربي:**
```
OpenCode Mobile تطبيق غير رسمي بيوصّلك بسيرفر OpenCode اللي على جهازك، فتقدر
تتابع شغل الوكيل من على تليفونك — بنفس الجلسات والردود اللي بتشوفها على الكمبيوتر.

■ بيشتغل إزاي؟
• سيرفر OpenCode بيشتغل على جهازك (ماك/لينكس/ويندوز) وبيعرّض API + أحداث لحظية.
• من التطبيق: امسح كود QR واحد (`opencode pair`) وخلاص — مفيش حسابات ولا تسجيل.
• بعد كده كل حاجة لحظية زي تطبيقات المحادثة: الرد بيتكتب كلمة كلمة، والتفكير
  والأدوات بتظهر وانت شايف.

■ المميزات
• محادثاتك كلها (sessions) بعناوينها وتكلفتها والموديل المستخدم.
• ردود متدفقة لحظيًا + التفكير قابل للطي.
• كروت لكل أداة (read / edit / shell / browser…) بإدخالها ونتيجتها.
• موافقة الصلاحيات من الموبايل: مرة / دايمًا / رفض.
• إيقاف التنفيذ في أي لحظة، وإنشاء جلسة جديدة في أي مشروع.
• اختيار الموديل والمشاريع، ومراجعة كل المحادثات بالمشاريع.
• إشعارات في الخلفية لما الوكيل يطلب صلاحية أو يخلّص تنفيذ.
• قياس الكوتة الشهرية (لخطط OpenCode Go): فاضل كام في الشهر/الأسبوع/آخر 5 ساعات.
• استهلاكك المحلي: التكلفة والتوكنز.
• وضع العرض: تجربة التطبيق بدون أي سيرفر (بيانات تجريبية).

■ ملاحظات مهمة
• التطبيق مش بيشغّل موديلات على الموبايل — هو واجهة لسيرفرك اللي على جهازك.
• محتاج الكمبيوتر والموبايل على نفس الشبكة، أو Tailscale للاتصال من بره.
• مشروع مجتمعي غير رسمي، مش مبني من فريق OpenCode وغير تابع لهم بأي شكل.
  OpenCode نفسه مفتوح المصدر (MIT).

■ الخصوصية
مفيش حسابات ولا تتبّع ولا إعلانات. بياناتك بتفضل عندك: الردود والمحادثات على
سيرفرك انت، والتطبيق بيخزّن على الجهاز عنوان السيرفر والتوكن (مشفّر) فقط.
```

**English:**
```
OpenCode Mobile is an unofficial client for the OpenCode server running on
your own computer — so you can follow your agent from your phone, with the
same sessions and replies you see on your desktop.

■ HOW IT WORKS
• OpenCode runs on your machine (macOS/Linux/Windows) and exposes an HTTP API
  plus a live event stream.
• In the app: scan one QR code from `opencode pair` — no account, no sign-up.
• After that everything is live like a chat app: replies stream word by word,
  with reasoning and tool calls shown as they happen.

■ FEATURES
• All your sessions with titles, cost and model.
• Live streaming replies, collapsible reasoning.
• A card per tool call (read / edit / shell / browser…) with input and output.
• Approve permissions from your phone: once / always / reject.
• Interrupt a run, start a new session in any project.
• Model picker, project switcher, full history grouped by project.
• Background notifications when the agent asks for permission or finishes.
• Plan quota meter (OpenCode Go): what is left this month / week / 5 hours.
• Local spend: cost and tokens.
• Demo mode: try the app with sample data — no server needed.

■ GOOD TO KNOW
• The app does not run models on the phone; it drives the server on your own
  machine.
• Your computer and phone usually need the same network (Tailscale works from
  anywhere).
• Unofficial community project — not built by, or affiliated with, the
  OpenCode team. OpenCode itself is open source (MIT).

■ PRIVACY
No accounts, no tracking, no ads. Your data stays with you: conversations live
on your own server, and the app stores only the server address and its pairing
token (encrypted) on the device.
```

## 4. تصنيف ومعلومات أساسية

| الحقل | القيمة |
|---|---|
| الفئة | `Developer tools` |
| وسوم | `developer tools` · `productivity` |
| البريد الإلكتروني | ⬅️ `support@globalweb.solutions` (أو إيميلك) |
| الموقع | `https://Globalweb.Solutions` |
| سياسة الخصوصية | ⬅️ `https://Globalweb.Solutions/privacy` (استخدم `docs/privacy-policy.md`) |
| إعلانات | **لا** |
| مشتريات داخل التطبيق | **لا** |
| مجاني / مدفوع | **مجاني** |
| الجمهور المستهدف | 18+ (أداة مطوّرين) |
| التطبيق يحتوي على محتوى مخصّص للأطفال؟ | لا |

## 5. App access (مهم — بيتوقف عليها القبول)

اختار **"All functionality is available without special access"** واكتب في
الملاحظات (Review instructions):

```
The app is a client for an OpenCode server that normally runs on the
reviewer's own computer. No server is required to review it:

1. Install and open the app.
2. On the pairing screen tap "جرّب من غير سيرفر — وضع العرض" /
   "Try it without a server — demo mode".
3. The app opens with sample projects, conversations, a streamed agent reply,
   tool cards and a pending permission request.

To test the real flow: install OpenCode on a computer
(curl -fsSL https://opencode.ai/install | bash), run
`opencode service set hostname 0.0.0.0` and
`opencode pair --url http://<computer-LAN-IP>:<PORT>`, then scan the QR from
the app (or paste the printed link).
```

## 6. Data safety (أمان البيانات)

| السؤال | الإجابة |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | ⬅️ **No*** |
| Do you provide a way for users to request that their data is deleted? | **Yes** — الإعدادات → حذف السيرفر (أو مسح بيانات التطبيق) |

\* بصراحة: التطبيق بيتكلم مع سيرفر المستخدم على الشبكة المحلية عن طريق HTTP
عادي (زي ما سيرفر OpenCode بيعمل). لو حطيت `Yes` هتسألك عن طريقة التشفير —
اختار `No` واشرح في الوصف إن التشفير متاح عبر Tailscale.

## 7. Content rating questionnaire

- Category: **Utility / Productivity / Developer tools**
- Violence / Sexuality / Language / Controlled substances: **No** لكل الأسئلة
- Does the app share user location? **No**
- Does the app allow users to interact/exchange content?
  **Yes** — لكن المحتوى بيتبادل مع سيرفر المستخدم نفسه (مش شبكة عامة).

## 8. Foreground service declaration (إجباري من أندرويد 14)

النوعين المستخدمين: **dataSync** + **remoteMessaging**

```
The app keeps a direct connection to the user's own OpenCode server so it can
raise notifications when the agent needs a permission decision or finishes a
run while the app is in the background. The service does not upload anything:
it only holds the SSE connection to the address the user paired, and it is
started/stopped by an in-app switch.
```

## 9. الجدول الزمني (مهم)

لو حسابك **شخصي واتعمل بعد 13 نوفمبر 2023**: مفيش نشر مباشر للإنتاج — لازم
**اختبار مغلق بـ 12 مختبر مسجّلين متواصلين 14 يوم**، وعادةً جوجل بتاخد 7 أيام
أو أقل للمراجعة بعده.

- جهّز **15–18 مختبر** (Number مش target)، وقوللهم صريح: يفضلوا مسجّلين 14 يوم.
- استخدم **وضع العرض** كـ onboarding للمختبرين: يسجّلوا، يفتحوا التطبيق، يجرّبوا
  الوضع التجريبي كامل (محادثة، كارت أداة، طلب صلاحية) — ده بالظبط اللي جوجل
  بتسأل عنه: "هل المختبرين استخدموا كل الميزات؟".
- ابدأ الـ closed test **بالتوازي** مع تجهيز صفحة المتجر (الـ 14 يوم وقت تقويمي).
- للحساب المؤسسي (D-U-N-S) الشرط ده مش موجود.

## 10. متطلبات قبل الرفع

- [ ] مفتاح التوقيع (`bash tools/make_upload_keystore.sh`) — من غيره **مش هينفع ترفع**
- [ ] `flutter build appbundle --release`
- [ ] رفع `build/app/outputs/bundle/release/app-release.aab`
- [ ] 3 صور شاشات على الأقل من `store/screenshots/store_*.png` (المقاس 1080×2160 ✓)
- [ ] أيقونة المتجر `store/play_icon_512.png` + الرسم الترويجي `store/feature_graphic_1024x500.png`
- [ ] نشر سياسة الخصوصية + وضع اللينك
- [ ] زوّد `version: 1.0.0+1` → `+2` مع كل رفعة
