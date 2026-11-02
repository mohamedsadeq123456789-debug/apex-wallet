-- =====================================================================
--  محفظتي · الجلسة 4 · الشاشات
--  الصفحات: 3 ادفع QR · 4 فواتير وشحن · 5 سحب نقدي · 6 استلام دفعة (تاجر) · 7 الوكيل
--  كل الشاشات تتصل بعملية Ajax واحدة اسمها WLT_API
-- =====================================================================
CREATE OR REPLACE PACKAGE wallet_ui2_pkg AS
  FUNCTION actions (p_role VARCHAR2) RETURN VARCHAR2;
  FUNCTION render_pay      RETURN CLOB;
  FUNCTION render_bills    RETURN CLOB;
  FUNCTION render_cash     RETURN CLOB;
  FUNCTION render_receive  RETURN CLOB;
  FUNCTION render_agent    RETURN CLOB;
  FUNCTION common          RETURN CLOB;
  PROCEDURE api;
END wallet_ui2_pkg;
/

CREATE OR REPLACE PACKAGE BODY wallet_ui2_pkg AS

  c_i_send CONSTANT VARCHAR2(300) := '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 2 11 13"/><path d="M22 2 15 22l-4-9-9-4z"/></svg>';
  c_i_qr   CONSTANT VARCHAR2(400) := '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3v3h-3zM20 14v.01M14 20h.01M17 20h4v-3"/></svg>';
  c_i_bill CONSTANT VARCHAR2(300) := '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 2h12v20l-3-2-3 2-3-2-3 2z"/><path d="M9 7h6M9 11h6M9 15h4"/></svg>';
  c_i_cash CONSTANT VARCHAR2(300) := '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="6" width="20" height="12" rx="2"/><circle cx="12" cy="12" r="2.5"/><path d="M6 12h.01M18 12h.01"/></svg>';
  c_i_in   CONSTANT VARCHAR2(300) := '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12"/><path d="m7 10 5 5 5-5"/><path d="M4 21h16"/></svg>';
  c_i_req  CONSTANT VARCHAR2(300) := '<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14"/><path d="m19 12-7 7-7-7"/></svg>';

  FUNCTION esc (p VARCHAR2) RETURN VARCHAR2 IS BEGIN RETURN apex_escape.html(p); END;

  FUNCTION money (p NUMBER) RETURN VARCHAR2 IS
  BEGIN
    RETURN TO_CHAR(p, 'FM999G999G990D000', 'NLS_NUMERIC_CHARACTERS=''.,''');
  END money;

  FUNCTION me RETURN wlt_v_wallets%ROWTYPE IS
    l wlt_v_wallets%ROWTYPE;
    l_w NUMBER := wallet_core_pkg.main_wallet(v('APP_USER'));
  BEGIN
    SELECT * INTO l FROM wlt_v_wallets WHERE wallet_id = l_w;
    RETURN l;
  END me;

  FUNCTION act (p_page NUMBER, p_icon VARCHAR2, p_label VARCHAR2, p_main BOOLEAN DEFAULT FALSE) RETURN VARCHAR2 IS
  BEGIN
    IF p_page IS NULL THEN
      RETURN '<a class="w-act soon"><i>' || p_icon || '</i>' || p_label || '</a>';
    END IF;
    RETURN '<a class="w-act' || CASE WHEN p_main THEN ' main' END || '" href="'
        || apex_page.get_url(p_page => p_page) || '"><i>' || p_icon || '</i>' || p_label || '</a>';
  END act;

  FUNCTION actions (p_role VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN '<nav class="w-actions">' ||
      CASE p_role
        WHEN 'MERCHANT' THEN act(6, c_i_qr, 'استلام دفعة', TRUE) || act(2, c_i_send, 'تحويل')
                          || act(4, c_i_bill, 'فواتير') || act(NULL, c_i_req, 'طلب أموال')
        WHEN 'AGENT'    THEN act(7, c_i_in, 'إيداع لعميل', TRUE) || act(7, c_i_cash, 'صرف سحب')
                          || act(2, c_i_send, 'تحويل') || act(4, c_i_bill, 'فواتير')
        ELSE act(2, c_i_send, 'تحويل', TRUE) || act(3, c_i_qr, 'ادفع QR')
          || act(4, c_i_bill, 'فواتير') || act(5, c_i_cash, 'سحب نقدي')
      END || '</nav>';
  END actions;

  -- -----------------------------------------------------------------
  -- أدوات مشتركة لكل الشاشات: تصميم إضافي + دوال JavaScript
  -- -----------------------------------------------------------------
  FUNCTION common RETURN CLOB IS
  BEGIN
    RETURN q'~<style>
.w-head{display:flex;align-items:center;gap:12px;margin-bottom:18px}
.w-head a{width:40px;height:40px;border-radius:13px;background:var(--w-paper);border:1px solid var(--w-rule);display:grid;place-items:center;color:var(--w-ink);text-decoration:none;font-size:18px;flex:none}
.w-head h1{font-family:var(--w-disp);font-size:22px;font-weight:800;margin:0;line-height:1.2}
.w-head p{margin:0;font-size:12.5px;color:var(--w-muted)}
.w-tabs{display:grid;grid-auto-flow:column;grid-auto-columns:1fr;background:var(--w-paper);border:1px solid var(--w-rule);border-radius:14px;padding:4px;margin-bottom:18px}
.w-tabs button{border:0;background:none;padding:10px;border-radius:10px;font-family:var(--w-body);font-weight:600;font-size:14px;color:var(--w-muted);cursor:pointer}
.w-tabs button.on{background:var(--w-g8);color:#fff}
.w-pane{display:none}.w-pane.on{display:block;animation:w-in .3s both}
.w-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-bottom:16px}
.w-tile{border:1.5px solid var(--w-rule);background:var(--w-paper);border-radius:16px;padding:14px 8px;text-align:center;cursor:pointer;font-family:var(--w-body);font-size:13px;font-weight:600;color:var(--w-ink);transition:border-color .15s,transform .15s}
.w-tile b{display:block;font-size:22px;margin-bottom:4px}
.w-tile:hover{transform:translateY(-2px)}.w-tile.on{border-color:var(--w-mint);background:var(--w-mint-s)}
.w-list{display:grid;gap:8px;margin:12px 0}
.w-bill{display:grid;grid-template-columns:1fr auto;gap:8px;align-items:center;border:1.5px solid var(--w-rule);background:var(--w-paper);border-radius:16px;padding:12px 14px;cursor:pointer}
.w-bill.on{border-color:var(--w-mint);background:var(--w-mint-s)}
.w-bill small{display:block;color:var(--w-muted);font-size:12px}
.w-bill b{font-family:var(--w-mono);direction:ltr}
.w-bill .late{color:var(--w-red);font-weight:600}
.w-cam{position:relative;border-radius:22px;overflow:hidden;background:var(--w-g9);aspect-ratio:1;margin-bottom:14px;display:grid;place-items:center;color:#cfe3dc;text-align:center}
.w-cam video{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}
.w-cam .frame{position:absolute;inset:18%;border-radius:20px;box-shadow:0 0 0 999px rgba(6,20,17,.45);border:2px solid rgba(233,197,111,.9)}
.w-cam .frame::after{content:"";position:absolute;left:8%;right:8%;height:2px;background:var(--w-gold);top:10%;animation:w-scan 2s ease-in-out infinite alternate;box-shadow:0 0 12px var(--w-gold)}
.w-cam .msg{position:relative;padding:20px;font-size:14px;line-height:1.7}
.w-cam .msg button{margin-top:12px}
.w-merchant{display:flex;align-items:center;gap:12px;border:1.5px solid var(--w-mint);background:var(--w-mint-s);border-radius:16px;padding:12px 14px;margin:12px 0}
.w-merchant i{width:44px;height:44px;border-radius:14px;background:var(--w-mint);color:#fff;display:grid;place-items:center;font-style:normal;font-family:var(--w-disp);font-weight:800}
.w-merchant b{display:block}.w-merchant small{color:var(--w-muted)}
.w-qr{background:#fff;border-radius:24px;padding:18px;border:1px solid var(--w-rule);text-align:center;margin:8px 0 14px;position:relative}
.w-qr svg{width:min(240px,70vw);height:auto;display:block;margin:0 auto}
.w-qr .amt{font-family:var(--w-mono);font-size:28px;font-weight:700;margin-top:8px}
.w-qr .tok{font-family:var(--w-mono);font-size:11px;color:var(--w-muted);letter-spacing:.08em;word-break:break-all}
.w-qr.paid::after{content:"✓ تمّ الدفع";position:absolute;inset:0;border-radius:24px;background:rgba(14,122,99,.92);color:#fff;display:grid;place-items:center;font-family:var(--w-disp);font-size:28px;font-weight:800;animation:w-pop .4s}
.w-timer{display:flex;justify-content:center;gap:6px;align-items:center;font-size:13px;color:var(--w-muted)}
.w-timer b{font-family:var(--w-mono);color:var(--w-ink)}
.w-code{display:flex;justify-content:center;gap:8px;direction:ltr;margin:14px 0}
.w-code span{width:46px;height:60px;border-radius:14px;background:var(--w-g8);color:var(--w-gold);display:grid;place-items:center;font-family:var(--w-mono);font-size:30px;font-weight:700;animation:w-pop .4s both}
.w-ring{width:100%;height:6px;border-radius:3px;background:var(--w-rule);overflow:hidden;margin:6px 0 14px}
.w-ring span{display:block;height:100%;background:var(--w-mint);transition:width 1s linear}
.w-note{font-size:12.5px;color:var(--w-muted);background:var(--w-paper);border:1px dashed var(--w-rule);border-radius:14px;padding:10px 14px;margin-top:14px;line-height:1.7}
.w-demo-chip{border:1px solid var(--w-rule);background:var(--w-paper);border-radius:999px;padding:4px 12px;font-size:12.5px;cursor:pointer;color:var(--w-ink);font-family:var(--w-body)}
.w-demo-chip b{font-family:var(--w-mono);font-weight:500}
@keyframes w-scan{to{top:88%}}
</style>
<script>
window.W=window.W||{};
W.api=function(a,d){var p={x01:a};d=d||{};['x02','x03','x04','x05','x06'].forEach(function(k){if(d[k]!=null)p[k]=String(d[k])});
  return new Promise(function(res){apex.server.process('WLT_API',p,{success:res,error:function(){res({ok:false,msg:'تعذّر الاتصال. لم يُخصم أي مبلغ.'})}})})};
W.uuid=function(){return (self.crypto&&crypto.randomUUID)?crypto.randomUUID():String(Date.now())+Math.random()};
W.esc=function(s){return apex.util.escapeHTML(String(s==null?'':s))};
W.sheet=function(h){var b=document.getElementById('wSheet');
  if(!b){b=document.createElement('div');b.id='wSheet';b.className='w-sheet-bg';b.innerHTML='<div class="w-sheet" id="wSheetBody"></div>';document.body.appendChild(b);
    b.addEventListener('click',function(e){if(e.target===b&&!W.busy)W.close()})}
  document.getElementById('wSheetBody').innerHTML=h;b.classList.add('on')};
W.close=function(){var b=document.getElementById('wSheet');if(b)b.classList.remove('on');W.busy=false};
W.err=function(id,m){var e=document.getElementById(id);if(!e)return;e.textContent=m||'';e.classList.toggle('on',!!m)};
W.confirm=function(title,rows,label,run){
  var h='<h3>'+W.esc(title)+'</h3><div class="w-rows">';
  rows.forEach(function(r){h+='<div'+(r[2]?' class="tot"':'')+'><span>'+W.esc(r[0])+'</span><b>'+W.esc(r[1])+'</b></div>'});
  h+='</div><button class="w-btn" id="wOk" type="button">'+W.esc(label)+'</button><div style="height:8px"></div><button class="w-btn ghost" type="button" onclick="W.close()">إلغاء</button>';
  W.sheet(h);document.getElementById('wOk').onclick=function(){if(W.busy)return;W.busy=true;this.disabled=true;this.textContent='جارٍ التنفيذ…';run()}};
W.receipt=function(r,title,sub){
  W.sheet('<div class="w-receipt"><div class="w-check"><svg viewBox="0 0 24 24"><path d="M5 12.5 10 17 19 7"/></svg></div>'
   +'<h3 style="margin-bottom:4px">'+W.esc(title)+'</h3><div class="big">'+r.amount+' <small style="font-size:14px">د.أ</small></div>'
   +(sub?'<p style="margin:6px 0 2px">'+W.esc(sub)+'</p>':'')+'<div class="w-ref">'+r.ref+' · '+r.time+'</div>'
   +'<div class="w-rows" style="margin-top:16px">'+(r.fee!=='0.000'?'<div><span>الرسوم</span><b>'+r.fee+'</b></div>':'')
   +'<div><span>رصيدك الآن</span><b>'+r.balance+' د.أ</b></div></div>'
   +'<a class="w-btn" style="display:block;text-decoration:none;text-align:center" href="'+r.home+'">العودة للرئيسية</a></div>');W.busy=true};
W.fail=function(id,r){W.close();W.err(id,r.msg)};
W.num=function(el){el.addEventListener('input',function(){el.value=el.value.replace(/[^\d.]/g,'')})};
W.tabs=function(){document.querySelectorAll('.w-tabs button').forEach(function(b){b.onclick=function(){
  document.querySelectorAll('.w-tabs button').forEach(function(x){x.classList.toggle('on',x===b)});
  document.querySelectorAll('.w-pane').forEach(function(p){p.classList.toggle('on',p.id===b.dataset.p)})}})};
</script>~';
  END common;

  FUNCTION head (p_title VARCHAR2, p_sub VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN '<div class="w-head"><a href="' || apex_page.get_url(p_page => 1) || '" title="الرئيسية">→</a>'
        || '<div><h1>' || esc(p_title) || '</h1><p>' || esc(p_sub) || '</p></div></div>';
  END head;

  FUNCTION avail (p NUMBER) RETURN VARCHAR2 IS
  BEGIN
    RETURN '<div class="w-avail"><span>رصيدك المتاح</span><b>' || money(p) || ' د.أ</b></div>';
  END avail;

  FUNCTION wrong_role (p_msg VARCHAR2) RETURN CLOB IS
  BEGIN
    RETURN common || '<div class="w-app">' || head('غير متاح', p_msg)
        || '<div class="w-empty">' || esc(p_msg) || '</div></div>';
  END wrong_role;

  -- -----------------------------------------------------------------
  -- 3) ادفع QR
  -- -----------------------------------------------------------------
  FUNCTION render_pay RETURN CLOB IS
    l wlt_v_wallets%ROWTYPE := me;
  BEGIN
    RETURN common || '<div class="w-app">' || head('ادفع للتاجر', 'امسح كود QR أو اكتب كود التاجر')
      || avail(l.available_balance)
      || '<div class="w-cam" id="wCam"><div class="msg">الكاميرا متوقفة<br><button class="w-btn" type="button" id="wCamGo" style="width:auto;padding:10px 22px">تشغيل الكاميرا</button></div></div>'
      || '<label class="w-field"><span>أو اكتب كود التاجر</span><input class="w-in ltr" id="wTarget" maxlength="40" placeholder="M2041" autocomplete="off"></label>'
      || '<div style="display:flex;gap:8px;flex-wrap:wrap;margin:-4px 0 12px"><button class="w-demo-chip" type="button" data-t="M2041">مقهى <b>M2041</b></button><button class="w-demo-chip" type="button" data-t="M3307">صيدلية <b>M3307</b></button></div>'
      || '<div id="wFound"></div>'
      || '<label class="w-field" id="wAmtBox" style="display:none"><span>المبلغ (د.أ)</span><input class="w-in w-amount" id="wAmt" inputmode="decimal" placeholder="0.000" autocomplete="off"></label>'
      || '<div class="w-err" id="wErr"></div>'
      || '<button class="w-btn" id="wGo" type="button" disabled>متابعة</button></div>'
      || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)},t=$('wTarget'),amt=$('wAmt'),go=$('wGo'),found=$('wFound'),box=$('wAmtBox');
  var info=null,stream=null,timer=null;W.num(amt);
  function valid(){go.disabled=!(info&&(info.amount||parseFloat(amt.value)>0))}
  function look(v){info=null;found.innerHTML='';box.style.display='none';W.err('wErr');valid();
    v=(v||'').trim();if(v.length<5)return;
    W.api('qr_info',{x02:v}).then(function(r){
      if(!r.ok){W.err('wErr',r.msg);return}
      info=r;info.target=v;
      found.innerHTML='<div class="w-merchant"><i>'+W.esc(r.name.charAt(0))+'</i><div><b>'+W.esc(r.name)+'</b><small>'+W.esc(r.category||'')
        +(r.amount?' · مبلغ محدد '+r.amount+' د.أ':'')+(r.note?' · '+W.esc(r.note):'')+'</small></div></div>';
      box.style.display=r.amount?'none':'block';if(!r.amount)amt.focus();valid()})}
  var lt;t.addEventListener('input',function(){clearTimeout(lt);lt=setTimeout(function(){look(t.value)},300)});
  amt.addEventListener('input',function(){W.err('wErr');valid()});
  document.querySelectorAll('.w-demo-chip').forEach(function(b){b.onclick=function(){t.value=b.dataset.t;look(t.value)}});
  function stop(){if(stream){stream.getTracks().forEach(function(x){x.stop()});stream=null}cancelAnimationFrame(timer)}
  $('wCamGo').onclick=function(){
    var cam=$('wCam');
    if(!('BarcodeDetector' in window)||!navigator.mediaDevices){cam.querySelector('.msg').innerHTML='هذا المتصفح لا يدعم قراءة QR بالكاميرا.<br>اكتب كود التاجر في الخانة بالأسفل.';return}
    navigator.mediaDevices.getUserMedia({video:{facingMode:'environment'}}).then(function(s){
      stream=s;cam.innerHTML='<video playsinline muted></video><div class="frame"></div>';
      var v=cam.querySelector('video');v.srcObject=s;v.play();
      var det=new BarcodeDetector({formats:['qr_code']});
      (function scan(){det.detect(v).then(function(c){
        if(c.length){stop();cam.innerHTML='<div class="msg">✓ تمّت قراءة الكود</div>';t.value=c[0].rawValue.replace(/^WLT:/i,'');look(t.value)}
        else timer=requestAnimationFrame(scan)}).catch(function(){timer=requestAnimationFrame(scan)})})();
    }).catch(function(){cam.querySelector('.msg').innerHTML='لم يُسمح باستخدام الكاميرا.<br>اكتب كود التاجر يدوياً.'})};
  window.addEventListener('pagehide',stop);
  go.onclick=function(){
    var a=info.amount||Number(amt.value).toFixed(3),idem=W.uuid();
    W.confirm('تأكيد الدفع',[['إلى',info.name],['الرسوم','0.000'],['المجموع',a+' د.أ',1]],'ادفع الآن',function(){
      W.api('pay',{x02:info.target,x03:a,x04:idem}).then(function(r){r.ok?W.receipt(r,'تمّ الدفع',info.name):W.fail('wErr',r)})})};
})();
</script>~';
  END render_pay;

  -- -----------------------------------------------------------------
  -- 4) الفواتير وشحن الخطوط
  -- -----------------------------------------------------------------
  FUNCTION render_bills RETURN CLOB IS
    l     wlt_v_wallets%ROWTYPE := me;
    l_h   CLOB;
  BEGIN
    l_h := common || '<div class="w-app">' || head('الفواتير والشحن', 'ادفع فاتورتك أو اشحن خطك في ثوانٍ')
      || avail(l.available_balance)
      || '<div class="w-tabs"><button class="on" type="button" data-p="pBills">فواتير</button><button type="button" data-p="pTop">شحن خط</button></div>'
      || '<section class="w-pane on" id="pBills"><div class="w-grid">';
    FOR b IN (SELECT * FROM wlt_billers WHERE pay_mode = 'BILLS' ORDER BY sort_order) LOOP
      l_h := l_h || '<button class="w-tile" type="button" data-b="' || b.biller_code || '" data-hint="' || esc(b.account_hint) || '"><b>'
        || CASE b.category WHEN 'ELECTRICITY' THEN '⚡' WHEN 'WATER' THEN '💧' ELSE '🌐' END
        || '</b>' || esc(b.name_ar) || '</button>';
    END LOOP;
    l_h := l_h || '</div>'
      || '<label class="w-field"><span id="wAcctLbl">اختر الجهة أولاً</span><input class="w-in ltr" id="wAcct" maxlength="20" inputmode="numeric" placeholder="—" disabled autocomplete="off"></label>'
      || '<div class="w-list" id="wBills"></div>'
      || '<div class="w-err" id="wErr"></div>'
      || '<button class="w-btn" id="wPayBill" type="button" disabled>ادفع الفاتورة</button>'
      || '<div class="w-note">للتجربة: كهرباء <b class="mono">10023</b> · مياه <b class="mono">55001</b> · إنترنت <b class="mono">8800123</b>. رسوم دفع الفاتورة 0.250 د.أ</div></section>'
      || '<section class="w-pane" id="pTop">'
      || '<label class="w-field"><span>رقم الخط</span><input class="w-in ltr" id="wLine" maxlength="10" inputmode="numeric" placeholder="07XXXXXXXX" value="' || esc(l.phone) || '"></label>'
      || '<span style="display:block;font-size:13px;font-weight:600;margin-bottom:8px">قيمة الشحن</span><div class="w-grid" id="wVals">'
      || '<button class="w-tile" type="button" data-v="1"><b>1</b>دينار</button><button class="w-tile" type="button" data-v="2"><b>2</b>دينار</button><button class="w-tile" type="button" data-v="5"><b>5</b>دنانير</button>'
      || '<button class="w-tile" type="button" data-v="10"><b>10</b>دنانير</button><button class="w-tile" type="button" data-v="15"><b>15</b>ديناراً</button><button class="w-tile" type="button" data-v="20"><b>20</b>ديناراً</button></div>'
      || '<div class="w-err" id="wErr2"></div>'
      || '<button class="w-btn" id="wTopGo" type="button" disabled>اشحن الآن</button></section></div>'
      || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)};W.tabs();
  var biller=null,bill=null,acct=$('wAcct'),list=$('wBills'),pay=$('wPayBill'),lt;
  document.querySelectorAll('#pBills .w-tile').forEach(function(b){b.onclick=function(){
    document.querySelectorAll('#pBills .w-tile').forEach(function(x){x.classList.toggle('on',x===b)});
    biller=b.dataset.b;$('wAcctLbl').textContent=b.dataset.hint;acct.disabled=false;acct.placeholder='أدخل '+b.dataset.hint;acct.value='';
    list.innerHTML='';bill=null;pay.disabled=true;W.err('wErr');acct.focus()}});
  acct.addEventListener('input',function(){acct.value=acct.value.replace(/\D/g,'');clearTimeout(lt);bill=null;pay.disabled=true;W.err('wErr');
    lt=setTimeout(function(){if(acct.value.length<4){list.innerHTML='';return}
      list.innerHTML='<div class="w-sub">جارٍ البحث…</div>';
      W.api('bills',{x02:biller,x03:acct.value}).then(function(r){
        if(!r.ok){list.innerHTML='';W.err('wErr',r.msg);return}
        if(!r.bills.length){list.innerHTML='<div class="w-empty">لا توجد فواتير مستحقة على هذا الحساب 🎉</div>';return}
        list.innerHTML=r.bills.map(function(x){return '<div class="w-bill" data-id="'+x.id+'" data-a="'+x.amount+'" data-p="'+W.esc(x.period)+'"><div>'+W.esc(x.period)
          +'<small'+(x.late?' class="late"':'')+'>'+(x.late?'متأخرة · ':'')+'تستحق '+x.due+'</small></div><b>'+x.amount+'</b></div>'}).join('');
        list.querySelectorAll('.w-bill').forEach(function(el){el.onclick=function(){list.querySelectorAll('.w-bill').forEach(function(y){y.classList.toggle('on',y===el)});
          bill={id:el.dataset.id,amount:el.dataset.a,period:el.dataset.p};pay.disabled=false}});
        list.querySelector('.w-bill').click()})},350)});
  pay.onclick=function(){var idem=W.uuid(),tot=(Number(bill.amount)+0.25).toFixed(3);
    W.confirm('تأكيد دفع الفاتورة',[['الحساب',acct.value],['الفترة',bill.period],['المبلغ',bill.amount],['الرسوم','0.250'],['المجموع',tot+' د.أ',1]],'ادفع الآن',function(){
      W.api('pay_bill',{x02:bill.id,x03:idem}).then(function(r){r.ok?W.receipt(r,'تمّ دفع الفاتورة',bill.period):W.fail('wErr',r)})})};
  var val=null,line=$('wLine'),tg=$('wTopGo');
  function tv(){tg.disabled=!(val&&/^07[789]\d{7}$/.test(line.value))}
  line.addEventListener('input',function(){line.value=line.value.replace(/\D/g,'');W.err('wErr2');tv()});
  document.querySelectorAll('#wVals .w-tile').forEach(function(b){b.onclick=function(){
    document.querySelectorAll('#wVals .w-tile').forEach(function(x){x.classList.toggle('on',x===b)});val=b.dataset.v;tv()}});
  tg.onclick=function(){var idem=W.uuid();
    W.confirm('تأكيد الشحن',[['الخط',line.value],['الرسوم','0.000'],['المجموع',Number(val).toFixed(3)+' د.أ',1]],'اشحن الآن',function(){
      W.api('recharge',{x02:'TEL',x03:line.value,x04:val,x05:idem}).then(function(r){r.ok?W.receipt(r,'تمّ الشحن','الخط '+line.value):W.fail('wErr2',r)})})};
})();
</script>~';
    RETURN l_h;
  END render_bills;

  -- -----------------------------------------------------------------
  -- 5) سحب نقدي: العميل يولّد كوداً لمرة واحدة
  -- -----------------------------------------------------------------
  FUNCTION render_cash RETURN CLOB IS
    l wlt_v_wallets%ROWTYPE := me;
  BEGIN
    IF l.user_type <> 'CUSTOMER' THEN
      RETURN wrong_role('السحب النقدي بالكود متاح لحسابات العملاء فقط');
    END IF;
    RETURN common || '<div class="w-app">' || head('سحب نقدي', 'استلم كاش من أي وكيل بكود لمرة واحدة')
      || avail(l.available_balance)
      || '<div id="wStep1"><label class="w-field"><span>المبلغ (دينار كامل)</span><input class="w-in w-amount" id="wAmt" inputmode="numeric" placeholder="0" autocomplete="off">'
      || '<div class="w-chips"><button type="button" data-v="10">10</button><button type="button" data-v="20">20</button><button type="button" data-v="50">50</button><button type="button" data-v="100">100</button></div></label>'
      || '<div class="w-rows" id="wFee" style="display:none"></div>'
      || '<div class="w-err" id="wErr"></div><button class="w-btn" id="wGo" type="button" disabled>ولّد كود السحب</button>'
      || '<div class="w-note">رسوم السحب 0.5% (أقل شيء 0.250 وأكثر شيء 5 د.أ). الكود صالح 10 دقائق ولمرة واحدة، والمبلغ لا يُخصم إلا عندما يصرفه الوكيل.</div></div>'
      || '<div id="wStep2" style="display:none;text-align:center"><p class="w-sub" style="margin:0">أعطِ هذا الكود للوكيل</p><div class="w-code" id="wCode"></div>'
      || '<div style="font-family:var(--w-mono);font-size:22px;font-weight:700" id="wCodeAmt"></div>'
      || '<div class="w-ring"><span id="wRing" style="width:100%"></span></div><div class="w-timer">ينتهي بعد <b id="wLeft">10:00</b></div>'
      || '<div style="height:16px"></div><button class="w-btn ghost" type="button" onclick="location.reload()">كود جديد</button></div></div>'
      || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)},amt=$('wAmt'),go=$('wGo');
  function fee(a){var f=Math.round(a*0.005*1000)/1000;return Math.min(5,Math.max(0.25,f))}
  function upd(){amt.value=amt.value.replace(/\D/g,'');var a=parseInt(amt.value,10);W.err('wErr');
    if(a>0){var f=fee(a);$('wFee').style.display='block';$('wFee').innerHTML='<div><span>المبلغ</span><b>'+a.toFixed(3)+'</b></div><div><span>الرسوم</span><b>'+f.toFixed(3)+'</b></div><div class="tot"><span>يُخصم من رصيدك</span><b>'+(a+f).toFixed(3)+' د.أ</b></div>'}
    else $('wFee').style.display='none';go.disabled=!(a>0)}
  amt.addEventListener('input',upd);
  document.querySelectorAll('.w-chips button').forEach(function(b){b.onclick=function(){amt.value=b.dataset.v;upd()}});
  go.onclick=function(){go.disabled=true;go.textContent='جارٍ التوليد…';
    W.api('cashout_code',{x02:amt.value}).then(function(r){
      if(!r.ok){go.textContent='ولّد كود السحب';go.disabled=false;W.err('wErr',r.msg);return}
      $('wStep1').style.display='none';$('wStep2').style.display='block';
      $('wCode').innerHTML=r.code.split('').map(function(d,i){return '<span style="animation-delay:'+(i*60)+'ms">'+d+'</span>'}).join('');
      $('wCodeAmt').textContent=r.amount+' د.أ';
      var end=Date.now()+r.seconds*1000,tot=r.seconds;
      (function tick(){var s=Math.max(0,Math.round((end-Date.now())/1000));
        $('wLeft').textContent=Math.floor(s/60)+':'+String(s%60).padStart(2,'0');$('wRing').style.width=(s/tot*100)+'%';
        if(s>0)setTimeout(tick,1000);else{$('wCode').style.opacity=.3;$('wLeft').textContent='انتهى'}})()})};
})();
</script>~';
  END render_cash;

  -- -----------------------------------------------------------------
  -- 6) استلام دفعة (للتاجر): QR بمبلغ محدد يتحول لـ"تمّ الدفع" تلقائياً
  -- -----------------------------------------------------------------
  FUNCTION render_receive RETURN CLOB IS
    l      wlt_v_wallets%ROWTYPE := me;
    l_code VARCHAR2(10);
  BEGIN
    IF l.user_type <> 'MERCHANT' THEN
      RETURN wrong_role('استلام الدفعات بـQR متاح لحسابات التجار فقط');
    END IF;
    SELECT MAX(merchant_code) INTO l_code FROM wlt_merchant_profiles WHERE user_id = l.user_id;
    RETURN common || '<div class="w-app">' || head('استلام دفعة', 'ولّد كود QR بالمبلغ، والزبون يمسحه ويدفع')
      || '<div class="w-avail"><span>كودك الثابت</span><b>' || esc(NVL(l_code, '—')) || '</b></div>'
      || '<div id="wStep1"><label class="w-field"><span>المبلغ المطلوب (د.أ)</span><input class="w-in w-amount" id="wAmt" inputmode="decimal" placeholder="0.000" autocomplete="off"></label>'
      || '<label class="w-field"><span>وصف (اختياري)</span><input class="w-in" id="wNote" maxlength="100" placeholder="مثلاً: قهوة × 2"></label>'
      || '<div class="w-err" id="wErr"></div><button class="w-btn" id="wGo" type="button" disabled>ولّد QR</button></div>'
      || '<div id="wStep2" style="display:none"><div class="w-qr" id="wQr"></div><div class="w-timer" id="wTimer">بانتظار الدفع · ينتهي بعد <b id="wLeft">15:00</b></div>'
      || '<div id="wPaid"></div><div style="height:14px"></div><button class="w-btn ghost" type="button" onclick="location.reload()">كود جديد</button></div></div>'
      || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)},amt=$('wAmt'),go=$('wGo');W.num(amt);
  amt.addEventListener('input',function(){W.err('wErr');go.disabled=!(parseFloat(amt.value)>0)});
  go.onclick=function(){go.disabled=true;go.textContent='جارٍ التوليد…';
    W.api('new_qr',{x02:Number(amt.value).toFixed(3),x03:$('wNote').value}).then(function(r){
      if(!r.ok){go.disabled=false;go.textContent='ولّد QR';W.err('wErr',r.msg);return}
      $('wStep1').style.display='none';$('wStep2').style.display='block';
      $('wQr').innerHTML=r.svg+'<div class="amt">'+r.amount+' د.أ</div><div class="tok">'+r.token+'</div>';
      var end=Date.now()+r.seconds*1000,done=false;
      (function tick(){if(done)return;var s=Math.max(0,Math.round((end-Date.now())/1000));
        $('wLeft').textContent=Math.floor(s/60)+':'+String(s%60).padStart(2,'0');if(s>0)setTimeout(tick,1000);else{$('wTimer').textContent='انتهت صلاحية الكود';$('wQr').style.opacity=.35}})();
      (function poll(){if(done||Date.now()>end)return;
        W.api('qr_status',{x02:r.token}).then(function(s){
          if(s.ok&&s.status==='USED'){done=true;$('wQr').classList.add('paid');$('wTimer').textContent='';
            $('wPaid').innerHTML='<div class="w-rows"><div><span>من</span><b>'+W.esc(s.payer)+'</b></div><div><span>الإيصال</span><b>'+s.ref+'</b></div></div>'}
          else setTimeout(poll,2500)})})()})};
})();
</script>~';
  END render_receive;

  -- -----------------------------------------------------------------
  -- 7) شاشة الوكيل: إيداع لعميل + صرف كود سحب
  -- -----------------------------------------------------------------
  FUNCTION render_agent RETURN CLOB IS
    l wlt_v_wallets%ROWTYPE := me;
  BEGIN
    IF l.user_type <> 'AGENT' THEN
      RETURN wrong_role('هذه الشاشة لحسابات الوكلاء فقط');
    END IF;
    RETURN common || '<div class="w-app">' || head('نقطة الوكيل', 'إيداع وسحب نقدي للعملاء')
      || avail(l.available_balance)
      || '<div class="w-tabs"><button class="on" type="button" data-p="pIn">إيداع لعميل</button><button type="button" data-p="pOut">صرف كود سحب</button></div>'
      || '<section class="w-pane on" id="pIn">'
      || '<label class="w-field"><span>رقم هاتف العميل</span><input class="w-in ltr" id="wCust" maxlength="10" inputmode="numeric" placeholder="07XXXXXXXX" autocomplete="off"><div class="w-who" id="wWho"></div></label>'
      || '<label class="w-field"><span>المبلغ المستلم نقداً (د.أ)</span><input class="w-in w-amount" id="wInAmt" inputmode="decimal" placeholder="0.000" autocomplete="off"></label>'
      || '<div class="w-err" id="wErr"></div><button class="w-btn" id="wInGo" type="button" disabled>أودِع في محفظة العميل</button>'
      || '<div class="w-note">استلم الكاش من العميل أولاً، ثم أودع. المبلغ يُخصم من رصيدك الإلكتروني ويُضاف للعميل فوراً.</div></section>'
      || '<section class="w-pane" id="pOut">'
      || '<label class="w-field"><span>كود السحب من العميل (6 أرقام)</span><input class="w-in ltr" id="wCode" maxlength="6" inputmode="numeric" placeholder="••••••" autocomplete="off" style="font-size:28px;text-align:center;letter-spacing:.4em"></label>'
      || '<div class="w-err" id="wErr2"></div><button class="w-btn" id="wOutGo" type="button" disabled>تحقّق واصرف</button>'
      || '<div class="w-note">بعد نجاح العملية سلّم العميل المبلغ نقداً. المبلغ ورسومه تُخصم من محفظة العميل، والمبلغ يُضاف لرصيدك.</div></section></div>'
      || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)};W.tabs();
  var cust=$('wCust'),amt=$('wInAmt'),ig=$('wInGo'),who=$('wWho'),name=null,lt;W.num(amt);
  function iv(){ig.disabled=!(name&&parseFloat(amt.value)>0)}
  cust.addEventListener('input',function(){cust.value=cust.value.replace(/\D/g,'');name=null;who.textContent='';who.className='w-who';W.err('wErr');iv();clearTimeout(lt);
    if(cust.value.length===10)lt=setTimeout(function(){W.api('lookup',{x02:cust.value}).then(function(r){
      if(r.ok){name=r.name;who.textContent='✓ '+r.name;who.className='w-who ok'}else{who.textContent=r.msg;who.className='w-who bad'}iv()})},200)});
  amt.addEventListener('input',function(){W.err('wErr');iv()});
  ig.onclick=function(){var a=Number(amt.value).toFixed(3),idem=W.uuid();
    W.confirm('تأكيد الإيداع',[['العميل',name],['الرقم',cust.value],['المبلغ',a+' د.أ',1]],'أودِع الآن',function(){
      W.api('cash_in',{x02:cust.value,x03:a,x04:idem}).then(function(r){r.ok?W.receipt(r,'تمّ الإيداع',name):W.fail('wErr',r)})})};
  var code=$('wCode'),og=$('wOutGo');
  code.addEventListener('input',function(){code.value=code.value.replace(/\D/g,'');W.err('wErr2');og.disabled=code.value.length!==6});
  og.onclick=function(){var idem=W.uuid();og.disabled=true;og.textContent='جارٍ التحقق…';
    W.api('redeem',{x02:code.value,x03:idem}).then(function(r){og.textContent='تحقّق واصرف';
      if(r.ok){code.value='';W.receipt(r,'سلّم العميل المبلغ نقداً',r.customer)}else{og.disabled=false;W.err('wErr2',r.msg)}})};
})();
</script>~';
  END render_agent;

  -- -----------------------------------------------------------------
  -- Ajax واحد لكل الشاشات
  -- -----------------------------------------------------------------
  PROCEDURE out_receipt (p_ref VARCHAR2, p_extra_key VARCHAR2 DEFAULT NULL, p_extra VARCHAR2 DEFAULT NULL) IS
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
    IF p_extra_key IS NOT NULL THEN apex_json.write(p_extra_key, p_extra); END IF;
    apex_json.close_object;
  END out_receipt;

  FUNCTION num (p VARCHAR2) RETURN NUMBER IS
  BEGIN
    RETURN TO_NUMBER(p, '999999990D999', 'NLS_NUMERIC_CHARACTERS=''.,''');
  END num;

  PROCEDURE api IS
    a    VARCHAR2(30) := apex_application.g_x01;
    x2   VARCHAR2(4000) := apex_application.g_x02;
    x3   VARCHAR2(4000) := apex_application.g_x03;
    x4   VARCHAR2(4000) := apex_application.g_x04;
    x5   VARCHAR2(4000) := apex_application.g_x05;
    u    VARCHAR2(20)   := v('APP_USER');
    l_ref   VARCHAR2(40);
    l_name  VARCHAR2(200);
    l_cat   VARCHAR2(60);
    l_qr    wlt_qr_codes%ROWTYPE;
    l_msg   VARCHAR2(4000);
    l_tgt   VARCHAR2(40);
  BEGIN
    CASE a
    WHEN 'qr_info' THEN
      l_tgt := UPPER(TRIM(REGEXP_REPLACE(x2, '^WLT:', '', 1, 1, 'i')));
      apex_json.open_object;
      IF REGEXP_LIKE(l_tgt, '^M[0-9]{4}$') THEN
        BEGIN
          SELECT w.shown_name, m.category INTO l_name, l_cat
            FROM wlt_merchant_profiles m JOIN wlt_v_wallets w ON w.user_id = m.user_id AND w.wallet_type = 'MAIN'
           WHERE m.merchant_code = l_tgt;
          apex_json.write('ok', TRUE); apex_json.write('name', l_name); apex_json.write('category', l_cat);
        EXCEPTION WHEN NO_DATA_FOUND THEN
          apex_json.write('ok', FALSE); apex_json.write('msg', 'لا يوجد تاجر بهذا الكود');
        END;
      ELSE
        BEGIN
          SELECT * INTO l_qr FROM wlt_qr_codes WHERE token = LOWER(l_tgt);
          SELECT shown_name INTO l_name FROM wlt_v_wallets WHERE user_id = l_qr.merchant_user_id AND wallet_type = 'MAIN';
          IF l_qr.status = 'USED' THEN
            apex_json.write('ok', FALSE); apex_json.write('msg', 'هذا الكود دُفع مسبقاً');
          ELSIF l_qr.expires_at < SYSTIMESTAMP OR l_qr.status <> 'ACTIVE' THEN
            apex_json.write('ok', FALSE); apex_json.write('msg', 'انتهت صلاحية الكود');
          ELSE
            apex_json.write('ok', TRUE); apex_json.write('name', l_name);
            apex_json.write('amount', money(l_qr.amount)); apex_json.write('note', l_qr.note);
          END IF;
        EXCEPTION WHEN NO_DATA_FOUND THEN
          apex_json.write('ok', FALSE); apex_json.write('msg', 'الكود غير صالح');
        END;
      END IF;
      apex_json.close_object;

    WHEN 'pay' THEN
      out_receipt(wallet_pay_pkg.pay_merchant(u, x2, num(x3), x4));

    WHEN 'bills' THEN
      apex_json.open_object;
      apex_json.write('ok', TRUE);
      apex_json.open_array('bills');
      FOR b IN (SELECT * FROM wlt_bills WHERE biller_code = x2 AND account_no = x3 AND status = 'UNPAID' ORDER BY due_date) LOOP
        apex_json.open_object;
        apex_json.write('id', b.bill_id);
        apex_json.write('period', b.period_ar);
        apex_json.write('amount', money(b.amount));
        apex_json.write('due', TO_CHAR(b.due_date, 'DD/MM/YYYY'));
        apex_json.write('late', b.due_date < TRUNC(SYSDATE));
        apex_json.close_object;
      END LOOP;
      apex_json.close_array;
      apex_json.close_object;

    WHEN 'pay_bill' THEN
      out_receipt(wallet_pay_pkg.pay_bill(u, TO_NUMBER(x2), x3));

    WHEN 'recharge' THEN
      out_receipt(wallet_pay_pkg.recharge(u, x2, x3, num(x4), x5));

    WHEN 'cashout_code' THEN
      l_ref := wallet_pay_pkg.new_cashout_code(u, TO_NUMBER(x2));
      apex_json.open_object;
      apex_json.write('ok', TRUE); apex_json.write('code', l_ref);
      apex_json.write('amount', money(TO_NUMBER(x2))); apex_json.write('seconds', 600);
      apex_json.close_object;

    WHEN 'new_qr' THEN
      l_ref := wallet_pay_pkg.create_qr(u, num(x2), x3, 15);
      apex_json.open_object;
      apex_json.write('ok', TRUE); apex_json.write('token', l_ref);
      apex_json.write('amount', money(num(x2))); apex_json.write('seconds', 900);
      apex_json.write('svg', apex_barcode.get_qrcode_svg(p_value => 'WLT:' || l_ref, p_foreground_color => '#0a2622'));
      apex_json.close_object;

    WHEN 'qr_status' THEN
      SELECT q.* INTO l_qr FROM wlt_qr_codes q JOIN wlt_users m ON m.user_id = q.merchant_user_id
       WHERE q.token = x2 AND m.phone = u;
      apex_json.open_object;
      apex_json.write('ok', TRUE); apex_json.write('status', l_qr.status);
      IF l_qr.status = 'USED' THEN
        SELECT shown_name INTO l_name FROM wlt_v_wallets WHERE user_id = l_qr.paid_by AND wallet_type = 'MAIN';
        SELECT txn_ref INTO l_ref FROM wlt_transactions WHERE txn_id = l_qr.paid_txn_id;
        apex_json.write('payer', l_name); apex_json.write('ref', l_ref);
      END IF;
      apex_json.close_object;

    WHEN 'lookup' THEN
      apex_json.open_object;
      BEGIN
        SELECT shown_name INTO l_name FROM wlt_v_wallets
         WHERE phone = x2 AND wallet_type = 'MAIN' AND user_type = 'CUSTOMER';
        apex_json.write('ok', TRUE); apex_json.write('name', l_name);
      EXCEPTION WHEN NO_DATA_FOUND THEN
        apex_json.write('ok', FALSE); apex_json.write('msg', 'لا يوجد عميل بهذا الرقم');
      END;
      apex_json.close_object;

    WHEN 'cash_in' THEN
      out_receipt(wallet_pay_pkg.cash_in(u, x2, num(x3), x4));

    WHEN 'redeem' THEN
      l_ref := wallet_pay_pkg.redeem_cashout(u, x2, x3);
      SELECT w.shown_name INTO l_name
        FROM wlt_transactions t JOIN wlt_v_wallets w ON w.wallet_id = t.from_wallet_id
       WHERE t.txn_ref = l_ref;
      out_receipt(l_ref, 'customer', l_name);

    ELSE
      apex_json.open_object; apex_json.write('ok', FALSE); apex_json.write('msg', 'عملية غير معروفة'); apex_json.close_object;
    END CASE;
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
      apex_json.write('ok', FALSE); apex_json.write('code', SQLCODE); apex_json.write('msg', l_msg);
      apex_json.close_object;
  END api;

END wallet_ui2_pkg;
/
