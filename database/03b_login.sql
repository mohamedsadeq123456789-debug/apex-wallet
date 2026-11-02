-- =====================================================================
--  محفظتي · الجلسة 3 · شاشة الدخول المخصصة + رسائل دخول واضحة
-- =====================================================================

-- رسالة دخول عربية واضحة بدل "Invalid Login Credentials"
CREATE OR REPLACE PACKAGE BODY wallet_auth_pkg AS
  c_max_attempts CONSTANT PLS_INTEGER := 5;

  FUNCTION authenticate (p_username IN VARCHAR2, p_password IN VARCHAR2) RETURN BOOLEAN IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_u     wlt_users%ROWTYPE;
    l_hash  VARCHAR2(64);
    l_left  PLS_INTEGER;
  BEGIN
    SELECT * INTO l_u FROM wlt_users
     WHERE phone = TRIM(p_username) AND user_type <> 'SYSTEM'
       FOR UPDATE;

    IF l_u.status <> 'ACTIVE' THEN
      ROLLBACK;
      apex_util.set_custom_auth_status('هذا الحساب موقوف');
      RETURN FALSE;
    END IF;
    IF l_u.locked_until > SYSTIMESTAMP THEN
      ROLLBACK;
      apex_util.set_custom_auth_status('الحساب مقفل مؤقتاً. حاول بعد '
        || CEIL((CAST(l_u.locked_until AS DATE) - SYSDATE) * 1440) || ' دقيقة');
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

    l_left := c_max_attempts - (l_u.failed_pin_attempts + 1);
    IF l_left <= 0 THEN
      UPDATE wlt_users SET failed_pin_attempts = 0,
                           locked_until = SYSTIMESTAMP + INTERVAL '15' MINUTE
       WHERE user_id = l_u.user_id;
      INSERT INTO wlt_audit_log (actor_user_id, action, entity, entity_id, details)
      VALUES (l_u.user_id, 'LOCKED', 'USER', l_u.user_id, '5 محاولات خاطئة: قفل 15 دقيقة');
      apex_util.set_custom_auth_status('5 محاولات خاطئة. الحساب مقفل 15 دقيقة');
    ELSE
      UPDATE wlt_users SET failed_pin_attempts = failed_pin_attempts + 1 WHERE user_id = l_u.user_id;
      INSERT INTO wlt_audit_log (actor_user_id, action, entity, entity_id)
      VALUES (l_u.user_id, 'LOGIN_FAILED', 'USER', l_u.user_id);
      apex_util.set_custom_auth_status('الرمز غير صحيح. بقيت ' || l_left || ' محاولات');
    END IF;
    COMMIT;
    RETURN FALSE;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      ROLLBACK;
      apex_util.set_custom_auth_status('هذا الرقم غير مسجّل في المحفظة');
      RETURN FALSE;
  END authenticate;
END wallet_auth_pkg;
/


CREATE OR REPLACE PACKAGE wallet_login_pkg AS
  FUNCTION render RETURN CLOB;
END wallet_login_pkg;
/

CREATE OR REPLACE PACKAGE BODY wallet_login_pkg AS
  FUNCTION render RETURN CLOB IS
    l_name VARCHAR2(400);
    l_tag  VARCHAR2(400);
  BEGIN
    IF NVL(v('APP_PAGE_ID'), 0) <> 9999 THEN
      RETURN NULL;
    END IF;
    SELECT MAX(CASE setting_key WHEN 'APP_NAME' THEN setting_value END),
           MAX(CASE setting_key WHEN 'APP_TAGLINE' THEN setting_value END)
      INTO l_name, l_tag
      FROM wlt_app_settings WHERE setting_key IN ('APP_NAME', 'APP_TAGLINE');

    RETURN q'~<style>
.t-PageBody--login .t-Body,.t-PageBody--login form#wwvFlowForm>*:not(.wl){visibility:hidden!important}
.wl{visibility:visible!important;position:fixed;inset:0;z-index:50;display:grid;grid-template-columns:1.05fr 1fr;direction:rtl;font-family:var(--w-body);color:var(--w-ink);background:var(--w-bg)}
.wl *{box-sizing:border-box}
/* البطل */
.wl-hero{position:relative;overflow:hidden;color:#f3efe2;padding:48px 56px;display:flex;flex-direction:column;justify-content:space-between;
 background:radial-gradient(70% 55% at 85% 10%,rgba(233,197,111,.22),transparent 60%),radial-gradient(60% 60% at 10% 100%,rgba(14,122,99,.45),transparent 65%),var(--w-g9)}
