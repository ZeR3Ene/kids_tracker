<<<<<<< HEAD
# Kids Tracker - تطبيق تتبع الأطفال

تطبيق Flutter لتتبع ساعات الأطفال الذكية باستخدام ESP32 و Firebase.

## المميزات

- 🔐 تسجيل الدخول باستخدام Google و Facebook
- 📱 واجهة مستخدم جميلة وسهلة الاستخدام
- 📍 تتبع الموقع في الوقت الفعلي
- 🗺️ عرض المواقع على خريطة Google
- 🔔 إشعارات عند خروج الطفل من المنطقة الآمنة
- 📊 عرض إحصائيات النشاط
- ⚙️ إعدادات مخصصة لكل طفل

## التثبيت والتشغيل

### المتطلبات

- Flutter SDK 3.7.2 أو أحدث
- Dart SDK
- Android Studio / VS Code
- حساب Firebase
- حساب Google Cloud Platform (لخرائط Google)

### خطوات التثبيت

1. **استنساخ المشروع:**
   ```bash
   git clone <repository-url>
   cd kids_tracker-master
   ```

2. **تثبيت التبعيات:**
   ```bash
   flutter pub get
   ```

3. **إعداد Firebase:**
   - أنشئ مشروع Firebase جديد
   - أضف تطبيق Android/iOS
   - انسخ ملف `google-services.json` إلى `android/app/`
   - انسخ ملف `GoogleService-Info.plist` إلى `ios/Runner/`

4. **إعداد Google Maps:**
   - احصل على مفتاح API من Google Cloud Console
   - أضفه إلى `android/app/src/main/AndroidManifest.xml`

5. **تشغيل التطبيق:**
   ```bash
   flutter run
   ```

## إصلاح مشاكل QR Scanner

إذا واجهت مشاكل في مسح QR codes، راجع ملف [QR_SCANNER_TROUBLESHOOTING.md](QR_SCANNER_TROUBLESHOOTING.md) للحصول على حلول مفصلة.

### المشاكل الشائعة:

1. **الكاميرا لا تعمل:** تأكد من منح صلاحية الكاميرا للتطبيق
2. **QR Code لا يتم مسحه:** تأكد من وضوح QR code وإضاءة كافية
3. **خطأ في تنسيق MAC Address:** تأكد من صحة تنسيق MAC address

## هيكل المشروع

```
lib/
├── main.dart                 # نقطة البداية
├── models/
│   └── esp32_watch.dart      # نموذج بيانات الساعة
├── screens/
│   ├── home_screen.dart      # الشاشة الرئيسية
│   ├── map_screen.dart       # شاشة الخريطة
│   ├── qr_pair_screen.dart   # شاشة ربط الساعة
│   ├── login_screen.dart     # شاشة تسجيل الدخول
│   └── ...                   # شاشات أخرى
├── widgets/
│   └── ...                   # مكونات واجهة المستخدم
└── utils/
    └── responsive_utils.dart # أدوات الاستجابة
```

## التكنولوجيات المستخدمة

- **Frontend:** Flutter
- **Backend:** Firebase (Authentication, Realtime Database)
- **Maps:** Google Maps Flutter
- **QR Scanner:** qr_code_scanner
- **Permissions:** permission_handler
- **Location:** geolocator

## الصلاحيات المطلوبة

### Android:
- `android.permission.CAMERA` - لمسح QR codes
- `android.permission.ACCESS_FINE_LOCATION` - لتتبع الموقع
- `android.permission.ACCESS_COARSE_LOCATION` - لتتبع الموقع التقريبي
- `android.permission.INTERNET` - للاتصال بالإنترنت

### iOS:
- `NSCameraUsageDescription` - لمسح QR codes
- `NSLocationWhenInUseUsageDescription` - لتتبع الموقع
- `NSLocationAlwaysAndWhenInUseUsageDescription` - لتتبع الموقع المستمر

## المساهمة

نرحب بالمساهمات! يرجى:

1. عمل Fork للمشروع
2. إنشاء branch جديد للميزة
3. عمل Commit للتغييرات
4. عمل Push إلى Branch
5. إنشاء Pull Request

## الترخيص

هذا المشروع مرخص تحت رخصة MIT. راجع ملف `LICENSE` للتفاصيل.

## الدعم

إذا واجهت أي مشاكل:

1. راجع ملف [QR_SCANNER_TROUBLESHOOTING.md](QR_SCANNER_TROUBLESHOOTING.md)
2. ابحث في Issues الموجودة
3. أنشئ Issue جديد مع تفاصيل المشكلة

## التحديثات الأخيرة

### v1.0.1
- إصلاح مشاكل QR Scanner
- إضافة صلاحيات الكاميرا
- تحسين رسائل الخطأ
- إضافة زر إعادة المحاولة
- تحسين واجهة المستخدم

### v1.0.0
- الإصدار الأولي
- الميزات الأساسية للتتبع
- واجهة مستخدم بسيطة
=======
# kids_tracker

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
>>>>>>> 62b6a07f4877dcdbe997cf47726dc5d75fb624ae
