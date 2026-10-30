import 'package:flutter_test/flutter_test.dart';
import 'package:gawezeny/features/chat/domain/chat_moderation_service.dart';

void main() {
  group('Chat Moderation - Phone Number Detection', () {
    test('blocks Egyptian numbers with standard formatting', () {
      expect(ChatModerationService.check('رقمي 01012345678').isAllowed, isFalse);
      expect(ChatModerationService.check('+201123456789').isAllowed, isFalse);
      expect(ChatModerationService.check('00201223456789').isAllowed, isFalse);
      expect(ChatModerationService.check('01512345678').isAllowed, isFalse);
    });

    test('blocks numbers with spaces and dashes (obfuscated)', () {
      expect(ChatModerationService.check('0 1 0 1 2 3 4 5 6 7 8').isAllowed, isFalse);
      expect(ChatModerationService.check('010-1234-5678').isAllowed, isFalse);
      expect(ChatModerationService.check('(010) 99887766').isAllowed, isFalse);
      expect(ChatModerationService.check('+20 10 9988 7766').isAllowed, isFalse);
    });

    test('blocks numbers with Eastern Arabic digits', () {
      expect(ChatModerationService.check('رقمي ٠١٠١٢٣٤٥٦٧٨ كلمني').isAllowed, isFalse);
      expect(ChatModerationService.check('+٢٠١١٩٩٨٨٧٧٦٦').isAllowed, isFalse);
    });

    test('blocks international numbers (e.g. US, Gulf)', () {
      expect(ChatModerationService.check('+1 555 123 4567').isAllowed, isFalse);
      expect(ChatModerationService.check('+966 50 123 4567').isAllowed, isFalse);
    });

    test('blocks numbers spelled out in Arabic words', () {
      expect(ChatModerationService.check('زيرو عشره اتنين تلاته اربعه').isAllowed, isFalse);
      expect(ChatModerationService.check('صفر واحد صفر تسعه تمانيه').isAllowed, isFalse);
      expect(ChatModerationService.check('رقمي هو زيرو واحد اتنين').isAllowed, isFalse);
    });
  });

  group('Chat Moderation - Links and URLs Detection', () {
    test('blocks explicit protocol URLs', () {
      expect(ChatModerationService.check('ادخل هنا https://example.com/profile').isAllowed, isFalse);
      expect(ChatModerationService.check('http://mywebsite.org').isAllowed, isFalse);
    });

    test('blocks www and shorteners', () {
      expect(ChatModerationService.check('شوف موقعي www.facebook.com').isAllowed, isFalse);
      expect(ChatModerationService.check('t.me/mychannel').isAllowed, isFalse);
      expect(ChatModerationService.check('wa.me/201012345678').isAllowed, isFalse);
      expect(ChatModerationService.check('bit.ly/3xYzAbc').isAllowed, isFalse);
    });

    test('blocks domains without protocol and obfuscated domains', () {
      expect(ChatModerationService.check('زورني على facebook.com').isAllowed, isFalse);
      expect(ChatModerationService.check('حسابي على facebook . com').isAllowed, isFalse);
      expect(ChatModerationService.check('فيس بوك دوت كوم').isAllowed, isFalse);
    });
  });

  group('Chat Moderation - Social Media Intent and Handles', () {
    test('blocks user examples from prompt', () {
      expect(ChatModerationService.check('ابعتلي أكاونت الفيسبوك').isAllowed, isFalse);
      expect(ChatModerationService.check('ابعتلي الأكاونت بتاعك').isAllowed, isFalse);
      expect(ChatModerationService.check('ابعتلي حسابك').isAllowed, isFalse);
      expect(ChatModerationService.check('ابعتلي الإنستجرام').isAllowed, isFalse);
      expect(ChatModerationService.check('ابعتلي الواتساب').isAllowed, isFalse);
      expect(ChatModerationService.check('ابعتلي حسابك على أي منصة تواصل').isAllowed, isFalse);
    });

    test('blocks social handles and chat outside intents', () {
      expect(ChatModerationService.check('ضيفني @ahmed_ali_99').isAllowed, isFalse);
      expect(ChatModerationService.check('هات اكاونتك نكلم بعض').isAllowed, isFalse);
      expect(ChatModerationService.check('نتكلم واتس احسن').isAllowed, isFalse);
      expect(ChatModerationService.check('نكمل كلام على الواتس').isAllowed, isFalse);
      expect(ChatModerationService.check('عايز رقمك لو سمحت').isAllowed, isFalse);
    });
  });

  group('Chat Moderation - Legitimate Normal Messages (No False Positives)', () {
    test('allows normal polite marriage conversations', () {
      expect(ChatModerationService.check('السلام عليكم ورحمة الله وبركاته').isAllowed, isTrue);
      expect(ChatModerationService.check('أهلاً وسهلاً بك، تشرفت بمعرفتك.').isAllowed, isTrue);
      expect(
        ChatModerationService.check('أنا مهندس برمجيات عمري 29 سنة وأسكن في القاهرة وأبحث عن شريكة حياة صالحة.')
            .isAllowed,
        isTrue,
      );
      expect(ChatModerationService.check('طولي 178 سم ووزني 75 كجم والحمد لله.').isAllowed, isTrue);
      expect(ChatModerationService.check('ما هي هواياتك المفضلة وتطلعاتك للمستقبل؟').isAllowed, isTrue);
      expect(ChatModerationService.check('الساعة الآن 5 مساءً، هل يناسبك الحديث لاحقاً؟').isAllowed, isTrue);
      expect(ChatModerationService.check('تخرجت عام 2018 من كلية الهندسة.').isAllowed, isTrue);
    });
  });
}
