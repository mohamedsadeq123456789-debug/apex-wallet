-- =====================================================================
--  الجلسة 1 · تعديل: محفظة بلا اسم تجاري وبلا ربط بشخص
--  1) جدول إعدادات: اسم التطبيق يُقرأ من هنا، يتغيّر بسطر واحد
--  2) الاسم الشخصي اختياري: المحفظة تُعرَف برقم الهاتف ورقمها فقط
--  3) البيانات التجريبية تحمل تسميات عامة لا تخص أي شخص
-- =====================================================================

CREATE TABLE wlt_app_settings (
  setting_key    VARCHAR2(40)   CONSTRAINT pk_wlt_settings PRIMARY KEY,
  setting_value  VARCHAR2(400)  NOT NULL,
  description_ar VARCHAR2(200)
);

INSERT INTO wlt_app_settings VALUES ('APP_NAME',    'محفظتي',                 'اسم التطبيق الظاهر في كل الصفحات');
INSERT INTO wlt_app_settings VALUES ('APP_TAGLINE', 'ادفع وحوّل في ثوانٍ',     'العبارة تحت الاسم في صفحة الدخول');
INSERT INTO wlt_app_settings VALUES ('BASE_CURRENCY','JOD',                    'العملة الافتراضية للمحافظ الجديدة');

-- الاسم الشخصي لم يعد إلزامياً
ALTER TABLE wlt_users MODIFY (full_name NULL);

-- اسم عرض اختياري يختاره المستخدم بنفسه (لقب، اسم متجر...)
ALTER TABLE wlt_users ADD (display_name VARCHAR2(60));

-- تسميات تجريبية عامة بدل الأسماء
UPDATE wlt_users SET full_name = NULL, display_name = 'عميل تجريبي 1' WHERE phone = '0791234567';
UPDATE wlt_users SET full_name = NULL, display_name = 'عميل تجريبي 2' WHERE phone = '0782345678';
UPDATE wlt_users SET full_name = NULL, display_name = 'عميل تجريبي 3' WHERE phone = '0773456789';
UPDATE wlt_users SET full_name = NULL, display_name = 'عميل تجريبي 4' WHERE phone = '0794567890';
UPDATE wlt_users SET full_name = NULL, display_name = 'عميل تجريبي 5' WHERE phone = '0785678901';
UPDATE wlt_users SET full_name = NULL, display_name = 'تاجر تجريبي · مقهى'   WHERE phone = '0796789012';
UPDATE wlt_users SET full_name = NULL, display_name = 'تاجر تجريبي · صيدلية' WHERE phone = '0777890123';
UPDATE wlt_users SET full_name = NULL, display_name = 'وكيل تجريبي'          WHERE phone = '0798901234';
UPDATE wlt_users SET full_name = NULL, display_name = 'مدير النظام'           WHERE phone = '0790000001';
UPDATE wlt_users SET full_name = NULL, display_name = 'النظام'                WHERE user_type = 'SYSTEM';
COMMIT;

-- العرض في الصفحات: اسم العرض إن وُجد، وإلا رقم الهاتف مخفياً جزئياً 079•••4567
CREATE OR REPLACE VIEW wlt_v_wallets AS
SELECT w.wallet_id, w.wallet_type, w.label, w.currency_code, w.balance, w.held_amount,
       w.balance - w.held_amount AS available_balance,
       w.status AS wallet_status,
       u.user_id,
       COALESCE(u.display_name,
                SUBSTR(u.phone, 1, 3) || '•••' || SUBSTR(u.phone, -4)) AS shown_name,
       u.phone, u.user_type, u.kyc_tier
  FROM wlt_wallets w
  JOIN wlt_users   u ON u.user_id = w.user_id;
