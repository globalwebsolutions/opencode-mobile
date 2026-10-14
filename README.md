# OpenCode Mobile 📱

تطبيق موبايل غير رسمي لاستخدام **[OpenCode](https://opencode.ai)** من على تليفونك —
واجهة دردشة زي تطبيقات Claude و ChatGPT بالظبط: بتفتح بحسابك (pairing بالـ QR)،
ب تشوف محادثاتك (sessions)، وبتشوف الردود **تتولد لحظيًا** وهي بتكتب، مع كروت الأدوات
وأزرار الموافقة على الصلاحيات.

> [!NOTE]
> هذا مشروع مجتمعي **غير رسمي**: لم يبنَ من فريق OpenCode ولا يتبع OpenCode بأي شكل.
> OpenCode نفسه مشروع مفتوح المصدر (MIT) متاح على
> [github.com/anomalyco/opencode](https://github.com/anomalyco/opencode).
> This is an unofficial, community-built client. It is **not** built by, endorsed by, or
> affiliated with the OpenCode team.

---

## إزاي بيشتغل؟ (المعمارية)

```
┌──────────────┐    QR pairing (مرة واحدة)    ┌─────────────────────┐
│  الموبايل     │ ─────────────────────────► │   الماك / الكمبيوتر  │
│  هذا التطبيق  │                             │  OpenCode (سيرفر)    │
│  Flutter      │ ◄────── SSE (لحظي) ──────── │  sessions + models  │
└──────────────┘  HTTP API (رسائل/أوامر)      └─────────────────────┘
```

- OpenCode V2 بيشتغل بمعمارية **client-server**: سيرفر خلفي بيمتلك الـ sessions
  والرسائل والصلاحيات، وبيعرض **HTTP API** (142 endpoint) + **SSE** للأحداث اللحظية.
- التطبيق ده عميل ليه: بيسجل دخول مرة واحدة عن طريق **pairing** بالـ QR
  (زي ما بتعمل sign in بالحساب)، وبعدها كل حاجة لحظية زي تطبيقات الدردشة.
- التطبيق مش بيشغل موديلات على الموبايل — بيوصّلك للـ models والمشاريع اللي على
  جهازك، فبتاخد نفس قوة الوكيل بتاعك في التليفون.

## المميزات

###  الميزات الأساسية
- ✅ **Pairing بالـ QR** — امسح كود `opencode pair` وخلاص
- ✅ **قائمة المحادثات** — كل الـ sessions بتاعتك بالعناوين والتكلفة والموديل
- ✅ **Streaming لحظي** — النص بيظهر كلمة كلمة، والتفكير (reasoning) قابل للطي
- ✅ **كروت الأدوات** — شوف كل أداة (read/edit/shell/browser...) إدخالها ونتيجتها
- ✅ **الصلاحيات** — وافق/ارفض من الموبايل (مرة / دايمًا / رفض)
- ✅ **إيقاف التنفيذ** — زرار stop وقت ما الوكيل شغال
- ✅ **إنشاء جلسات** — اختار المشروع وابدأ محادثة جديدة
- ✅ **إعادة اتصال تلقائية** + reconciling مع السيرفر بعد أي انقطاع

### 🧪 وضع العرض (تجربة من غير سيرفر)
مش محتاج تفتح OpenCode ولا توصّل أي حاجة عشان تشوف التطبيق شغال:
شاشة التوصيل → **«جرّب من غير سيرفر — وضع العرض»**. هتلاقي مشاريع ومحادثات
وهمية، رد بيتكتب لحظيًا، كارت أداة، وطلب صلاحية معلّق تجرّب عليه الموافقة/الرفض.
(مفيد كمان للمراجعة على المتجر — شوف `docs/PLAY_STORE.md`.)

### 🔥 الميزات المتقدمة
- ✅ **Multi-Server** — إدارة أكتر من سيرفر OpenCode في نفس التطبيق
  - إضافة/حذف/تسمية السيرفرات
  - التبديل بين السيرفرات بضغطة واحدة
  - كل سيرفر له pairing مستقل
- ✅ **إشعارات الخلفية (Android)** — تنبيهات فورية وأنت بره التطبيق
  - تنبيه عند طلب الوكيل صلاحية (مهم جدًا — الوكيل بيستنى ردّك)
  - تنبيه عند انتهاء/فشل تنفيذ جلسة
  - خدمة خلفية مستمرة (foreground service) تحافظ على الاتصال
  - toggle في الإعدادات للتفعيل/الإيقاف
  - iOS: مش متاح دلوقتي (محتاج push من السيرفر — في الـ roadmap)

## التسطيب

### المتطلبات على الكمبيوتر

- OpenCode v2.x مسطب على الماك/الكمبيوتر (`curl -fsSL https://opencode.ai/install | bash`)
- الموبايل والكمبيوتر على **نفس الشبكة** (Wi-Fi واحد)، أو استخدم
  [Tailscale](https://tailscale.com) للاتصال من بره الشبكة.

### خطوات التوصيل (مرة واحدة)

على الكمبيوتر:

```bash
# 1) خلّي سيرفر OpenCode يسمح بالاتصال من الشبكة
opencode service set hostname 0.0.0.0

# 2) اطلب لينك pairing (هيطلع QR + لينك)
opencode pair --url http://<عنوان-IP-بتاع-الكمبيوتر>:<البورت>
```

> 💡 تعرف IP الكمبيوتر من: `ipconfig getifaddr en0` (على الماك)
> والبورت من آخر السطر اللي `opencode pair` بيطبعه (مثال: `49374`).

على الموبايل:

1. سطب التطبيق (APK للأندرويد — شوف تحت).
2. اضغط **"امسح كود الـ QR"** وامسح الكود الظاهر في التيرمنال.
   - أو انسخ اللينك من التيرمنال والصقه في التطبيق.
3. مبروك 🎉 — لقيت المحادثات بتاعتك وتبدأ محادثة جديدة.

> لما السيرفر بيتحديث أو البورت بيتغير بعد restart، باظ الـ pairing القديم —
> كرر الخطوة 2 وخلاص. (الـ sessions نفسها محفوظة عند OpenCode ومش بتتأثر.)

### التسطيب من الكود

```bash
flutter pub get
flutter test

# أندرويد
flutter build apk --release
# الناتج: build/app/outputs/flutter-apk/app-release.apk

# iOS (محتاج Mac + Xcode)
flutter build ipa --release
# أو افتح ios/Runner.xcworkspace من Xcode وسطب على تليفونك
```

المنصات المدعومة: **Android** و **iOS** (وكمان macOS للتجربة المحلية:
`flutter run -d macos` — الصق لينك الـ pairing بدل المسح).

## البنية

```
lib/
├── app.dart                        # MaterialApp + الثيم + التنقل الجذري
├── core/
│   ├── models.dart                 # موديلات الـ API (sessions/messages/parts/events)
│   ├── opencode_client.dart        # REST + SSE client (Basic auth + reconnect)
│   ├── connection_store.dart       # تخزين آمن لقائمة السيرفرات (v2)
│   ├── watcher_config.dart         # إعدادات watcher للخلفية (بدون platform channels)
│   ├── notification_watcher.dart   # TaskHandler للعزلة الخلفية (SSE + poll)
│   └── notification_center.dart    # Main isolate: init + local notifications
├── state/
│   ├── app_state.dart              # Multi-server + connection lifecycle + SSE hub
│   ├── sessions_state.dart         # قائمة المحادثات بالتحديث اللحظي
│   └── chat_state.dart             # الرسائل + الـ streaming + الصلاحيات
├── screens/
│   ├── welcome_screen.dart         # pairing (يدعم إضافة سيرفر من الإعدادات)
│   ├── scanner_screen.dart         # ماسح الـ QR
│   ├── home_screen.dart            # قائمة المحادثات
│   ├── new_session_screen.dart     # مشروع جديد
│   ├── chat_screen.dart            # المحادثة
│   └── settings_screen.dart        # إدارة السيرفرات + إشعارات الخلفية
└── widgets/                        # فقاعات، كروت الأدوات، الصلاحيات، شريط الإدخال
```

## ملحوظات تقنية

- **الـ auth**: سيرفر OpenCode بيستخدم HTTP Basic (`opencode:<token>`) —
  الـ token بيتولد من لينك الـ pairing مرة واحدة وبيتخزن في
  `flutter_secure_storage` (Keychain على iOS/macOS و Keystore على Android)،
  مع fallback لملف خاص بالتطبيق لو التخزين الآمن مش متاح.
- **الأحداث**: `GET /api/event` (SSE) — stream "live-only" من غير replay،
  فالتطبيق بيعمل reconnect تلقائي وبعدها بيعمل refresh للحالة من السيرفر.
- **إشعارات الخلفية**: لازم حاجتين موجودين في المشروع ومينفعش يتشالوا:
  (1) تعريف الـ `<service>` بتاع `flutter_foreground_task` في
  `android/app/src/main/AndroidManifest.xml` (البلجن مابيعرّفوش بنفسه، ومن
  غير `foregroundServiceType` الخدمة مش هتشتغل من أندرويد 14)، و
  (2) نداء `FlutterForegroundTask.initCommunicationPort()` في `main()` —
  من غيره أي داتا جاية من الـ isolate بتاع الخدمة مش بتوصل للـ UI.
  فيه تست (`test/android_notifications_test.dart`) بيحرس الاتنين دول.
- **الصلاحيات**: بيتعمل poll على `GET /api/session/{id}/permission` كل 2.5 ثانية
  طول ما الوكيل شغال + فورًا مع كل نداء أداة، والرد بيروح لـ
  `POST /api/session/{id}/permission/{requestId}/reply`.
- كل أشكال البيانات في `models.dart` متبنية على ردود فعلية من سيرفر
  OpenCode 2.0.x (شوف `test/models_test.dart`).
- التطبيق بيسمح بـ **HTTP غير مشفر** على الشبكة المحلية فقط لأن سيرفر OpenCode
  بيتواصل بـ HTTP عادي — لو بتستخدمه عبر الإنترنت، استخدم Tailscale (مشفّر).

## تحسينات مستقبلية (اسحب وكمّل 😄)

- اختيار الموديل/الوكيل من داخل التطبيق (`/api/model` + `/api/agent`)
- عرض الـ diffs والملفات المعدلة داخل كروت الأدوات
- إشعارات محلية عند اكتمال التنفيذ أو طلب صلاحية والتطبيق في الخلفية
- بحث داخل الجلسات + تقسيمها بالمشاريع
- WebSocket PTY للطرفية الحية (`/api/pty`)

## مشاريع ذات صلة

| المشروع | الوصف |
|---|---|
| [**OpenCode Chat Sidebar**](https://github.com/globalwebsolutions/opencode-chat-sidebar) | إضافة VS Code — دردشة مع وكلاء OpenCode جوه المحرر (نفس الفريق) |

> الاثنين بيتكلموا مع نفس سيرفر OpenCode، فتقدر تبدأ محادثة على الكمبيوتر
> وتكمّلها من الموبايل (أو العكس) لأن الجلسات محفوظة عند السيرفر.

## النشر على المتجر

- الـ package name: `com.gws.opencode`
- الأيقونات وصور المتجر بتتولد من `tools/generate_brand_assets.py`
- كل خطوات النشر (التوقيع، الـ AAB، نماذج Play، بيانات الاختبار):
  [`docs/PLAY_STORE.md`](docs/PLAY_STORE.md)

## الفريق

التطبيق ده صُنع واتطوّر بواسطة **Global Web Solutions** — 2026.
🔗 [Globalweb.Solutions](https://Globalweb.Solutions)

## الترخيص

MIT — نفس ترخيص OpenCode.
