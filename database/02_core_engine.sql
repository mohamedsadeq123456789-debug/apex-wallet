-- =====================================================================
--  محفظتي · الجلسة 2 · محرك التحويل WALLET_CORE_PKG
--  كل عملية مالية تمر من هنا فقط. الصفحات لاحقاً تستدعي هذه الحزمة.
-- =====================================================================

-- محافظ النظام تُقرأ من الإعدادات بدل تثبيت أرقامها في الكود
INSERT INTO wlt_app_settings (setting_key, setting_value, description_ar)
SELECT 'FUNDING_WALLET_ID', TO_CHAR(wallet_id), 'محفظة التمويل الخارجي'
  FROM wlt_wallets WHERE wallet_type = 'SYSTEM' AND allow_negative = 'Y';

INSERT INTO wlt_app_settings (setting_key, setting_value, description_ar)
SELECT 'FEES_WALLET_ID', TO_CHAR(wallet_id), 'محفظة إيرادات الرسوم'
  FROM wlt_wallets WHERE wallet_type = 'SYSTEM' AND allow_negative = 'N';

COMMIT;

-- فهرس يسرّع حساب الحدود اليومية والشهرية
CREATE INDEX ix_wlt_txn_limits ON wlt_transactions (from_wallet_id, status, created_at, txn_type, amount);
DROP INDEX ix_wlt_txn_from;


