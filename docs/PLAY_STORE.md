# النشر على Google Play — قائمة الشغل

آخر تحديث: أكتوبر 2026 · التطبيق: OpenCode Mobile · الفريق: Global Web Solutions

> ده الملف اللي تمشي عليه بالترتيب من فوق لتحت. كل مرة قبله ✅ يبقى خلصان.

---

## 1. الحالة الحالية (خلص)

| البند | الحالة |
|---|---|
| Package name | ✅ `com.gws.opencode` (أندرويد + `com.gws.opencode` على iOS/macOS) |
| أيقونة التطبيق | ✅ أداة توليد + أيقونة مكيّفة (Adaptive) + نسخة دائرية + monochrome لثيمات أندرويد 13 |
| أيقونة الإشعارات | ✅ `>_` أبيض (vector) |
| شاشة البداية (Splash) | ✅ خلفية براند + اللوجو، فاتح/غامق |
| صور المتجر | ✅ `store/play_icon_512.png` + `store/feature_graphic_1024x500.png` |
| توقيع الإصدار | ✅ `build.gradle.kts` بيقرا `android/key.properties` (ناقص بس ملف المفاتيح بتاعك) |
| وضع العرض (بيانات اختبار) | ✅ من غير سيرفر — جاهز للمراجعة والاختبار |

أداة توليد الصور: `python3 tools/generate_brand_assets.py` (بتحدّث الأيقونات وصور المتجر كلها من
مصدر واحد). محتاجة مكتبة Pillow:

```bash
python3 -m pip install pillow      # أو استخدم venv
python3 tools/generate_brand_assets.py
```

> 🖼️ صور الشاشات: اتصوّر منها **3** لحد الآن في `store/screenshots/`
> (الرئيسية + شاشة التوصيل + الإعدادات). لما توصّل الموبايل تاني شغّل
> `bash tools/capture_store_screenshots.sh` وهيوديك على 6 شاشات ويحوّلهم لمقاس جوجل.

---

## 2. اللي ناقص — لازم قبل الرفع

### أ) مفتاح التوقيع (Upload keystore) ⚠️ الأهم

```bash
keytool -genkey -v -keystore ~/opencode-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload

cp android/key.properties.example android/key.properties
# وعدّل فيه المسار والباسورد
```

- `android/key.properties` و `*.jks` مستثنين من الجيت (متشيلهمش).
- **اعمل باك أب للملف** (`~/opencode-upload.jks`) — لو ضاع مش هتقدر تحدّث التطبيق، إلا لو مفعّل Play App Signing (وده اللي بنصح بيه — من أول رفع).
- لو الملف مش موجود، البيلد هيمشي بمفتاح الـ debug والمتجر **مش** هيقبله.

### ب) بناء الـ App Bundle (مش APK)

```bash
flutter build appbundle --release
# الناتج: build/app/outputs/bundle/release/app-release.aab
```

- رقم الإصدار من `pubspec.yaml` (`version: 1.0.0+1`) — زوّد `+1` كل رفعة.

### ج) في Play Console

| البند | التفاصيل |
|---|---|
| إنشاء التطبيق | الاسم: `OpenCode Mobile` · اللغة الافتراضية: العربية · مجاني |
| اسم المتجر | أقصى 30 حرف |
| الوصف القصير | أقصى 80 حرف |
| الوصف الكامل | أقصى 4000 حرف — اشرح إنه عميل غير رسمي ومحتاج سيرفر OpenCode على نفس الشبكة |
| صور الشاشات | **2 على الأقل** من `store/screenshots/` (المقاس 1080×2160، نسبة 1:2 — مسموح لحد 2:1) |
| أيقونة المتجر | `store/play_icon_512.png` (512×512، بدون شفافية) |
| الرسم الترويجي | `store/feature_graphic_1024x500.png` |
| الفئة | `Developer Tools` أو `Productivity` |
| بيانات التواصل | `support@globalweb.solutions` + الموقع |
| سياسة الخصوصية | **مطلوبة** لو صرّحت بجمع أي بيانات — انشرها على `globalweb.solutions/privacy` وحط اللينك |

### د) نماذج Play الإلزامية

