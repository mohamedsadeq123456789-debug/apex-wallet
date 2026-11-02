-- =====================================================================
--  محفظتي · الجلسة 7 · شاشات الحصّالات (14) وكود الدفع (15) والعائلة (16)
-- =====================================================================
CREATE OR REPLACE PACKAGE wallet_ui5_pkg AS
  FUNCTION render_save   RETURN CLOB;
  FUNCTION render_code   RETURN CLOB;
  FUNCTION render_family RETURN CLOB;
  PROCEDURE api;
END wallet_ui5_pkg;
/

CREATE OR REPLACE PACKAGE BODY wallet_ui5_pkg AS

  FUNCTION esc (p VARCHAR2) RETURN VARCHAR2 IS BEGIN RETURN apex_escape.html(p); END;
  FUNCTION money (p NUMBER) RETURN VARCHAR2 IS
  BEGIN RETURN TO_CHAR(p, 'FM999G999G990D000', 'NLS_NUMERIC_CHARACTERS=''.,'''); END;

  FUNCTION me RETURN wlt_v_wallets%ROWTYPE IS
    l   wlt_v_wallets%ROWTYPE;
    l_w NUMBER := wallet_core_pkg.main_wallet(v('APP_USER'));
  BEGIN
    SELECT * INTO l FROM wlt_v_wallets WHERE wallet_id = l_w;
    RETURN l;
  END me;

  FUNCTION head (p_title VARCHAR2, p_sub VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN '<div class="w-head"><a href="' || apex_page.get_url(p_page => 1) || '" title="الرئيسية">→</a>'
        || '<div><h1>' || esc(p_title) || '</h1><p>' || esc(p_sub) || '</p></div></div>';
  END head;

  FUNCTION css RETURN VARCHAR2 IS
  BEGIN
    RETURN q'~<style>
.s-hero{position:relative;overflow:hidden;border-radius:24px;padding:20px 20px 18px;margin-bottom:18px;color:#f3efe2;
  background:radial-gradient(120% 90% at 100% 0%,rgba(233,197,111,.30),transparent 55%),linear-gradient(140deg,var(--w-g9),var(--w-g7));box-shadow:0 22px 40px -22px rgba(5,30,25,.6)}
.s-hero small{opacity:.75;font-size:12.5px}
.s-hero b{display:block;font-family:var(--w-mono);font-size:34px;font-weight:700;direction:ltr;text-align:right;color:var(--w-gold);line-height:1.2;margin:4px 0 10px}
.s-hero .meta{display:flex;gap:8px;flex-wrap:wrap}
.s-hero .meta span{background:rgba(255,255,255,.1);border-radius:999px;padding:3px 11px;font-size:12px}
.s-jar{position:absolute;left:14px;top:12px;width:74px;height:84px;opacity:.9}
.g-card{border:1px solid var(--w-rule);background:var(--w-paper);border-radius:22px;padding:16px;margin-bottom:12px;animation:w-in .4s both;position:relative;overflow:hidden}
.g-top{display:flex;gap:12px;align-items:center}
.g-emo{width:52px;height:52px;border-radius:16px;display:grid;place-items:center;font-size:26px;background:var(--w-mint-s);flex:none}
.g-top h3{font-family:var(--w-disp);font-size:16.5px;margin:0}
.g-top small{display:block;color:var(--w-muted);font-size:12px}
.g-amt{margin-inline-start:auto;text-align:left;font-family:var(--w-mono);direction:ltr}
.g-amt b{display:block;font-size:19px}.g-amt span{font-size:11.5px;color:var(--w-muted)}
.g-bar{height:10px;border-radius:6px;background:var(--w-rule);overflow:hidden;margin:14px 0 6px;position:relative}
.g-bar i{display:block;height:100%;border-radius:6px;background:linear-gradient(90deg,var(--w-mint),#2fae8e 70%,var(--w-gold));width:0;transition:width 1s cubic-bezier(.2,.8,.2,1)}
.g-row{display:flex;justify-content:space-between;font-size:12px;color:var(--w-muted)}
.g-acts{display:flex;gap:8px;margin-top:14px}
.g-acts button{flex:1;border-radius:12px;padding:10px;font-family:var(--w-disp);font-weight:600;font-size:14px;cursor:pointer;border:1.5px solid var(--w-rule);background:var(--w-paper);color:var(--w-ink)}
.g-acts button.go{background:var(--w-g8);border-color:var(--w-g8);color:#fff}
.g-acts button:disabled{opacity:.45;cursor:not-allowed}
.g-acts .more{flex:0 0 46px}
.g-lock{position:absolute;top:12px;left:12px;font-size:11px;background:#fdf1d6;color:#8a6110;border-radius:999px;padding:2px 9px}
.g-done{position:absolute;top:12px;left:12px;font-size:11px;background:var(--w-mint);color:#fff;border-radius:999px;padding:2px 9px}
.s-emos{display:grid;grid-template-columns:repeat(8,1fr);gap:6px;margin-bottom:14px}
.s-emos button{aspect-ratio:1;border-radius:12px;border:1.5px solid var(--w-rule);background:var(--w-paper);font-size:20px;cursor:pointer;padding:0}
.s-emos button.on{border-color:var(--w-mint);background:var(--w-mint-s);transform:scale(1.06)}
.s-sw{display:flex;align-items:center;justify-content:space-between;gap:12px;border:1px solid var(--w-rule);background:var(--w-paper);border-radius:16px;padding:12px 14px;margin-bottom:12px;cursor:pointer}
.s-sw small{display:block;color:var(--w-muted);font-size:12px}
.s-sw input{display:none}
.s-sw i{width:46px;height:28px;border-radius:999px;background:var(--w-rule);position:relative;flex:none;transition:background .2s}
.s-sw i::after{content:"";position:absolute;top:3px;right:3px;width:22px;height:22px;border-radius:50%;background:#fff;box-shadow:0 1px 3px rgba(0,0,0,.25);transition:transform .2s}
.s-sw input:checked+i{background:var(--w-mint)}.s-sw input:checked+i::after{transform:translateX(-18px)}
.r-card{border:1px solid var(--w-rule);background:var(--w-paper);border-radius:20px;padding:14px 16px;margin-bottom:12px;animation:w-in .4s both}
.r-card.on{border-color:var(--w-mint);box-shadow:0 0 0 3px var(--w-mint-s)}
.r-hd{display:flex;gap:12px;align-items:flex-start}
.r-hd .ic{width:42px;height:42px;border-radius:13px;display:grid;place-items:center;font-size:20px;background:var(--w-bg);flex:none}
.r-hd h3{font-family:var(--w-disp);font-size:15px;margin:0}
.r-hd p{margin:2px 0 0;font-size:12.5px;color:var(--w-muted);line-height:1.6}
.r-hd .s-sw{border:0;padding:0;margin:0 0 0 0;background:none;margin-inline-start:auto}
.r-body{display:none;gap:8px;margin-top:12px;align-items:center;flex-wrap:wrap}
.r-card.on .r-body{display:flex}
.r-body select,.r-body input{flex:1;min-width:110px;border:1.5px solid var(--w-rule);border-radius:12px;padding:10px;font-family:var(--w-body);font-size:14px;background:var(--w-bg);color:var(--w-ink)}
.r-body button{border:0;background:var(--w-mint);color:#fff;border-radius:12px;padding:10px 16px;font-family:var(--w-disp);font-weight:600;cursor:pointer}
.r-stat{font-size:11.5px;color:var(--w-mint);margin-top:8px}
.r-ex{font-family:var(--w-mono);font-size:12px;direction:ltr;display:inline-block;background:var(--w-mint-s);color:var(--w-g8);border-radius:6px;padding:0 6px}
.c-box{border-radius:26px;padding:22px 16px 18px;text-align:center;color:#f3efe2;margin-bottom:14px;position:relative;overflow:hidden;
  background:radial-gradient(100% 70% at 50% 0%,rgba(233,197,111,.25),transparent 60%),linear-gradient(160deg,var(--w-g9),var(--w-g7))}
.c-box small{opacity:.75;font-size:12.5px}
.c-digits{display:flex;justify-content:center;gap:6px;direction:ltr;margin:14px 0 6px}
.c-digits span{width:34px;height:50px;border-radius:11px;background:rgba(255,255,255,.08);border:1px solid rgba(233,197,111,.35);display:grid;place-items:center;font-family:var(--w-mono);font-size:26px;font-weight:700;color:var(--w-gold);animation:w-pop .4s both}
.c-digits .gap{width:10px;background:none;border:0}
.c-ring{--p:100;width:64px;height:64px;border-radius:50%;margin:12px auto 4px;display:grid;place-items:center;font-family:var(--w-mono);font-size:14px;
  background:conic-gradient(var(--w-gold) calc(var(--p)*1%),rgba(255,255,255,.12) 0)}
.c-ring b{width:52px;height:52px;border-radius:50%;background:var(--w-g8);display:grid;place-items:center}
.c-box.used{background:linear-gradient(160deg,#0e7a63,#13997a)}
.c-box.dead{filter:grayscale(.8);opacity:.75}
.c-max{display:inline-block;margin-top:6px;background:rgba(255,255,255,.1);border-radius:999px;padding:3px 12px;font-size:12.5px}
.c-in{font-family:var(--w-mono);font-size:30px;text-align:center;letter-spacing:.25em;direction:ltr}
.f-kid{border:1px solid var(--w-rule);background:var(--w-paper);border-radius:22px;overflow:hidden;margin-bottom:14px;animation:w-in .4s both}
.f-top{display:flex;gap:12px;align-items:center;padding:16px;background:linear-gradient(135deg,#fff8e6,var(--w-paper))}
.f-av{width:50px;height:50px;border-radius:50%;display:grid;place-items:center;font-family:var(--w-disp);font-weight:800;font-size:20px;color:#fff;flex:none;background:linear-gradient(135deg,#e9a23b,#c8487a)}
.f-top h3{font-family:var(--w-disp);font-size:16.5px;margin:0}
.f-top small{display:block;color:var(--w-muted);font-size:12px;direction:ltr;text-align:right}
.f-bal{margin-inline-start:auto;text-align:left;font-family:var(--w-mono);direction:ltr}
.f-bal b{display:block;font-size:19px}.f-bal span{font-size:11px;color:var(--w-muted)}
.f-body{padding:0 16px 16px}
.f-tags{display:flex;gap:6px;flex-wrap:wrap;margin:10px 0}
.f-tags span{font-size:11.5px;border-radius:999px;padding:2px 10px;background:var(--w-bg);border:1px solid var(--w-rule)}
.f-tags span.no{color:var(--w-red);border-color:var(--w-red-s);background:var(--w-red-s)}
.f-tags span.yes{color:var(--w-mint);border-color:var(--w-mint-s);background:var(--w-mint-s)}
.f-cats{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:12px}
.f-cats button{border:1.5px solid var(--w-rule);background:var(--w-paper);border-radius:999px;padding:6px 12px;font-family:var(--w-body);font-size:13px;cursor:pointer;color:var(--w-ink)}
.f-cats button.on{border-color:var(--w-red);background:var(--w-red-s);color:var(--w-red);text-decoration:line-through}
.f-steps{display:flex;gap:6px;margin-bottom:16px}
.f-steps i{flex:1;height:5px;border-radius:3px;background:var(--w-rule)}.f-steps i.on{background:var(--w-mint)}
.f-otp{display:flex;gap:8px;justify-content:center;direction:ltr;margin:6px 0 14px}
.f-otp input{width:44px;height:56px;border-radius:14px;border:1.5px solid var(--w-rule);text-align:center;font-family:var(--w-mono);font-size:24px;background:var(--w-paper);color:var(--w-ink)}
.f-otp input:focus{border-color:var(--w-mint);outline:0;box-shadow:0 0 0 3px var(--w-mint-s)}
.f-sms{position:fixed;top:14px;left:50%;transform:translate(-50%,-140%);z-index:1200;width:min(380px,92vw);background:#101c1a;color:#f3efe2;border-radius:18px;padding:12px 16px;box-shadow:0 18px 40px rgba(0,0,0,.35);transition:transform .45s cubic-bezier(.2,.9,.3,1.2);font-size:13px;line-height:1.6}
.f-sms.on{transform:translate(-50%,0)}.f-sms b{color:var(--w-gold);font-family:var(--w-mono);font-size:15px}
.f-sms small{display:block;opacity:.6;font-size:11px}
.w-preview{background:var(--w-g8);color:#f3efe2;border-radius:16px;padding:12px 16px;margin:6px 0 14px;font-size:13px;display:flex;justify-content:space-between;align-items:center}
.w-preview b{font-family:var(--w-mono);color:var(--w-gold);font-size:17px}
.w-chips{display:flex;gap:8px;flex-wrap:wrap}.w-chip{border:1px solid var(--w-rule);background:var(--w-paper);border-radius:999px;padding:6px 16px;font-family:var(--w-mono);cursor:pointer;color:var(--w-ink)}
.f-me{border-radius:22px;padding:18px;background:linear-gradient(135deg,#fff8e6,var(--w-paper));border:1px solid var(--w-rule);margin-bottom:14px}
</style>~';
  END css;

  -- -----------------------------------------------------------------
  -- 14) الحصّالات والقواعد الذكية
  -- -----------------------------------------------------------------
  FUNCTION render_save RETURN CLOB IS
    l      wlt_v_wallets%ROWTYPE := me;
    l_h    CLOB;
    l_n    PLS_INTEGER := 0;
    l_tot  NUMBER;
    l_cnt  NUMBER;
    l_rul  NUMBER;
    l_pct  NUMBER;
    l_opts VARCHAR2(4000);
    l_r    wlt_smart_rules%ROWTYPE;
    l_none wlt_smart_rules%ROWTYPE;
    TYPE t_def IS RECORD (k VARCHAR2(12), ic VARCHAR2(8), t VARCHAR2(80), d VARCHAR2(300), dflt NUMBER);
    TYPE t_defs IS TABLE OF t_def;
    l_defs t_defs := t_defs();
    PROCEDURE add_def (k VARCHAR2, ic VARCHAR2, t VARCHAR2, d VARCHAR2, dflt NUMBER) IS
    BEGIN l_defs.EXTEND; l_defs(l_defs.LAST).k := k; l_defs(l_defs.LAST).ic := ic; l_defs(l_defs.LAST).t := t;
          l_defs(l_defs.LAST).d := d; l_defs(l_defs.LAST).dflt := dflt; END;
  BEGIN
    wallet_save_pkg.process_wallet(l.wallet_id);
    SELECT NVL(SUM(w.balance), 0), COUNT(*) INTO l_tot, l_cnt
      FROM wlt_goals g JOIN wlt_wallets w ON w.wallet_id = g.wallet_id
     WHERE g.user_id = l.user_id AND g.status = 'ACTIVE';
    SELECT COUNT(*) INTO l_rul FROM wlt_smart_rules WHERE user_id = l.user_id AND is_active = 'Y';

    l_h := wallet_ui2_pkg.common || css || '<div class="w-app">'
      || head('الحصّالات', 'ادّخر لأهدافك، ودع القواعد الذكية تدّخر عنك')
      || '<div class="s-hero"><svg class="s-jar" viewBox="0 0 74 84" fill="none"><rect x="20" y="4" width="34" height="10" rx="4" fill="#e9c56f"/>'
      || '<path d="M14 22c0-4 3-8 8-8h30c5 0 8 4 8 8v46c0 8-6 14-14 14H28c-8 0-14-6-14-14z" fill="rgba(255,255,255,.12)" stroke="rgba(233,197,111,.7)" stroke-width="2"/>'
      || '<circle cx="31" cy="58" r="8" fill="#e9c56f"/><circle cx="45" cy="64" r="7" fill="#c9a34e"/><circle cx="40" cy="48" r="6" fill="#f3d98f"/></svg>'
      || '<small>مجموع مدخراتك</small><b>' || money(l_tot) || '</b>'
      || '<div class="meta"><span>🐷 ' || l_cnt || ' حصّالات</span><span>⚡ ' || l_rul || ' قواعد فعّالة</span></div></div>'
      || '<div class="w-tabs"><button type="button" class="on" data-p="pGoals">حصّالاتي</button><button type="button" data-p="pNew">جديدة</button><button type="button" data-p="pRules">القواعد الذكية</button></div>'
      || '<section class="w-pane on" id="pGoals">';

    FOR g IN (SELECT g.*, w.balance FROM wlt_goals g JOIN wlt_wallets w ON w.wallet_id = g.wallet_id
               WHERE g.user_id = l.user_id AND g.status = 'ACTIVE' ORDER BY g.created_at) LOOP
      l_n := l_n + 1;
      l_pct := CASE WHEN g.target_amount > 0 THEN LEAST(100, ROUND(g.balance / g.target_amount * 100)) END;
      l_opts := l_opts || '<option value="' || g.goal_id || '">' || esc(g.emoji || ' ' || g.name) || '</option>';
      l_h := l_h || '<div class="g-card" style="animation-delay:' || (l_n * 60) || 'ms">'
        || CASE WHEN g.reached_at IS NOT NULL THEN '<span class="g-done">✓ وصلت للهدف</span>'
                WHEN g.locked_until > SYSDATE THEN '<span class="g-lock">🔒 مقفلة حتى ' || TO_CHAR(g.locked_until, 'DD/MM') || '</span>' END
        || '<div class="g-top"><div class="g-emo">' || esc(g.emoji) || '</div><div><h3>' || esc(g.name) || '</h3><small>'
        || CASE WHEN g.target_date IS NOT NULL THEN 'باقي ' || GREATEST(TRUNC(g.target_date - SYSDATE), 0) || ' يوم'
                ELSE 'بدون موعد' END
        || '</small></div><div class="g-amt" style="margin-top:' || CASE WHEN g.reached_at IS NOT NULL OR g.locked_until > SYSDATE THEN '18' ELSE '0' END || 'px"><b>' || money(g.balance) || '</b>'
        || CASE WHEN g.target_amount IS NOT NULL THEN '<span>من ' || money(g.target_amount) || '</span>' END || '</div></div>'
        || CASE WHEN l_pct IS NOT NULL THEN '<div class="g-bar"><i data-w="' || l_pct || '"></i></div><div class="g-row"><span>' || l_pct || '%</span><span>'
             || CASE WHEN g.balance < g.target_amount THEN 'ينقصك ' || money(g.target_amount - g.balance) || ' د.أ' ELSE '🎉 اكتمل' END || '</span></div>' END
        || '<div class="g-acts"><button type="button" class="go" data-dep="' || g.goal_id || '" data-n="' || esc(g.emoji || ' ' || g.name) || '">＋ إيداع</button>'
        || '<button type="button" data-wd="' || g.goal_id || '" data-n="' || esc(g.emoji || ' ' || g.name) || '" data-b="' || money(g.balance) || '"'
        || CASE WHEN g.locked_until > SYSDATE OR g.balance = 0 THEN ' disabled' END || '>سحب</button>'
        || '<button type="button" class="more" data-close="' || g.goal_id || '" data-n="' || esc(g.name) || '" data-b="' || money(g.balance) || '"'
        || CASE WHEN g.locked_until > SYSDATE THEN ' disabled' END || ' title="إغلاق الحصّالة">✕</button></div></div>';
    END LOOP;
    IF l_n = 0 THEN
      l_h := l_h || '<div class="w-empty">🐷 لا توجد حصّالات بعد.<br>أنشئ أول حصّالة لهدف تحلم فيه.</div>';
    END IF;
    l_h := l_h || '<div class="w-err" id="gErr"></div></section>'

      || '<section class="w-pane" id="pNew">'
      || '<div class="s-emos" id="sEmo">' ;
    FOR e IN (SELECT COLUMN_VALUE v FROM TABLE(sys.odcivarchar2list('🎯','✈️','🚗','🏠','🎓','💍','📱','🎁'))) LOOP
      l_h := l_h || '<button type="button"' || CASE WHEN e.v = '🎯' THEN ' class="on"' END || ' data-e="' || e.v || '">' || e.v || '</button>';
    END LOOP;
    l_h := l_h || '</div>'
      || '<label class="w-field"><span>اسم الحصّالة</span><input class="w-in" id="gName" maxlength="60" placeholder="مثلاً: سفرة الصيف"></label>'
      || '<div class="w-row2" style="display:flex;gap:8px;margin-bottom:14px"><label class="w-field" style="flex:1;margin:0"><span>الهدف (د.أ) — اختياري</span><input class="w-in ltr" id="gTarget" inputmode="decimal" placeholder="500"></label>'
      || '<label class="w-field" style="flex:1;margin:0"><span>الموعد — اختياري</span><input class="w-in ltr" id="gDate" type="date"></label></div>'
      || '<label class="s-sw"><div><b>🔒 اقفلها حتى الموعد</b><small>لا سحب قبل التاريخ. يحميك من الصرف المفاجئ</small></div><input type="checkbox" id="gLock"><i></i></label>'
      || '<div class="w-preview" id="gPrev" style="display:none"><span id="gPrevT"></span><b id="gPrevA"></b></div>'
      || '<div class="w-err" id="nErr"></div><button class="w-btn" id="gGo" type="button" disabled>أنشئ الحصّالة</button></section>'

      || '<section class="w-pane" id="pRules">';

    add_def('ROUNDUP', '🪙', 'فكّة كل دفعة',
      'كل ما تدفع، نقرّب المبلغ لأعلى والفرق يروح للحصّالة. مثال: دفعت <span class="r-ex">2.350</span> ← تدّخر <span class="r-ex">0.650</span>', 1);
    add_def('PCT_IN', '📥', 'نسبة من كل مبلغ يصلك',
      'أي تحويل أو شحن أو جمعية تستلمها، نحوّل نسبة منه تلقائياً للحصّالة', 10);
    add_def('SWEEP', '🌙', 'الزيادة آخر اليوم',
      'كل ليلة، أي رصيد فوق الحد الذي تختاره ينتقل للحصّالة، ويبقى لك الحد للصرف', 50);
    add_def('SPEND_ALERT', '🔔', 'تنبيه حد الصرف اليومي',
      'نرسل لك إشعاراً لحظة تجاوز صرفك اليومي المبلغ الذي تحدده', 20);

    IF l_cnt = 0 THEN
      l_h := l_h || '<div class="w-note" style="margin:0 0 14px">أنشئ حصّالة أولاً حتى تعمل قواعد الادخار. تنبيه الصرف يعمل بدونها.</div>';
    END IF;
    FOR i IN 1 .. l_defs.COUNT LOOP
      BEGIN
        SELECT * INTO l_r FROM wlt_smart_rules WHERE user_id = l.user_id AND rule_type = l_defs(i).k;
      EXCEPTION WHEN NO_DATA_FOUND THEN l_r := l_none;
      END;
      l_h := l_h || '<div class="r-card' || CASE WHEN l_r.is_active = 'Y' THEN ' on' END || '" data-rule="' || l_defs(i).k || '" style="animation-delay:' || (i * 60) || 'ms">'
        || '<div class="r-hd"><div class="ic">' || l_defs(i).ic || '</div><div><h3>' || l_defs(i).t || '</h3><p>' || l_defs(i).d || '</p></div>'
        || '<label class="s-sw"><input type="checkbox" class="r-on"' || CASE WHEN l_r.is_active = 'Y' THEN ' checked' END
        || CASE WHEN l_cnt = 0 AND l_defs(i).k <> 'SPEND_ALERT' THEN ' disabled' END || '><i></i></label></div>'
        || '<div class="r-body">';
      IF l_defs(i).k = 'ROUNDUP' THEN
        l_h := l_h || '<select class="r-p"><option value="0.25"' || CASE WHEN l_r.param_num = 0.25 THEN ' selected' END || '>لأقرب ربع دينار</option>'
          || '<option value="0.5"' || CASE WHEN l_r.param_num = 0.5 THEN ' selected' END || '>لأقرب نصف دينار</option>'
          || '<option value="1"' || CASE WHEN NVL(l_r.param_num, 1) = 1 THEN ' selected' END || '>لأقرب دينار</option></select>';
      ELSE
        l_h := l_h || '<input class="r-p ltr" inputmode="decimal" value="' || NVL(TO_CHAR(l_r.param_num, 'FM99990D999', 'NLS_NUMERIC_CHARACTERS=''.,'''), l_defs(i).dflt)
          || '" placeholder="' || CASE l_defs(i).k WHEN 'PCT_IN' THEN '%' ELSE 'د.أ' END || '" title="'
          || CASE l_defs(i).k WHEN 'PCT_IN' THEN 'النسبة %' ELSE 'المبلغ بالدينار' END || '">';
      END IF;
      IF l_defs(i).k <> 'SPEND_ALERT' THEN
        l_h := l_h || '<select class="r-g">' || REPLACE(l_opts, 'value="' || l_r.goal_id || '"', 'value="' || l_r.goal_id || '" selected') || '</select>';
      END IF;
      l_h := l_h || '<button type="button" class="r-save">حفظ</button></div>'
        || CASE WHEN l_r.fired_count > 0 THEN '<div class="r-stat">✓ اشتغلت ' || l_r.fired_count || ' مرة'
             || CASE WHEN l_r.total_moved > 0 THEN ' · ادّخرت ' || money(l_r.total_moved) || ' د.أ' END || '</div>' END
        || '</div>';
    END LOOP;
    l_h := l_h || '<div class="w-err" id="rErr"></div></section></div>'

      || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)};W.tabs();
  function P(a,x){var p={x01:a};Object.keys(x).forEach(function(k){p[k]=String(x[k])});
    return new Promise(function(res){apex.server.process('WLT_PLUS',p,{success:res,error:function(){res({ok:false,msg:'تعذّر الاتصال. لم يُخصم أي مبلغ.'})}})})}
  setTimeout(function(){document.querySelectorAll('.g-bar i').forEach(function(i){i.style.width=i.dataset.w+'%'})},120);
  function amtSheet(title,sub,btn,run){
    W.sheet('<h3>'+W.esc(title)+'</h3><p class="w-sub">'+W.esc(sub)+'</p><input class="w-in ltr" id="sAmt" inputmode="decimal" placeholder="0.000" style="font-size:28px;text-align:center;font-family:var(--w-mono)">'
      +'<div class="w-chips" style="justify-content:center;margin:10px 0 4px" id="sQuick"><button type="button" class="w-chip" data-v="1">1</button><button type="button" class="w-chip" data-v="5">5</button><button type="button" class="w-chip" data-v="10">10</button><button type="button" class="w-chip" data-v="20">20</button></div>'
      +'<div class="w-err" id="sErr"></div><button class="w-btn" id="sOk" type="button" disabled>'+W.esc(btn)+'</button><div style="height:8px"></div><button class="w-btn ghost" type="button" onclick="W.close()">إلغاء</button>');
    var a=$('sAmt'),ok=$('sOk');W.num(a);a.focus();
    a.addEventListener('input',function(){ok.disabled=!(parseFloat(a.value)>0);W.err('sErr')});
    document.querySelectorAll('#sQuick button').forEach(function(b){b.onclick=function(){a.value=b.dataset.v;ok.disabled=false}});
    ok.onclick=function(){if(W.busy)return;W.busy=true;ok.disabled=true;ok.textContent='جارٍ التنفيذ…';
      run(Number(a.value).toFixed(3)).then(function(r){if(!r.ok){W.busy=false;ok.disabled=false;ok.textContent=btn;W.err('sErr',r.msg)}})}}
  document.querySelectorAll('[data-dep]').forEach(function(b){b.onclick=function(){var idem=W.uuid();
    amtSheet('إيداع في '+b.dataset.n,'من رصيدك الرئيسي إلى الحصّالة','أودِع',function(v){
      return P('dep',{x02:b.dataset.dep,x03:v,x04:idem}).then(function(r){if(r.ok){W.receipt(r,'تمّ الإيداع 🐷',b.dataset.n);var a=document.querySelector('.w-receipt a');if(a)a.href=location.href}return r})})}});
  document.querySelectorAll('[data-wd]').forEach(function(b){b.onclick=function(){var idem=W.uuid();
    amtSheet('سحب من '+b.dataset.n,'المتاح في الحصّالة '+b.dataset.b+' د.أ','اسحب لرصيدي',function(v){
      return P('wd',{x02:b.dataset.wd,x03:v,x04:idem}).then(function(r){if(r.ok){W.receipt(r,'تمّ السحب',b.dataset.n);var a=document.querySelector('.w-receipt a');if(a)a.href=location.href}return r})})}});
  document.querySelectorAll('[data-close]').forEach(function(b){b.onclick=function(){
    W.confirm('إغلاق حصّالة '+b.dataset.n,[['يرجع لرصيدك',b.dataset.b+' د.أ',1]],'أغلق الحصّالة',function(){
      P('close',{x02:b.dataset.close}).then(function(r){r.ok?location.reload():W.fail('gErr',r)})})}});
  var emo='🎯';
  document.querySelectorAll('#sEmo button').forEach(function(b){b.onclick=function(){document.querySelectorAll('#sEmo button').forEach(function(x){x.classList.toggle('on',x===b)});emo=b.dataset.e}});
  var d=new Date();d.setMonth(d.getMonth()+3);$('gDate').min=new Date(Date.now()+864e5).toISOString().slice(0,10);
  function nv(){var t=parseFloat($('gTarget').value),dt=$('gDate').value;$('gGo').disabled=!$('gName').value.trim();W.err('nErr');
    if(t>0&&dt){var days=Math.max(1,Math.ceil((new Date(dt)-new Date())/864e5)),w=Math.max(1,days/7);
      $('gPrev').style.display='flex';$('gPrevT').textContent='لتصل في الموعد ادّخر أسبوعياً';$('gPrevA').textContent=(t/w).toFixed(3)+' د.أ'}
    else $('gPrev').style.display='none'}
  ['gName','gTarget','gDate'].forEach(function(i){$(i).addEventListener('input',nv)});W.num($('gTarget'));
  $('gGo').onclick=function(){var b=this;b.disabled=true;
    P('goal',{x02:$('gName').value,x03:emo,x04:$('gTarget').value?Number($('gTarget').value).toFixed(3):'',x05:$('gDate').value,x06:$('gLock').checked?'Y':'N'}).then(function(r){
      if(r.ok)location.reload();else{b.disabled=false;W.err('nErr',r.msg)}})};
  document.querySelectorAll('.r-card').forEach(function(c){
    var on=c.querySelector('.r-on'),sv=c.querySelector('.r-save');
    function save(active){var g=c.querySelector('.r-g'),p=c.querySelector('.r-p');sv.disabled=true;W.err('rErr');
      return P('rule',{x02:c.dataset.rule,x03:g?g.value:'',x04:p.value,x05:active}).then(function(r){sv.disabled=false;
        if(!r.ok){W.err('rErr',r.msg);on.checked=!on.checked;c.classList.toggle('on',on.checked);return}
        sv.textContent='✓ حُفظت';setTimeout(function(){sv.textContent='حفظ'},1600)})}
    on.addEventListener('change',function(){c.classList.toggle('on',on.checked);save(on.checked?'Y':'N')});
    sv.onclick=function(){save('Y')}});
})();
</script>~';
    RETURN l_h;
  END render_save;

  -- -----------------------------------------------------------------
  -- 15) كود الدفع المؤقت
  -- -----------------------------------------------------------------
  FUNCTION render_code RETURN CLOB IS
    l   wlt_v_wallets%ROWTYPE := me;
    l_h CLOB;
    l_n PLS_INTEGER := 0;
  BEGIN
    l_h := wallet_ui2_pkg.common || css || '<div class="w-app">';
    IF l.user_type = 'MERCHANT' THEN
      l_h := l_h || head('التحصيل بالكود', 'العميل يعطيك كوداً من 8 أرقام، وأنت تخصم المبلغ')
        || '<div class="c-box"><small>اكتب كود العميل</small><input class="w-in c-in" id="mCode" inputmode="numeric" maxlength="9" placeholder="0000 0000" style="background:rgba(255,255,255,.95);margin-top:10px"></div>'
        || '<label class="w-field"><span>المبلغ (د.أ)</span><input class="w-in ltr" id="mAmt" inputmode="decimal" placeholder="0.000" style="font-size:22px"></label>'
        || '<div class="w-err" id="mErr"></div><button class="w-btn" id="mGo" type="button" disabled>اخصم من العميل</button>'
        || '<div class="w-note">الكود صالح لمرة واحدة وبسقف يحدده العميل. بعد 8 محاولات خاطئة يتوقف التحصيل بالكود 10 دقائق لحمايتك.</div>'
        || '<div class="w-sec" style="margin-top:22px"><h2>آخر التحصيلات بالكود</h2></div>';
      FOR c IN (SELECT p.used_amount, p.used_at, u.shown_name FROM wlt_pay_codes p
                  JOIN wlt_v_wallets u ON u.user_id = p.user_id AND u.wallet_type = 'MAIN'
                 WHERE p.used_by = l.user_id ORDER BY p.used_at DESC FETCH FIRST 6 ROWS ONLY) LOOP
        l_n := l_n + 1;
        l_h := l_h || '<div class="w-card2"><div class="t"><div><b>' || esc(c.shown_name) || '</b><small>' || TO_CHAR(c.used_at, 'DD/MM HH24:MI')
          || '</small></div><div class="amt">+' || money(c.used_amount) || '</div></div></div>';
      END LOOP;
      IF l_n = 0 THEN l_h := l_h || '<div class="w-empty">لا تحصيلات بعد</div>'; END IF;
      RETURN l_h || '</div>' || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)},c=$('mCode'),a=$('mAmt'),b=$('mGo'),idem=W.uuid();W.num(a);
  function v(){var d=c.value.replace(/\D/g,'').slice(0,8);c.value=d.length>4?d.slice(0,4)+' '+d.slice(4):d;b.disabled=!(d.length===8&&parseFloat(a.value)>0);W.err('mErr')}
  c.addEventListener('input',v);a.addEventListener('input',v);c.focus();
  b.onclick=function(){var amt=Number(a.value).toFixed(3);
    W.confirm('تحصيل بالكود',[['الكود',c.value],['المبلغ',amt+' د.أ',1]],'اخصم الآن',function(){
      apex.server.process('WLT_PLUS',{x01:'charge',x02:c.value,x03:amt,x04:idem},{success:function(r){
        if(r.ok){W.receipt(r,'تمّ التحصيل ✓','دفع بكود مؤقت');var h=document.querySelector('.w-receipt a');if(h){h.href=location.href;h.textContent='تحصيل جديد'}}
        else{W.fail('mErr',r);idem=W.uuid()}},error:function(){W.fail('mErr',{msg:'تعذّر الاتصال'})}})})};
})();
</script>~';
    END IF;

    l_h := l_h || head('كود الدفع', 'ادفع في المتجر بدون هاتف التاجر وبدون مشاركة رقمك')
      || '<div id="cArea"><div class="c-box" id="cIdle"><div style="font-size:42px;line-height:1">🔐</div>'
      || '<h3 style="font-family:var(--w-disp);margin:8px 0 4px">كود لمرة واحدة</h3><small>8 أرقام تعطيها للتاجر. ينتهي بعد دقائق، ولا يخصم أكثر من السقف</small></div>'
      || '<label class="w-field"><span>أقصى مبلغ مسموح (د.أ)</span><input class="w-in ltr" id="cMax" inputmode="decimal" placeholder="10.000" style="font-size:22px"></label>'
      || '<div class="w-grid" id="cMin" style="grid-template-columns:repeat(4,1fr)"><button class="w-tile" type="button" data-m="2"><b>2</b>دقيقة</button>'
      || '<button class="w-tile" type="button" data-m="5"><b>5</b>دقائق</button><button class="w-tile on" type="button" data-m="10"><b>10</b>دقائق</button>'
      || '<button class="w-tile" type="button" data-m="30"><b>30</b>دقيقة</button></div>'
      || '<div class="w-err" id="cErr"></div><button class="w-btn" id="cGo" type="button" disabled>ولّد الكود</button>'
      || '<div class="w-note">يحمي رصيدك: التاجر لا يرى رصيدك ولا رقمك، والكود يُلغى تلقائياً بعد أول استخدام أو انتهاء الوقت. توليد كود جديد يلغي السابق.</div></div>'
      || '<div class="w-sec" style="margin-top:22px"><h2>آخر الأكواد</h2></div>';
    FOR c IN (SELECT p.*, u.shown_name m FROM wlt_pay_codes p LEFT JOIN wlt_v_wallets u ON u.user_id = p.used_by AND u.wallet_type = 'MAIN'
               WHERE p.user_id = l.user_id ORDER BY p.created_at DESC FETCH FIRST 6 ROWS ONLY) LOOP
      l_n := l_n + 1;
      l_h := l_h || '<div class="w-card2"><div class="t"><div><b>' || CASE c.status WHEN 'USED' THEN 'دُفع لدى ' || esc(c.m) WHEN 'ACTIVE' THEN 'كود فعّال' ELSE 'كود بسقف ' || money(c.max_amount) END
        || '</b><small>' || TO_CHAR(c.created_at, 'DD/MM HH24:MI') || '</small></div><div style="text-align:left">'
        || CASE WHEN c.status = 'USED' THEN '<div class="amt">−' || money(c.used_amount) || '</div>' END
        || '<span class="w-pill ' || CASE c.status WHEN 'USED' THEN 'done' WHEN 'ACTIVE' THEN 'active' ELSE 'expired' END || '">'
        || CASE c.status WHEN 'USED' THEN 'مُستخدم' WHEN 'ACTIVE' THEN 'فعّال' WHEN 'CANCELLED' THEN 'ملغي' ELSE 'منتهي' END
        || '</span></div></div></div>';
    END LOOP;
    IF l_n = 0 THEN l_h := l_h || '<div class="w-empty">لم تولّد أكواداً بعد</div>'; END IF;

    RETURN l_h || '<style>.w-pill{display:inline-block;font-size:11px;font-weight:600;border-radius:999px;padding:1px 9px;background:var(--w-rule)}.w-pill.active{background:#fdf1d6;color:#8a6110}.w-pill.done{background:var(--w-mint-s);color:var(--w-mint)}.w-pill.expired{background:var(--w-red-s);color:var(--w-red)}'
      || '.w-card2{border:1px solid var(--w-rule);background:var(--w-paper);border-radius:18px;padding:14px;margin-bottom:10px}.w-card2 .t{display:flex;justify-content:space-between;gap:10px}.w-card2 small{display:block;color:var(--w-muted);font-size:12px}.w-card2 .amt{font-family:var(--w-mono);font-weight:700;direction:ltr}</style></div>'
      || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)},min=10,timer,poll;W.num($('cMax'));
  $('cMax').addEventListener('input',function(){$('cGo').disabled=!(parseFloat(this.value)>0);W.err('cErr')});
  document.querySelectorAll('#cMin .w-tile').forEach(function(b){b.onclick=function(){document.querySelectorAll('#cMin .w-tile').forEach(function(x){x.classList.toggle('on',x===b)});min=+b.dataset.m}});
  function P(a,x){var p={x01:a};Object.keys(x).forEach(function(k){p[k]=String(x[k])});
    return new Promise(function(res){apex.server.process('WLT_PLUS',p,{success:res,error:function(){res({ok:false,msg:'تعذّر الاتصال'})}})})}
  function show(r){var d=r.code.split(''),h='';d.forEach(function(x,i){if(i===4)h+='<span class="gap"></span>';h+='<span style="animation-delay:'+(i*45)+'ms">'+x+'</span>'});
    $('cArea').innerHTML='<div class="c-box" id="cBox"><small>أعطِ هذا الكود للتاجر</small><div class="c-digits">'+h+'</div>'
      +'<span class="c-max">السقف '+r.max+' د.أ</span><div class="c-ring" id="cRing"><b id="cLeft"></b></div><small id="cState">بانتظار التاجر…</small></div>'
      +'<button class="w-btn ghost" id="cCancel" type="button">إلغاء الكود</button>';
    var end=Date.now()+r.secs*1000,tot=r.secs;
    function tick(){var s=Math.max(0,Math.round((end-Date.now())/1000));$('cLeft').textContent=Math.floor(s/60)+':'+String(s%60).padStart(2,'0');
      $('cRing').style.setProperty('--p',Math.round(s/tot*100));if(s<=0){stop();$('cBox').classList.add('dead');$('cState').textContent='انتهت صلاحية الكود';$('cCancel').textContent='كود جديد';$('cCancel').onclick=function(){location.reload()}}}
    function stop(){clearInterval(timer);clearInterval(poll)}
    tick();timer=setInterval(tick,1000);
    poll=setInterval(function(){P('cstat',{x02:r.id}).then(function(s){if(!s.ok||s.status==='ACTIVE')return;stop();
      if(s.status==='USED'){$('cBox').classList.add('used');$('cBox').innerHTML='<div style="font-size:46px">✓</div><h3 style="font-family:var(--w-disp);margin:6px 0">دفعت '+s.amount+' د.أ</h3><small>لدى '+W.esc(s.merchant)+'</small>';
        $('cCancel').textContent='تمّ';$('cCancel').onclick=function(){location.reload()}}
      else{$('cBox').classList.add('dead');$('cState').textContent='الكود لم يعد صالحاً'}})},2500);
    $('cCancel').onclick=function(){stop();P('cancel',{x02:r.id}).then(function(){location.reload()})}}
  $('cGo').onclick=function(){var b=this;b.disabled=true;
    P('newcode',{x02:Number($('cMax').value).toFixed(3),x03:min}).then(function(r){if(r.ok)show(r);else{b.disabled=false;W.err('cErr',r.msg)}})};
})();
</script>~';
  END render_code;

  -- -----------------------------------------------------------------
  -- 16) العائلة: محافظ الأبناء
  -- -----------------------------------------------------------------
  FUNCTION render_family RETURN CLOB IS
    l      wlt_v_wallets%ROWTYPE := me;
    l_h    CLOB;
    l_n    PLS_INTEGER := 0;
    l_sp   NUMBER;
    l_pct  NUMBER;
    l_cats VARCHAR2(4000);
    l_c    wlt_child_links%ROWTYPE;
    l_pn   VARCHAR2(200);
  BEGIN
    l_h := wallet_ui2_pkg.common || css || '<div class="w-app">';

    -- الابن يرى ضوابطه فقط
    IF wallet_family_pkg.is_child(l.user_id) THEN
      SELECT * INTO l_c FROM wlt_child_links WHERE child_user_id = l.user_id;
      SELECT shown_name INTO l_pn FROM wlt_v_wallets WHERE user_id = l_c.parent_user_id AND wallet_type = 'MAIN';
      SELECT NVL(SUM(amount), 0) INTO l_sp FROM wlt_transactions
       WHERE from_wallet_id = l.wallet_id AND status = 'COMPLETED' AND created_at >= TRUNC(SYSDATE)
         AND txn_type NOT IN ('SAVE','ROUNDUP')
         AND to_wallet_id NOT IN (SELECT pw.wallet_id FROM wlt_wallets pw WHERE pw.user_id = l_c.parent_user_id);
      l_pct := CASE WHEN l_c.daily_limit > 0 THEN LEAST(100, ROUND(l_sp / l_c.daily_limit * 100)) ELSE 100 END;
      RETURN l_h || head('محفظتي العائلية', 'يديرها ' || l_pn)
        || '<div class="f-me"><div class="g-row"><span>صرفت اليوم</span><span>المسموح ' || money(l_c.daily_limit) || ' د.أ</span></div>'
        || '<div style="font-family:var(--w-mono);font-size:30px;font-weight:700;direction:ltr;text-align:right;margin:6px 0">' || money(l_sp) || '</div>'
        || '<div class="g-bar"><i data-w="' || l_pct || '"></i></div>'
        || '<div class="g-row"><span>المتبقي اليوم</span><b>' || money(GREATEST(l_c.daily_limit - l_sp, 0)) || ' د.أ</b></div></div>'
        || '<div class="f-tags">'
        || CASE WHEN l_c.paused = 'Y' THEN '<span class="no">⏸ الصرف موقوف مؤقتاً</span>' ELSE '<span class="yes">▶ المحفظة فعّالة</span>' END
        || '<span class="' || CASE l_c.allow_p2p WHEN 'Y' THEN 'yes">✓' ELSE 'no">✕' END || ' التحويل للأصدقاء</span>'
        || '<span class="' || CASE l_c.allow_cash WHEN 'Y' THEN 'yes">✓' ELSE 'no">✕' END || ' السحب النقدي</span>'
        || CASE WHEN l_c.blocked_cats IS NOT NULL THEN '<span class="no">✕ ' || esc(REPLACE(l_c.blocked_cats, ':', '، ')) || '</span>' END
        || '</div><div class="w-note">التحويل لولي أمرك مسموح دائماً. ادّخر من مصروفك في «الحصّالات» 🐷</div></div>'
        || '<script>setTimeout(function(){document.querySelectorAll(".g-bar i").forEach(function(i){i.style.width=i.dataset.w+"%"})},120)</script>';
    END IF;

    l_h := l_h || head('العائلة', 'محافظ لأبنائك بمصروف وضوابط أنت تحددها')
      || '<div class="w-tabs"><button type="button" class="on" data-p="pKids">أبنائي</button><button type="button" data-p="pAdd">إضافة ابن / ابنة</button></div>'
      || '<section class="w-pane on" id="pKids">';

    FOR k IN (SELECT DISTINCT category FROM wlt_merchant_profiles ORDER BY category) LOOP
      l_cats := l_cats || '<button type="button" data-cat="' || esc(k.category) || '">' || esc(k.category) || '</button>';
    END LOOP;

    FOR c IN (SELECT c.*, w.wallet_id, w.balance, w.shown_name, w.phone,
                     (SELECT NVL(SUM(x.amount), 0) FROM wlt_transactions x
                       WHERE x.from_wallet_id = w.wallet_id AND x.status = 'COMPLETED' AND x.created_at >= TRUNC(SYSDATE)
                         AND x.txn_type NOT IN ('SAVE','ROUNDUP')
                         AND x.to_wallet_id NOT IN (SELECT pw.wallet_id FROM wlt_wallets pw WHERE pw.user_id = c.parent_user_id)) AS spent,
                     (SELECT COUNT(*) FROM wlt_scheduled_transfers s
                       WHERE s.from_user_id = c.parent_user_id AND s.to_user_id = c.child_user_id AND s.status = 'ACTIVE') AS weekly
                FROM wlt_child_links c JOIN wlt_v_wallets w ON w.user_id = c.child_user_id AND w.wallet_type = 'MAIN'
               WHERE c.parent_user_id = l.user_id ORDER BY c.created_at) LOOP
      l_n := l_n + 1;
      l_pct := CASE WHEN c.daily_limit > 0 THEN LEAST(100, ROUND(c.spent / c.daily_limit * 100)) ELSE 100 END;
      l_h := l_h || '<div class="f-kid" style="animation-delay:' || (l_n * 60) || 'ms"><div class="f-top">'
        || '<div class="f-av">' || esc(SUBSTR(c.shown_name, 1, 1)) || '</div><div><h3>' || esc(c.shown_name) || '</h3><small>' || c.phone || '</small></div>'
        || '<div class="f-bal"><b>' || money(c.balance) || '</b><span>الرصيد</span></div></div><div class="f-body">'
        || '<div class="g-row" style="margin-top:12px"><span>صرف اليوم ' || money(c.spent) || '</span><span>من ' || money(c.daily_limit) || ' د.أ</span></div>'
        || '<div class="g-bar" style="margin-top:6px"><i data-w="' || l_pct || '"' || CASE WHEN l_pct >= 90 THEN ' style="background:var(--w-red)"' END || '></i></div>'
        || '<div class="f-tags">'
        || CASE WHEN c.paused = 'Y' THEN '<span class="no">⏸ موقوفة</span>' ELSE '<span class="yes">▶ فعّالة</span>' END
        || '<span class="' || CASE c.allow_p2p WHEN 'Y' THEN 'yes">✓' ELSE 'no">✕' END || ' تحويل</span>'
        || '<span class="' || CASE c.allow_cash WHEN 'Y' THEN 'yes">✓' ELSE 'no">✕' END || ' سحب نقدي</span>'
        || CASE WHEN c.blocked_cats IS NOT NULL THEN '<span class="no">✕ ' || esc(REPLACE(c.blocked_cats, ':', '، ')) || '</span>' END
        || CASE WHEN c.weekly > 0 THEN '<span class="yes">🗓 مصروف أسبوعي</span>' END
        || '</div><div class="g-acts" style="margin-top:4px">'
        || '<button type="button" class="go" data-allow="' || c.child_user_id || '" data-n="' || esc(c.shown_name) || '">💸 مصروف</button>'
        || '<button type="button" data-ctrl="' || c.child_user_id || '" data-n="' || esc(c.shown_name) || '" data-d="' || money(c.daily_limit)
        || '" data-f="' || c.allow_p2p || c.allow_cash || c.paused || c.notify_parent || '" data-b="' || esc(c.blocked_cats) || '">⚙️ الضوابط</button>'
        || '<button type="button" class="more" data-week="' || c.child_user_id || '" data-n="' || esc(c.shown_name) || '" title="مصروف أسبوعي">🗓</button>'
        || '</div></div></div>';
    END LOOP;
    IF l_n = 0 THEN
      l_h := l_h || '<div class="w-empty">👨‍👩‍👧 لا توجد محافظ أبناء بعد.<br>أضف ابنك أو ابنتك برقم هاتفه.</div>';
    END IF;

    l_h := l_h || '<div class="w-err" id="kErr"></div></section>'
      || '<section class="w-pane" id="pAdd"><div class="f-steps"><i class="on" id="st1"></i><i id="st2"></i><i id="st3"></i></div>'
      || '<div id="a1"><label class="w-field"><span>رقم هاتف الابن / الابنة</span><input class="w-in ltr" id="aPh" inputmode="tel" placeholder="07X XXX XXXX" style="font-size:22px"></label>'
      || '<div class="w-err" id="aErr1"></div><button class="w-btn" id="aSend" type="button" disabled>أرسل رمز التفعيل</button>'
      || '<div class="w-note">يصل رمز لهاتف الابن للتأكد أن الرقم بيده. الرقم يجب أن يكون غير مسجّل في المحفظة.</div></div>'
      || '<div id="a2" style="display:none"><p class="w-sub" style="text-align:center">اكتب الرمز الذي وصل إلى <b id="aPhS" style="direction:ltr;display:inline-block"></b></p>'
      || '<div class="f-otp" id="aOtp">' || '<input maxlength="1" inputmode="numeric"><input maxlength="1" inputmode="numeric"><input maxlength="1" inputmode="numeric"><input maxlength="1" inputmode="numeric"><input maxlength="1" inputmode="numeric"><input maxlength="1" inputmode="numeric">' || '</div>'
      || '<div class="w-err" id="aErr2"></div><button class="w-btn ghost" id="aBack" type="button">تغيير الرقم</button></div>'
      || '<div id="a3" style="display:none"><label class="w-field"><span>الاسم</span><input class="w-in" id="aName" maxlength="40" placeholder="مثلاً: سارة"></label>'
      || '<label class="w-field"><span>رمز سري للابن (4 أرقام)</span><input class="w-in ltr" id="aPin" type="password" inputmode="numeric" maxlength="4" style="letter-spacing:.5em;font-size:22px"></label>'
      || '<label class="w-field"><span>المصروف اليومي المسموح (د.أ)</span><input class="w-in ltr" id="aDaily" inputmode="decimal" value="5.000"></label>'
      || '<div class="w-err" id="aErr3"></div><button class="w-btn" id="aGo" type="button" disabled>أنشئ المحفظة</button>'
      || '<div class="w-note">الابن يدخل برقمه ورمزه. افتراضياً: التحويل للأصدقاء والسحب النقدي مغلقان، ويصلك إشعار بكل عملية صرف.</div></div>'
      || '</section></div><div class="f-sms" id="aSms"></div>'
      || '<template id="catTpl">' || l_cats || '</template>'
      || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)},ph='',ticket='';W.tabs();
  setTimeout(function(){document.querySelectorAll('.g-bar i').forEach(function(i){i.style.width=i.dataset.w+'%'})},120);
  function P(a,x){var p={x01:a};Object.keys(x).forEach(function(k){p[k]=String(x[k])});
    return new Promise(function(res){apex.server.process('WLT_PLUS',p,{success:res,error:function(){res({ok:false,msg:'تعذّر الاتصال'})}})})}
  function step(n){[1,2,3].forEach(function(i){$('a'+i).style.display=i===n?'block':'none';$('st'+i).classList.toggle('on',i<=n)})}
  function norm(v){v=v.replace(/[٠-٩]/g,function(d){return '٠١٢٣٤٥٦٧٨٩'.indexOf(d)}).replace(/\D/g,'');
    if(v.indexOf('00962')===0)v=v.slice(5);else if(v.indexOf('962')===0&&v.length===12)v=v.slice(3);if(v.length===9&&v[0]==='7')v='0'+v;return v}
  $('aPh').addEventListener('input',function(){$('aSend').disabled=!/^07[789]\d{7}$/.test(norm(this.value));W.err('aErr1')});
  function sms(t){var s=$('aSms');s.innerHTML='<small>رسالة نصية · وضع التجربة</small>'+W.esc(t).replace(/(\d{6})/,'<b>$1</b>');s.classList.add('on');setTimeout(function(){s.classList.remove('on')},9000)}
  $('aSend').onclick=function(){var b=this;b.disabled=true;ph=norm($('aPh').value);
    P('childotp',{x02:ph}).then(function(r){b.disabled=false;if(!r.ok){W.err('aErr1',r.msg);return}
      $('aPhS').textContent=ph;step(2);if(r.sms)sms(r.sms);var f=document.querySelector('#aOtp input');f.focus()})};
  $('aBack').onclick=function(){step(1)};
  var boxes=[].slice.call(document.querySelectorAll('#aOtp input'));
  boxes.forEach(function(x,i){x.addEventListener('input',function(){x.value=x.value.replace(/\D/g,'');if(x.value&&i<5)boxes[i+1].focus();W.err('aErr2');
      var code=boxes.map(function(y){return y.value}).join('');if(code.length===6)P('childverify',{x02:ph,x03:code}).then(function(r){
        if(r.ok){ticket=r.ticket;step(3);$('aName').focus()}else{W.err('aErr2',r.msg);boxes.forEach(function(y){y.value=''});boxes[0].focus()}})});
    x.addEventListener('keydown',function(e){if(e.key==='Backspace'&&!x.value&&i>0)boxes[i-1].focus()})});
  function v3(){$('aGo').disabled=!($('aName').value.trim()&&/^\d{4}$/.test($('aPin').value)&&parseFloat($('aDaily').value)>=0);W.err('aErr3')}
  ['aName','aPin','aDaily'].forEach(function(i){$(i).addEventListener('input',v3)});W.num($('aDaily'));
  $('aGo').onclick=function(){var b=this;b.disabled=true;
    P('addchild',{x02:ph,x03:ticket,x04:$('aName').value,x05:$('aPin').value,x06:Number($('aDaily').value).toFixed(3)}).then(function(r){
      if(r.ok)location.reload();else{b.disabled=false;W.err('aErr3',r.msg)}})};

  function amt(title,sub,btn,run){
    W.sheet('<h3>'+W.esc(title)+'</h3><p class="w-sub">'+sub+'</p><input class="w-in ltr" id="sAmt" inputmode="decimal" placeholder="0.000" style="font-size:28px;text-align:center;font-family:var(--w-mono)">'
      +'<div class="w-chips" style="justify-content:center;margin:10px 0 4px" id="sQuick"><button type="button" class="w-chip" data-v="1">1</button><button type="button" class="w-chip" data-v="2">2</button><button type="button" class="w-chip" data-v="5">5</button><button type="button" class="w-chip" data-v="10">10</button></div>'
      +'<div class="w-err" id="sErr"></div><button class="w-btn" id="sOk" type="button" disabled>'+W.esc(btn)+'</button><div style="height:8px"></div><button class="w-btn ghost" type="button" onclick="W.close()">إلغاء</button>');
    var a=$('sAmt'),ok=$('sOk');W.num(a);a.focus();
    a.addEventListener('input',function(){ok.disabled=!(parseFloat(a.value)>0);W.err('sErr')});
    document.querySelectorAll('#sQuick button').forEach(function(b){b.onclick=function(){a.value=b.dataset.v;ok.disabled=false}});
    ok.onclick=function(){if(W.busy)return;W.busy=true;ok.disabled=true;ok.textContent='جارٍ التنفيذ…';
      run(Number(a.value).toFixed(3)).then(function(r){if(!r.ok){W.busy=false;ok.disabled=false;ok.textContent=btn;W.err('sErr',r.msg)}})}}
  document.querySelectorAll('[data-allow]').forEach(function(b){b.onclick=function(){var idem=W.uuid();
    amt('مصروف لـ '+b.dataset.n,'يصل فوراً لمحفظته','أرسل المصروف',function(v){
      return P('allow',{x02:b.dataset.allow,x03:v,x04:idem}).then(function(r){if(r.ok){W.receipt(r,'وصل المصروف 💸',b.dataset.n);var h=document.querySelector('.w-receipt a');if(h)h.href=location.href}return r})})}});
  document.querySelectorAll('[data-week]').forEach(function(b){b.onclick=function(){
    amt('مصروف أسبوعي لـ '+b.dataset.n,'يُحوَّل تلقائياً كل أسبوع الساعة 8 صباحاً، ويمكنك إيقافه من «مجدولة»','فعّل المصروف الأسبوعي',function(v){
      return P('weekly',{x02:b.dataset.week,x03:v}).then(function(r){if(r.ok){W.close();location.reload()}return r})})}});
  document.querySelectorAll('[data-ctrl]').forEach(function(b){b.onclick=function(){
    var f=b.dataset.f,blk=(b.dataset.b||'').split(':').filter(Boolean);
    function sw(id,t,s,on){return '<label class="s-sw"><div><b>'+t+'</b><small>'+s+'</small></div><input type="checkbox" id="'+id+'"'+(on?' checked':'')+'><i></i></label>'}
    W.sheet('<h3>ضوابط '+W.esc(b.dataset.n)+'</h3>'
      +'<label class="w-field"><span>المصروف اليومي (د.أ)</span><input class="w-in ltr" id="cD" inputmode="decimal" value="'+b.dataset.d+'"></label>'
      +sw('cP','التحويل للأصدقاء','التحويل لك مسموح دائماً',f[0]==='Y')+sw('cC','السحب النقدي','من الوكلاء',f[1]==='Y')
      +sw('cS','⏸ إيقاف الصرف مؤقتاً','يتوقف كل صرف حتى تعيد التفعيل',f[2]==='Y')+sw('cN','🔔 إشعار بكل عملية صرف','',f[3]==='Y')
      +'<p class="w-sub" style="margin:4px 0 8px">امنع الدفع لهذه المتاجر:</p><div class="f-cats" id="cCats">'+$('catTpl').innerHTML+'</div>'
      +'<div class="w-err" id="cErr"></div><button class="w-btn" id="cOk" type="button">احفظ الضوابط</button><div style="height:8px"></div><button class="w-btn ghost" type="button" onclick="W.close()">إلغاء</button>');
    document.querySelectorAll('#cCats button').forEach(function(x){if(blk.indexOf(x.dataset.cat)>=0)x.classList.add('on');x.onclick=function(){x.classList.toggle('on')}});
    W.num($('cD'));
    $('cOk').onclick=function(){var o=this;o.disabled=true;
      var fl=['cP','cC','cS','cN'].map(function(i){return $(i).checked?'Y':'N'}).join(''),cats=[].slice.call(document.querySelectorAll('#cCats button.on')).map(function(x){return x.dataset.cat}).join(':');
      P('ctrl',{x02:b.dataset.ctrl,x03:Number($('cD').value).toFixed(3),x04:fl,x05:cats}).then(function(r){if(r.ok)location.reload();else{o.disabled=false;W.err('cErr',r.msg)}})}}});
})();
</script>~';
    RETURN l_h;
  END render_family;

  -- -----------------------------------------------------------------
  PROCEDURE receipt (p_ref VARCHAR2) IS
    l_t wlt_transactions%ROWTYPE;
    l   wlt_v_wallets%ROWTYPE := me;
  BEGIN
    SELECT * INTO l_t FROM wlt_transactions WHERE txn_ref = p_ref;
    apex_json.open_object;
    apex_json.write('ok', TRUE);
    apex_json.write('ref', p_ref);
    apex_json.write('amount', money(l_t.amount));
    apex_json.write('fee', money(CASE WHEN l_t.from_wallet_id = l.wallet_id THEN l_t.fee ELSE 0 END));
    apex_json.write('balance', money(l.available_balance));
    apex_json.write('time', TO_CHAR(l_t.created_at, 'DD/MM/YYYY HH24:MI'));
    apex_json.write('home', apex_page.get_url(p_page => 1));
    apex_json.close_object;
  END receipt;

  PROCEDURE api IS
    a    VARCHAR2(20)   := apex_application.g_x01;
    x2   VARCHAR2(4000) := apex_application.g_x02;
    x3   VARCHAR2(4000) := apex_application.g_x03;
    x4   VARCHAR2(4000) := apex_application.g_x04;
    x5   VARCHAR2(4000) := apex_application.g_x05;
    x6   VARCHAR2(4000) := apex_application.g_x06;
    u    VARCHAR2(20)   := v('APP_USER');
    l_s  VARCHAR2(400);
    l_s2 VARCHAR2(400);
    l_n  NUMBER;
    l_c  wlt_pay_codes%ROWTYPE;
    l_m  VARCHAR2(200);
    l_msg VARCHAR2(4000);
    FUNCTION num (p VARCHAR2) RETURN NUMBER IS
    BEGIN RETURN TO_NUMBER(p, '999999990D999', 'NLS_NUMERIC_CHARACTERS=''.,'''); END;
    PROCEDURE ok IS BEGIN apex_json.open_object; apex_json.write('ok', TRUE); END;
  BEGIN
    CASE a
      WHEN 'goal'  THEN
        l_n := wallet_save_pkg.create_goal(u, x2, x3, CASE WHEN x4 IS NOT NULL THEN num(x4) END,
                                           CASE WHEN x5 IS NOT NULL THEN TO_DATE(x5, 'YYYY-MM-DD') END, x6);
        ok; apex_json.close_object;
      WHEN 'dep'   THEN receipt(wallet_save_pkg.deposit(u, TO_NUMBER(x2), num(x3), x4));
      WHEN 'wd'    THEN receipt(wallet_save_pkg.withdraw(u, TO_NUMBER(x2), num(x3), x4));
      WHEN 'close' THEN wallet_save_pkg.close_goal(u, TO_NUMBER(x2)); ok; apex_json.close_object;
      WHEN 'rule'  THEN
        wallet_save_pkg.set_rule(u, x2, CASE WHEN x3 IS NOT NULL THEN TO_NUMBER(x3) END, num(x4), x5);
        ok; apex_json.close_object;

      WHEN 'newcode' THEN
        wallet_paycode_pkg.new_code(u, num(x2), TO_NUMBER(x3), l_s, l_n);
        ok; apex_json.write('code', l_s); apex_json.write('id', l_n);
        apex_json.write('max', money(num(x2))); apex_json.write('secs', TO_NUMBER(x3) * 60);
        apex_json.close_object;
      WHEN 'cancel'  THEN wallet_paycode_pkg.cancel_code(u, TO_NUMBER(x2)); ok; apex_json.close_object;
      WHEN 'cstat'   THEN
        SELECT p.* INTO l_c FROM wlt_pay_codes p JOIN wlt_users w ON w.user_id = p.user_id
         WHERE p.code_id = TO_NUMBER(x2) AND w.phone = u;
        IF l_c.status = 'ACTIVE' AND l_c.expires_at < SYSTIMESTAMP THEN l_c.status := 'EXPIRED'; END IF;
        IF l_c.used_by IS NOT NULL THEN
          SELECT shown_name INTO l_m FROM wlt_v_wallets WHERE user_id = l_c.used_by AND wallet_type = 'MAIN';
        END IF;
        ok; apex_json.write('status', l_c.status); apex_json.write('amount', money(l_c.used_amount));
        apex_json.write('merchant', l_m); apex_json.close_object;
      WHEN 'charge'  THEN receipt(wallet_paycode_pkg.charge(u, x2, num(x3), x4));

      WHEN 'childotp' THEN
        wallet_otp_pkg.request_code(x2, 'CHILD', l_s, l_s2);
        ok; apex_json.write('sms', l_s2); apex_json.close_object;
      WHEN 'childverify' THEN
        l_s := wallet_otp_pkg.verify_code(x2, 'CHILD', x3);
        ok; apex_json.write('ticket', l_s); apex_json.close_object;
      WHEN 'addchild' THEN
        l_n := wallet_family_pkg.add_child(u, x2, x3, x4, x5, num(x6));
        ok; apex_json.close_object;
      WHEN 'ctrl' THEN
        wallet_family_pkg.set_controls(u, TO_NUMBER(x2), num(x3), SUBSTR(x4, 1, 1), SUBSTR(x4, 2, 1),
                                       x5, SUBSTR(x4, 3, 1), SUBSTR(x4, 4, 1));
        ok; apex_json.close_object;
      WHEN 'allow'  THEN receipt(wallet_family_pkg.send_allowance(u, TO_NUMBER(x2), num(x3), x4));
      WHEN 'weekly' THEN l_n := wallet_family_pkg.weekly_allowance(u, TO_NUMBER(x2), num(x3), NULL); ok; apex_json.close_object;
      ELSE RAISE_APPLICATION_ERROR(-20199, 'عملية غير معروفة');
    END CASE;
  EXCEPTION WHEN OTHERS THEN
    l_msg := CASE WHEN SQLCODE BETWEEN -20999 AND -20000
                  THEN REGEXP_REPLACE(REGEXP_SUBSTR(SQLERRM, '^[^' || CHR(10) || ']+'), '^ORA-\d+: ', '')
                  WHEN SQLCODE IN (-6502, -1722, -1830, -1843, -1847, -1858) THEN 'تحقق من القيم المدخلة'
                  WHEN SQLCODE = 100 THEN 'غير موجود'
                  ELSE 'حدث خطأ غير متوقع. لم يُخصم أي مبلغ.' END;
    apex_json.open_object;
    apex_json.write('ok', FALSE);
    apex_json.write('msg', l_msg);
    apex_json.close_object;
  END api;

