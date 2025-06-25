# دليل المطور - إصلاح مشاكل QR Scanner

## المشكلة الأصلية
كانت المشكلة الرئيسية هي عدم وجود صلاحيات الكاميرا في ملفات التكوين، مما يمنع QR scanner من العمل بشكل صحيح.

## الإصلاحات المطبقة

### 1. إضافة صلاحيات الكاميرا في Android

**الملف:** `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
```

### 2. إضافة صلاحيات الكاميرا في iOS

**الملف:** `ios/Runner/Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan QR codes for pairing child watches.</string>
```

### 3. تحسين كود QR Scanner

**الملف:** `lib/screens/qr_pair_screen.dart`

#### التحسينات المطبقة:

1. **إضافة معالجة أخطاء أفضل:**
   ```dart
   try {
     final status = await Permission.camera.request();
     // ... معالجة الحالة
   } catch (e) {
     // ... معالجة الخطأ
   }
   ```

2. **تحسين regex لـ MAC Address:**
   ```dart
   // دعم صيغ أكثر مرونة
   if (!RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$').hasMatch(cleanedQR)) {
     throw Exception('Invalid MAC address format');
   }
   ```

3. **إضافة تصحيح مفصل:**
   ```dart
   print('QR Scanner: Camera controller created');
   print('QR Scanner: Data received: ${scanData.code}');
   ```

4. **إضافة زر إعادة المحاولة:**
   ```dart
   void _retryScanning() {
     setState(() {
       error = null;
       scanned = false;
       isProcessing = false;
       processingMessage = null;
     });
     
     if (controller != null) {
       controller!.resumeCamera();
     }
   }
   ```

## كيفية اختبار الإصلاح

### 1. اختبار الصلاحيات
```bash
# تأكد من أن التطبيق يطلب صلاحية الكاميرا
flutter run
# انتقل إلى شاشة QR Scanner
# تأكد من ظهور طلب صلاحية الكاميرا
```

### 2. اختبار QR Scanner
```bash
# أنشئ QR code يحتوي على MAC address صحيح
# مثال: 12:34:56:78:90:AB
# جرب مسح QR code
# تأكد من نجاح العملية
```

### 3. اختبار معالجة الأخطاء
```bash
# جرب مسح QR code بتنسيق خاطئ
# تأكد من ظهور رسالة خطأ واضحة
# جرب زر "Try Again"
```

## ملفات التكوين المحدثة

### Android
- `android/app/src/main/AndroidManifest.xml` - إضافة صلاحيات الكاميرا

### iOS
- `ios/Runner/Info.plist` - إضافة صلاحيات الكاميرا والموقع

### Flutter
- `lib/screens/qr_pair_screen.dart` - تحسين كود QR scanner

## أفضل الممارسات

### 1. طلب الصلاحيات
```dart
// دائماً اطلب الصلاحيات في بداية التطبيق
Future<void> _requestCameraPermission() async {
  try {
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      // اعرض رسالة خطأ واضحة
      setState(() {
        error = 'Camera permission is required';
      });
    }
  } catch (e) {
    // عالج الأخطاء
  }
}
```

### 2. معالجة الأخطاء
```dart
// استخدم try-catch لمعالجة جميع الأخطاء
try {
  // كود QR scanner
} catch (e) {
  print('Error: $e');
  setState(() {
    error = 'Failed to process QR code: $e';
  });
}
```

### 3. إدارة الحالة
```dart
// استخدم متغيرات حالة واضحة
bool _cameraInitialized = false;
bool isProcessing = false;
String? error;
```

## استكشاف الأخطاء

### 1. الكاميرا لا تفتح
- تحقق من صلاحيات الكاميرا
- تأكد من عدم استخدام الكاميرا من تطبيق آخر
- أعد تشغيل التطبيق

### 2. QR Code لا يتم مسحه
- تحقق من وضوح QR code
- تأكد من وجود إضاءة كافية
- جرب تقريب الكاميرا من QR code

### 3. خطأ في Firebase
- تحقق من اتصال الإنترنت
- تأكد من إعدادات Firebase
- تحقق من تسجيل الدخول

## المراجع

- [Flutter Camera Plugin](https://pub.dev/packages/camera)
- [QR Code Scanner](https://pub.dev/packages/qr_code_scanner)
- [Permission Handler](https://pub.dev/packages/permission_handler)
- [Android Permissions](https://developer.android.com/training/permissions/requesting)
- [iOS Privacy](https://developer.apple.com/documentation/bundleresources/information_property_list)

## ملاحظات إضافية

- تأكد من اختبار التطبيق على أجهزة حقيقية
- اختبر على إصدارات مختلفة من Android و iOS
- تأكد من عمل التطبيق في وضع عدم الاتصال
- اختبر مع أنواع مختلفة من QR codes 