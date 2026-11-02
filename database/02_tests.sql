-- =====================================================================
--  محفظتي · الجلسة 2 · اختبارات محرك التحويل
--  شغّله في SQL Commands. كل سطر في الناتج يبدأ بـ OK أو FAIL
-- =====================================================================
DECLARE
  l_ref   VARCHAR2(20);
  l_ref2  VARCHAR2(20);
  l_t1    VARCHAR2(20);
  l_a     NUMBER;
  l_b     NUMBER;
  l_t0    NUMBER;
  l_ms    NUMBER;

  PROCEDURE ok (p VARCHAR2) IS BEGIN DBMS_OUTPUT.PUT_LINE('OK   | ' || p); END;
  PROCEDURE bad (p VARCHAR2) IS BEGIN DBMS_OUTPUT.PUT_LINE('FAIL | ' || p); END;

  FUNCTION bal (p_phone VARCHAR2) RETURN NUMBER IS
    l NUMBER;
  BEGIN
    SELECT balance INTO l FROM wlt_wallets WHERE wallet_id = wallet_core_pkg.main_wallet(p_phone);
    RETURN l;
  END;

  -- ينفّذ تحويلاً متوقَّعاً رفضه، ويتأكد من رقم الخطأ
  PROCEDURE expect (p_name VARCHAR2, p_code NUMBER, p_from VARCHAR2, p_to VARCHAR2,
                    p_amt NUMBER, p_type VARCHAR2 DEFAULT 'TRANSFER') IS
    l VARCHAR2(20);
  BEGIN
    l := wallet_core_pkg.transfer(wallet_core_pkg.main_wallet(p_from),
                                  wallet_core_pkg.main_wallet(p_to), p_amt, p_type);
    bad(p_name || ' : مرّت ولم تُرفض ' || l);
  EXCEPTION WHEN OTHERS THEN
    IF SQLCODE = p_code THEN ok(p_name || ' : ' || SQLCODE || ' ' || SUBSTR(SQLERRM, 12, 90));
    ELSE bad(p_name || ' : ' || SQLERRM); END IF;
  END;

  PROCEDURE add_test_user (p_phone VARCHAR2, p_label VARCHAR2) IS
    l_salt VARCHAR2(16) := DBMS_RANDOM.STRING('X', 16);
    l_uid  NUMBER;
  BEGIN
    INSERT INTO wlt_users (phone, display_name, user_type, kyc_tier, pin_hash, pin_salt)
    VALUES (p_phone, p_label, 'CUSTOMER', 'BASIC',
            RAWTOHEX(STANDARD_HASH(l_salt || '1234', 'SHA256')), l_salt)
    RETURNING user_id INTO l_uid;
    INSERT INTO wlt_wallets (user_id, wallet_type, label) VALUES (l_uid, 'MAIN', 'المحفظة الرئيسية');
  EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
  END;
