# النشر على App Store — قائمة الشغل

التطبيق: OpenCode Mobile · Bundle ID: `com.gws.opencode` · الفريق: Global Web Solutions
آخر تحديث: أكتوبر 2026

---

## 1. اللي جاهز

| البند | الحالة |
|---|---|
| Bundle ID | ✅ `com.gws.opencode` |
| البناء | ✅ `flutter build ios --release` بينجح (deployment target اتظبط لـ 15.0) |
| اللوجو/الأيقونة | ✅ `mipmap` بتاعت أندرويد مش هتستخدم — أيقونة iOS محتاجة `Assets.xcassets` (شوف تحت) |
| نصوص المتجر | ✅ نفس نصوص `docs/store-listing.md` (عدّل اللي بيتكلم عن أندرويد) |
| سياسة الخصوصية | ✅ `docs/privacy-policy.md` — **إجبارية** في App Store Connect |

## 2. اللي ناقص

### أ) حساب Apple Developer Program
- 99$ **سنويًا** (مختلف عن جوجل اللي مرة واحدة).
- لو لسه مش مشترك: enrol من [developer.apple.com/programs](https://developer.apple.com/programs/) — بيربط بحسابك (فرد أو شركة، وشركة محتاجة D-U-N-S).
- لو الحساب **شركة**: ممكن تطلع Team ID وتستخدمه في Xcode.

### ب) أيقونة iOS
iOS مش بيقرأ `mipmap` بتاعة أندرويد. محتاج `ios/Runner/Assets.xcassets/AppIcon.appiconset/`:

```bash
# الأداة عندنا بتولّد PNG 1024 — وده كل اللي iOS 14+ محتاج (Single Size)
cp store/play_icon_512.png /tmp/icon_1024.png   # ثم كبّرها لـ 1024
# الأفضل: ضيف حجم 1024 في tools/generate_brand_assets.py
```
> مطلوب **1024×1024** بدون شفافية (App Store Connect بيرفض اللي فيه alpha).

### ج) الـ Signing في Xcode
```
open ios/Runner.xcworkspace
Runner → Signing & Capabilities → Team: ⬅️ فريقك
Bundle Identifier: com.gws.opencode
```
وبعدين:
```bash
flutter build ipa --release
# الناتج: build/ios/ipa/*.ipa  ← ترفعه بـ Transporter أو Xcode
```

### د) في App Store Connect
| البند | التفاصيل |
|---|---|
| New App | الاسم + اللغة الأساسية + Bundle ID + SKU |
| الوصف | نفس نصوص `docs/store-listing.md` (بدّل "Android" بـ "iPhone/iPad") |
| صور الشاشات | **إجبارية**: 6.9" (مثلاً 1290×2796) و6.5" (1242×2688) — **مش نفس مقاسات جوجل** |
| Privacy Policy URL | إجباري (نفس لينك جوجل) |
| App Privacy | "Data Not Collected" لكل الفئات (نفس منطق Data safety) |
| Age Rating | 18+ / 4+ حسب الأسئلة — أداة مطوّرين |
| Support URL | `https://Globalweb.Solutions` |
| Export Compliance | التطبيق بيستخدم تشفير؟ **لا** (اتصال HTTP عادي على الشبكة المحلية) → `No` |

### هـ) صور شاشات iOS
أسهل طريقة من السيموليتور على الماك:

```bash
open -a Simulator                       # افتح iPhone 16 Pro Max (6.9")
flutter run -d "iPhone 16 Pro Max"
# لكل شاشة:
xcrun simctl io booted screenshot store/ios-screenshots/01_home.png
```

## 3. ملاحظات مهمة للمراجعة

1. **الإشعارات في الخلفية مش مدعومة على iOS** (بيبعت من السيرفر = webhook/push
   مش موجود). لازم تكتب ده صريح في **Notes for Review**:

```
Background notifications are intentionally Android-only for now: on iOS the
app stops receiving server events when it is suspended, because that would
require server-side push (APNs) infrastructure that this open-source client
does not ship yet. Everything else works identically on iOS.
```

2. **التطبيق محتاج سيرفر على جهاز المستخدم.** اكتب للمراجع:

```
The app is a client for an OpenCode server running on the reviewer's own
computer. No server is required to review: on the pairing screen tap
"Try it without a server — demo mode", which loads sample projects, a
streamed agent reply, tool cards and a permission request.
```

3. **التطبيق غير رسمي** — مكتوب في الوصف وفي شاشة التوصيل، وده بيقلل خطر
   الرفض بسبب "تضليل" (Misleading).

## 4. الأوامر

```bash
flutter build ipa --release        # بناء للرفع
open build/ios/archive/*.xcarchive # أو من Xcode → Organizer
```

## 5. الفرق بين المنصتين — نظرة سريعة

| | Google Play | App Store |
|---|---|---|
| التكلفة | 25$ مرة واحدة | 99$ سنويًا |
| مفتاح التوقيع | انت بتمتلكه (upload key) | الشهادات في Xcode (Apple بتمتلك التوقيع النهائي) |
| اختبار إجباري | 12 مختبر × 14 يوم (حساب شخصي جديد) | لا يوجد شرط مشابه |
| مقاسات الصور | 1080×2160 كافية | مقاسات أجهزة أبل تحديدًا |