1. **Data safety** — التطبيق مابيرفعش بيانات على سيرفراتنا: كل حاجة بتفضل على جهاز المستخدم/السيرفر بتاعه.
   - يجمع بيانات؟ **لا** (ما عدا: التطبيق بيتصل بسيرفر المستخدم نفسه).
   - يشارك بيانات؟ **لا**.
   - مشفّرة خلال النقل؟ لاحظ إن الاتصال بسيرفر المستخدم HTTP على الشبكة المحلية (أو Tailscale للتشفير) — اشرح ده في الوصف.
   - يقدر المستخدم يطلب مسح بياناته؟ الاتصال بيتشال من «الإعدادات → حذف السيرفر».
2. **Content rating** → questionnaire (التطبيق أداة مطوّرين، مفيش محتوى مقيّد).
3. **Target audience** → 18+ (أداة مطوّرين).
4. **Foreground service declaration** (إجباري للمستهدفين أندرويد 14+):
   - النوعين المستخدمين: `dataSync` + `remoteMessaging`.
   - السبب: «الحفاظ على اتصال مباشر بسيرفر المستخدم (SSE) في الخلفية لإرسال تنبيهات طلبات الموافقة وانتهاء التنفيذ.»
5. **App access** (مهم جداً) — التطبيق محتاج سيرفر، فالمُراجع لازم يعرف إزاي يجرّبه:
   > The app needs an OpenCode server on the same network. **No server is required to review**: on the pairing screen tap **"جرّب من غير سيرفر — وضع العرض / Try it without a server — demo mode"**. Demo mode ships with sample projects, conversations, a live streaming reply and a permission request. To test the real flow, install OpenCode (`curl -fsSL https://opencode.ai/install | bash`), run `opencode service set hostname 0.0.0.0` and `opencode pair --url http://<LAN-IP>:<PORT>`, then scan the QR from the app.

### هـ) مسار الاختبار

1. **Internal testing** → ارفع الـ AAB → ضيف إيميلات المختبرين (حتى 100) → ابعتلهم لينك الانضمام.
2. **Closed / Open testing** → بعد ما الداخلي يعدّي.
3. **Production** → بعد 14 يوم من الإصدارات السابقة (لو حسابك جديد) ومراجعة Google.

---

## 3. بيانات الاختبار

### أ) وضع العرض (بدون سيرفر) — الأسرع
شاشة التوصيل → **«جرّب من غير سيرفر — وضع العرض»**. هتلاقي:
- 3 مشاريع و4 محادثات (عناوين وتكاليف وموديلات مختلفة).
- محادثة فيها **تفكير قابل للطي + كارت أداة (read) + رد متدفق**.
- **طلب صلاحية معلّق** عشان تجرّب أزرار الموافقة/الرفض.
- أي رسالة تبعتها بترجّع رد تجريبي بيتكتب كلمة كلمة.

> للخروج: بانر «وضع العرض» فوق في الهوم → «خروج» (أو من الإعدادات).

### ب) سيرفر حقيقي للمختبرين
على جهاز الاختبار:
```bash
opencode service set hostname 0.0.0.0      # يسمح بالاتصال من الشبكة
opencode pair --url http://$(ipconfig getifaddr en0):49374
```
ابعت الـ QR/اللينك للمختبر — أو استخدم Tailscale لو بره الشبكة.

### ج) حسابات/بيانات جاهزة
- **مفيش تساعد دخول**: مفيش إيميل/باسورد — التوصيل بـ pairing token بيتخزن في
  `flutter_secure_storage` ومابيتشاركش مع حد.
- لو هيئة المراجعة طلبت "test credentials" → اختار **App access → All functionality is
  available without special access** واكتب ملاحظة وضع العرض اللي فوق.

---

## 4. أوامر سريعة

```bash
# الأيقونات وصور المتجر
python3 tools/generate_brand_assets.py

# صور شاشات للمتجر (من موبايل موصول بالـ USB)
bash tools/capture_store_screenshots.sh

# بناء للنشر
flutter build appbundle --release

# فحص أخير قبل الرفع
flutter analyze && flutter test
```

## 5. ملاحظات قانونية
- التطبيق **غير رسمي** ومش تابع لفريق OpenCode — مكتوبة في الوصف وفي شاشة التوصيل.
- الترخيص MIT، وكود OpenCode نفسه مش منسوخ جوه التطبيق (التطبيق عميل بيستخدم الـ API).
