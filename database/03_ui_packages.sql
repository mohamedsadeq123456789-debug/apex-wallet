-- =====================================================================
--  محفظتي · الجلسة 3 · حزم الدخول والواجهة
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) الدخول: رقم الهاتف + PIN، وقفل 15 دقيقة بعد 5 محاولات خاطئة
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE wallet_auth_pkg AS
  FUNCTION authenticate (p_username IN VARCHAR2, p_password IN VARCHAR2) RETURN BOOLEAN;
END wallet_auth_pkg;
/

CREATE OR REPLACE PACKAGE BODY wallet_auth_pkg AS
  c_max_attempts CONSTANT PLS_INTEGER := 5;

  FUNCTION authenticate (p_username IN VARCHAR2, p_password IN VARCHAR2) RETURN BOOLEAN IS
    PRAGMA AUTONOMOUS_TRANSACTION;   -- عدّاد المحاولات يُحفظ حتى لو فشل الدخول
    l_u     wlt_users%ROWTYPE;
    l_hash  VARCHAR2(64);
  BEGIN
    SELECT * INTO l_u FROM wlt_users
     WHERE phone = TRIM(p_username) AND user_type <> 'SYSTEM'
       FOR UPDATE;

    IF l_u.status <> 'ACTIVE' OR l_u.locked_until > SYSTIMESTAMP THEN
      ROLLBACK;
      RETURN FALSE;
    END IF;

    SELECT RAWTOHEX(STANDARD_HASH(l_u.pin_salt || p_password, 'SHA256')) INTO l_hash FROM dual;

    IF l_hash = l_u.pin_hash THEN
      UPDATE wlt_users SET failed_pin_attempts = 0, locked_until = NULL WHERE user_id = l_u.user_id;
      INSERT INTO wlt_audit_log (actor_user_id, action, entity, entity_id)
      VALUES (l_u.user_id, 'LOGIN', 'USER', l_u.user_id);
      COMMIT;
      RETURN TRUE;
    END IF;

    IF l_u.failed_pin_attempts + 1 >= c_max_attempts THEN
      UPDATE wlt_users SET failed_pin_attempts = 0,
                           locked_until = SYSTIMESTAMP + INTERVAL '15' MINUTE
       WHERE user_id = l_u.user_id;
      INSERT INTO wlt_audit_log (actor_user_id, action, entity, entity_id, details)
      VALUES (l_u.user_id, 'LOCKED', 'USER', l_u.user_id, '5 محاولات خاطئة: قفل 15 دقيقة');
    ELSE
      UPDATE wlt_users SET failed_pin_attempts = failed_pin_attempts + 1 WHERE user_id = l_u.user_id;
      INSERT INTO wlt_audit_log (actor_user_id, action, entity, entity_id)
      VALUES (l_u.user_id, 'LOGIN_FAILED', 'USER', l_u.user_id);
    END IF;
    COMMIT;
    RETURN FALSE;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      ROLLBACK;
      RETURN FALSE;
  END authenticate;
END wallet_auth_pkg;
/


-- ---------------------------------------------------------------------
-- 2) الواجهة: كل صفحة تُرسم من هنا كـHTML، والتفاعل عبر Ajax
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE wallet_ui_pkg AS
  FUNCTION styles        RETURN CLOB;   -- التصميم العام (منطقة في الصفحة 0)
  FUNCTION render_home   RETURN CLOB;   -- الصفحة 1
  FUNCTION render_send   RETURN CLOB;   -- الصفحة 2
  PROCEDURE ajax_lookup;                -- اسم المستلم قبل التحويل
  PROCEDURE ajax_transfer;              -- تنفيذ التحويل
END wallet_ui_pkg;
/