BEGIN
  -- 1) تحويل عادي
  l_a := bal('0791234567'); l_b := bal('0782345678');
  l_t1 := wallet_core_pkg.transfer_by_phone('0791234567', '0782345678', 15.250, 'S2-T1', 'غداء');
  IF bal('0791234567') = l_a - 15.25 AND bal('0782345678') = l_b + 15.25
  THEN ok('تحويل 15.250 من عميل 1 لعميل 2 : ' || l_t1);
  ELSE bad('تحويل عادي: الأرصدة غير صحيحة'); END IF;

  -- 2) نفس الطلب مرة ثانية (ضغطة مزدوجة)
  l_a := bal('0791234567');
  l_ref := wallet_core_pkg.transfer_by_phone('0791234567', '0782345678', 15.250, 'S2-T1', 'غداء');
  IF l_ref = l_t1 AND bal('0791234567') = l_a
  THEN ok('ضغطة مزدوجة: نفس الإيصال ' || l_ref || ' بدون خصم ثانٍ');
  ELSE bad('idempotency لم يعمل'); END IF;

  -- 3) دفع فاتورة برسوم ثابتة 0.250
  l_a := bal('0794567890');
  l_ref := wallet_core_pkg.transfer(wallet_core_pkg.main_wallet('0794567890'),
                                    wallet_core_pkg.main_wallet('0777890123'), 20, 'BILL_PAY');
  IF bal('0794567890') = l_a - 20.25 THEN ok('فاتورة 20 + رسوم 0.250 = خُصم 20.250 : ' || l_ref);
  ELSE bad('رسوم الفاتورة'); END IF;

  -- 4) سحب نقدي برسوم 0.5%
  l_a := bal('0782345678');
  l_ref := wallet_core_pkg.transfer(wallet_core_pkg.main_wallet('0782345678'),
                                    wallet_core_pkg.main_wallet('0798901234'), 100, 'CASH_OUT');
  IF bal('0782345678') = l_a - 100.5 THEN ok('سحب 100 عند وكيل + رسوم 0.5% = خُصم 100.500 : ' || l_ref);
  ELSE bad('رسوم السحب'); END IF;

  -- 5) حالات يجب أن تُرفض
  expect('رصيد غير كافٍ (عميل 5 عنده 30 ويرسل 50)', -20101, '0785678901', '0791234567', 50);
  expect('تجاوز حد العملية (أساسي حده 200)',          -20102, '0782345678', '0791234567', 250);
  expect('المستلم يتجاوز أقصى رصيد (أساسي 1000)',       -20105, '0798901234', '0773456789', 990);
  expect('تحويل لنفس المحفظة',                          -20108, '0791234567', '0791234567', 5);
  expect('مبلغ سالب',                                    -20107, '0791234567', '0782345678', -5);
  expect('مبلغ بأربع خانات عشرية',                       -20107, '0791234567', '0782345678', 1.2345);

  -- 6) الحد اليومي: حساب اختبار أساسي حده اليومي 500
  add_test_user('0770000001', 'حساب اختبار أ');
  add_test_user('0770000002', 'حساب اختبار ب');
  l_ref := wallet_core_pkg.topup(wallet_core_pkg.main_wallet('0770000001'), 900, 'S2-TOPUP-A');
  l_ref := wallet_core_pkg.transfer_by_phone('0770000001', '0770000002', 200, 'S2-D1');
  l_ref := wallet_core_pkg.transfer_by_phone('0770000001', '0770000002', 200, 'S2-D2');
  expect('تجاوز الحد اليومي (400 مستخدمة + 200 > 500)', -20103, '0770000001', '0770000002', 200);

  -- 7) عكس العملية الأولى
  l_a := bal('0791234567');
  l_ref := wallet_core_pkg.reverse(l_t1, 'اختبار العكس');
  IF bal('0791234567') = l_a + 15.25 THEN ok('عكس ' || l_t1 || ' بالعملية ' || l_ref || ' ورجعت 15.250');
  ELSE bad('العكس'); END IF;

  BEGIN
    l_ref := wallet_core_pkg.reverse(l_t1);
    bad('عكس مرتين مرّ');
  EXCEPTION WHEN OTHERS THEN
    IF SQLCODE = -20111 THEN ok('عكس نفس العملية مرة ثانية رُفض : -20111');
    ELSE bad('عكس مرتين: ' || SQLERRM); END IF;
  END;

  -- 8) السرعة: 200 تحويل كامل، كل واحد بقفل وقيود وحفظ
  l_a := wallet_core_pkg.main_wallet('0770000002');
  l_b := wallet_core_pkg.main_wallet('0770000001');
  l_t0 := DBMS_UTILITY.GET_TIME;
  FOR i IN 1 .. 200 LOOP
    IF MOD(i, 2) = 1 THEN
      l_ref := wallet_core_pkg.transfer(l_a, l_b, 0.010);
    ELSE
      l_ref := wallet_core_pkg.transfer(l_b, l_a, 0.010);
    END IF;
  END LOOP;
  l_ms := (DBMS_UTILITY.GET_TIME - l_t0) * 10;
  ok('السرعة: 200 تحويل في ' || l_ms || ' ms = ' || ROUND(l_ms / 200, 2) || ' ms للتحويل');

  -- 9) فحوصات السلامة
  SELECT COUNT(*) INTO l_a FROM wlt_v_check_unbalanced_txns;
  IF l_a = 0 THEN ok('كل العمليات متوازنة (D = C)'); ELSE bad(l_a || ' عملية غير متوازنة'); END IF;
  SELECT COUNT(*) INTO l_a FROM wlt_v_check_wallet_drift;
  IF l_a = 0 THEN ok('كل الأرصدة تطابق الدفتر'); ELSE bad(l_a || ' محفظة منحرفة'); END IF;
  SELECT SUM(balance) INTO l_a FROM wlt_wallets;
  IF l_a = 0 THEN ok('مجموع أرصدة النظام = 0'); ELSE bad('المجموع ' || l_a); END IF;
  SELECT COUNT(*) INTO l_a FROM wlt_audit_log WHERE action = 'TRANSFER_FAILED';
  ok('محاولات فاشلة مسجّلة في سجل التدقيق: ' || l_a);
END;
