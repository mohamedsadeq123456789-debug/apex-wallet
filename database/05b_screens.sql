-- =====================================================================
--  محفظتي · الجلسة 5 · الشاشات
--  8 طلب أموال · 9 تقسيم الفاتورة · 10 التحويلات المجدولة · 11 الإشعارات
-- =====================================================================
CREATE OR REPLACE PACKAGE wallet_ui3_pkg AS
  FUNCTION bell            RETURN VARCHAR2;
  FUNCTION more_actions    RETURN VARCHAR2;
  FUNCTION render_request  RETURN CLOB;
  FUNCTION render_split    RETURN CLOB;
  FUNCTION render_sched    RETURN CLOB;
  FUNCTION render_inbox    RETURN CLOB;
  PROCEDURE api;
END wallet_ui3_pkg;
/

CREATE OR REPLACE PACKAGE BODY wallet_ui3_pkg AS

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

  FUNCTION ago (p TIMESTAMP) RETURN VARCHAR2 IS
    l_min NUMBER := ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(p AS DATE)) * 1440);
  BEGIN
    RETURN CASE WHEN l_min < 1 THEN 'الآن' WHEN l_min < 60 THEN 'قبل ' || l_min || ' د'
                WHEN l_min < 1440 THEN 'قبل ' || ROUND(l_min / 60) || ' س'
                ELSE TO_CHAR(p, 'DD/MM HH24:MI') END;
  END ago;

  FUNCTION left_txt (p TIMESTAMP) RETURN VARCHAR2 IS
    l_min NUMBER := ROUND((CAST(p AS DATE) - SYSDATE) * 1440);
  BEGIN
    RETURN CASE WHEN l_min <= 0 THEN 'منتهٍ' WHEN l_min < 60 THEN 'باقي ' || l_min || ' د'
                ELSE 'باقي ' || ROUND(l_min / 60) || ' س' END;
  END left_txt;

  FUNCTION pill (p_status VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN '<span class="w-pill ' || LOWER(p_status) || '">' ||
      CASE p_status WHEN 'PENDING' THEN 'بانتظار الدفع' WHEN 'PAID' THEN 'مدفوع' WHEN 'DECLINED' THEN 'مرفوض'
                    WHEN 'CANCELLED' THEN 'ملغى' WHEN 'EXPIRED' THEN 'منتهٍ' WHEN 'ACTIVE' THEN 'فعّال'
                    WHEN 'PAUSED' THEN 'متوقف' WHEN 'DONE' THEN 'اكتمل' ELSE p_status END || '</span>';
  END pill;

  FUNCTION head (p_title VARCHAR2, p_sub VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN '<div class="w-head"><a href="' || apex_page.get_url(p_page => 1) || '" title="الرئيسية">→</a>'
        || '<div><h1>' || esc(p_title) || '</h1><p>' || esc(p_sub) || '</p></div></div>';
  END head;

  -- الجرس في رأس الرئيسية، مع عدد غير المقروء
  FUNCTION bell RETURN VARCHAR2 IS
    l_n NUMBER;
    l   wlt_v_wallets%ROWTYPE := me;
  BEGIN
    SELECT COUNT(*) INTO l_n FROM wlt_notifications WHERE user_id = l.user_id AND is_read = 'N';
    RETURN '<a class="w-icon-btn w-bell" title="الإشعارات" href="' || apex_page.get_url(p_page => 11) || '">'
      || '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg>'
      || CASE WHEN l_n > 0 THEN '<b>' || CASE WHEN l_n > 9 THEN '9+' ELSE TO_CHAR(l_n) END || '</b>' END
      || '</a>';
  END bell;

  -- صف ثانٍ من الأزرار في الرئيسية
  FUNCTION more_actions RETURN VARCHAR2 IS
    l_in NUMBER;
    l    wlt_v_wallets%ROWTYPE := me;
  BEGIN
    SELECT COUNT(*) INTO l_in FROM wlt_money_requests
     WHERE payer_user_id = l.user_id AND status = 'PENDING' AND expires_at > SYSTIMESTAMP;
    RETURN '<style>.w-more{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin:-8px 0 22px}'
      || '.w-more a{display:flex;align-items:center;gap:8px;justify-content:center;background:var(--w-paper);border:1px solid var(--w-rule);border-radius:14px;padding:10px 6px;text-decoration:none;color:var(--w-ink);font-size:12.5px;font-weight:600;position:relative}'
      || '.w-more a:hover{border-color:var(--w-mint);color:var(--w-mint)}.w-more span{font-size:16px}'
      || '.w-more b{position:absolute;top:-7px;left:-4px;background:var(--w-red);color:#fff;border-radius:999px;font-size:10.5px;min-width:18px;height:18px;display:grid;place-items:center;padding:0 5px}'
      || '.w-bell{position:relative}.w-bell b{position:absolute;top:-5px;left:-5px;background:var(--w-red);color:#fff;border-radius:999px;font-size:10px;min-width:18px;height:18px;display:grid;place-items:center;padding:0 4px;font-family:var(--w-mono)}</style>'
      || '<nav class="w-more">'
      || '<a href="' || apex_page.get_url(p_page => 8) || '"><span>↙</span>طلب أموال'
      || CASE WHEN l_in > 0 THEN '<b>' || l_in || '</b>' END || '</a>'
      || '<a href="' || apex_page.get_url(p_page => 9) || '"><span>➗</span>تقسيم فاتورة</a>'
      || '<a href="' || apex_page.get_url(p_page => 10) || '"><span>🗓</span>مجدولة</a>'
      || '</nav>';
  END more_actions;

  FUNCTION css RETURN VARCHAR2 IS
  BEGIN
    RETURN q'~<style>
.w-pill{display:inline-block;font-size:11px;font-weight:600;border-radius:999px;padding:1px 9px;background:var(--w-rule);color:var(--w-ink)}
.w-pill.pending,.w-pill.active{background:#fdf1d6;color:#8a6110}.w-pill.paid,.w-pill.done{background:var(--w-mint-s);color:var(--w-mint)}
.w-pill.declined,.w-pill.expired,.w-pill.cancelled{background:var(--w-red-s);color:var(--w-red)}.w-pill.paused{background:#e8ecf3;color:#41608a}
.w-card2{border:1px solid var(--w-rule);background:var(--w-paper);border-radius:18px;padding:14px;margin-bottom:10px;animation:w-in .35s both}
.w-card2 .t{display:flex;justify-content:space-between;align-items:flex-start;gap:10px}
.w-card2 .t b{font-size:14.5px}
.w-card2 .amt{font-family:var(--w-mono);font-weight:700;font-size:18px;direction:ltr;white-space:nowrap}
.w-card2 small{display:block;color:var(--w-muted);font-size:12px;margin-top:2px}
.w-card2 .acts{display:flex;gap:8px;margin-top:12px}
.w-card2 .acts button{flex:1;border-radius:12px;padding:10px;font-family:var(--w-disp);font-weight:600;font-size:14px;cursor:pointer;border:1.5px solid var(--w-rule);background:var(--w-paper);color:var(--w-ink)}
.w-card2 .acts button.go{background:var(--w-mint);border-color:var(--w-mint);color:#fff}
.w-prog{height:8px;border-radius:4px;background:var(--w-rule);overflow:hidden;margin:10px 0 8px}
.w-prog span{display:block;height:100%;background:linear-gradient(90deg,var(--w-mint),#2fae8e);border-radius:4px}
.w-people{display:flex;flex-direction:column;gap:6px}
.w-person{display:flex;justify-content:space-between;align-items:center;font-size:13px;padding:6px 0;border-top:1px dashed var(--w-rule)}
.w-person span.n{font-family:var(--w-mono);direction:ltr}
.w-tags{display:flex;flex-wrap:wrap;gap:6px;margin:8px 0}
.w-tag{display:inline-flex;align-items:center;gap:6px;background:var(--w-mint-s);color:var(--w-g8);border-radius:999px;padding:4px 6px 4px 12px;font-size:13px}
.w-tag button{border:0;background:var(--w-paper);border-radius:50%;width:22px;height:22px;cursor:pointer;color:var(--w-red);font-size:13px;line-height:1}
.w-row2{display:flex;gap:8px}.w-row2 .w-in{flex:1}
.w-row2 button{border:0;border-radius:14px;background:var(--w-g8);color:#fff;padding:0 18px;font-family:var(--w-disp);font-weight:600;cursor:pointer}
.w-preview{background:var(--w-g8);color:#f3efe2;border-radius:16px;padding:12px 16px;margin:6px 0 14px;font-size:13px;display:flex;justify-content:space-between;align-items:center}
.w-preview b{font-family:var(--w-mono);color:var(--w-gold);font-size:18px}
.w-toggle{display:flex;align-items:center;gap:10px;font-size:13.5px;margin-bottom:14px;cursor:pointer}
.w-toggle input{width:20px;height:20px;accent-color:var(--w-mint)}
.w-link{display:flex;gap:8px;align-items:center;background:var(--w-bg);border:1px dashed var(--w-rule);border-radius:12px;padding:8px 10px;margin:10px 0;direction:ltr}
.w-link code{flex:1;font-family:var(--w-mono);font-size:11px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.w-link button{border:0;background:var(--w-mint);color:#fff;border-radius:9px;padding:6px 12px;font-family:var(--w-body);cursor:pointer;font-size:12.5px}
.w-sec2{font-family:var(--w-disp);font-size:15px;font-weight:800;margin:22px 0 10px}
.w-notif{display:grid;grid-template-columns:42px 1fr;gap:12px;padding:12px 4px;border-bottom:1px solid var(--w-rule);text-decoration:none;color:var(--w-ink);animation:w-in .35s both}
.w-notif i{width:42px;height:42px;border-radius:14px;display:grid;place-items:center;font-style:normal;font-size:18px;background:var(--w-mint-s)}
.w-notif.unread{background:linear-gradient(90deg,transparent,rgba(14,122,99,.06))}
.w-notif.unread b::after{content:"";display:inline-block;width:8px;height:8px;border-radius:50%;background:var(--w-mint);margin-inline-start:6px;vertical-align:middle}
.w-notif small{display:block;color:var(--w-muted);font-size:12px;line-height:1.5}
</style>~';
  END css;

  FUNCTION js RETURN VARCHAR2 IS
  BEGIN
    RETURN q'~<script>
window.S=function(a,d){var p={x01:a};d=d||{};['x02','x03','x04','x05','x06','x07'].forEach(function(k){if(d[k]!=null)p[k]=String(d[k])});
  return new Promise(function(res){apex.server.process('WLT_SOCIAL',p,{success:res,error:function(){res({ok:false,msg:'تعذّر الاتصال. لم يُخصم أي مبلغ.'})}})})};
window.wLook=function(inp,out,cb){var lt;inp.addEventListener('input',function(){inp.value=inp.value.replace(/\D/g,'');clearTimeout(lt);cb(null);out.textContent='';out.className='w-who';
  if(inp.value.length===10)lt=setTimeout(function(){S('lookup',{x02:inp.value}).then(function(r){
    if(r.ok){out.textContent='✓ '+r.name;out.className='w-who ok';cb(r.name)}else{out.textContent=r.msg;out.className='w-who bad'}})},200)})};
window.wCopy=function(t,btn){try{navigator.clipboard.writeText(t).then(function(){btn.textContent='تمّ النسخ ✓'},function(){btn.textContent='انسخ يدوياً'})}catch(e){btn.textContent='انسخ يدوياً'}};
</script>~';
  END js;


  -- -----------------------------------------------------------------
  -- 8) طلب أموال
  -- -----------------------------------------------------------------
  FUNCTION render_request RETURN CLOB IS
    l   wlt_v_wallets%ROWTYPE := me;
    l_h CLOB;
    l_n PLS_INTEGER;
  BEGIN
    l_h := wallet_ui2_pkg.common || css || js || '<div class="w-app">' || head('طلب أموال', 'اطلب مبلغاً برقم الهاتف أو برابط')
      || '<div class="w-tabs"><button type="button" data-p="pNew" class="on">اطلب</button><button type="button" data-p="pIn">واردة</button><button type="button" data-p="pOut">صادرة</button></div>'
      || '<section class="w-pane on" id="pNew">'
      || '<label class="w-field"><span>من (رقم الهاتف، اختياري)</span><input class="w-in ltr" id="rPhone" maxlength="10" inputmode="numeric" placeholder="اتركه فارغاً لطلب برابط مفتوح"><div class="w-who" id="rWho"></div></label>'
      || '<label class="w-field"><span>المبلغ (د.أ)</span><input class="w-in w-amount" id="rAmt" inputmode="decimal" placeholder="0.000"></label>'
      || '<label class="w-field"><span>السبب</span><input class="w-in" id="rNote" maxlength="100" placeholder="مثلاً: حصتك من الهدية"></label>'
      || '<div class="w-err" id="rErr"></div><button class="w-btn" id="rGo" type="button" disabled>أرسل الطلب</button>'
      || '<div class="w-note">الطلب صالح 48 ساعة. إذا كتبت رقماً يصله إشعار فوراً، وإذا تركته فارغاً تحصل على رابط وكود QR يدفع منه أي شخص مسجّل.</div></section>';

    -- الواردة
    l_h := l_h || '<section class="w-pane" id="pIn">';
    l_n := 0;
    FOR r IN (SELECT q.*, u.shown_name AS who FROM wlt_money_requests q JOIN wlt_v_wallets u
                ON u.user_id = q.requester_user_id AND u.wallet_type = 'MAIN'
               WHERE q.payer_user_id = l.user_id AND q.status = 'PENDING' AND q.expires_at > SYSTIMESTAMP
               ORDER BY q.created_at DESC) LOOP
      l_n := l_n + 1;
      l_h := l_h || '<div class="w-card2"><div class="t"><div><b>' || esc(r.who) || '</b><small>' || esc(NVL(r.note, 'طلب أموال'))
        || ' · ' || left_txt(r.expires_at) || '</small></div><div class="amt">' || money(r.amount) || '</div></div>'
        || '<div class="acts"><button type="button" class="go" data-pay="' || r.token || '" data-a="' || money(r.amount) || '" data-w="' || esc(r.who) || '">ادفع</button>'
        || '<button type="button" data-dec="' || r.token || '">رفض</button></div></div>';
    END LOOP;
    IF l_n = 0 THEN l_h := l_h || '<div class="w-empty">لا توجد طلبات بانتظارك 👌</div>'; END IF;
    l_h := l_h || '<div class="w-err" id="iErr"></div></section>';

    -- الصادرة
    l_h := l_h || '<section class="w-pane" id="pOut">';
    l_n := 0;
    FOR r IN (SELECT q.*, u.shown_name AS who FROM wlt_money_requests q LEFT JOIN wlt_v_wallets u
                ON u.user_id = q.payer_user_id AND u.wallet_type = 'MAIN'
               WHERE q.requester_user_id = l.user_id AND q.split_id IS NULL
               ORDER BY q.created_at DESC FETCH FIRST 20 ROWS ONLY) LOOP
      l_n := l_n + 1;
      l_h := l_h || '<div class="w-card2"><div class="t"><div><b>' || esc(NVL(r.who, 'رابط مفتوح')) || '</b><small>'
        || esc(NVL(r.note, 'طلب أموال')) || ' · ' || ago(r.created_at) || '</small></div><div style="text-align:left"><div class="amt">'
        || money(r.amount) || '</div>' || pill(CASE WHEN r.status = 'PENDING' AND r.expires_at < SYSTIMESTAMP THEN 'EXPIRED' ELSE r.status END) || '</div></div>'
        || CASE WHEN r.status = 'PENDING' AND r.expires_at > SYSTIMESTAMP THEN
             '<div class="acts"><button type="button" data-link="' || r.token || '">الرابط</button><button type="button" data-can="' || r.token || '">إلغاء</button></div>' END
        || '</div>';
    END LOOP;
    IF l_n = 0 THEN l_h := l_h || '<div class="w-empty">لم ترسل أي طلب بعد</div>'; END IF;
    l_h := l_h || '<div class="w-err" id="oErr"></div></section></div>';

    RETURN l_h || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)};W.tabs();
  var ph=$('rPhone'),amt=$('rAmt'),go=$('rGo'),name=null;W.num(amt);
  function v(){var a=parseFloat(amt.value)>0;go.disabled=!(a&&(ph.value===''||name))}
  wLook(ph,$('rWho'),function(n){name=n;v()});ph.addEventListener('input',v);amt.addEventListener('input',function(){W.err('rErr');v()});
  function base(){return location.href.split('#')[0].replace(/[?&]session=[^&]*/,'')}
  function showLink(tok,amount){
    S('req_qr',{x02:tok}).then(function(q){
      var url=base()+'#'+tok;
      W.sheet('<div class="w-receipt"><h3>شارك الطلب</h3><div class="w-qr" style="margin:0">'+(q.svg||'')+'<div class="amt">'+amount+' د.أ</div></div>'
        +'<div class="w-link"><code>'+W.esc(url)+'</code><button type="button" id="cp">نسخ</button></div>'
        +'<p class="w-sub">من يفتح الرابط بعد الدخول، أو يكتب الكود في «ادفع»، يدفع الطلب مباشرة.</p>'
        +'<button class="w-btn" type="button" onclick="location.reload()">تمّ</button></div>');
      $('cp').onclick=function(){wCopy(url,this)}})}
  go.onclick=function(){go.disabled=true;
    S('request',{x02:ph.value,x03:Number(amt.value).toFixed(3),x04:$('rNote').value}).then(function(r){
      if(!r.ok){go.disabled=false;W.err('rErr',r.msg);return}
      if(ph.value){W.sheet('<div class="w-receipt"><div class="w-check"><svg viewBox="0 0 24 24"><path d="M5 12.5 10 17 19 7"/></svg></div><h3>أُرسل الطلب</h3><p>وصل إشعار إلى '+W.esc(name)+'</p><button class="w-btn" type="button" onclick="location.reload()">تمّ</button></div>')}
      else showLink(r.token,r.amount)})};
  function payTok(tok,a,who){var idem=W.uuid();
    W.confirm('دفع طلب',[['إلى',who],['المبلغ',a+' د.أ',1]],'ادفع الآن',function(){
      S('pay_req',{x02:tok,x03:idem}).then(function(r){r.ok?W.receipt(r,'تمّ دفع الطلب',who):W.fail('iErr',r)})})}
  document.querySelectorAll('[data-pay]').forEach(function(b){b.onclick=function(){payTok(b.dataset.pay,b.dataset.a,b.dataset.w)}});
  document.querySelectorAll('[data-dec]').forEach(function(b){b.onclick=function(){b.disabled=true;
    S('decline_req',{x02:b.dataset.dec}).then(function(r){r.ok?location.reload():W.err('iErr',r.msg)})}});
  document.querySelectorAll('[data-can]').forEach(function(b){b.onclick=function(){b.disabled=true;
    S('cancel_req',{x02:b.dataset.can}).then(function(r){r.ok?location.reload():W.err('oErr',r.msg)})}});
  document.querySelectorAll('[data-link]').forEach(function(b){b.onclick=function(){showLink(b.dataset.link,b.closest('.w-card2').querySelector('.amt').textContent)}});
  var h=location.hash.replace('#','');
  if(/^[a-z0-9]{20}$/.test(h)){S('req_info',{x02:h}).then(function(r){
    if(r.ok)payTok(h,r.amount,r.who);else{document.querySelector('[data-p=pIn]').click();W.err('iErr',r.msg)}})}
  else if(document.querySelector('[data-pay]'))document.querySelector('[data-p=pIn]').click();
})();
</script>~';
  END render_request;

  -- -----------------------------------------------------------------
  -- 9) تقسيم الفاتورة
  -- -----------------------------------------------------------------
  FUNCTION render_split RETURN CLOB IS
    l   wlt_v_wallets%ROWTYPE := me;
    l_h CLOB;
    l_n PLS_INTEGER := 0;
  BEGIN
    l_h := wallet_ui2_pkg.common || css || js || '<div class="w-app">' || head('تقسيم فاتورة', 'قسّم أي مصروف على أصحابك بضغطة')
      || '<label class="w-field"><span>على ماذا؟</span><input class="w-in" id="sTitle" maxlength="100" placeholder="مثلاً: عشاء الجمعة"></label>'
      || '<label class="w-field"><span>المبلغ الكلي (د.أ)</span><input class="w-in w-amount" id="sTotal" inputmode="decimal" placeholder="0.000"></label>'
      || '<label class="w-field"><span>مع من؟</span><div class="w-row2"><input class="w-in ltr" id="sPhone" maxlength="10" inputmode="numeric" placeholder="07XXXXXXXX"><button type="button" id="sAdd" disabled>أضف</button></div><div class="w-who" id="sWho"></div></label>'
      || '<div class="w-tags" id="sTags"></div>'
      || '<label class="w-toggle"><input type="checkbox" id="sMe" checked> أنا مشارك في الدفع أيضاً</label>'
      || '<div class="w-preview" id="sPrev" style="display:none"><span id="sPrevT"></span><b id="sPrevA"></b></div>'
      || '<div class="w-err" id="sErr"></div><button class="w-btn" id="sGo" type="button" disabled>قسّم وأرسل الطلبات</button>'
      || '<div class="w-sec2">تقسيماتك</div>';

    FOR s IN (SELECT sp.*,
                     (SELECT COUNT(*) FROM wlt_money_requests r WHERE r.split_id = sp.split_id) AS n_all,
                     (SELECT COUNT(*) FROM wlt_money_requests r WHERE r.split_id = sp.split_id AND r.status = 'PAID') AS n_paid,
                     (SELECT NVL(SUM(amount), 0) FROM wlt_money_requests r WHERE r.split_id = sp.split_id AND r.status = 'PAID') AS got
                FROM wlt_splits sp WHERE sp.owner_user_id = l.user_id ORDER BY sp.created_at DESC FETCH FIRST 10 ROWS ONLY) LOOP
      l_n := l_n + 1;
      l_h := l_h || '<div class="w-card2"><div class="t"><div><b>' || esc(s.title) || '</b><small>' || ago(s.created_at)
        || ' · وصلك ' || money(s.got) || ' من ' || money(s.total_amount - s.owner_share) || '</small></div><div class="amt">'
        || money(s.total_amount) || '</div></div>'
        || '<div class="w-prog"><span style="width:' || ROUND(s.n_paid / NULLIF(s.n_all, 0) * 100) || '%"></span></div>'
        || '<div class="w-people">';
      FOR p IN (SELECT r.amount, r.status, u.shown_name FROM wlt_money_requests r
                  JOIN wlt_v_wallets u ON u.user_id = r.payer_user_id AND u.wallet_type = 'MAIN'
                 WHERE r.split_id = s.split_id ORDER BY r.req_id) LOOP
        l_h := l_h || '<div class="w-person"><span>' || esc(p.shown_name) || ' ' || pill(p.status) || '</span><span class="n">' || money(p.amount) || '</span></div>';
      END LOOP;
      l_h := l_h || '</div>'
        || CASE WHEN s.n_paid < s.n_all THEN '<div class="acts"><button type="button" data-rem="' || s.split_id || '">🔔 ذكّر المتأخرين'
             || CASE WHEN s.reminders > 0 THEN ' (' || s.reminders || ')' END || '</button></div>' END
        || '</div>';
    END LOOP;
    IF l_n = 0 THEN l_h := l_h || '<div class="w-empty">لا توجد تقسيمات بعد</div>'; END IF;

    RETURN l_h || '</div>' || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)},people=[],cand=null,ph=$('sPhone'),tot=$('sTotal'),go=$('sGo');W.num(tot);
  wLook(ph,$('sWho'),function(n){cand=n?{p:ph.value,n:n}:null;$('sAdd').disabled=!cand||people.some(function(x){return x.p===cand.p})});
  function draw(){$('sTags').innerHTML=people.map(function(x,i){return '<span class="w-tag">'+W.esc(x.n)+'<button type="button" data-i="'+i+'">×</button></span>'}).join('');
    $('sTags').querySelectorAll('button').forEach(function(b){b.onclick=function(){people.splice(+b.dataset.i,1);draw()}});calc()}
  function calc(){var t=parseFloat(tot.value),n=people.length+($('sMe').checked?1:0);
    if(t>0&&people.length){var s=Math.floor(t/n*1000)/1000;$('sPrev').style.display='flex';$('sPrevT').textContent='حصة كل شخص ('+n+' أشخاص)';$('sPrevA').textContent=s.toFixed(3)}
    else $('sPrev').style.display='none';
    go.disabled=!(t>0&&people.length&&$('sTitle').value.trim())}
  $('sAdd').onclick=function(){if(!cand)return;people.push(cand);cand=null;ph.value='';$('sWho').textContent='';this.disabled=true;draw()};
  [tot,$('sTitle')].forEach(function(e){e.addEventListener('input',function(){W.err('sErr');calc()})});$('sMe').onchange=calc;
  go.onclick=function(){go.disabled=true;go.textContent='جارٍ الإرسال…';
    S('split',{x02:$('sTitle').value,x03:Number(tot.value).toFixed(3),x04:people.map(function(x){return x.p}).join(','),x05:$('sMe').checked?'Y':'N'}).then(function(r){
      if(r.ok){W.sheet('<div class="w-receipt"><div class="w-check"><svg viewBox="0 0 24 24"><path d="M5 12.5 10 17 19 7"/></svg></div><h3>أُرسلت '+people.length+' طلبات</h3><p>حصة كل شخص '+r.share+' د.أ</p><button class="w-btn" type="button" onclick="location.reload()">تمّ</button></div>')}
      else{go.disabled=false;go.textContent='قسّم وأرسل الطلبات';W.err('sErr',r.msg)}})};
  document.querySelectorAll('[data-rem]').forEach(function(b){b.onclick=function(){b.disabled=true;
    S('remind',{x02:b.dataset.rem}).then(function(r){b.textContent=r.ok?'✓ وصل التذكير لـ'+r.n:r.msg})}});
})();
</script>~';
  END render_split;

  -- -----------------------------------------------------------------
  -- 10) التحويلات المجدولة
  -- -----------------------------------------------------------------
  FUNCTION render_sched RETURN CLOB IS
    l   wlt_v_wallets%ROWTYPE := me;
    l_h CLOB;
    l_n PLS_INTEGER := 0;
  BEGIN
    l_h := wallet_ui2_pkg.common || css || js || '<div class="w-app">' || head('التحويلات المجدولة', 'الإيجار، المصروف، أي دفعة متكررة')
      || '<label class="w-field"><span>إلى</span><input class="w-in ltr" id="cPhone" maxlength="10" inputmode="numeric" placeholder="07XXXXXXXX"><div class="w-who" id="cWho"></div></label>'
      || '<label class="w-field"><span>المبلغ (د.أ)</span><input class="w-in w-amount" id="cAmt" inputmode="decimal" placeholder="0.000"></label>'
      || '<span style="display:block;font-size:13px;font-weight:600;margin-bottom:8px">التكرار</span>'
      || '<div class="w-grid" id="cFreq" style="grid-template-columns:repeat(4,1fr)"><button class="w-tile on" type="button" data-f="ONCE">مرة</button><button class="w-tile" type="button" data-f="DAILY">يومي</button>'
      || '<button class="w-tile" type="button" data-f="WEEKLY">أسبوعي</button><button class="w-tile" type="button" data-f="MONTHLY">شهري</button></div>'
      || '<div class="w-row2" style="margin-bottom:14px"><label class="w-field" style="flex:1;margin:0"><span>أول تنفيذ</span><input class="w-in ltr" id="cWhen" type="datetime-local"></label>'
      || '<label class="w-field" style="width:120px;margin:0" id="cCntBox"><span>عدد المرات</span><input class="w-in ltr" id="cCnt" inputmode="numeric" placeholder="∞"></label></div>'
      || '<label class="w-field"><span>ملاحظة</span><input class="w-in" id="cNote" maxlength="100" placeholder="مثلاً: مصروف الأسبوع"></label>'
      || '<div class="w-err" id="cErr"></div><button class="w-btn" id="cGo" type="button" disabled>جدولة التحويل</button>'
      || '<div class="w-note">المهمة تعمل تلقائياً كل 5 دقائق في قاعدة البيانات. إذا لم يكفِ رصيدك يصلك إشعار، ولا يُكرَّر الخصم أبداً.</div>'
      || '<div class="w-sec2">جدولاتك</div>';

    FOR s IN (SELECT t.*, u.shown_name AS who FROM wlt_scheduled_transfers t
                JOIN wlt_v_wallets u ON u.user_id = t.to_user_id AND u.wallet_type = 'MAIN'
               WHERE t.from_user_id = l.user_id AND t.status <> 'CANCELLED'
               ORDER BY CASE t.status WHEN 'ACTIVE' THEN 1 WHEN 'PAUSED' THEN 2 ELSE 3 END, t.next_run_at) LOOP
      l_n := l_n + 1;
      l_h := l_h || '<div class="w-card2"><div class="t"><div><b>' || esc(s.who) || '</b><small>'
        || CASE s.frequency WHEN 'ONCE' THEN 'مرة واحدة' WHEN 'DAILY' THEN 'يومياً' WHEN 'WEEKLY' THEN 'أسبوعياً' ELSE 'شهرياً' END
        || CASE WHEN s.status IN ('ACTIVE','PAUSED') THEN ' · التالي ' || TO_CHAR(s.next_run_at, 'DD/MM HH24:MI') END
        || ' · نُفّذ ' || s.runs_count || CASE WHEN s.max_runs IS NOT NULL THEN ' من ' || s.max_runs END
        || CASE WHEN s.note IS NOT NULL THEN ' · ' || esc(s.note) END || '</small>'
        || CASE WHEN s.last_error IS NOT NULL THEN '<small style="color:var(--w-red)">⚠ ' || esc(s.last_error) || '</small>' END
        || '</div><div style="text-align:left"><div class="amt">' || money(s.amount) || '</div>' || pill(s.status) || '</div></div>'
        || CASE WHEN s.status IN ('ACTIVE','PAUSED') THEN '<div class="acts"><button type="button" data-tog="' || s.sched_id || '" data-to="'
             || CASE s.status WHEN 'ACTIVE' THEN 'PAUSED">⏸ إيقاف مؤقت' ELSE 'ACTIVE">▶ استئناف' END || '</button>'
             || '<button type="button" data-tog="' || s.sched_id || '" data-to="CANCELLED">إلغاء</button></div>' END
        || '</div>';
    END LOOP;
    IF l_n = 0 THEN l_h := l_h || '<div class="w-empty">لا توجد تحويلات مجدولة</div>'; END IF;

    RETURN l_h || '<div class="w-err" id="lErr"></div></div>' || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)},freq='ONCE',name=null,amt=$('cAmt'),go=$('cGo'),when=$('cWhen');W.num(amt);
  var d=new Date(Date.now()+10*60000);d.setSeconds(0,0);
  when.value=new Date(d.getTime()-d.getTimezoneOffset()*60000).toISOString().slice(0,16);
  function v(){go.disabled=!(name&&parseFloat(amt.value)>0&&when.value)}
  wLook($('cPhone'),$('cWho'),function(n){name=n;v()});amt.addEventListener('input',function(){W.err('cErr');v()});when.onchange=v;
  $('cCntBox').style.visibility='hidden';
  document.querySelectorAll('#cFreq .w-tile').forEach(function(b){b.onclick=function(){
    document.querySelectorAll('#cFreq .w-tile').forEach(function(x){x.classList.toggle('on',x===b)});freq=b.dataset.f;
    $('cCntBox').style.visibility=freq==='ONCE'?'hidden':'visible'}});
  go.onclick=function(){go.disabled=true;
    var w=new Date(when.value),iso=w.getFullYear()+'-'+String(w.getMonth()+1).padStart(2,'0')+'-'+String(w.getDate()).padStart(2,'0')+' '+String(w.getHours()).padStart(2,'0')+':'+String(w.getMinutes()).padStart(2,'0');
    S('schedule',{x02:$('cPhone').value,x03:Number(amt.value).toFixed(3),x04:$('cNote').value,x05:freq,x06:iso,x07:$('cCnt').value}).then(function(r){
      if(r.ok)location.reload();else{go.disabled=false;W.err('cErr',r.msg)}})};
  document.querySelectorAll('[data-tog]').forEach(function(b){b.onclick=function(){b.disabled=true;
    S('sched_status',{x02:b.dataset.tog,x03:b.dataset.to}).then(function(r){r.ok?location.reload():W.err('lErr',r.msg)})}});
})();
</script>~';
  END render_sched;

  -- -----------------------------------------------------------------
  -- 11) الإشعارات
  -- -----------------------------------------------------------------
  FUNCTION render_inbox RETURN CLOB IS
    l   wlt_v_wallets%ROWTYPE := me;
    l_h CLOB;
    l_n PLS_INTEGER := 0;
  BEGIN
    l_h := css || js || wallet_ui2_pkg.common || '<div class="w-app">' || head('الإشعارات', 'كل ما يحدث في محفظتك');
    FOR n IN (SELECT * FROM wlt_notifications WHERE user_id = l.user_id ORDER BY notif_id DESC FETCH FIRST 40 ROWS ONLY) LOOP
      l_n := l_n + 1;
      l_h := l_h || '<a class="w-notif' || CASE WHEN n.is_read = 'N' THEN ' unread' END || '" href="'
        || CASE WHEN n.link_page IS NOT NULL THEN apex_page.get_url(p_page => n.link_page) ELSE '#' END
        || '" style="animation-delay:' || LEAST(l_n * 30, 600) || 'ms"><i>'
        || CASE n.kind WHEN 'MONEY_IN' THEN '💸' WHEN 'REQUEST' THEN '🙋' WHEN 'REQUEST_PAID' THEN '✅' WHEN 'REQUEST_DECLINED' THEN '✖'
                       WHEN 'REMINDER' THEN '🔔' WHEN 'SCHEDULED_OK' THEN '🗓' WHEN 'SCHEDULED_FAIL' THEN '⚠' ELSE '•' END
        || '</i><div><b>' || esc(n.title) || '</b><small>' || esc(n.body) || '</small><small>' || ago(n.created_at) || '</small></div></a>';
    END LOOP;
    IF l_n = 0 THEN l_h := l_h || '<div class="w-empty">لا توجد إشعارات بعد</div>'; END IF;
    RETURN l_h || '</div><script>window.addEventListener("load",function(){S("read_all")})</script>';
  END render_inbox;

  -- -----------------------------------------------------------------
  -- Ajax
  -- -----------------------------------------------------------------
  PROCEDURE out_receipt (p_ref VARCHAR2) IS
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
  END out_receipt;

  FUNCTION num (p VARCHAR2) RETURN NUMBER IS
  BEGIN RETURN TO_NUMBER(p, '999999990D999', 'NLS_NUMERIC_CHARACTERS=''.,'''); END;

  PROCEDURE ok_only IS
  BEGIN apex_json.open_object; apex_json.write('ok', TRUE); apex_json.close_object; END;

  PROCEDURE api IS
    a   VARCHAR2(30)   := apex_application.g_x01;
    x2  VARCHAR2(4000) := apex_application.g_x02;
    x3  VARCHAR2(4000) := apex_application.g_x03;
    x4  VARCHAR2(4000) := apex_application.g_x04;
    x5  VARCHAR2(4000) := apex_application.g_x05;
    x6  VARCHAR2(4000) := apex_application.g_x06;
    x7  VARCHAR2(4000) := apex_application.g_x07;
    u   VARCHAR2(20)   := v('APP_USER');
    l   wlt_v_wallets%ROWTYPE;
    l_s VARCHAR2(200);
    l_n NUMBER;
    l_id NUMBER;
    l_r wlt_money_requests%ROWTYPE;
    l_msg VARCHAR2(4000);
  BEGIN
    CASE a
    WHEN 'lookup' THEN
      apex_json.open_object;
      BEGIN
        SELECT shown_name INTO l_s FROM wlt_v_wallets
         WHERE phone = x2 AND wallet_type = 'MAIN' AND user_type IN ('CUSTOMER','MERCHANT','AGENT') AND phone <> u;
        apex_json.write('ok', TRUE); apex_json.write('name', l_s);
      EXCEPTION WHEN NO_DATA_FOUND THEN
        apex_json.write('ok', FALSE);
        apex_json.write('msg', CASE WHEN x2 = u THEN 'هذا رقمك أنت' ELSE 'هذا الرقم غير مسجّل في المحفظة' END);
      END;
      apex_json.close_object;

    WHEN 'request' THEN
      l_s := wallet_social_pkg.request_money(u, NULLIF(x2, ''), num(x3), x4);
      apex_json.open_object; apex_json.write('ok', TRUE); apex_json.write('token', l_s);
      apex_json.write('amount', money(num(x3))); apex_json.close_object;

    WHEN 'req_qr' THEN
      apex_json.open_object; apex_json.write('ok', TRUE);
      apex_json.write('svg', apex_barcode.get_qrcode_svg(p_value => 'WLT-REQ:' || x2, p_foreground_color => '#0a2622'));
      apex_json.close_object;

    WHEN 'req_info' THEN
      apex_json.open_object;
      BEGIN
        SELECT * INTO l_r FROM wlt_money_requests WHERE token = x2;
        SELECT shown_name INTO l_s FROM wlt_v_wallets WHERE user_id = l_r.requester_user_id AND wallet_type = 'MAIN';
        IF l_r.status <> 'PENDING' OR l_r.expires_at < SYSTIMESTAMP THEN
          apex_json.write('ok', FALSE); apex_json.write('msg', 'هذا الطلب لم يعد متاحاً');
        ELSE
          apex_json.write('ok', TRUE); apex_json.write('who', l_s); apex_json.write('amount', money(l_r.amount));
        END IF;
      EXCEPTION WHEN NO_DATA_FOUND THEN
        apex_json.write('ok', FALSE); apex_json.write('msg', 'الطلب غير موجود');
      END;
      apex_json.close_object;

    WHEN 'pay_req'     THEN out_receipt(wallet_social_pkg.pay_request(u, x2, x3));
    WHEN 'decline_req' THEN wallet_social_pkg.decline_request(u, x2); ok_only;
    WHEN 'cancel_req'  THEN wallet_social_pkg.cancel_request(u, x2); ok_only;

    WHEN 'split' THEN
      l_id := wallet_social_pkg.create_split(u, x2, num(x3), x4, x5 = 'Y');
      SELECT MAX(amount) INTO l_n FROM wlt_money_requests WHERE split_id = l_id;
      apex_json.open_object; apex_json.write('ok', TRUE); apex_json.write('share', money(l_n)); apex_json.close_object;

    WHEN 'remind' THEN
      l_n := wallet_social_pkg.remind_split(u, TO_NUMBER(x2));
      apex_json.open_object; apex_json.write('ok', TRUE); apex_json.write('n', l_n); apex_json.close_object;

    WHEN 'schedule' THEN
      l_n := wallet_social_pkg.schedule(u, x2, num(x3), x4, x5,
               TO_TIMESTAMP(x6, 'YYYY-MM-DD HH24:MI'), TO_NUMBER(NULLIF(TRIM(x7), '')));
      ok_only;

    WHEN 'sched_status' THEN
      wallet_social_pkg.set_schedule_status(u, TO_NUMBER(x2), x3); ok_only;

    WHEN 'read_all' THEN
      l := me;
      UPDATE wlt_notifications SET is_read = 'Y' WHERE user_id = l.user_id AND is_read = 'N';
      COMMIT;
      ok_only;

    ELSE
      apex_json.open_object; apex_json.write('ok', FALSE); apex_json.write('msg', 'عملية غير معروفة'); apex_json.close_object;
    END CASE;
  EXCEPTION
    WHEN OTHERS THEN
      l_msg := SQLERRM;
      IF SQLCODE BETWEEN -20999 AND -20000 THEN
        l_msg := REGEXP_REPLACE(REGEXP_SUBSTR(l_msg, '^[^' || CHR(10) || ']+'), '^ORA-\d+: ', '');
      ELSIF SQLCODE IN (-6502, -1722, -1830, -1843, -1847, -1858) THEN
        l_msg := 'تحقق من القيم المدخلة';
      ELSE
        l_msg := 'حدث خطأ غير متوقع. لم يُخصم أي مبلغ.';
      END IF;
      apex_json.open_object;
      apex_json.write('ok', FALSE); apex_json.write('code', SQLCODE); apex_json.write('msg', l_msg);
      apex_json.close_object;
  END api;

END wallet_ui3_pkg;
/
