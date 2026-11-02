-- =====================================================================
--  محفظتي · الجلسة 9 (أ) · إصلاحات: الوقت المحلي، قائمة «المزيد»، شريط صفحة العائلة
-- =====================================================================

-- الخادم يعمل بتوقيت UTC؛ كل ما يُعرض للمستخدم يمر عبر هذه الدالة إلى توقيت عمّان
CREATE OR REPLACE FUNCTION wlt_local (p_ts TIMESTAMP) RETURN TIMESTAMP DETERMINISTIC IS
BEGIN
  -- الأردن على +03:00 طوال السنة منذ 2022؛ ملف المناطق الزمنية في الخادم أقدم، لذا نثبّت الإزاحة
  RETURN CAST(FROM_TZ(p_ts, 'UTC') AT TIME ZONE '+03:00' AS TIMESTAMP);
END wlt_local;
/

-- كل TO_CHAR(عمود, 'DD…' أو 'HH24…') في شاشات العرض يصبح TO_CHAR(wlt_local(عمود), …)
DECLARE
  l   CLOB;
  l2  CLOB;
  n   NUMBER;
BEGIN
  FOR p IN (SELECT DISTINCT name FROM user_source
             WHERE type = 'PACKAGE BODY' AND (name LIKE 'WALLET_UI%' OR name IN ('WALLET_LOGIN_PKG'))) LOOP
    l := NULL;
    FOR r IN (SELECT text FROM user_source WHERE name = p.name AND type = 'PACKAGE BODY' ORDER BY line) LOOP
      l := l || r.text;
    END LOOP;
    l2 := REGEXP_REPLACE(l, 'TO_CHAR\(([A-Za-z_][A-Za-z0-9_.]*|NVL\([A-Za-z0-9_., ]+\)), ''(DD|HH24)', 'TO_CHAR(wlt_local(\1), ''\2');
    l2 := REPLACE(l2, 'wlt_local(wlt_local(', 'wlt_local(');
    IF DBMS_LOB.COMPARE(l, l2) <> 0 THEN
      EXECUTE IMMEDIATE 'CREATE OR REPLACE ' || l2;
      DBMS_OUTPUT.PUT_LINE('FIXED TIME ' || p.name);
    END IF;
  END LOOP;
END;
/

-- شريط إشعار الرسالة التجريبية كان يظهر طرفه أعلى صفحة العائلة
DECLARE
  l CLOB;
BEGIN
  FOR r IN (SELECT text FROM user_source WHERE name = 'WALLET_UI5_PKG' AND type = 'PACKAGE BODY' ORDER BY line) LOOP
    l := l || r.text;
  END LOOP;
  IF INSTR(l, 'translate(-50%,-140%)') > 0 THEN
    l := REPLACE(l, 'transform:translate(-50%,-140%);', 'transform:translate(-50%,-160px);visibility:hidden;');
    l := REPLACE(l, '.f-sms.on{transform:translate(-50%,0)}', '.f-sms.on{transform:translate(-50%,0);visibility:visible}');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE ' || l;
  END IF;
END;
/