CREATE OR REPLACE PACKAGE BODY wallet_ui_pkg AS

  FUNCTION esc (p VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN apex_escape.html(p);
  END esc;

  FUNCTION money (p NUMBER) RETURN VARCHAR2 IS
  BEGIN
    RETURN TO_CHAR(p, 'FM999G999G990D000', 'NLS_NUMERIC_CHARACTERS=''.,''');
  END money;

  FUNCTION my_wallet RETURN NUMBER IS
  BEGIN
    RETURN wallet_core_pkg.main_wallet(v('APP_USER'));
  END my_wallet;

  FUNCTION app_name RETURN VARCHAR2 IS
    l VARCHAR2(400);
  BEGIN
    SELECT setting_value INTO l FROM wlt_app_settings WHERE setting_key = 'APP_NAME';
    RETURN l;
  EXCEPTION WHEN NO_DATA_FOUND THEN RETURN 'محفظتي';
  END app_name;

  FUNCTION rel_time (p TIMESTAMP) RETURN VARCHAR2 IS
    l_min NUMBER := ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(p AS DATE)) * 1440);
  BEGIN
    RETURN CASE
      WHEN l_min < 1    THEN 'الآن'
      WHEN l_min < 60   THEN 'قبل ' || l_min || ' د'
      WHEN l_min < 1440 THEN 'قبل ' || ROUND(l_min / 60) || ' س'
      ELSE TO_CHAR(p, 'DD/MM HH24:MI') END;
  END rel_time;

  -- -----------------------------------------------------------------
  FUNCTION styles RETURN CLOB IS
  BEGIN
    RETURN q'~
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Alexandria:wght@400;600;800&family=IBM+Plex+Sans+Arabic:wght@400;500;600&family=JetBrains+Mono:wght@500;700&display=swap">
<style>
:root{--w-bg:#eef1ec;--w-paper:#fbfcf8;--w-ink:#0f1c1a;--w-muted:#66746f;--w-rule:#dbe3dd;
 --w-g9:#0a2622;--w-g8:#0f3a33;--w-g7:#155447;--w-mint:#0e7a63;--w-mint-s:#dcefe8;
 --w-gold:#e9c56f;--w-gold-d:#b8861b;--w-red:#c0472f;--w-red-s:#fbe7e2;
 --w-disp:"Alexandria","IBM Plex Sans Arabic",Tahoma,sans-serif;
 --w-body:"IBM Plex Sans Arabic",Tahoma,sans-serif;--w-mono:"JetBrains Mono",ui-monospace,monospace}