.wl-hero::before{content:"";position:absolute;inset:0;background-image:linear-gradient(rgba(255,255,255,.04) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,.04) 1px,transparent 1px);background-size:44px 44px;mask-image:radial-gradient(80% 70% at 50% 40%,#000,transparent)}
.wl-hero>*{position:relative}
.wl-mark{display:flex;align-items:center;gap:12px;font-family:var(--w-disp);font-weight:800;font-size:22px}
.wl-mark i{width:38px;height:28px;border-radius:7px;background:linear-gradient(135deg,#ecca76,#a8791a);display:block}
.wl-h{font-family:var(--w-disp);font-weight:800;font-size:clamp(30px,3.6vw,52px);line-height:1.2;margin:0 0 14px;max-width:13ch}
.wl-h em{font-style:normal;color:var(--w-gold)}
.wl-p{font-size:16px;opacity:.78;max-width:40ch;margin:0}
.wl-stage{perspective:1000px;display:flex;justify-content:flex-start;margin:28px 0}
.wl-card{width:min(360px,100%);aspect-ratio:1.586;border-radius:22px;padding:22px 24px;display:flex;flex-direction:column;justify-content:space-between;
 background:linear-gradient(135deg,#123f37,#1d6b5a 60%,#0f3a33);box-shadow:0 40px 70px -25px rgba(0,0,0,.65),inset 0 1px 0 rgba(255,255,255,.14);
 transform:rotateX(10deg) rotateY(14deg) rotateZ(-4deg);transition:transform .5s cubic-bezier(.2,.8,.2,1);position:relative;overflow:hidden;animation:wl-float 6s ease-in-out infinite}
.wl-card::after{content:"";position:absolute;inset:-50%;background:linear-gradient(100deg,transparent 42%,rgba(255,255,255,.2) 50%,transparent 58%);animation:wl-shine 4.5s ease-in-out infinite}
.wl-card .r{display:flex;justify-content:space-between;align-items:center;position:relative;z-index:1}
.wl-card .b{font-family:var(--w-mono);font-size:28px;font-weight:700;direction:ltr;text-align:right;position:relative;z-index:1}
.wl-card .s{font-size:11px;opacity:.7}
.wl-card .pan{font-family:var(--w-mono);letter-spacing:.16em;font-size:13px;direction:ltr;opacity:.85}
.wl-stats{display:flex;flex-wrap:wrap;gap:10px}
.wl-stat{background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.12);border-radius:14px;padding:10px 14px;backdrop-filter:blur(6px)}
.wl-stat b{display:block;font-family:var(--w-mono);font-size:18px;color:var(--w-gold);direction:ltr;text-align:right}
.wl-stat span{font-size:12px;opacity:.75}
/* النموذج */
.wl-side{display:flex;align-items:center;justify-content:center;padding:40px 24px;overflow:auto}
.wl-form{width:100%;max-width:380px}
.wl-form h1{font-family:var(--w-disp);font-weight:800;font-size:30px;margin:0 0 6px}
.wl-form .sub{color:var(--w-muted);margin:0 0 30px;font-size:15px}
.wl-lbl{display:block;font-size:13px;font-weight:600;margin-bottom:8px}
.wl-phone{display:flex;align-items:stretch;border:1.5px solid var(--w-rule);border-radius:16px;background:var(--w-paper);overflow:hidden;transition:border-color .15s,box-shadow .15s;direction:ltr}
.wl-phone:focus-within{border-color:var(--w-mint);box-shadow:0 0 0 4px rgba(14,122,99,.12);background:#fff}
.wl-phone span{display:grid;place-items:center;padding:0 14px;font-family:var(--w-mono);font-size:15px;color:var(--w-muted);background:var(--w-bg);border-right:1px solid var(--w-rule)}
.wl-phone input{flex:1;min-width:0;border:0;outline:0;background:transparent;padding:16px 14px;font-family:var(--w-mono);font-size:20px;letter-spacing:.08em;color:var(--w-ink)}
.wl-pin{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;direction:ltr;margin-bottom:8px}
.wl-pin input{width:100%;aspect-ratio:1;max-height:72px;border:1.5px solid var(--w-rule);border-radius:16px;background:var(--w-paper);text-align:center;font-family:var(--w-mono);font-size:28px;font-weight:700;color:var(--w-ink);outline:0;transition:border-color .15s,box-shadow .15s,transform .15s;-webkit-text-security:disc}
.wl-pin input:focus{border-color:var(--w-mint);box-shadow:0 0 0 4px rgba(14,122,99,.12);background:#fff;transform:translateY(-2px)}
.wl-pin input.f{border-color:var(--w-mint);background:var(--w-mint-s)}
.wl-gap{height:22px}
.wl-err{min-height:22px;color:var(--w-red);font-size:14px;font-weight:600;margin:6px 0 14px}
.wl-btn{width:100%;border:0;border-radius:16px;padding:16px;font-family:var(--w-disp);font-weight:600;font-size:17px;cursor:pointer;background:var(--w-mint);color:#fff;display:flex;align-items:center;justify-content:center;gap:10px;transition:transform .1s,opacity .2s,background .2s}
.wl-btn:hover{background:#0b6a56}.wl-btn:active{transform:scale(.98)}.wl-btn[disabled]{opacity:.5;cursor:not-allowed}
.wl-spin{width:18px;height:18px;border:2.5px solid rgba(255,255,255,.4);border-top-color:#fff;border-radius:50%;animation:wl-rot .7s linear infinite;display:none}
.wl-busy .wl-spin{display:block}
.wl-demo{margin-top:26px;border-top:1px dashed var(--w-rule);padding-top:18px}
.wl-demo p{font-size:12.5px;color:var(--w-muted);margin:0 0 10px}
.wl-demo div{display:flex;flex-wrap:wrap;gap:8px}
.wl-demo button{border:1px solid var(--w-rule);background:var(--w-paper);border-radius:999px;padding:6px 12px;font-size:12.5px;cursor:pointer;color:var(--w-ink);font-family:var(--w-body)}
.wl-demo button:hover{border-color:var(--w-mint);color:var(--w-mint)}
.wl-demo button b{font-family:var(--w-mono);font-weight:500;margin-inline-start:4px}
.wl-shake{animation:wl-shake .4s}
.wl-sec{display:flex;align-items:center;gap:8px;justify-content:center;margin-top:18px;font-size:12px;color:var(--w-muted)}
@keyframes wl-float{0%,100%{translate:0 0}50%{translate:0 -10px}}
@keyframes wl-shine{0%{transform:translateX(-60%)}60%,100%{transform:translateX(60%)}}
@keyframes wl-rot{to{transform:rotate(360deg)}}
@keyframes wl-shake{20%,60%{transform:translateX(-8px)}40%,80%{transform:translateX(8px)}}
@media (max-width:860px){
 .wl{grid-template-columns:1fr;grid-template-rows:auto 1fr;overflow:auto;position:fixed}
 .wl-hero{padding:24px 20px 26px}
 .wl-h{font-size:26px;max-width:none}.wl-p{font-size:14px}
 .wl-stage{display:none}.wl-stats{margin-top:16px}.wl-stat{padding:7px 11px}.wl-stat b{font-size:15px}
 .wl-side{align-items:flex-start;padding:28px 20px}
}
@media (prefers-reduced-motion:reduce){.wl-card,.wl-card::after{animation:none}}
</style>~'
    || '<div class="wl" id="wl"><section class="wl-hero">'
    || '<div class="wl-mark"><i></i>' || apex_escape.html(l_name) || '</div>'
    || q'~<div><h2 class="wl-h">محفظتك، <em>أسرع</em> من الكاش.</h2>
<p class="wl-p">حوّل، ادفع، وادّخر من رقم هاتفك. كل عملية مسجّلة في دفتر مزدوج لا يُعدَّل، وكل دينار محسوب.</p>
<div class="wl-stage"><div class="wl-card" id="wlCard"><div class="r"><b style="font-family:var(--w-disp)">~'
    || apex_escape.html(l_name)
    || q'~</b><span class="w-chip"></span></div><div><div class="s">الرصيد المتاح</div><div class="b">1,250.000</div></div>
<div class="r"><span class="pan">079 •••• 4567</span><span class="s">موثّق</span></div></div></div></div>
<div class="wl-stats"><div class="wl-stat"><b>1.5ms</b><span>لكل تحويل</span></div><div class="wl-stat"><b>0.000</b><span>رسوم بين المحافظ</span></div><div class="wl-stat"><b>24/7</b><span>فوري دائماً</span></div></div>
</section>
<section class="wl-side"><div class="wl-form" id="wlForm">
<h1>أهلاً بعودتك</h1><p class="sub">ادخل برقم هاتفك ورمزك السري.</p>
<label class="wl-lbl" for="wlPhone">رقم الهاتف</label>
<div class="wl-phone"><span>+962</span><input id="wlPhone" inputmode="numeric" maxlength="10" placeholder="07X XXX XXXX" autocomplete="off"></div>
<div class="wl-gap"></div>
<label class="wl-lbl" for="wlP1">الرمز السري</label>
<div class="wl-pin" id="wlPin"><input id="wlP1" inputmode="numeric" maxlength="1" autocomplete="off" aria-label="الرقم 1"><input inputmode="numeric" maxlength="1" autocomplete="off" aria-label="الرقم 2"><input inputmode="numeric" maxlength="1" autocomplete="off" aria-label="الرقم 3"><input inputmode="numeric" maxlength="1" autocomplete="off" aria-label="الرقم 4"></div>
<div class="wl-err" id="wlErr" role="alert"></div>
<button class="wl-btn" id="wlGo" type="button" disabled><span class="wl-spin"></span><span>دخول</span></button>
<div class="wl-sec">🔒 يُقفل الحساب 15 دقيقة بعد 5 محاولات خاطئة</div>
<div class="wl-demo"><p>حسابات تجريبية (الرمز لكلها 1234). اضغط لتعبئة الرقم:</p><div>
<button type="button" data-p="0791234567">عميل 1<b>0791234567</b></button>
<button type="button" data-p="0794567890">عميل 4<b>0794567890</b></button>
<button type="button" data-p="0798901234">وكيل<b>0798901234</b></button></div></div>
</div></section></div>
<script>
(function(){
  function init(){
    var form=document.getElementById('wwvFlowForm'),wl=document.getElementById('wl');
    if(form&&wl.parentElement!==form)form.appendChild(wl);
    var ph=document.getElementById('wlPhone'),pins=[].slice.call(document.querySelectorAll('#wlPin input')),
        go=document.getElementById('wlGo'),err=document.getElementById('wlErr'),f=document.getElementById('wlForm');
    var u=document.getElementById('P9999_USERNAME'),p=document.getElementById('P9999_PASSWORD');
    var al=document.querySelector('#t_Alert_Notification,.t-Alert--warning,.t-Alert--danger,.a-Notification');
    if(al){var m=(al.innerText||'').split('\n').filter(Boolean).pop()||'';
      err.textContent=/Invalid Login/i.test(m)?'الرقم أو الرمز غير صحيح':m;al.style.display='none';
      f.classList.add('wl-shake');}
    if(u&&u.value&&/^07\d{8}$/.test(u.value))ph.value=u.value;
    function pin(){return pins.map(function(i){return i.value}).join('')}
    function check(){go.disabled=!(/^07[789]\d{7}$/.test(ph.value)&&pin().length===4);
      pins.forEach(function(i){i.classList.toggle('f',!!i.value)})}
    ph.addEventListener('input',function(){ph.value=ph.value.replace(/\D/g,'').slice(0,10);err.textContent='';check();
      if(ph.value.length===10)pins[0].focus()});
    pins.forEach(function(i,k){
      i.addEventListener('input',function(){i.value=i.value.replace(/\D/g,'').slice(-1);err.textContent='';check();
        if(i.value&&k<3)pins[k+1].focus();if(pin().length===4&&!go.disabled)submit()});
      i.addEventListener('keydown',function(e){if(e.key==='Backspace'&&!i.value&&k>0){pins[k-1].focus();pins[k-1].value='';check()}});
      i.addEventListener('paste',function(e){var d=(e.clipboardData.getData('text')||'').replace(/\D/g,'').slice(0,4);
        if(d.length){e.preventDefault();pins.forEach(function(x,j){x.value=d[j]||''});check();(pins[d.length]||pins[3]).focus();if(d.length===4)submit()}});
    });
    document.querySelectorAll('.wl-demo button').forEach(function(b){b.onclick=function(){ph.value=b.dataset.p;check();
      pins.forEach(function(x){x.value=''});pins[0].focus()}});
    var busy=false;
    function submit(){if(busy||go.disabled)return;busy=true;go.classList.add('wl-busy');go.disabled=true;
      u.value=ph.value;p.value=pin();
      try{apex.submit({request:'LOGIN',showWait:false})}catch(e){form.submit()}}
    f.addEventListener('keydown',function(e){if(e.key==='Enter'){e.preventDefault();submit()}});go.addEventListener('click',function(e){e.preventDefault();submit()});
    var card=document.getElementById('wlCard'),hero=card&&card.closest('.wl-hero');
    if(hero&&matchMedia('(hover:hover)').matches&&!matchMedia('(prefers-reduced-motion:reduce)').matches){
      hero.addEventListener('pointermove',function(e){var r=hero.getBoundingClientRect(),x=(e.clientX-r.left)/r.width-.5,y=(e.clientY-r.top)/r.height-.5;
        card.style.transform='rotateX('+(-y*16)+'deg) rotateY('+(x*22)+'deg)'});
      hero.addEventListener('pointerleave',function(){card.style.transform=''});}
    (ph.value?pins[0]:ph).focus();check();
  }
  if(document.readyState!=='loading')init();else document.addEventListener('DOMContentLoaded',init);
})();
</script>~';
  END render;
END wallet_login_pkg;
/
