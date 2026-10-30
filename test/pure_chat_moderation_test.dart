// ignore_for_file: avoid_print
import 'dart:io';
import 'package:gawezeny/features/chat/domain/chat_moderation_service.dart';

void main() {
  print('--- Testing Chat Moderation Rules ---');

  int passed = 0;
  int failed = 0;

  void testCase(String description, String input, bool expectedAllowed) {
    final result = ChatModerationService.check(input);
    if (result.isAllowed == expectedAllowed) {
      passed++;
      print('✓ PASS: $description');
    } else {
      failed++;
      print('✗ FAIL: $description');
      print('   Input: "$input"');
      print('   Expected allowed: $expectedAllowed, got: ${result.isAllowed} (Reason: ${result.message})');
    }
  }

  // 1. Phone numbers
  testCase('Standard Egyptian 010', 'رقمي 01012345678 كلمني', false);
  testCase('Standard Egyptian +20', '+201123456789', false);
  testCase('Standard Egyptian 0020', '00201223456789', false);
  testCase('Standard Egyptian 015', '01512345678', false);
  testCase('Spaced digits 0 1 0', '0 1 0 1 2 3 4 5 6 7 8', false);
  testCase('Dashes in phone', '010-1234-5678', false);
  testCase('Parentheses in phone', '(010) 99887766', false);
  testCase('Eastern Arabic digits', 'رقمي ٠١٠١٢٣٤٥٦٧٨', false);
  testCase('International US +1', '+1 555 123 4567', false);
  testCase('Spelled out Egyptian numbers', 'زيرو عشره اتنين تلاته اربعه', false);
  testCase('Spelled digits phrase', 'رقمي هو زيرو واحد اتنين', false);

  // 2. Links & URLs
  testCase('Explicit HTTPS URL', 'ادخل هنا https://example.com/profile', false);
  testCase('Explicit HTTP URL', 'http://mywebsite.org', false);
  testCase('WWW domain', 'شوف موقعي www.facebook.com', false);
  testCase('Telegram shortener', 't.me/mychannel', false);
  testCase('WhatsApp shortener', 'wa.me/201012345678', false);
  testCase('Bitly shortener', 'bit.ly/3xYzAbc', false);
  testCase('Direct domain facebook.com', 'زورني على facebook.com', false);
  testCase('Obfuscated domain dot com', 'حسابي على facebook . com', false);
  testCase('Arabic spelled domain', 'فيس بوك دوت كوم', false);

  // 3. Social Media Exchange Intent (From User Prompt)
  testCase('Prompt example: ابعتلي أكاونت الفيسبوك', 'ابعتلي أكاونت الفيسبوك', false);
  testCase('Prompt example: ابعتلي الأكاونت بتاعك', 'ابعتلي الأكاونت بتاعك', false);
  testCase('Prompt example: ابعتلي حسابك', 'ابعتلي حسابك', false);
  testCase('Prompt example: ابعتلي الإنستجرام', 'ابعتلي الإنستجرام', false);
  testCase('Prompt example: ابعتلي الواتساب', 'ابعتلي الواتساب', false);
  testCase('Prompt example: ابعتلي حسابك على أي منصة', 'ابعتلي حسابك على أي منصة تواصل', false);
  testCase('Social handle @', 'ضيفني عندك @ahmed_ali_99', false);
  testCase('Outside chat request: نتكلم واتس', 'نتكلم واتس احسن', false);
  testCase('Outside chat request: نكمل كلام على الواتس', 'نكمل كلام على الواتس', false);
  testCase('Outside chat request: عايز رقمك', 'عايز رقمك لو سمحت', false);

  // 4. Legitimate Messages (NO False Positives!)
  testCase('Salam greeting', 'السلام عليكم ورحمة الله وبركاته', true);
  testCase('Polite introduction', 'أهلاً وسهلاً بك، تشرفت بمعرفتك.', true);
  testCase('Age and career', 'أنا مهندس برمجيات عمري 29 سنة وأسكن في القاهرة وأبحث عن شريكة حياة صالحة.', true);
  testCase('Height and weight', 'طولي 178 سم ووزني 75 كجم والحمد لله.', true);
  testCase('Hobbies question', 'ما هي هواياتك المفضلة وتطلعاتك للمستقبل؟', true);
  testCase('Time sentence', 'الساعة الآن 5 مساءً، هل يناسبك الحديث لاحقاً؟', true);
  testCase('Graduation year', 'تخرجت عام 2018 من كلية الهندسة.', true);

  print('\nSummary: $passed passed, $failed failed.');
  if (failed > 0) {
    exit(1);
  }
}