/* إخفاء هيكل APEX الافتراضي: التطبيق يرسم واجهته بنفسه */
.t-Header,.t-Footer,.t-Body-title,.t-Breadcrumb-region,.t-Body-nav,.t-Body-actions{display:none!important}
.t-Body-main,.t-Body-content,.t-Body-contentInner,.t-Body{margin:0!important;padding:0!important;background:transparent!important;min-height:0}
.t-Body-wrap,.t-PageBody{padding-top:0!important}
html,body,.t-PageBody{background:var(--w-bg)!important}
body{font-family:var(--w-body)!important;color:var(--w-ink)}
.w-app{direction:rtl;max-width:460px;margin:0 auto;padding:18px 16px 40px;font-family:var(--w-body);color:var(--w-ink);font-size:15px;line-height:1.6}
.w-app *{box-sizing:border-box}
.w-top{display:flex;align-items:center;justify-content:space-between;margin-bottom:16px}
.w-hello{font-size:13px;color:var(--w-muted)}
.w-hello b{display:block;font-family:var(--w-disp);font-size:20px;color:var(--w-ink);font-weight:800}
.w-icon-btn{width:42px;height:42px;border-radius:14px;background:var(--w-paper);border:1px solid var(--w-rule);display:grid;place-items:center;color:var(--w-ink);text-decoration:none}
.w-icon-btn:hover{background:#fff}
.w-icon-btn svg{width:20px;height:20px}
/* البطاقة */
.w-card{position:relative;border-radius:22px;padding:22px 22px 18px;color:#f3efe2;overflow:hidden;
 background:linear-gradient(135deg,var(--w-g9),var(--w-g7) 70%,var(--w-g9));box-shadow:0 22px 40px -18px rgba(5,40,32,.55);
 transform:perspective(900px) rotateX(3deg);animation:w-in .6s cubic-bezier(.2,.8,.2,1) both}
.w-card::before{content:"";position:absolute;inset:0;background:repeating-linear-gradient(115deg,transparent 0 14px,rgba(255,255,255,.035) 14px 15px),radial-gradient(120% 80% at 100% 0%,rgba(233,197,111,.28),transparent 60%);pointer-events:none}
.w-card::after{content:"";position:absolute;inset:-40%;background:linear-gradient(100deg,transparent 40%,rgba(255,255,255,.18) 50%,transparent 60%);transform:translateX(-60%);animation:w-shine 2.6s .5s ease-out 1 both;pointer-events:none}
.w-card>*{position:relative;z-index:1}
.w-card-top{display:flex;justify-content:space-between;align-items:center}
.w-brand{font-family:var(--w-disp);font-weight:800;font-size:17px}
.w-chip{width:40px;height:30px;border-radius:7px;background:linear-gradient(135deg,#ecca76,#a8791a)}
.w-lbl{font-size:12px;opacity:.75;margin-top:18px}
.w-bal{font-family:var(--w-mono);font-size:34px;font-weight:700;direction:ltr;text-align:right;line-height:1.15;font-variant-numeric:tabular-nums}
.w-bal small{font-family:var(--w-body);font-size:14px;opacity:.75;margin-left:6px}
.w-eye{background:none;border:0;color:inherit;opacity:.7;cursor:pointer;padding:0;vertical-align:middle}
.w-card-bot{display:flex;justify-content:space-between;align-items:flex-end;margin-top:18px;font-size:12px}
.w-pan{font-family:var(--w-mono);letter-spacing:.14em;direction:ltr;opacity:.85}
.w-tier{background:rgba(233,197,111,.18);color:var(--w-gold);border:1px solid rgba(233,197,111,.35);padding:2px 10px;border-radius:999px;font-weight:600}
.w-limit{margin-top:14px}
.w-limit-row{display:flex;justify-content:space-between;font-size:11.5px;opacity:.8}
.w-meter{height:5px;border-radius:3px;background:rgba(255,255,255,.15);overflow:hidden;margin-top:5px}
.w-meter span{display:block;height:100%;background:linear-gradient(90deg,#e9c56f,#f6e2a8);border-radius:3px}
.w-hidden .w-bal span.v{filter:blur(9px)}
/* الأزرار السريعة */
.w-actions{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin:18px 0 22px}
.w-act{display:flex;flex-direction:column;align-items:center;gap:6px;text-decoration:none;color:var(--w-ink);font-size:12.5px;font-weight:500;position:relative}
.w-act i{width:56px;height:56px;border-radius:18px;background:var(--w-paper);border:1px solid var(--w-rule);display:grid;place-items:center;transition:transform .15s,background .15s}
.w-act i svg{width:24px;height:24px;stroke:var(--w-mint)}
.w-act:hover i{transform:translateY(-2px);background:#fff}
.w-act.main i{background:var(--w-mint);border-color:var(--w-mint)}
.w-act.main i svg{stroke:#fff}
.w-act.soon{opacity:.55;pointer-events:none}
.w-act.soon::after{content:"قريباً";position:absolute;top:-6px;left:2px;font-size:9.5px;background:var(--w-gold-d);color:#fff;padding:0 6px;border-radius:999px}
/* ملخص الشهر */
.w-month{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:22px}
.w-m{background:var(--w-paper);border:1px solid var(--w-rule);border-radius:16px;padding:12px 14px}
.w-m span{font-size:12px;color:var(--w-muted)}
.w-m b{display:block;font-family:var(--w-mono);font-size:18px;direction:ltr;text-align:right;font-variant-numeric:tabular-nums}
.w-m.in b{color:var(--w-mint)} .w-m.out b{color:var(--w-red)}
/* سجل الحركات: إيصالات */
.w-sec{display:flex;justify-content:space-between;align-items:baseline;margin-bottom:10px}
.w-sec h2{font-family:var(--w-disp);font-size:17px;font-weight:800;margin:0}
.w-sec span{font-size:12px;color:var(--w-muted)}
.w-feed{list-style:none;margin:0;padding:0;display:grid;gap:8px}
.w-tx{display:grid;grid-template-columns:44px 1fr auto;gap:12px;align-items:center;background:var(--w-paper);border:1px solid var(--w-rule);border-radius:16px;padding:10px 12px;animation:w-in .45s cubic-bezier(.2,.8,.2,1) both}
.w-tx .ic{width:44px;height:44px;border-radius:14px;display:grid;place-items:center;font-family:var(--w-disp);font-weight:800;font-size:16px}
.w-tx.in .ic{background:var(--w-mint-s);color:var(--w-mint)} .w-tx.out .ic{background:var(--w-red-s);color:var(--w-red)}
.w-tx .who{font-weight:600;font-size:14px;line-height:1.35}
.w-tx .meta{font-size:11.5px;color:var(--w-muted)}
.w-tx .amt{font-family:var(--w-mono);font-weight:700;font-size:15px;direction:ltr;text-align:left;white-space:nowrap}
.w-tx.in .amt{color:var(--w-mint)} .w-tx.out .amt{color:var(--w-ink)}
.w-tx .amt small{display:block;font-size:10.5px;color:var(--w-muted);font-weight:500}
.w-tx.rev{opacity:.55} .w-tx.rev .amt{text-decoration:line-through}
.w-empty{text-align:center;color:var(--w-muted);padding:30px 10px;border:1px dashed var(--w-rule);border-radius:16px}
/* صفحة التحويل */
.w-back{display:inline-flex;align-items:center;gap:6px;color:var(--w-muted);text-decoration:none;font-size:13px;margin-bottom:10px}
.w-title{font-family:var(--w-disp);font-size:26px;font-weight:800;margin:0 0 4px}
.w-sub{color:var(--w-muted);font-size:13px;margin:0 0 18px}
.w-avail{display:flex;justify-content:space-between;background:var(--w-g8);color:#f3efe2;border-radius:16px;padding:12px 16px;margin-bottom:18px;font-size:13px}
.w-avail b{font-family:var(--w-mono);direction:ltr;color:var(--w-gold)}
.w-field{display:block;margin-bottom:14px}
.w-field span{display:block;font-size:13px;font-weight:600;margin-bottom:6px}
.w-in{width:100%;border:1.5px solid var(--w-rule);background:var(--w-paper);border-radius:14px;padding:13px 14px;font-size:16px;font-family:var(--w-body);color:var(--w-ink);outline:none;transition:border-color .15s}
.w-in:focus{border-color:var(--w-mint);background:#fff}
.w-in.ltr{direction:ltr;text-align:right;font-family:var(--w-mono);letter-spacing:.06em}
.w-amount{font-family:var(--w-mono);font-size:34px;font-weight:700;text-align:center;direction:ltr;padding:16px}
.w-who{min-height:22px;font-size:13px;margin-top:6px}
.w-who.ok{color:var(--w-mint);font-weight:600} .w-who.bad{color:var(--w-red)}
.w-chips{display:flex;gap:8px;flex-wrap:wrap;margin-top:8px}
.w-chips button{border:1px solid var(--w-rule);background:var(--w-paper);border-radius:999px;padding:5px 14px;font-family:var(--w-mono);font-size:13px;cursor:pointer;color:var(--w-ink)}
.w-chips button:hover{border-color:var(--w-mint);color:var(--w-mint)}
.w-btn{width:100%;border:0;border-radius:16px;padding:15px;font-family:var(--w-disp);font-weight:600;font-size:16px;cursor:pointer;background:var(--w-mint);color:#fff;transition:transform .1s,opacity .15s}
.w-btn:active{transform:scale(.98)} .w-btn[disabled]{opacity:.45;cursor:not-allowed}
.w-btn.ghost{background:transparent;color:var(--w-ink);border:1.5px solid var(--w-rule)}
.w-err{display:none;background:var(--w-red-s);color:var(--w-red);border-radius:12px;padding:10px 14px;font-size:13.5px;margin:12px 0}
.w-err.on{display:block}
/* ورقة التأكيد والإيصال */
.w-sheet-bg{position:fixed;inset:0;background:rgba(6,20,17,.55);backdrop-filter:blur(3px);display:none;align-items:flex-end;justify-content:center;z-index:900}
.w-sheet-bg.on{display:flex}
.w-sheet{direction:rtl;width:100%;max-width:460px;background:var(--w-paper);border-radius:26px 26px 0 0;padding:22px 20px calc(24px + env(safe-area-inset-bottom,0px));font-family:var(--w-body);animation:w-up .35s cubic-bezier(.2,.8,.2,1)}
.w-sheet h3{font-family:var(--w-disp);font-size:18px;margin:0 0 14px;text-align:center}
.w-rows{border:1px solid var(--w-rule);border-radius:16px;margin-bottom:16px}
.w-rows div{display:flex;justify-content:space-between;padding:10px 14px;border-bottom:1px dashed var(--w-rule);font-size:14px}
.w-rows div:last-child{border:0}
.w-rows b{font-family:var(--w-mono);direction:ltr}
.w-rows .tot b{font-size:18px;color:var(--w-mint)}
.w-receipt{text-align:center}
.w-check{width:74px;height:74px;border-radius:50%;background:var(--w-mint);display:grid;place-items:center;margin:4px auto 12px;animation:w-pop .5s cubic-bezier(.3,1.6,.5,1)}
.w-check svg{width:38px;height:38px;stroke:#fff;stroke-width:3;fill:none;stroke-dasharray:40;stroke-dashoffset:40;animation:w-draw .4s .25s forwards}
.w-receipt .big{font-family:var(--w-mono);font-size:30px;font-weight:700;direction:ltr}
.w-ref{font-family:var(--w-mono);font-size:12px;color:var(--w-muted);letter-spacing:.08em}
/* صفحة الدخول */
.t-PageBody--login{background:var(--w-g9)!important}
.t-PageBody--login .t-Body{background:radial-gradient(90% 60% at 100% 0%,rgba(233,197,111,.18),transparent 60%),repeating-linear-gradient(115deg,transparent 0 18px,rgba(255,255,255,.025) 18px 19px),var(--w-g9)!important}
.t-PageBody--login form#wwvFlowForm{display:grid!important;place-items:center!important;min-height:100vh;padding:24px 16px}
.t-PageBody--login .t-Login-container{width:100%;max-width:400px;margin:auto!important}
.t-PageBody--login .t-Login-region{border-radius:24px!important;background:var(--w-paper)!important;box-shadow:0 30px 60px -20px rgba(0,0,0,.5)!important;direction:rtl}
.t-PageBody--login .t-Login-logo{display:none}
.t-PageBody--login .t-Login-title{font-family:var(--w-disp)!important;font-weight:800!important}
.t-PageBody--login .t-Button--hot{background:var(--w-mint)!important;border-radius:14px!important;font-family:var(--w-disp)!important;padding:12px!important}
.t-PageBody--login input{font-family:var(--w-mono)!important;direction:ltr;text-align:right}
.w-login-brand{text-align:center;color:#f3efe2;margin-bottom:22px;direction:rtl}
.w-login-brand .w-chip{margin:0 auto 12px;width:52px;height:38px}
.w-login-brand b{display:block;font-family:var(--w-disp);font-size:30px;font-weight:800}
.w-login-brand span{opacity:.75;font-size:14px}
.w-login-hint{direction:rtl;text-align:center;font-size:12px;color:var(--w-muted);margin-top:10px}
@keyframes w-in{from{opacity:.001;transform:translateY(8px)}to{opacity:1;transform:none}}
@keyframes w-up{from{transform:translateY(40px)}to{transform:none}}
@keyframes w-shine{to{transform:translateX(60%)}}
@keyframes w-pop{from{transform:scale(.4)}to{transform:scale(1)}}
@keyframes w-draw{to{stroke-dashoffset:0}}
@media (prefers-reduced-motion:reduce){.w-card,.w-card::after,.w-tx,.w-sheet,.w-check,.w-check svg{animation:none!important}.w-check svg{stroke-dashoffset:0}}
</style>~';
  END styles;

  -- -----------------------------------------------------------------
  FUNCTION render_home RETURN CLOB IS
    l_w      NUMBER;
    l_v      wlt_v_wallets%ROWTYPE;
    l_today  NUMBER;
    l_daily  NUMBER;
    l_in     NUMBER;
    l_out    NUMBER;
    l_html   CLOB;
    l_n      PLS_INTEGER := 0;
    c_send   CONSTANT VARCHAR2(400) := '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 2 11 13"/><path d="M22 2 15 22l-4-9-9-4z"/></svg>';
    c_req    CONSTANT VARCHAR2(400) := '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14"/><path d="m19 12-7 7-7-7"/></svg>';
    c_qr     CONSTANT VARCHAR2(400) := '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3v3h-3zM20 14v.01M14 20h.01M17 20h4v-3"/></svg>';
    c_bill   CONSTANT VARCHAR2(400) := '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 2h12v20l-3-2-3 2-3-2-3 2z"/><path d="M9 7h6M9 11h6M9 15h4"/></svg>';
  BEGIN
    l_w := my_wallet;
    SELECT * INTO l_v FROM wlt_v_wallets WHERE wallet_id = l_w;
    SELECT daily_limit INTO l_daily FROM wlt_kyc_tiers WHERE tier_code = l_v.kyc_tier;

    SELECT NVL(SUM(x.amount), 0) INTO l_today
      FROM wlt_transactions x JOIN wlt_txn_types t ON t.txn_type = x.txn_type
     WHERE x.from_wallet_id = l_w AND x.status = 'COMPLETED'
       AND t.counts_to_limit = 'Y' AND x.created_at >= TRUNC(SYSDATE);

    SELECT NVL(SUM(CASE WHEN entry_type = 'C' THEN amount END), 0),
           NVL(SUM(CASE WHEN entry_type = 'D' THEN amount END), 0)
      INTO l_in, l_out
      FROM wlt_ledger_entries
     WHERE wallet_id = l_w AND created_at >= TRUNC(SYSDATE, 'MM');

    l_html := '<div class="w-app">'
      || '<header class="w-top"><div class="w-hello">أهلاً بك<b>' || esc(l_v.shown_name) || '</b></div>'
      || '<div style="display:flex;gap:8px">' || wallet_ui3_pkg.bell || '<a class="w-icon-btn" title="خروج" href="#" onclick="location.href=document.getElementById(''wLogoutUrl'').href;return false;">'
      || '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/></svg></a></div></header>'

      || '<section class="w-card" id="wCard"><div class="w-card-top"><span class="w-brand">' || esc(app_name) || '</span><span class="w-chip"></span></div>'
      || '<div class="w-lbl">الرصيد المتاح <button class="w-eye" type="button" onclick="document.getElementById(''wCard'').classList.toggle(''w-hidden'')" title="إخفاء الرصيد">◉</button></div>'
      || '<div class="w-bal"><span class="v">' || money(l_v.available_balance) || '</span><small>د.أ</small></div>'
      || '<div class="w-limit"><div class="w-limit-row"><span>استخدمت اليوم ' || money(l_today) || '</span><span>من ' || money(l_daily) || '</span></div>'
      || '<div class="w-meter"><span style="width:' || LEAST(100, ROUND(l_today / l_daily * 100)) || '%"></span></div></div>'
      || '<div class="w-card-bot"><span class="w-pan">' || SUBSTR(l_v.phone, 1, 3) || ' •••• ' || SUBSTR(l_v.phone, -4) || '</span>'
      || '<span class="w-tier">' || CASE l_v.kyc_tier WHEN 'BASIC' THEN 'أساسي' WHEN 'VERIFIED' THEN 'موثّق' ELSE 'مميّز' END || '</span></div></section>'

      || wallet_ui2_pkg.actions(l_v.user_type) || wallet_ui3_pkg.more_actions

      || '<div class="w-month"><div class="w-m in"><span>دخل هذا الشهر</span><b>+' || money(l_in) || '</b></div>'
      || '<div class="w-m out"><span>صرف هذا الشهر</span><b>−' || money(l_out) || '</b></div></div>'

      || '<div class="w-sec"><h2>آخر الحركات</h2><span>آخر 12 عملية</span></div><ul class="w-feed">';

    FOR r IN (
      SELECT t.txn_ref, t.txn_type, tt.name_ar, t.amount, t.fee, t.status, t.description, t.created_at,
             CASE WHEN t.from_wallet_id = l_w THEN 'out' ELSE 'in' END AS dir,
             CASE WHEN o.user_type = 'SYSTEM' THEN tt.name_ar ELSE o.shown_name END AS other
        FROM wlt_transactions t
        JOIN wlt_txn_types tt ON tt.txn_type = t.txn_type
        LEFT JOIN wlt_v_wallets o
          ON o.wallet_id = CASE WHEN t.from_wallet_id = l_w THEN t.to_wallet_id ELSE t.from_wallet_id END
       WHERE (t.from_wallet_id = l_w OR t.to_wallet_id = l_w)
         AND t.status IN ('COMPLETED', 'REVERSED')
       ORDER BY t.txn_id DESC
       FETCH FIRST 12 ROWS ONLY
    ) LOOP
      l_n := l_n + 1;
      l_html := l_html
        || '<li class="w-tx ' || r.dir || CASE WHEN r.status = 'REVERSED' THEN ' rev' END
        || '" style="animation-delay:' || (l_n * 40) || 'ms">'
        || '<span class="ic">' || CASE r.dir WHEN 'in' THEN '↓' ELSE '↑' END || '</span>'
        || '<div><div class="who">' || esc(NVL(r.other, r.name_ar)) || '</div>'
        || '<div class="meta">' || esc(r.name_ar)
        || CASE WHEN r.description IS NOT NULL THEN ' · ' || esc(r.description) END
        || CASE WHEN r.status = 'REVERSED' THEN ' · معكوسة' END
        || ' · ' || rel_time(r.created_at) || '</div></div>'
        || '<div class="amt">' || CASE r.dir WHEN 'in' THEN '+' ELSE '−' END || money(r.amount)
        || CASE WHEN r.dir = 'out' AND r.fee > 0 THEN '<small>+ رسوم ' || money(r.fee) || '</small>' END
        || '<small>' || r.txn_ref || '</small></div></li>';
    END LOOP;

    IF l_n = 0 THEN
      l_html := l_html || '<li class="w-empty">لا توجد حركات بعد. أول تحويل تعمله سيظهر هنا.</li>';
    END IF;

    RETURN l_html || '</ul></div>';
  END render_home;

  -- -----------------------------------------------------------------
  FUNCTION render_send RETURN CLOB IS
    l_v wlt_v_wallets%ROWTYPE;
    l_t wlt_kyc_tiers%ROWTYPE;
    l_w NUMBER := my_wallet;
  BEGIN
    SELECT * INTO l_v FROM wlt_v_wallets WHERE wallet_id = l_w;
    SELECT * INTO l_t FROM wlt_kyc_tiers WHERE tier_code = l_v.kyc_tier;

    RETURN '<div class="w-app">'
      || '<a class="w-back" href="' || apex_page.get_url(p_page => 1) || '">→ الرئيسية</a>'
      || '<h1 class="w-title">تحويل أموال</h1><p class="w-sub">فوري، وبدون رسوم بين المحافظ.</p>'
      || '<div class="w-avail"><span>رصيدك المتاح</span><b>' || money(l_v.available_balance) || ' د.أ</b></div>'
      || '<label class="w-field"><span>رقم هاتف المستلم</span>'
      || '<input class="w-in ltr" id="wTo" inputmode="numeric" maxlength="10" placeholder="07XXXXXXXX" autocomplete="off">'
      || '<div class="w-who" id="wWho"></div></label>'
      || '<label class="w-field"><span>المبلغ (د.أ)</span>'
      || '<input class="w-in w-amount" id="wAmt" inputmode="decimal" placeholder="0.000" autocomplete="off">'
      || '<div class="w-chips"><button type="button" data-v="5">5</button><button type="button" data-v="10">10</button>'
      || '<button type="button" data-v="20">20</button><button type="button" data-v="50">50</button></div></label>'
      || '<label class="w-field"><span>ملاحظة (اختياري)</span><input class="w-in" id="wNote" maxlength="100" placeholder="مثلاً: غداء"></label>'
      || '<div class="w-err" id="wErr"></div>'
      || '<button class="w-btn" id="wGo" type="button" disabled>متابعة</button>'
      || '<p class="w-sub" style="text-align:center;margin-top:12px">حد العملية الواحدة لمستواك ' || money(l_t.single_txn_limit) || ' د.أ</p>'
      || '</div>'

      || '<div class="w-sheet-bg" id="wSheet"><div class="w-sheet" id="wSheetBody"></div></div>'

      || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)};
  var to=$('wTo'),amt=$('wAmt'),note=$('wNote'),go=$('wGo'),who=$('wWho'),err=$('wErr');
  var okName=null,idem=null,busy=false,t=null;
  function fmt(n){return Number(n).toFixed(3)}
  function valid(){var a=parseFloat(amt.value);go.disabled=!(okName&&a>0);}
  function showErr(m){err.textContent=m;err.classList.add('on')}
  function clearErr(){err.classList.remove('on')}
  function lookup(){
    okName=null;valid();clearErr();
    var p=to.value.replace(/\D/g,'');to.value=p;
    if(p.length<10){who.textContent='';who.className='w-who';return}
    who.textContent='جارٍ البحث…';who.className='w-who';
    apex.server.process('WLT_LOOKUP',{x01:p},{success:function(r){
      if(r.ok){okName=r.name;who.textContent='✓ '+r.name;who.className='w-who ok'}
      else{who.textContent=r.msg;who.className='w-who bad'}
      valid();
    }});
  }
  to.addEventListener('input',function(){clearTimeout(t);t=setTimeout(lookup,250)});
  amt.addEventListener('input',function(){amt.value=amt.value.replace(/[^\d.]/g,'');clearErr();valid()});
  document.querySelectorAll('.w-chips button').forEach(function(b){b.onclick=function(){amt.value=b.dataset.v;valid()}});
  function sheet(h){$('wSheetBody').innerHTML=h;$('wSheet').classList.add('on')}
  window.wClose=function(){$('wSheet').classList.remove('on');busy=false};
  $('wSheet').addEventListener('click',function(e){if(e.target.id==='wSheet'&&!busy)wClose()});
  go.onclick=function(){
    idem=(self.crypto&&crypto.randomUUID)?crypto.randomUUID():String(Date.now())+Math.random();
    var a=fmt(amt.value);
    sheet('<h3>تأكيد التحويل</h3><div class="w-rows">'
      +'<div><span>إلى</span><span>'+apex.util.escapeHTML(okName)+'</span></div>'
      +'<div><span>الرقم</span><b>'+to.value+'</b></div>'
      +(note.value?'<div><span>ملاحظة</span><span>'+apex.util.escapeHTML(note.value)+'</span></div>':'')
      +'<div><span>الرسوم</span><b>0.000</b></div>'
      +'<div class="tot"><span>المجموع</span><b>'+a+' د.أ</b></div></div>'
      +'<button class="w-btn" id="wConfirm" type="button">تأكيد وإرسال</button>'
      +'<div style="height:8px"></div><button class="w-btn ghost" type="button" onclick="wClose()">إلغاء</button>');
    $('wConfirm').onclick=send;
  };
  function send(){
    if(busy)return;busy=true;
    var b=$('wConfirm');b.disabled=true;b.textContent='جارٍ الإرسال…';
    apex.server.process('WLT_TRANSFER',{x01:to.value,x02:fmt(amt.value),x03:note.value,x04:idem},{
      success:function(r){
        if(r.ok){
          sheet('<div class="w-receipt"><div class="w-check"><svg viewBox="0 0 24 24"><path d="M5 12.5 10 17 19 7"/></svg></div>'
            +'<h3 style="margin-bottom:4px">تمّ التحويل</h3><div class="big">'+r.amount+' <small style="font-size:14px">د.أ</small></div>'
            +'<p style="margin:6px 0 2px">إلى '+apex.util.escapeHTML(okName)+'</p><div class="w-ref">'+r.ref+' · '+r.time+'</div>'
            +'<div class="w-rows" style="margin-top:16px"><div><span>رصيدك الآن</span><b>'+r.balance+' د.أ</b></div></div>'
            +'<a class="w-btn" style="display:block;text-decoration:none;text-align:center" href="'+r.home+'">العودة للرئيسية</a></div>');
          busy=true;
        }else{wClose();showErr(r.msg)}
      },
      error:function(){wClose();showErr('تعذّر الاتصال. لم يُخصم أي مبلغ، حاول مرة أخرى.')}
    });
  }
})();
</script>~';
  END render_send;

  -- -----------------------------------------------------------------
  PROCEDURE ajax_lookup IS
    l_name VARCHAR2(200);
    l_me   VARCHAR2(20) := v('APP_USER');
  BEGIN
    SELECT shown_name INTO l_name FROM wlt_v_wallets
     WHERE phone = apex_application.g_x01 AND wallet_type = 'MAIN'
       AND user_type IN ('CUSTOMER', 'MERCHANT', 'AGENT') AND wallet_status = 'ACTIVE';
    apex_json.open_object;
    IF apex_application.g_x01 = l_me THEN
      apex_json.write('ok', FALSE);
      apex_json.write('msg', 'هذا رقمك أنت');
    ELSE
      apex_json.write('ok', TRUE);
      apex_json.write('name', l_name);
    END IF;
    apex_json.close_object;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      apex_json.open_object;
      apex_json.write('ok', FALSE);
      apex_json.write('msg', 'هذا الرقم غير مسجّل في المحفظة');
      apex_json.close_object;
  END ajax_lookup;

  PROCEDURE ajax_transfer IS
    l_ref  VARCHAR2(20);
    l_amt  NUMBER;
    l_bal  NUMBER;
    l_w    NUMBER;
    l_msg  VARCHAR2(4000);
  BEGIN
    l_amt := TO_NUMBER(apex_application.g_x02, '999999990D999', 'NLS_NUMERIC_CHARACTERS=''.,''');
    l_ref := wallet_core_pkg.transfer_by_phone(
               p_from_phone  => v('APP_USER'),
               p_to_phone    => apex_application.g_x01,
               p_amount      => l_amt,
               p_idem_key    => apex_application.g_x04,
               p_description => SUBSTR(apex_application.g_x03, 1, 100));
    l_w := my_wallet;
    SELECT available_balance INTO l_bal FROM wlt_v_wallets WHERE wallet_id = l_w;

    apex_json.open_object;
    apex_json.write('ok', TRUE);
    apex_json.write('ref', l_ref);
    apex_json.write('amount', money(l_amt));
    apex_json.write('balance', money(l_bal));
    apex_json.write('time', TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI'));
    apex_json.write('home', apex_page.get_url(p_page => 1));
    apex_json.close_object;
  EXCEPTION
    WHEN OTHERS THEN
      l_msg := SQLERRM;
      IF SQLCODE BETWEEN -20999 AND -20000 THEN
        l_msg := REGEXP_REPLACE(REGEXP_SUBSTR(l_msg, '^[^' || CHR(10) || ']+'), '^ORA-\d+: ', '');
      ELSIF SQLCODE IN (-6502, -1722) THEN
        l_msg := 'المبلغ غير صالح';
      ELSE
        l_msg := 'حدث خطأ غير متوقع. لم يُخصم أي مبلغ.';
      END IF;
      apex_json.open_object;
      apex_json.write('ok', FALSE);
      apex_json.write('code', SQLCODE);
      apex_json.write('msg', l_msg);
      apex_json.close_object;
  END ajax_transfer;

END wallet_ui_pkg;
/
