-- =====================================================================
--  محفظتي · الجلسة 6 · شاشة الدخول: حساب جديد + نسيت الرمز + أي صيغة للرقم
--  تعديل على wallet_login_pkg الموجودة (الجلسة 3) بدل إعادة كتابتها
-- =====================================================================
DECLARE
  l CLOB;
  PROCEDURE rep (a VARCHAR2, b VARCHAR2) IS
  BEGIN
    IF INSTR(l, a) = 0 THEN raise_application_error(-20000, 'not found: ' || SUBSTR(a, 1, 60)); END IF;
    l := REPLACE(l, a, b);
  END;
BEGIN
  FOR r IN (SELECT text FROM user_source WHERE name = 'WALLET_LOGIN_PKG' AND type = 'PACKAGE BODY' ORDER BY line) LOOP
    l := l || r.text;
  END LOOP;
  IF INSTR(l, 'FUNCTION panel') > 0 THEN RETURN; END IF;

  -- 1) دالة ترسم لوحة (حساب جديد / نسيت الرمز)
  rep('  FUNCTION render RETURN CLOB IS', q'#  FUNCTION panel (p_id VARCHAR2, p_purpose VARCHAR2) RETURN VARCHAR2 IS
    l_pin4 VARCHAR2(400) := '<input inputmode="numeric" maxlength="1" autocomplete="off"><input inputmode="numeric" maxlength="1" autocomplete="off"><input inputmode="numeric" maxlength="1" autocomplete="off"><input inputmode="numeric" maxlength="1" autocomplete="off">';
    l_otp  VARCHAR2(800) := '<input inputmode="numeric" maxlength="1" autocomplete="one-time-code">' || l_pin4 || '<input inputmode="numeric" maxlength="1" autocomplete="off">';
    l_reg  BOOLEAN := p_purpose = 'REGISTER';
  BEGIN
    RETURN '<div class="wl-form" id="' || p_id || '" hidden>'
      || '<button class="wl-back" type="button" data-go="wlForm">→ رجوع للدخول</button>'
      || '<h1>' || CASE WHEN l_reg THEN 'حساب جديد' ELSE 'استعادة الرمز' END || '</h1>'
      || '<p class="sub">' || CASE WHEN l_reg THEN 'برقم هاتفك فقط، بأي صيغة تكتبه. نرسل لك رمز تفعيل.'
                                ELSE 'نرسل رمزاً لرقمك المسجّل، ثم تختار رمزاً سرياً جديداً.' END || '</p>'
      || '<div class="st" data-s="1"><label class="wl-lbl">رقم الهاتف</label><div class="wl-phone"><span>+962</span>'
      || '<input class="f-ph" inputmode="tel" maxlength="20" placeholder="07X XXX XXXX" autocomplete="tel"></div>'
      || '<div class="wl-gap"></div><button class="wl-btn f-send" type="button" disabled>أرسل رمز التفعيل</button></div>'
      || '<div class="st" data-s="2" hidden><p class="sub f-sent"></p><label class="wl-lbl">رمز التفعيل</label>'
      || '<div class="wl-otp f-otp">' || l_otp || '</div>'
      || '<button class="wl-btn f-verify" type="button" disabled>تحقّق</button>'
      || '<button class="wl-resend f-resend" type="button" disabled>إعادة الإرسال</button></div>'
      || '<div class="st" data-s="3" hidden>'
      || CASE WHEN l_reg THEN '<label class="wl-lbl">اسمك (اختياري)</label><input class="wl-in f-name" maxlength="40" placeholder="كيف نناديك؟"><div class="wl-gap"></div>' END
      || '<label class="wl-lbl">' || CASE WHEN l_reg THEN 'اختر رمزاً سرياً من 4 أرقام' ELSE 'الرمز السري الجديد' END || '</label>'
      || '<div class="wl-pin f-p1">' || l_pin4 || '</div>'
      || '<label class="wl-lbl">أعد كتابة الرمز</label><div class="wl-pin f-p2">' || l_pin4 || '</div>'
      || '<button class="wl-btn f-done" type="button" disabled>' || CASE WHEN l_reg THEN 'أنشئ حسابي وادخل' ELSE 'احفظ الرمز وادخل' END || '</button></div>'
      || '<div class="wl-err f-err" role="alert"></div></div>';
  END panel;

  FUNCTION render RETURN CLOB IS#');

  -- 2) تصميم اللوحات ورسالة SMS التجريبية
  rep('@keyframes wl-float', q'#.wl-links{display:flex;justify-content:space-between;margin-top:16px}
.wl-links button,.wl-back,.wl-resend{background:none;border:0;color:var(--w-mint);font-family:var(--w-body);font-weight:600;font-size:14px;cursor:pointer;padding:4px 0}
.wl-back{color:var(--w-muted);margin-bottom:14px;font-size:13px}
.wl-resend{display:block;margin:12px auto 0;color:var(--w-muted)}.wl-resend:not([disabled]){color:var(--w-mint)}
.wl-otp{display:grid;grid-template-columns:repeat(6,1fr);gap:8px;direction:ltr;margin:6px 0 16px}
.wl-otp input{width:100%;aspect-ratio:.82;border:1.5px solid var(--w-rule);border-radius:14px;background:var(--w-paper);text-align:center;font-family:var(--w-mono);font-size:24px;font-weight:700;outline:0;color:var(--w-ink)}
.wl-otp input:focus{border-color:var(--w-mint);box-shadow:0 0 0 4px rgba(14,122,99,.12);background:#fff}
.wl-in{width:100%;border:1.5px solid var(--w-rule);background:var(--w-paper);border-radius:16px;padding:14px;font-size:16px;font-family:var(--w-body);outline:0;color:var(--w-ink)}
.wl-in:focus{border-color:var(--w-mint);background:#fff}
.wl-toast{position:fixed;top:calc(14px + env(safe-area-inset-top,0px));left:50%;transform:translateX(-50%);z-index:999;width:min(380px,calc(100% - 32px));background:rgba(20,28,26,.94);color:#fff;border-radius:18px;padding:12px 16px;box-shadow:0 18px 40px rgba(0,0,0,.35);direction:rtl;animation:wl-drop .4s cubic-bezier(.2,.8,.2,1);backdrop-filter:blur(10px)}
.wl-toast b{display:block;font-size:12px;opacity:.7;margin-bottom:2px}
.wl-toast span{display:block;font-size:14.5px;line-height:1.6}
.wl-toast small{display:block;font-size:11px;color:var(--w-gold);margin-top:6px}
@keyframes wl-drop{from{transform:translate(-50%,-30px);opacity:0}}
@keyframes wl-float#');

  -- 3) روابط تحت زر الدخول
  rep('<div class="wl-sec">', '<div class="wl-links"><button type="button" data-go="wlReg">✨ حساب جديد</button><button type="button" data-go="wlRst">نسيت الرمز؟</button></div><div class="wl-sec">');

  -- 4) اللوحتان + مكان رسالة SMS
  rep('</div></section></div>', q'#</div>~' || panel('wlReg', 'REGISTER') || panel('wlRst', 'RESET') || q'~</section><div class="wl-toast" id="wlToast" hidden></div></div>#');

  -- 5) خانة الدخول تقبل أي صيغة للرقم
  rep('<input id="wlPhone" inputmode="numeric" maxlength="10"', '<input id="wlPhone" inputmode="tel" maxlength="20"');
  rep(q'#ph.value=ph.value.replace(/\D/g,'').slice(0,10)#', 'ph.value=wNorm(ph.value)');

  -- 6) منطق اللوحات
  rep('    (ph.value?pins[0]:ph).focus();check();', q'#    function wNorm(v){var d=(v||'').replace(/[٠-٩]/g,function(c){return c.charCodeAt(0)-1632}).replace(/\D/g,'');
      if(d.indexOf('00962')===0)d=d.slice(5);else if(d.indexOf('962')===0)d=d.slice(3);if(d.charAt(0)==='7')d='0'+d;return d.slice(0,10)}
    function P(a,d){d.x01=a;return new Promise(function(res){apex.server.process('WLT_PUBLIC',d,{success:res,error:function(){res({ok:false,msg:'تعذّر الاتصال، حاول مرة أخرى'})}})})}
    function boxes(c,n){var b=[].slice.call(c.querySelectorAll('input'));
      b.forEach(function(i,k){i.addEventListener('input',function(){i.value=i.value.replace(/\D/g,'').slice(-1);if(i.value&&k<n-1)b[k+1].focus();c.dispatchEvent(new Event('change'))});
        i.addEventListener('keydown',function(e){if(e.key==='Backspace'&&!i.value&&k>0){b[k-1].focus();b[k-1].value=''}});
        i.addEventListener('paste',function(e){var d=(e.clipboardData.getData('text')||'').replace(/\D/g,'').slice(0,n);if(d){e.preventDefault();b.forEach(function(x,j){x.value=d[j]||''});c.dispatchEvent(new Event('change'))}})});
      return function(){return b.map(function(i){return i.value}).join('')}}
    function toast(sms){var t=document.getElementById('wlToast');
      t.innerHTML='<b>رسالة SMS · الآن</b><span></span><small>وضع التجربة: لا يوجد مزوّد SMS مربوط بعد، لذلك تظهر الرسالة هنا</small>';
      t.querySelector('span').textContent=sms;t.hidden=false;clearTimeout(t._h);t._h=setTimeout(function(){t.hidden=true},20000)}
    function flow(root,purpose){
      var q=function(s){return root.querySelector(s)},err=q('.f-err'),fp=q('.f-ph'),phone='',ticket='',cd,
          otp=boxes(q('.f-otp'),6),p1=boxes(q('.f-p1'),4),p2=boxes(q('.f-p2'),4);
      function step(n){root.querySelectorAll('.st').forEach(function(s){s.hidden=+s.dataset.s!==n});var f=q('.st[data-s="'+n+'"] input');if(f)f.focus()}
      function E(m){err.textContent=m||'';if(m){root.classList.remove('wl-shake');void root.offsetWidth;root.classList.add('wl-shake')}}
      fp.addEventListener('input',function(){fp.value=wNorm(fp.value);E();q('.f-send').disabled=!/^07[789]\d{7}$/.test(fp.value)});
      function send(btn){btn.disabled=true;E();P('send',{x02:fp.value,x03:purpose}).then(function(r){btn.disabled=false;
        if(!r.ok){E(r.msg);return}phone=r.phone;q('.f-sent').textContent='أرسلنا رمزاً من 6 أرقام إلى '+phone;if(r.demo)toast(r.sms);step(2);
        var s=60,rb=q('.f-resend');rb.disabled=true;clearInterval(cd);
        cd=setInterval(function(){s--;rb.textContent=s>0?'إعادة الإرسال بعد '+s+' ث':'إعادة الإرسال';if(s<=0){clearInterval(cd);rb.disabled=false}},1000)})}
      q('.f-send').onclick=function(){send(this)};q('.f-resend').onclick=function(){send(this)};
      q('.f-otp').addEventListener('change',function(){var full=otp().length===6;q('.f-verify').disabled=!full;if(full)q('.f-verify').click()});
      q('.f-verify').onclick=function(){var b=this;if(b.disabled&&otp().length!==6)return;b.disabled=true;E();
        P('verify',{x02:phone,x03:purpose,x04:otp()}).then(function(r){
          if(!r.ok){b.disabled=false;E(r.msg);root.querySelectorAll('.f-otp input').forEach(function(i){i.value=''});q('.f-otp input').focus();return}
          ticket=r.ticket;step(3)})};
      function pv(){q('.f-done').disabled=!(p1().length===4&&p2().length===4)}
      q('.f-p1').addEventListener('change',function(){pv();if(p1().length===4)q('.f-p2 input').focus()});
      q('.f-p2').addEventListener('change',pv);
      q('.f-done').onclick=function(){var b=this;if(p1()!==p2()){E('الرمزان غير متطابقين');return}b.disabled=true;E();
        P(purpose==='REGISTER'?'register':'reset',{x02:phone,x03:ticket,x04:(q('.f-name')||{}).value||'',x05:p1()}).then(function(r){
          if(!r.ok){b.disabled=false;E(r.msg);return}
          b.textContent='جارٍ الدخول…';u.value=phone;p.value=p1();
          try{apex.submit({request:'LOGIN',showWait:false})}catch(e){form.submit()}})};
    }
    document.querySelectorAll('[data-go]').forEach(function(b){b.onclick=function(){
      ['wlForm','wlReg','wlRst'].forEach(function(id){document.getElementById(id).hidden=id!==b.dataset.go});
      var i=document.getElementById(b.dataset.go).querySelector('input');if(i)i.focus()}});
    flow(document.getElementById('wlReg'),'REGISTER');flow(document.getElementById('wlRst'),'RESET');
    (ph.value?pins[0]:ph).focus();check();#');

  EXECUTE IMMEDIATE 'CREATE OR REPLACE ' || l;
END;
/