END wallet_ui5_pkg;
/

-- قائمة «المزيد» في الرئيسية: الحصّالات وكود الدفع والعائلة
DECLARE
  l CLOB;
  c_old CONSTANT VARCHAR2(200) := q'#'<nav class="w-more">'#';
BEGIN
  FOR r IN (SELECT text FROM user_source WHERE name = 'WALLET_UI3_PKG' AND type = 'PACKAGE BODY' ORDER BY line) LOOP
    l := l || r.text;
  END LOOP;
  IF INSTR(l, 'p_page => 14') = 0 THEN
    IF INSTR(l, c_old) = 0 THEN RAISE_APPLICATION_ERROR(-20000, 'more_actions anchor'); END IF;
    l := REPLACE(l, c_old, c_old || CHR(10)
      || q'#      || '<a href="' || apex_page.get_url(p_page => 14) || '"><span>🐷</span>الحصّالات</a>'#' || CHR(10)
      || q'#      || '<a href="' || apex_page.get_url(p_page => 15) || '"><span>🔐</span>' || CASE WHEN l.user_type = 'MERCHANT' THEN 'تحصيل بكود' ELSE 'كود الدفع' END || '</a>'#' || CHR(10)
      || q'#      || '<a href="' || apex_page.get_url(p_page => 16) || '"><span>👨‍👩‍👧</span>العائلة</a>'#');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE ' || l;
  END IF;
END;
/
