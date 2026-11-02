-- =====================================================================
--  محفظتي · الجلسة 10 · تلميع بعد المراجعة المرئية
-- =====================================================================
DECLARE
  l CLOB; l2 CLOB;
  PROCEDURE load (p_name VARCHAR2) IS
  BEGIN
    l := NULL;
    FOR r IN (SELECT text FROM user_source WHERE name = p_name AND type = 'PACKAGE BODY' ORDER BY line) LOOP l := l || r.text; END LOOP;
  END;
  PROCEDURE save IS
  BEGIN
    IF DBMS_LOB.COMPARE(l, l2) <> 0 THEN EXECUTE IMMEDIATE 'CREATE OR REPLACE ' || l2; END IF;
  END;
BEGIN
  -- الرئيسية: «صرف هذا الشهر» لا يظهر ‎-0.000، والإيداع في حصّالتك يظهر باسم العملية لا باسمك
  load('WALLET_UI_PKG');
  l2 := REPLACE(l, q'#<b>−' || money(l_out)#', q'#<b>' || CASE WHEN l_out > 0 THEN '−' END || money(l_out)#');
  l2 := REPLACE(l2, q'#CASE WHEN o.user_type = 'SYSTEM' THEN tt.name_ar ELSE o.shown_name END AS other#',
                    q'#CASE WHEN o.user_type = 'SYSTEM' OR o.user_id = l_v.user_id THEN tt.name_ar ELSE o.shown_name END AS other#');
  save;
  -- تحليل المصاريف: بطاقة النصيحة كانت تُرسم داخل بطاقة ثانية
  load('WALLET_UI7_PKG');
  l2 := REPLACE(REPLACE(l, '.i-tips div{', '.i-tips>div{'), '.i-tips div span{', '.i-tips>div>span{');
  save;
  -- إيصالات الحصّالات والعائلة: الزر يعيد للصفحة نفسها فاسمه «تمّ» لا «العودة للرئيسية»
  load('WALLET_UI5_PKG');
  l2 := REPLACE(l, 'if(a)a.href=location.href', 'if(a){a.href=location.href;a.textContent=''تمّ''}');
  l2 := REPLACE(l2, 'if(h)h.href=location.href', 'if(h){h.href=location.href;h.textContent=''تمّ''}');
  save;
END;
/

-- بعد تقسيم الجدول تصبح الـ MV غير صالحة حتى تُعاد ترجمتها
ALTER MATERIALIZED VIEW wlt_mv_daily COMPILE;
BEGIN DBMS_MVIEW.REFRESH('WLT_MV_DAILY', 'C'); END;
/
