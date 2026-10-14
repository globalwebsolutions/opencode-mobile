# سياسة الخصوصية — OpenCode Mobile

**آخر تحديث:** أكتوبر 2026
**المطوّر:** Global Web Solutions — https://Globalweb.Solutions

> انشر النص ده على `https://Globalweb.Solutions/privacy` (أو أي عنوان دائم)،
> وحط اللينك في Google Play Console → Store listing → Privacy policy.

---

## بالعربي

### الخلاصة
OpenCode Mobile تطبيق **غير رسمي** بيوصّل موبايلك بسيرفر OpenCode اللي انت
مشغّله على جهازك. **مفيش عندنا سيرفرات، ولا حسابات، ولا تتبّع، ولا إعلانات**،
وإحنا مش بنجمع أي بيانات عنك.

### البيانات اللي بتتخزن على جهازك
- **عنوان سيرفر OpenCode** بتاعك + **توكن التوصيل (pairing token)** — في تخزين
  مشفّر على الجهاز (`flutter_secure_storage`: Keystore على أندرويد، Keychain على
  iOS). التوكن ده بيتولد لما انت بتعمل pairing وبيستخدم للمصادقة مع سيرفرك بس.
- **تفضيلات التطبيق**: اللغة والمظهر.
- **إعدادات الإشعارات**: عنوان وتوكن السيرفر (افتراضيًا بيبقى نص عادي في مساحة
  التطبيق الخاصة، عشان خدمة الخلفية تقراها).
- **صور مرفقة**: بتتبعت لسيرفرك وتُخزَّن عنده (في مكان سيرفرك)، مش عندنا.

مفيش أي بيانات بتترسل لـ Global Web Solutions. إحنا مش بنشوف سيرفرك ولا محتواه.

### البيانات اللي بتخرج من الجهاز
| الوجهة | إيه اللي بيتبعت | إمتى |
|---|---|---|
| **سيرفر OpenCode بتاعك** (على شبكتك) | رسائلك، طلبات الموافقة، أوامر التنفيذ، الصور اللي بترفقها | طول ما انت بتستخدم التطبيق |
| **opencode.ai** (اختياري) | توكن حساب OpenCode المسجّل على سيرفرك، لقراءة كوتة خطتك | بس لما تفتح كارت «الكوتة» — ومفيش أي بيانات محادثات |

- الاتصال بسيرفرك بيحصل عن طريق HTTP على الشبكة المحلية (زي ما سيرفر
  OpenCode نفسه بيشتغل). لو عايز تشفير كامل استخدم
  [Tailscale](https://tailscale.com) ووصّل التطبيق على عنوان الـ Tailscale.
- إحنا مش بنستخدم أي خدمة تحليلات أو تتبّع أو إعلانات.

### الصلاحيات وليه
| الصلاحية | السبب |
|---|---|
| الإنترنت | الاتصال بسيرفر OpenCode بتاعك |
| الكاميرا | مسح كود الـ QR للمرة الواحدة، وإرفاق صور من الكاميرا |
| الصور | إرفاق صورة في رسالة |
| الإشعارات | تنبيهك لما الوكيل يطلب موافقة أو يخلّص تنفيذ |
| خدمة في الخلفية | تفضل متوصل بالسيرفر وانت بره التطبيق (تقدر تقفلها من الإعدادات) |
| منع النوم / Vibate | الحفاظ على الاتصال وتنبيهك |

### الأطفال
التطبيق أداة مطوّرين ومش مخصّص للأطفال (18+)، ومش بنجمع أي بيانات من أي حد.

### حذف بياناتك
- **على التطبيق**: الإعدادات → حذف السيرفر (يمسح التوكن والعنوان)، أو امسح
  بيانات التطبيق من إعدادات النظام.
- **على الكمبيوتر**: المحادثات محفوظة عند سيرفر OpenCode بتاعك — امسحها من هناك
  (`opencode session` أو من مجلد بيانات OpenCode).
- مفيش بيانات عندنا عشان نمسحها (إحنا مش بنخزّن حاجة).

### تغييرات
أي تحديث للسياسة هيتنشر على نفس اللينك مع تاريخ جديد.

### تواصل
support@globalweb.solutions · https://Globalweb.Solutions

---

## English

### In short
OpenCode Mobile is an **unofficial** client that connects your phone to the
OpenCode server **you** run on your own computer. There are **no servers of
ours, no accounts, no tracking and no ads**, and we do not collect any data
about you.

### Stored on your device
- Your **OpenCode server address** and its **pairing token**, kept in encrypted
  storage (Android Keystore / iOS Keychain). The token authorises requests to
  *your* server only.
- App preferences (language, theme).
- Notification settings: your server address and token (plain, in the app's
  private support directory, so the background service can read them).
- Attached images: uploaded to *your* server and stored there.

Nothing is sent to Global Web Solutions. We cannot see your server or its
contents.

### Leaving the device
| Destination | What | When |
|---|---|---|
| **Your OpenCode server** (on your network) | your messages, permission replies, run commands, attached images | while you use the app |
| **opencode.ai** (optional) | the OpenCode account token held by your server, to read your plan quota | only when you open the quota card — never conversations |

Traffic to your server uses plain HTTP on your local network, exactly as the
OpenCode server itself works; use [Tailscale](https://tailscale.com) for full
encryption. We use no analytics, tracking or advertising services.

### Permissions
Internet (reach your server) · Camera (pairing QR, camera attachments) ·
Photos (attachments) · Notifications (permission requests, finished runs) ·
Foreground service (stay connected while backgrounded — switchable off in
Settings) · Wake lock / vibrate (keep the connection alive, alert you).

### Children
A developer tool, not aimed at children (18+). We collect nothing from anyone.

### Deleting your data
Remove the server in Settings → delete server, or clear the app's data. Your
conversations live on your own OpenCode server — delete them there. We hold no
data to delete.

### Changes
Updates are published at the same URL with a new date.

### Contact
support@globalweb.solutions · https://Globalweb.Solutions
