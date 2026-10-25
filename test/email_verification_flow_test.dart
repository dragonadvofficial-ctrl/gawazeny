import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gawezeny/core/constants/supabase_constants.dart';

void main() {
  group('Email Verification Flow & Deep Linking Tests', () {
    test('SupabaseConstants.authRedirectUrl is secure and does NOT contain localhost', () {
      expect(SupabaseConstants.authRedirectUrl, isNotEmpty);
      expect(SupabaseConstants.authRedirectUrl.contains('localhost'), isFalse,
          reason: 'Must never point to localhost in production settings');
      expect(SupabaseConstants.authRedirectUrl.startsWith('https://'), isTrue,
          reason: 'Must use HTTPS for secure verification redirection');
    });

    test('SupabaseConstants.appAuthDeepLink is configured with gawezeny scheme', () {
      expect(SupabaseConstants.appAuthDeepLink, 'gawezeny://auth/confirm');
    });

    test('AndroidManifest.xml contains gawezeny custom URL scheme intent filters', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      expect(content.contains('android:scheme="gawezeny"'), isTrue);
      expect(content.contains('android:host="auth"'), isTrue);
      expect(content.contains('android:host="login"'), isTrue);
    });

    test('Info.plist contains gawezeny URL scheme for iOS', () {
      final plistFile = File('ios/Runner/Info.plist');
      expect(plistFile.existsSync(), isTrue);

      final content = plistFile.readAsStringSync();
      expect(content.contains('CFBundleURLSchemes'), isTrue);
      expect(content.contains('<string>gawezeny</string>'), isTrue);
    });

    test('HTML Email Template contains required Arabic copy and Supabase variable', () {
      final templateFile = File('supabase/email_templates/confirm_signup.html');
      expect(templateFile.existsSync(), isTrue);

      final html = templateFile.readAsStringSync();
      // Required subject and branding
      expect(html.contains('تأكيد بريدك الإلكتروني — جوزيني يا ماما'), isTrue);
      expect(html.contains('مرحبًا بك في جوزيني يا ماما 👋'), isTrue);
      expect(html.contains('شكرًا لانضمامك إلينا! يسعدنا وجودك معنا.'), isTrue);
      expect(html.contains('تأكيد البريد الإلكتروني'), isTrue);
      expect(html.contains('إذا لم تقم بإنشاء هذا الحساب، يمكنك تجاهل هذه الرسالة.'), isTrue);
      expect(html.contains('مع تحيات فريق جوزيني يا ماما.'), isTrue);

      // Must use official Supabase ConfirmationURL variable
      expect(html.contains('{{ .ConfirmationURL }}'), isTrue);
      expect(html.contains('localhost:3000'), isFalse);
    });

    test('Web Verification page handles Success, Expired, and Error states', () {
      final verifyFile = File('web/verify.html');
      expect(verifyFile.existsSync(), isTrue);

      final html = verifyFile.readAsStringSync();
      // State elements
      expect(html.contains('id="state-loading"'), isTrue);
      expect(html.contains('id="state-success"'), isTrue);
      expect(html.contains('id="state-expired"'), isTrue);
      expect(html.contains('id="state-error"'), isTrue);

      // Required Arabic texts
      expect(html.contains('تم تأكيد بريدك الإلكتروني بنجاح!'), isTrue);
      expect(html.contains('أصبح بإمكانك الآن تسجيل الدخول إلى حسابك والاستمتاع باستخدام'), isTrue);
      expect(html.contains('تعذّر تأكيد البريد الإلكتروني'), isTrue);
      expect(html.contains('رابط التأكيد غير صالح أو انتهت صلاحيته.'), isTrue);
      expect(html.contains('إعادة إرسال رسالة التأكيد'), isTrue);

      // Deep link launcher
      expect(html.contains('gawezeny://login'), isTrue);
      expect(html.contains('@supabase/supabase-js'), isTrue);
    });
  });
}
