# 📌 الدليل الشامل لإعداد وإصلاح تأكيد البريد الإلكتروني (Email Verification Flow)
**منصة: جوزيني يا ماما**

---

## 1. سبب المشكلة الأساسية (`localhost:3000` و `ERR_CONNECTION_REFUSED`)
1. **Site URL الافتراضي في Supabase:** عند إنشاء أي مشروع جديد على Supabase، يتم تعيين `Site URL` تلقائيًا إلى `http://localhost:3000`.
2. **غياب تحديد `emailRedirectTo` في الكود:** عند استدعاء `_client.auth.signUp()` دون تمرير عنوان إعادة توجيه صريح، يلجأ Supabase تلقائيًا لاستخدام قيمة `Site URL`.
3. **متغير `{{ .ConfirmationURL }}`:** يقوم Supabase بإنشاء رابط التفعيل بحيث يُعيد توجيه المستخدم إلى:  
   `http://localhost:3000/#access_token=...&refresh_token=...`
4. **النتيجة على الموبايل:** عند فتح الإيميل على الهاتف والضغط على الزر، يحاول متصفح الهاتف فتح المنفذ 3000 على الهاتف نفسه (حيث لا يوجد سيرفر)، فيظهر خطأ `ERR_CONNECTION_REFUSED`.
5. **سبب اسم المرسل "Supabase Auth":** يستخدم Supabase خادم بريد تجريبي افتراضي (`noreply@mail.app.supabase.io`) مع حصة مقيدة (3 إلى 30 رسالة في الساعة)، ولا يسمح بتغيير اسم المرسل إلا بعد تفعيل **Custom SMTP**.

---

## 2. الإعدادات المطلوبة في لوحة تحكم Supabase Dashboard

ادخل إلى لوحة تحكم مشروعك:
[https://supabase.com/dashboard/project/npcqnrucmwzompwmvztw](https://supabase.com/dashboard/project/npcqnrucmwzompwmvztw)

### أ) ضبط Site URL و Redirect URLs
1. انتقل إلى: **Authentication** -> **URL Configuration**.
2. في حقل **Site URL**:
   - ضع الدومين الحقيقي لصفحة التأكيد (أو دومين موقعك الرسمي):
     ```text
     https://npcqnrucmwzompwmvztw.supabase.co/storage/v1/object/public/static/verify.html
     ```
     *(أو دومينك الخاص إذا قمت بربطه مثل `https://gawezeny.com/verify.html`)*
3. في قائمة **Redirect URLs** (أضف الروابط التالية واضغط Add URL):
   - `https://npcqnrucmwzompwmvztw.supabase.co/**`
   - `https://gawezeny.com/**`
   - `https://gawezeny.web.app/**`
   - `gawezeny://**` (لدعم فتح التطبيق مباشرة على الموبايل)
   - `gawezeny://auth/confirm`
   - `gawezeny://login`
4. اضغط **Save Changes**.

---

### ب) تخصيص قالب البريد الإلكتروني (Email Template)
1. انتقل إلى: **Authentication** -> **Email Templates**.
2. اختر قالب: **Confirm signup**.
3. في حقل **Subject** (عنوان الرسالة):
   ```text
   تأكيد بريدك الإلكتروني — جوزيني يا ماما
   ```
4. في حقل **Body (Message Content)**:
   - احذف المحتوى الإنجليزي الافتراضي.
   - انسخ محتوى الملف المجهز لك في المشروع:
     [`supabase/email_templates/confirm_signup.html`](file:///c:/Users/DELL/Desktop/gawezeny/supabase/email_templates/confirm_signup.html)
   - الصق الكود واضغط **Save**.

---

### ج) تغيير اسم المرسل والبريد (Custom SMTP Provider)
لإزالة اسم **Supabase Auth** نهائياً وإرسال الإيميلات باسم **جوزيني يا ماما**:
1. انتقل إلى: **Project Settings** -> **Authentication** -> **SMTP Settings**.
2. فعّل خيار **Enable Custom SMTP**.
3. أدخل بيانات مزود البريد المعتمد لديك (أشهر وأسهل المزودين):
   - **Resend** (مجاني حتى 3,000 إيميل/شهر - يُنصح به لسرعته وسهولة إعداده):
     - Host: `smtp.resend.com`
     - Port: `465` أو `587`
     - User: `resend`
     - Password: `re_xxxxxxxx` (API Key من حسابك في Resend)
     - Sender Email: `noreply@yourdomain.com` أو `support@yourdomain.com`
     - Sender Name: `جوزيني يا ماما`
   - أو **SendGrid** / **Brevo** / **Google Workspace**.
4. اضغط **Save Changes**.
*(ملاحظة: يتطلب الدومين المخصص إثبات ملكية عبر إضافة سجلات DNS مثل SPF و DKIM لدى مسجل النطاق الخاص بك لضمان وصول الرسائل للـ Inbox وعدم الذهاب للـ Spam).*

---

## 3. التعديلات المنفذة في كود تطبيق Flutter

1. **تمرير `emailRedirectTo` الصريح:**
   - تم تحديث [`AuthRepository`](file:///c:/Users/DELL/Desktop/gawezeny/lib/features/auth/data/auth_repository.dart) بحيث يمرر دائماً `emailRedirectTo: SupabaseConstants.authRedirectUrl` في عمليتي `signUpWithEmail` و `resendVerificationEmail` لمنع Supabase من استخدام `localhost:3000` إطلاقاً.
2. **دعم الـ Deep Linking في أنظمة التشغيل:**
   - **أندرويد:** تم تحديث [`AndroidManifest.xml`](file:///c:/Users/DELL/Desktop/gawezeny/android/app/src/main/AndroidManifest.xml) بإضافة `intent-filter` للـ scheme الرسمي `gawezeny://auth/confirm` و `gawezeny://login`.
   - **آبل iOS:** تم تحديث [`Info.plist`](file:///c:/Users/DELL/Desktop/gawezeny/ios/Runner/Info.plist) بإضافة `CFBundleURLTypes` للـ scheme `gawezeny`.
3. **صفحة الويب الاحترافية للتأكيد:**
   - تم بناء صفحة متكاملة ومتجاوبة في [`web/verify.html`](file:///c:/Users/DELL/Desktop/gawezeny/web/verify.html) و [`admin_dashboard/verify.html`](file:///c:/Users/DELL/Desktop/gawezeny/admin_dashboard/verify.html) تعالج الحالات الثلاث:
     - **الحالة الأولى (نجاح التأكيد):** أيقونة خضراء، ورسالة النجاح، وزر الانتقال للتطبيق وتسجيل الدخول.
     - **الحالة الثانية (رابط منتهي أو غير صالح):** رسالة اعتذار عربية واضحة، مع حقل وزر لإعادة إرسال رسالة التأكيد ومؤقت 60 ثانية.
     - **الحالة الثالثة (انقطاع الاتصال):** توضيح المشكلة وزر لإعادة المحاولة.
