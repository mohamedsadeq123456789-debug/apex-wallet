-- =====================================================================
--  محفظتي · الجلسة 10 · الأداء: التقسيم الشهري، الفهارس، الإحصاءات، اختبار الضغط
--  (نُفّذ خطوة بخطوة من SQL Commands؛ المستخدم هناك APEX_PUBLIC_USER لذلك اسم المخطط صريح)
-- =====================================================================

-- 1) تقسيم جدول الحركات شهرياً، بدون إيقاف، والفهارس غير الفريدة تصبح محلية لكل شهر
ALTER TABLE wlt_transactions MODIFY
  PARTITION BY RANGE (created_at) INTERVAL (NUMTOYMINTERVAL(1, 'MONTH'))
  (PARTITION p_2026_09 VALUES LESS THAN (TIMESTAMP '2026-10-01 00:00:00'))
  ONLINE UPDATE INDEXES (ix_wlt_txn_limits LOCAL, ix_wlt_txn_to LOCAL, ix_wlt_txn_type LOCAL);

-- 2) فهارس ناقصة: مفتاح أجنبي بلا فهرس + استعلامات لوحة الإدارة حسب الوقت
CREATE INDEX ix_wlt_txn_actor   ON wlt_transactions (created_by) LOCAL;
CREATE INDEX ix_wlt_txn_created ON wlt_transactions (created_at, status) LOCAL;

-- 3) إحصاءات المحسِّن
BEGIN
  FOR t IN (SELECT table_name FROM all_tables WHERE owner = 'WKSP_MOHAMMADAPEX'
               AND table_name IN ('WLT_TRANSACTIONS','WLT_LEDGER_ENTRIES','WLT_WALLETS','WLT_USERS')) LOOP
    DBMS_STATS.GATHER_TABLE_STATS('WKSP_MOHAMMADAPEX', t.table_name, cascade => TRUE);
  END LOOP;
END;
/

-- 4) اختبار الضغط المتسلسل: 1000 تحويل بين مستخدمَي اختبار (PREMIUM)
--    النتيجة: 3.77 ms للتحويل الواحد شاملاً فحص الاحتيال والقيود والمشغّلات والحفظ ≈ 265 تحويل/ثانية، صفر فشل
DECLARE
  l_wa NUMBER := wallet_core_pkg.main_wallet('0770009001');
  l_wb NUMBER := wallet_core_pkg.main_wallet('0770009002');
  l_ref VARCHAR2(40); t0 NUMBER;
BEGIN
  t0 := DBMS_UTILITY.GET_TIME;
  FOR i IN 1 .. 1000 LOOP
    IF MOD(i, 2) = 1 THEN l_ref := wallet_core_pkg.transfer(l_wa, l_wb, 1.25, 'TRANSFER', 'STRESS-S-' || i);
    ELSE                  l_ref := wallet_core_pkg.transfer(l_wb, l_wa, 1.25, 'TRANSFER', 'STRESS-S-' || i);
    END IF;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE((DBMS_UTILITY.GET_TIME - t0) * 10 / 1000 || ' ms/transfer');
END;
/

-- 5) اختبار التزامن: 4 مهام متوازية × 250 تحويل على نفس المحفظتين باتجاهين متعاكسين
--    النتيجة: 1000 تحويل في 7.1 ثانية، صفر deadlock، صفر فشل، الرصيدان رجعا 3000/3000 بالضبط
BEGIN
  FOR w IN 1 .. 4 LOOP
    DBMS_SCHEDULER.CREATE_JOB(
      job_name   => 'WLT_STRESS_' || w,
      job_type   => 'PLSQL_BLOCK',
      job_action => 'DECLARE r VARCHAR2(40); a NUMBER := wallet_core_pkg.main_wallet(''0770009001''); b NUMBER := wallet_core_pkg.main_wallet(''0770009002'');
                     BEGIN FOR i IN 1 .. 250 LOOP
                       IF MOD(i + ' || w || ', 2) = 0 THEN r := wallet_core_pkg.transfer(a, b, 0.75, ''TRANSFER'', ''STRESS-P' || w || '-'' || i);
                       ELSE r := wallet_core_pkg.transfer(b, a, 0.75, ''TRANSFER'', ''STRESS-P' || w || '-'' || i); END IF;
                     END LOOP; END;',
      start_date => SYSTIMESTAMP, enabled => TRUE, auto_drop => TRUE);
  END LOOP;
END;
/