CREATE OR REPLACE PACKAGE wallet_core_pkg AS
  -- رموز الأخطاء: كل خطأ له رقم ثابت ورسالة عربية
  c_err_insufficient  CONSTANT PLS_INTEGER := -20101;  -- الرصيد غير كافٍ
  c_err_single_limit  CONSTANT PLS_INTEGER := -20102;  -- تجاوز حد العملية الواحدة
  c_err_daily_limit   CONSTANT PLS_INTEGER := -20103;  -- تجاوز الحد اليومي
  c_err_month_limit   CONSTANT PLS_INTEGER := -20104;  -- تجاوز الحد الشهري
  c_err_max_balance   CONSTANT PLS_INTEGER := -20105;  -- المستلم تجاوز أقصى رصيد
  c_err_inactive      CONSTANT PLS_INTEGER := -20106;  -- محفظة أو مستخدم غير فعّال
  c_err_bad_amount    CONSTANT PLS_INTEGER := -20107;  -- مبلغ غير صالح
  c_err_same_wallet   CONSTANT PLS_INTEGER := -20108;  -- تحويل لنفس المحفظة
  c_err_currency      CONSTANT PLS_INTEGER := -20109;  -- عملتان مختلفتان
  c_err_not_found     CONSTANT PLS_INTEGER := -20110;  -- غير موجود
  c_err_reverse       CONSTANT PLS_INTEGER := -20111;  -- لا يمكن عكس العملية

  -- الرسوم: تُحسب من جدول أنواع العمليات وتُحفظ في الذاكرة المؤقتة
  FUNCTION calc_fee (p_txn_type VARCHAR2, p_amount NUMBER) RETURN NUMBER RESULT_CACHE;

  -- المحفظة الرئيسية لرقم هاتف
  FUNCTION main_wallet (p_phone VARCHAR2, p_currency VARCHAR2 DEFAULT 'JOD') RETURN NUMBER;

  -- قلب المحرك: يرجع الرقم المرجعي للعملية
  FUNCTION transfer (
    p_from_wallet  NUMBER,
    p_to_wallet    NUMBER,
    p_amount       NUMBER,
    p_txn_type     VARCHAR2 DEFAULT 'TRANSFER',
    p_idem_key     VARCHAR2 DEFAULT NULL,
    p_description  VARCHAR2 DEFAULT NULL,
    p_actor_user   NUMBER   DEFAULT NULL,
    p_commit       BOOLEAN  DEFAULT TRUE
  ) RETURN VARCHAR2;

  -- نفس التحويل لكن بأرقام الهواتف (هكذا ستستخدمه الصفحات)
  FUNCTION transfer_by_phone (
    p_from_phone   VARCHAR2,
    p_to_phone     VARCHAR2,
    p_amount       NUMBER,
    p_idem_key     VARCHAR2 DEFAULT NULL,
    p_description  VARCHAR2 DEFAULT NULL
  ) RETURN VARCHAR2;

  -- شحن رصيد من محفظة التمويل
  FUNCTION topup (p_to_wallet NUMBER, p_amount NUMBER, p_idem_key VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;

  -- عكس عملية مكتملة: يرجع المبلغ والرسوم للمرسل بعملية جديدة
  FUNCTION reverse (p_txn_ref VARCHAR2, p_reason VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;
END wallet_core_pkg;
/


CREATE OR REPLACE PACKAGE BODY wallet_core_pkg AS

  -- ---------------------------------------------------------------
  -- أدوات داخلية
  -- ---------------------------------------------------------------

  FUNCTION setting_num (p_key VARCHAR2) RETURN NUMBER RESULT_CACHE IS
    l_val wlt_app_settings.setting_value%TYPE;
  BEGIN
    SELECT setting_value INTO l_val FROM wlt_app_settings WHERE setting_key = p_key;
    RETURN TO_NUMBER(l_val);
  END setting_num;

  PROCEDURE fail (p_code PLS_INTEGER, p_msg VARCHAR2) IS
  BEGIN
    RAISE_APPLICATION_ERROR(p_code, p_msg);
  END fail;

  -- يكتب الفشل في سجل التدقيق حتى لو تراجعت العملية نفسها
  PROCEDURE log_failure (p_action VARCHAR2, p_details VARCHAR2, p_actor NUMBER) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO wlt_audit_log (actor_user_id, action, entity, details)
    VALUES (p_actor, p_action, 'TRANSACTION', SUBSTR(p_details, 1, 4000));
    COMMIT;
  END log_failure;

  FUNCTION next_ref RETURN VARCHAR2 IS
  BEGIN
    RETURN 'TX' || TO_CHAR(SYSDATE, 'YYMMDD') || LPAD(wlt_txn_ref_seq.NEXTVAL, 8, '0');
  END next_ref;

  -- يقفل المحافظ دائماً من الرقم الأصغر للأكبر.
  -- عمليتان متعاكستان في نفس اللحظة (أ→ب و ب→أ) تنتظر إحداهما الأخرى
  -- بدل أن تقفل كل واحدة محفظة وتنتظر الثانية للأبد (deadlock)
  PROCEDURE lock_wallets (p_ids sys.odcinumberlist) IS
    l_dummy NUMBER;
  BEGIN
    FOR r IN (SELECT DISTINCT COLUMN_VALUE AS id FROM TABLE(p_ids)
               WHERE COLUMN_VALUE IS NOT NULL ORDER BY 1) LOOP
      BEGIN
        SELECT wallet_id INTO l_dummy FROM wlt_wallets WHERE wallet_id = r.id FOR UPDATE;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN fail(c_err_not_found, 'المحفظة رقم ' || r.id || ' غير موجودة');
      END;
    END LOOP;
  END lock_wallets;

  -- قيد واحد في الدفتر + تحديث الرصيد، في خطوة واحدة
  PROCEDURE post (p_txn_id NUMBER, p_wallet_id NUMBER, p_type CHAR, p_amount NUMBER) IS
    l_bal NUMBER;
  BEGIN
    IF p_amount = 0 THEN RETURN; END IF;
    UPDATE wlt_wallets
       SET balance = balance + CASE p_type WHEN 'C' THEN p_amount ELSE -p_amount END
     WHERE wallet_id = p_wallet_id
    RETURNING balance INTO l_bal;

    INSERT INTO wlt_ledger_entries (txn_id, wallet_id, entry_type, amount, balance_after)
    VALUES (p_txn_id, p_wallet_id, p_type, p_amount, l_bal);
  END post;

  FUNCTION existing_ref (p_idem_key VARCHAR2) RETURN VARCHAR2 IS
    l_ref wlt_transactions.txn_ref%TYPE;
  BEGIN
    IF p_idem_key IS NULL THEN RETURN NULL; END IF;
    SELECT txn_ref INTO l_ref FROM wlt_transactions WHERE idempotency_key = p_idem_key;
    RETURN l_ref;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
  END existing_ref;

  -- ---------------------------------------------------------------
  -- الواجهة العامة
  -- ---------------------------------------------------------------

  FUNCTION calc_fee (p_txn_type VARCHAR2, p_amount NUMBER) RETURN NUMBER RESULT_CACHE IS
    l_t   wlt_txn_types%ROWTYPE;
    l_fee NUMBER;
  BEGIN
    SELECT * INTO l_t FROM wlt_txn_types WHERE txn_type = p_txn_type;
    l_fee := ROUND(p_amount * l_t.fee_pct / 100 + l_t.fee_fixed, 3);
    IF l_fee > 0 OR l_t.fee_pct > 0 THEN
      l_fee := GREATEST(l_fee, l_t.fee_min);
    END IF;
    IF l_t.fee_max IS NOT NULL THEN
      l_fee := LEAST(l_fee, l_t.fee_max);
    END IF;
    RETURN l_fee;
  END calc_fee;

  FUNCTION main_wallet (p_phone VARCHAR2, p_currency VARCHAR2 DEFAULT 'JOD') RETURN NUMBER IS
    l_id NUMBER;
  BEGIN
    SELECT w.wallet_id INTO l_id
      FROM wlt_users u JOIN wlt_wallets w ON w.user_id = u.user_id
     WHERE u.phone = p_phone AND w.wallet_type = 'MAIN' AND w.currency_code = p_currency;
    RETURN l_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      fail(c_err_not_found, 'لا توجد محفظة للرقم ' || p_phone);
      RETURN NULL;
  END main_wallet;


  FUNCTION transfer (
    p_from_wallet  NUMBER,
    p_to_wallet    NUMBER,
    p_amount       NUMBER,
    p_txn_type     VARCHAR2 DEFAULT 'TRANSFER',
    p_idem_key     VARCHAR2 DEFAULT NULL,
    p_description  VARCHAR2 DEFAULT NULL,
    p_actor_user   NUMBER   DEFAULT NULL,
    p_commit       BOOLEAN  DEFAULT TRUE
  ) RETURN VARCHAR2 IS
    l_ref      wlt_transactions.txn_ref%TYPE;
    l_txn_id   NUMBER;
    l_fee      NUMBER;
    l_fees_w   NUMBER := setting_num('FEES_WALLET_ID');
    l_counts   wlt_txn_types.counts_to_limit%TYPE;
    l_from     wlt_v_wallets%ROWTYPE;
    l_to       wlt_v_wallets%ROWTYPE;
    l_from_st  wlt_users.status%TYPE;
    l_to_st    wlt_users.status%TYPE;
    l_tier     wlt_kyc_tiers%ROWTYPE;
    l_to_max   NUMBER;
    l_today    NUMBER;
    l_month    NUMBER;
  BEGIN
    -- 1) نفس الطلب وصل من قبل؟ نرجع نفس الإيصال بدون أي خصم جديد
    l_ref := existing_ref(p_idem_key);
    IF l_ref IS NOT NULL THEN RETURN l_ref; END IF;

    SAVEPOINT sp_transfer;

    -- 2) فحوصات سريعة لا تحتاج قفل
    IF p_amount IS NULL OR p_amount <= 0 OR p_amount <> ROUND(p_amount, 3) THEN
      fail(c_err_bad_amount, 'المبلغ يجب أن يكون أكبر من صفر وبثلاث خانات عشرية كحد أقصى');
    END IF;
    IF p_from_wallet = p_to_wallet THEN
      fail(c_err_same_wallet, 'لا يمكن التحويل لنفس المحفظة');
    END IF;

    BEGIN
      SELECT counts_to_limit INTO l_counts FROM wlt_txn_types
       WHERE txn_type = p_txn_type AND is_active = 'Y';
    EXCEPTION WHEN NO_DATA_FOUND THEN
      fail(c_err_not_found, 'نوع العملية ' || p_txn_type || ' غير معروف');
    END;
    l_fee := calc_fee(p_txn_type, p_amount);

    -- 3) القفل بترتيب ثابت. من هنا لا أحد غيرنا يلمس هذه الأرصدة
    lock_wallets(sys.odcinumberlist(p_from_wallet, p_to_wallet, CASE WHEN l_fee > 0 THEN l_fees_w END));

    -- 4) القراءة بعد القفل: الأرقام هنا نهائية ولا تتغير تحت أيدينا
    SELECT * INTO l_from FROM wlt_v_wallets WHERE wallet_id = p_from_wallet;
    SELECT * INTO l_to   FROM wlt_v_wallets WHERE wallet_id = p_to_wallet;
    SELECT status INTO l_from_st FROM wlt_users WHERE user_id = l_from.user_id;
    SELECT status INTO l_to_st   FROM wlt_users WHERE user_id = l_to.user_id;

    IF l_from.wallet_status <> 'ACTIVE' OR l_from_st <> 'ACTIVE' THEN
      fail(c_err_inactive, 'محفظة المرسل غير فعّالة');
    END IF;
    IF l_to.wallet_status <> 'ACTIVE' OR l_to_st <> 'ACTIVE' THEN
      fail(c_err_inactive, 'محفظة المستلم غير فعّالة');
    END IF;
    IF l_from.currency_code <> l_to.currency_code THEN
      fail(c_err_currency, 'عملة المحفظتين مختلفة');
    END IF;

    -- 5) الرصيد: المتاح = الرصيد − المحجوز (محفظة التمويل مستثناة)
    IF l_from.user_type <> 'SYSTEM' AND l_from.available_balance < p_amount + l_fee THEN
      fail(c_err_insufficient,
           'الرصيد غير كافٍ. المتاح ' || TO_CHAR(l_from.available_balance, 'FM999G990D000')
           || ' والمطلوب ' || TO_CHAR(p_amount + l_fee, 'FM999G990D000'));
    END IF;

    -- 6) حدود مستوى التوثيق للمرسل
    IF l_counts = 'Y' AND l_from.user_type <> 'SYSTEM' THEN
      SELECT * INTO l_tier FROM wlt_kyc_tiers WHERE tier_code = l_from.kyc_tier;

      IF p_amount > l_tier.single_txn_limit THEN
        fail(c_err_single_limit, 'الحد الأقصى للعملية الواحدة ' || l_tier.single_txn_limit);
      END IF;

      SELECT NVL(SUM(CASE WHEN x.created_at >= TRUNC(SYSDATE) THEN x.amount END), 0),
             NVL(SUM(x.amount), 0)
        INTO l_today, l_month
        FROM wlt_transactions x
        JOIN wlt_txn_types   t ON t.txn_type = x.txn_type
       WHERE x.from_wallet_id = p_from_wallet
         AND x.status = 'COMPLETED'
         AND t.counts_to_limit = 'Y'
         AND x.created_at >= TRUNC(SYSDATE, 'MM');

      IF l_today + p_amount > l_tier.daily_limit THEN
        fail(c_err_daily_limit, 'تجاوز الحد اليومي ' || l_tier.daily_limit
             || '. المستخدم اليوم ' || l_today);
      END IF;
      IF l_month + p_amount > l_tier.monthly_limit THEN
        fail(c_err_month_limit, 'تجاوز الحد الشهري ' || l_tier.monthly_limit);
      END IF;
    END IF;

    -- 7) أقصى رصيد للمستلم (للعملاء فقط)
    IF l_to.user_type = 'CUSTOMER' THEN
      SELECT max_balance INTO l_to_max FROM wlt_kyc_tiers WHERE tier_code = l_to.kyc_tier;
      IF l_to.balance + p_amount > l_to_max THEN
        fail(c_err_max_balance, 'المستلم سيتجاوز أقصى رصيد مسموح لمستواه ' || l_to_max);
      END IF;
    END IF;

    -- 8) الكتابة: رأس العملية ثم القيود
    l_ref := next_ref;
    INSERT INTO wlt_transactions
      (txn_ref, idempotency_key, txn_type, from_wallet_id, to_wallet_id,
       amount, fee, currency_code, status, description, created_by)
    VALUES
      (l_ref, p_idem_key, p_txn_type, p_from_wallet, p_to_wallet,
       p_amount, l_fee, l_from.currency_code, 'PENDING', p_description,
       NVL(p_actor_user, l_from.user_id))
    RETURNING txn_id INTO l_txn_id;

    post(l_txn_id, p_from_wallet, 'D', p_amount);
    post(l_txn_id, p_to_wallet,   'C', p_amount);
    IF l_fee > 0 THEN
      post(l_txn_id, p_from_wallet, 'D', l_fee);
      post(l_txn_id, l_fees_w,      'C', l_fee);
    END IF;

    UPDATE wlt_transactions
       SET status = 'COMPLETED', completed_at = SYSTIMESTAMP
     WHERE txn_id = l_txn_id;

    IF p_commit THEN COMMIT; END IF;
    RETURN l_ref;

  EXCEPTION
    -- طلبان بنفس المفتاح في نفس اللحظة: الثاني يصطدم بالفهرس الفريد
    WHEN DUP_VAL_ON_INDEX THEN
      ROLLBACK TO sp_transfer;
      l_ref := existing_ref(p_idem_key);
      IF l_ref IS NOT NULL THEN RETURN l_ref; END IF;
      RAISE;
    WHEN OTHERS THEN
      ROLLBACK TO sp_transfer;
      log_failure('TRANSFER_FAILED',
                  p_txn_type || ' ' || p_from_wallet || '->' || p_to_wallet
                  || ' amount=' || p_amount || ' : ' || SQLERRM,
                  p_actor_user);
      RAISE;
  END transfer;


  FUNCTION transfer_by_phone (
    p_from_phone   VARCHAR2,
    p_to_phone     VARCHAR2,
    p_amount       NUMBER,
    p_idem_key     VARCHAR2 DEFAULT NULL,
    p_description  VARCHAR2 DEFAULT NULL
  ) RETURN VARCHAR2 IS
  BEGIN
    RETURN transfer(
      p_from_wallet => main_wallet(p_from_phone),
      p_to_wallet   => main_wallet(p_to_phone),
      p_amount      => p_amount,
      p_idem_key    => p_idem_key,
      p_description => p_description);
  END transfer_by_phone;


  FUNCTION topup (p_to_wallet NUMBER, p_amount NUMBER, p_idem_key VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
  BEGIN
    RETURN transfer(
      p_from_wallet => setting_num('FUNDING_WALLET_ID'),
      p_to_wallet   => p_to_wallet,
      p_amount      => p_amount,
      p_txn_type    => 'TOPUP',
      p_idem_key    => p_idem_key,
      p_description => 'شحن رصيد');
  END topup;


  FUNCTION reverse (p_txn_ref VARCHAR2, p_reason VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
    l_orig    wlt_transactions%ROWTYPE;
    l_ref     wlt_transactions.txn_ref%TYPE;
    l_txn_id  NUMBER;
    l_fees_w  NUMBER := setting_num('FEES_WALLET_ID');
  BEGIN
    SAVEPOINT sp_reverse;

    BEGIN
      SELECT * INTO l_orig FROM wlt_transactions WHERE txn_ref = p_txn_ref FOR UPDATE;
    EXCEPTION WHEN NO_DATA_FOUND THEN
      fail(c_err_not_found, 'العملية ' || p_txn_ref || ' غير موجودة');
    END;

    IF l_orig.status <> 'COMPLETED' OR l_orig.txn_type = 'REVERSAL' THEN
      fail(c_err_reverse, 'لا يمكن عكس العملية ' || p_txn_ref || ' لأن حالتها ' || l_orig.status);
    END IF;

    lock_wallets(sys.odcinumberlist(l_orig.from_wallet_id, l_orig.to_wallet_id,
                       CASE WHEN l_orig.fee > 0 THEN l_fees_w END));

    l_ref := next_ref;
    INSERT INTO wlt_transactions
      (txn_ref, txn_type, from_wallet_id, to_wallet_id, amount, fee,
       currency_code, status, description)
    VALUES
      (l_ref, 'REVERSAL', l_orig.to_wallet_id, l_orig.from_wallet_id,
       l_orig.amount + l_orig.fee, 0, l_orig.currency_code, 'PENDING',
       SUBSTR('عكس ' || p_txn_ref || NVL2(p_reason, ': ' || p_reason, ''), 1, 200))
    RETURNING txn_id INTO l_txn_id;

    -- عكس القيود: المستلم يرجع المبلغ، ومحفظة الرسوم ترجع الرسوم
    post(l_txn_id, l_orig.to_wallet_id,   'D', l_orig.amount);
    post(l_txn_id, l_orig.from_wallet_id, 'C', l_orig.amount);
    IF l_orig.fee > 0 THEN
      post(l_txn_id, l_fees_w,             'D', l_orig.fee);
      post(l_txn_id, l_orig.from_wallet_id, 'C', l_orig.fee);
    END IF;

    UPDATE wlt_transactions SET status = 'COMPLETED', completed_at = SYSTIMESTAMP
     WHERE txn_id = l_txn_id;
    UPDATE wlt_transactions SET status = 'REVERSED'
     WHERE txn_id = l_orig.txn_id;

    INSERT INTO wlt_audit_log (action, entity, entity_id, details)
    VALUES ('REVERSE', 'TRANSACTION', l_orig.txn_id, p_txn_ref || ' -> ' || l_ref);

    COMMIT;
    RETURN l_ref;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO sp_reverse;
      log_failure('REVERSE_FAILED', p_txn_ref || ' : ' || SQLERRM, NULL);
      RAISE;
  END reverse;

END wallet_core_pkg;
/
