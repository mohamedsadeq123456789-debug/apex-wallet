-- =====================================================================
--  محفظتي · الجلسة 9 (ج) · قائمة «المزيد» + روابط التحليل ولوحة الإدارة في الرئيسية
-- =====================================================================
DECLARE
  l CLOB;
BEGIN
  FOR r IN (SELECT text FROM user_source WHERE name = 'WALLET_UI3_PKG' AND type = 'PACKAGE BODY' ORDER BY line) LOOP
    l := l || r.text;
  END LOOP;
  -- رابطا الجمعية والعيدية سقطا من القائمة في الجلسة 8: يعودان بعد «مجدولة» (12 رابطاً = 3 صفوف كاملة)
  IF REGEXP_INSTR(l, 'p_page\s*=>\s*12\)') = 0 THEN
    IF REGEXP_INSTR(l, 'apex_page\.get_url\(p_page => 10\) \|\| ''"><span>[^<]*</span>[^<]*</a>''') = 0 THEN
      RAISE_APPLICATION_ERROR(-20000, 'menu anchor 10');
    END IF;
    l := REGEXP_REPLACE(l, '(apex_page\.get_url\(p_page => 10\) \|\| ''"><span>[^<]*</span>[^<]*</a>'')',
      '\1' || CHR(10)
      || q'#      || '<a href="' || apex_page.get_url(p_page => 12) || '"><span>🤝</span>الجمعية</a>'#' || CHR(10)
      || q'#      || '<a href="' || apex_page.get_url(p_page => 13) || '"><span>🎁</span>العيدية</a>'#');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE ' || l;
  END IF;
END;
/

DECLARE
  l CLOB;
  c_anch CONSTANT VARCHAR2(200) := q'#'<div class="w-sec"><h2>آخر الحركات</h2>#';
BEGIN
  FOR r IN (SELECT text FROM user_source WHERE name = 'WALLET_UI_PKG' AND type = 'PACKAGE BODY' ORDER BY line) LOOP
    l := l || r.text;
  END LOOP;
  IF INSTR(l, 'p_page => 22') = 0 THEN
    IF INSTR(l, c_anch) = 0 OR INSTR(l, c_anch, 1, 2) > 0 THEN RAISE_APPLICATION_ERROR(-20000, 'home anchor'); END IF;
    l := REPLACE(l, c_anch, q'#'<style>.w-ban{display:flex;justify-content:space-between;align-items:center;gap:10px;text-decoration:none;color:var(--w-ink);background:linear-gradient(135deg,#fff8e6,var(--w-paper));border:1px solid var(--w-rule);border-radius:16px;padding:12px 16px;margin:-6px 0 12px;font-family:var(--w-disp);font-weight:700;font-size:14px}'
      || '.w-ban span{font-family:var(--w-body);font-weight:500;font-size:12px;color:var(--w-mint)}.w-ban.adm{background:linear-gradient(135deg,var(--w-g9),var(--w-g7));color:#f3efe2;border:0}.w-ban.adm span{color:var(--w-gold)}</style>'
      || CASE WHEN l_v.user_type = 'ADMIN' THEN '<a class="w-ban adm" href="' || apex_page.get_url(p_page => 21) || '">🛠️ لوحة الإدارة<span>المراجعات والإحصاءات ←</span></a>' END
      || '<a class="w-ban" href="' || apex_page.get_url(p_page => 22) || '">📊 حلّل مصاريفك<span>أين يذهب مالك هذا الشهر؟ ←</span></a>'
      || #' || c_anch);
    EXECUTE IMMEDIATE 'CREATE OR REPLACE ' || l;
  END IF;
END;
/
