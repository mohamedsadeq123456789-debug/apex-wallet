-- =====================================================================
--  محفظتي · الجلسة 9 · لوحة الإدارة (21) وتحليل مصاريفي (22)
-- =====================================================================
CREATE OR REPLACE PACKAGE wallet_ui7_pkg AS
  FUNCTION render_admin    RETURN CLOB;
  FUNCTION render_insights RETURN CLOB;
  PROCEDURE api;
END wallet_ui7_pkg;
/

CREATE OR REPLACE PACKAGE BODY wallet_ui7_pkg AS

  FUNCTION esc (p VARCHAR2) RETURN VARCHAR2 IS BEGIN RETURN apex_escape.html(p); END;
  FUNCTION js (p VARCHAR2) RETURN VARCHAR2 IS BEGIN RETURN apex_escape.json(p); END;
  FUNCTION money (p NUMBER) RETURN VARCHAR2 IS
  BEGIN RETURN TO_CHAR(NVL(p, 0), 'FM999G999G990D000', 'NLS_NUMERIC_CHARACTERS=''.,'''); END;
  FUNCTION num (p NUMBER) RETURN VARCHAR2 IS
  BEGIN RETURN TO_CHAR(NVL(p, 0), 'FM9999999990D000', 'NLS_NUMERIC_CHARACTERS=''.,'''); END;

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

  -- رسوم بيانية خفيفة بـ SVG: أعمدة (سلسلة أو سلسلتان) وحلقة، مع تلميح عند المرور ووسيلة إيضاح
  FUNCTION charts RETURN VARCHAR2 IS
  BEGIN
    RETURN q'~<style>
.v-root{--s1:#2a78d6;--s2:#eb6834;--s3:#1baf7a;--s4:#eda100;--s5:#e87ba4;--s6:#008300;--s7:#6250d6;--s8:#e34948;--grid:#e4e7e2;--axis:#8b958f}
.v-card{border:1px solid var(--w-rule);background:var(--w-paper);border-radius:20px;padding:14px 14px 10px;margin-bottom:12px}
.v-card h3{font-family:var(--w-disp);font-size:14.5px;margin:0 0 2px}.v-card p{margin:0 0 8px;font-size:12px;color:var(--w-muted)}
.v-svg{width:100%;height:auto;display:block;overflow:visible}
.v-svg text{font-family:var(--w-mono);font-size:10px;fill:var(--axis)}
.v-leg{display:flex;flex-wrap:wrap;gap:6px 14px;margin-top:8px;font-size:12px;color:var(--w-ink)}
.v-leg span{display:inline-flex;align-items:center;gap:6px}.v-leg i{width:10px;height:10px;border-radius:3px;display:inline-block}
.v-leg b{font-family:var(--w-mono);font-weight:600;color:var(--w-muted)}
.v-donut{display:grid;grid-template-columns:150px 1fr;gap:14px;align-items:center}
.v-donut .v-leg{flex-direction:column;margin:0}
.v-tip{position:fixed;z-index:2000;pointer-events:none;background:#101c1a;color:#f3efe2;font-size:12px;line-height:1.5;border-radius:10px;padding:6px 10px;box-shadow:0 8px 20px rgba(0,0,0,.25);opacity:0;transition:opacity .12s;white-space:nowrap}
.v-tip.on{opacity:1}.v-tip b{font-family:var(--w-mono);color:var(--w-gold)}
.v-hit{fill:transparent;cursor:pointer}.v-hit:hover+.v-bar,.v-bar:hover{opacity:.8}
.v-table{display:none;width:100%;font-size:12px;border-collapse:collapse;margin-top:8px}.v-table.on{display:table}
.v-table td,.v-table th{padding:4px 6px;border-bottom:1px dashed var(--w-rule);text-align:right}
.v-tgl{border:0;background:none;color:var(--w-mint);font-size:11.5px;cursor:pointer;padding:0;margin-top:6px}
</style>
<script>
window.V=(function(){
  var tip;function T(){if(!tip){tip=document.createElement('div');tip.className='v-tip';document.body.appendChild(tip)}return tip}
  function show(e,h){var t=T();t.innerHTML=h;t.classList.add('on');var x=e.clientX,y=e.clientY;t.style.left=Math.min(x+12,innerWidth-t.offsetWidth-8)+'px';t.style.top=(y-t.offsetHeight-12)+'px'}
  function hide(){T().classList.remove('on')}
  function f(n){return Number(n).toLocaleString('en-US',{minimumFractionDigits:0,maximumFractionDigits:3})}
  function table(el,heads,rows){var t='<table class="v-table"><tr>'+heads.map(function(h){return '<th>'+h+'</th>'}).join('')+'</tr>'
    +rows.map(function(r){return '<tr>'+r.map(function(c){return '<td>'+c+'</td>'}).join('')+'</tr>'}).join('')+'</table>';
    el.insertAdjacentHTML('beforeend','<button type="button" class="v-tgl">عرض كجدول</button>'+t);
    var b=el.querySelector('.v-tgl'),tb=el.querySelector('.v-table');b.onclick=function(){tb.classList.toggle('on');b.textContent=tb.classList.contains('on')?'إخفاء الجدول':'عرض كجدول'}}
  // series: [{name,color,key}] ; data: [{l:label, k1:.., k2:..}]
  function bars(el,data,series,unit){
    var W=320,H=150,pl=34,pb=18,pt=6,n=data.length,max=0;
    data.forEach(function(d){series.forEach(function(s){max=Math.max(max,d[s.key]||0)})});max=max||1;
    var step=Math.pow(10,Math.floor(Math.log10(max))),top=Math.ceil(max/step)*step;if(top/step>6)step*=2;
    var cw=(W-pl)/n,gw=Math.min(cw*0.72,26*series.length),bw=gw/series.length-1,s='<svg class="v-svg" viewBox="0 0 '+W+' '+(H+pb)+'">';
    for(var g=0;g<=top;g+=step){var y=pt+(H-pt)*(1-g/top);s+='<line x1="'+pl+'" x2="'+W+'" y1="'+y+'" y2="'+y+'" stroke="var(--grid)" stroke-width="1"/><text x="'+(pl-4)+'" y="'+(y+3)+'" text-anchor="end">'+f(g)+'</text>'}
    data.forEach(function(d,i){var x0=pl+i*cw+(cw-gw)/2;
      series.forEach(function(se,j){var v=d[se.key]||0,h=(H-pt)*v/top,x=x0+j*(bw+1),y=H-h,r=Math.min(4,bw/2,h);
        s+='<path class="v-bar" d="M'+x+','+H+'V'+(y+r)+'Q'+x+','+y+' '+(x+r)+','+y+'H'+(x+bw-r)+'Q'+(x+bw)+','+y+' '+(x+bw)+','+(y+r)+'V'+H+'Z" fill="'+se.color+'"/>'});
      s+='<rect class="v-hit" data-i="'+i+'" x="'+(pl+i*cw)+'" y="0" width="'+cw+'" height="'+H+'"/>';
      if(n<=8||i%Math.ceil(n/7)===0||i===n-1)s+='<text x="'+(pl+i*cw+cw/2)+'" y="'+(H+13)+'" text-anchor="middle">'+d.l+'</text>'});
    s+='<line x1="'+pl+'" x2="'+W+'" y1="'+H+'" y2="'+H+'" stroke="var(--axis)" stroke-width="1"/></svg>';
    if(series.length>1)s+='<div class="v-leg">'+series.map(function(se){return '<span><i style="background:'+se.color+'"></i>'+se.name+'</span>'}).join('')+'</div>';
    el.insertAdjacentHTML('beforeend',s);
    el.querySelectorAll('.v-hit').forEach(function(r){var d=data[+r.dataset.i];
      r.addEventListener('mousemove',function(e){show(e,'<div>'+(d.t||d.l)+'</div>'+series.map(function(se){return (series.length>1?se.name+': ':'')+'<b>'+f(d[se.key]||0)+'</b> '+(unit||'')}).join('<br>'))});
      r.addEventListener('mouseleave',hide)});
    table(el,['الفترة'].concat(series.map(function(s){return s.name})),data.map(function(d){return [d.t||d.l].concat(series.map(function(s){return f(d[s.key]||0)}))}))}
  // data: [{l,v}] — حتى 8 فئات، الباقي في «أخرى»
  function donut(el,data,unit){
    data=data.slice().sort(function(a,b){return b.v-a.v});
    if(data.length>8){var o=data.slice(7).reduce(function(a,d){return a+d.v},0);data=data.slice(0,7).concat([{l:'أخرى',v:o}])}
    var tot=data.reduce(function(a,d){return a+d.v},0)||1,R=60,r=38,c=75,a0=-Math.PI/2,s='<svg class="v-svg" viewBox="0 0 150 150">';
    data.forEach(function(d,i){var a1=a0+2*Math.PI*d.v/tot,lg=(a1-a0)>Math.PI?1:0,col='var(--s'+(i+1)+')';
      if(data.length===1){s+='<circle cx="'+c+'" cy="'+c+'" r="'+((R+r)/2)+'" fill="none" stroke="'+col+'" stroke-width="'+(R-r)+'" class="v-seg" data-i="0"/>'}
      else{var p=function(a,rr){return (c+rr*Math.cos(a))+','+(c+rr*Math.sin(a))};
        s+='<path class="v-seg" data-i="'+i+'" d="M'+p(a0,R)+'A'+R+','+R+' 0 '+lg+' 1 '+p(a1,R)+'L'+p(a1,r)+'A'+r+','+r+' 0 '+lg+' 0 '+p(a0,r)+'Z" fill="'+col+'" stroke="var(--w-paper)" stroke-width="2"/>'}
      a0=a1});
    s+='<text x="75" y="72" text-anchor="middle" style="font-size:15px;fill:var(--w-ink);font-weight:700">'+f(Math.round(tot))+'</text><text x="75" y="88" text-anchor="middle">'+(unit||'')+'</text></svg>';
    var lg='<div class="v-leg">'+data.map(function(d,i){return '<span><i style="background:var(--s'+(i+1)+')"></i>'+d.l+' <b>'+Math.round(d.v/tot*100)+'%</b></span>'}).join('')+'</div>';
    el.insertAdjacentHTML('beforeend','<div class="v-donut"><div>'+s+'</div>'+lg+'</div>');
    el.querySelectorAll('.v-seg').forEach(function(g){var d=data[+g.dataset.i];g.style.cursor='pointer';
      g.addEventListener('mousemove',function(e){show(e,d.l+'<br><b>'+f(d.v)+'</b> '+(unit||'')+' · '+Math.round(d.v/tot*100)+'%')});g.addEventListener('mouseleave',hide)});
    table(el,['الفئة','القيمة','النسبة'],data.map(function(d){return [d.l,f(d.v),Math.round(d.v/tot*100)+'%']}))}
  return {bars:bars,donut:donut}})();
</script>~';
  END charts;

  FUNCTION css RETURN VARCHAR2 IS
  BEGIN
    RETURN q'~<style>
.a-kpis{display:grid;grid-template-columns:repeat(2,1fr);gap:10px;margin-bottom:16px}
.a-kpi{border-radius:18px;padding:12px 14px;background:var(--w-paper);border:1px solid var(--w-rule)}
.a-kpi.dark{background:linear-gradient(140deg,var(--w-g9),var(--w-g7));color:#f3efe2;border:0}
.a-kpi small{display:block;font-size:11.5px;opacity:.75}
.a-kpi b{display:block;font-family:var(--w-mono);font-size:21px;direction:ltr;text-align:right;margin-top:4px}
.a-kpi.dark b{color:var(--w-gold)}
.a-kpi em{font-style:normal;font-size:11px;color:var(--w-muted)}.a-kpi.dark em{color:#cfe3dc}
.a-kpi.alert{border-color:var(--w-red);background:var(--w-red-s)}.a-kpi.alert b{color:var(--w-red)}
.a-case{border:1px solid var(--w-rule);background:var(--w-paper);border-radius:18px;padding:14px;margin-bottom:10px}
.a-case .t{display:flex;gap:12px;align-items:flex-start}
.a-score{width:52px;height:52px;border-radius:50%;display:grid;place-items:center;font-family:var(--w-mono);font-weight:700;font-size:18px;flex:none;color:#fff}
.a-score.hi{background:#c0392b}.a-score.mid{background:#d68910}.a-score.lo{background:#7f8c8d}
.a-case h4{margin:0;font-family:var(--w-disp);font-size:15px}.a-case small{display:block;color:var(--w-muted);font-size:12px}
.a-why{display:flex;flex-wrap:wrap;gap:4px;margin:8px 0 0}
.a-why span{font-size:11px;background:var(--w-bg);border:1px solid var(--w-rule);border-radius:999px;padding:1px 8px}
.a-acts{display:flex;gap:6px;margin-top:10px}
.a-acts button{flex:1;border-radius:11px;padding:9px 6px;font-family:var(--w-body);font-weight:600;font-size:13px;cursor:pointer;border:1.5px solid var(--w-rule);background:var(--w-paper);color:var(--w-ink)}
.a-acts .go{background:var(--w-g8);border-color:var(--w-g8);color:#fff}.a-acts .no{color:var(--w-red);border-color:var(--w-red-s)}
.a-rank{display:grid;grid-template-columns:28px 1fr auto;gap:8px;align-items:center;padding:8px 0;border-bottom:1px dashed var(--w-rule);font-size:13px}
.a-rank i{font-style:normal;width:24px;height:24px;border-radius:8px;background:var(--w-mint-s);color:var(--w-g8);display:grid;place-items:center;font-family:var(--w-mono);font-size:12px;font-weight:700}
.a-rank b{font-family:var(--w-mono);direction:ltr}
.a-user{border:1px solid var(--w-rule);background:var(--w-paper);border-radius:18px;padding:14px;margin-top:10px;display:none}
.a-user.on{display:block;animation:w-in .3s}
.a-user dl{display:grid;grid-template-columns:auto 1fr;gap:4px 12px;font-size:13px;margin:8px 0}
.a-user dt{color:var(--w-muted)}.a-user dd{margin:0;font-family:var(--w-mono)}
.a-row{display:flex;gap:8px;align-items:end;margin-bottom:10px}.a-row .w-field{flex:1;margin:0}
.a-row button{border:0;background:var(--w-mint);color:#fff;border-radius:12px;padding:12px 16px;font-family:var(--w-disp);font-weight:600;cursor:pointer}
.a-row select{width:100%;border:1.5px solid var(--w-rule);border-radius:12px;padding:11px;background:var(--w-paper);font-family:var(--w-body)}
.i-hero{border-radius:24px;padding:18px 20px;margin-bottom:14px;color:#f3efe2;background:radial-gradient(120% 90% at 100% 0%,rgba(233,197,111,.25),transparent 55%),linear-gradient(140deg,var(--w-g9),var(--w-g7))}
.i-hero small{opacity:.75;font-size:12.5px}.i-hero b.big{display:block;font-family:var(--w-mono);font-size:32px;color:var(--w-gold);direction:ltr;text-align:right;margin:2px 0 8px}
.i-hero .row{display:flex;flex-wrap:wrap;gap:8px}.i-hero .row span{background:rgba(255,255,255,.1);border-radius:999px;padding:3px 11px;font-size:12px}
.i-chg{font-family:var(--w-mono)}.i-chg.up::before{content:"▲ "}.i-chg.down::before{content:"▼ "}
.i-tips{display:grid;gap:8px;margin-bottom:14px}
.i-tips div{display:flex;gap:10px;align-items:flex-start;border:1px solid var(--w-rule);background:var(--w-paper);border-radius:16px;padding:10px 12px;font-size:13px;line-height:1.6}
.i-tips div span{font-size:20px;line-height:1}
</style>~';
  END css;

  -- -----------------------------------------------------------------
  -- 21) لوحة الإدارة
  -- -----------------------------------------------------------------
  FUNCTION render_admin RETURN CLOB IS
    l      wlt_v_wallets%ROWTYPE := me;
    l_h    CLOB;
    l_d    CLOB;
    l_n    PLS_INTEGER;
    k_users NUMBER; k_active NUMBER; k_liab NUMBER; k_today NUMBER; k_tcnt NUMBER; k_fees NUMBER;
    k_risk NUMBER; k_disp NUMBER; k_bnpl NUMBER; k_late NUMBER;
    l_fees_w NUMBER;
  BEGIN
    IF l.user_type <> 'ADMIN' THEN
      RETURN wallet_ui2_pkg.common || '<div class="w-app">' || head('لوحة الإدارة', '') || '<div class="w-empty">🔒 هذه الصفحة لفريق الإدارة فقط</div></div>';
    END IF;

    SELECT COUNT(*) INTO k_users FROM wlt_users WHERE user_type IN ('CUSTOMER','MERCHANT','AGENT');
    SELECT COUNT(DISTINCT w.user_id) INTO k_active FROM wlt_transactions t JOIN wlt_wallets w ON w.wallet_id = t.from_wallet_id
     JOIN wlt_users u ON u.user_id = w.user_id
     WHERE t.created_at > SYSDATE - 7 AND t.status = 'COMPLETED' AND u.user_type IN ('CUSTOMER','MERCHANT','AGENT');
    SELECT NVL(SUM(w.balance), 0) INTO k_liab FROM wlt_wallets w JOIN wlt_users u ON u.user_id = w.user_id
     WHERE u.user_type <> 'SYSTEM' AND w.currency_code = 'JOD';
    SELECT NVL(SUM(amount), 0), COUNT(*) INTO k_today, k_tcnt FROM wlt_transactions
     WHERE status = 'COMPLETED' AND created_at >= CAST(TRUNC(CAST(wlt_local(SYSTIMESTAMP) AS DATE)) - 3/24 AS TIMESTAMP);
    SELECT TO_NUMBER(setting_value) INTO l_fees_w FROM wlt_app_settings WHERE setting_key = 'FEES_WALLET_ID';
    SELECT balance INTO k_fees FROM wlt_wallets WHERE wallet_id = l_fees_w;
    SELECT COUNT(*) INTO k_risk FROM wlt_risk_cases WHERE status = 'OPEN';
    SELECT COUNT(*) INTO k_disp FROM wlt_escrow_deals WHERE status = 'DISPUTED';
    SELECT NVL(SUM(amount), 0), COUNT(CASE WHEN status = 'LATE' THEN 1 END) INTO k_bnpl, k_late FROM wlt_bnpl_installments WHERE status <> 'PAID';

    l_h := wallet_ui2_pkg.common || css || charts || '<div class="w-app v-root">'
      || head('لوحة الإدارة', 'نظرة حيّة على المحفظة · ' || TO_CHAR(wlt_local(SYSTIMESTAMP), 'DD/MM HH24:MI'))
      || '<div class="a-kpis">'
      || '<div class="a-kpi dark"><small>أرصدة المستخدمين (د.أ)</small><b>' || money(k_liab) || '</b><em>' || k_users || ' مستخدم · ' || k_active || ' نشط هذا الأسبوع</em></div>'
      || '<div class="a-kpi dark"><small>حجم اليوم (د.أ)</small><b>' || money(k_today) || '</b><em>' || k_tcnt || ' عملية</em></div>'
      || '<div class="a-kpi"><small>الرسوم المحصّلة</small><b>' || money(k_fees) || '</b><em>إجمالي محفظة الرسوم</em></div>'
      || '<div class="a-kpi' || CASE WHEN k_late > 0 THEN ' alert' END || '"><small>ادفع لاحقاً قائم</small><b>' || money(k_bnpl) || '</b><em>' || k_late || ' قسط متأخر</em></div>'
      || '<div class="a-kpi' || CASE WHEN k_risk > 0 THEN ' alert' END || '"><small>🛡️ عمليات بانتظار المراجعة</small><b>' || k_risk || '</b><em>كشف الاحتيال</em></div>'
      || '<div class="a-kpi' || CASE WHEN k_disp > 0 THEN ' alert' END || '"><small>⚖️ اعتراضات ضمان</small><b>' || k_disp || '</b><em>بانتظار قرار</em></div></div>'
      || '<div class="w-tabs"><button type="button" class="on" data-p="tO">نظرة عامة</button><button type="button" data-p="tR">الأمان' || CASE WHEN k_risk > 0 THEN ' (' || k_risk || ')' END
      || '</button><button type="button" data-p="tE">الضمان' || CASE WHEN k_disp > 0 THEN ' (' || k_disp || ')' END || '</button><button type="button" data-p="tU">المستخدمون</button><button type="button" data-p="tF">الأسعار</button></div>'
      || '<section class="w-pane on" id="tO">'
      || '<div class="v-card" id="cVol"><h3>حجم العمليات اليومي</h3><p>آخر 14 يوماً · بالدينار · من الإحصاءات المجمّعة</p></div>'
      || '<div class="v-card" id="cMix"><h3>توزيع العمليات حسب النوع</h3><p>آخر 30 يوماً · بالقيمة</p></div>'
      || '<div class="v-card" id="cHour"><h3>متى يستخدم الناس المحفظة؟</h3><p>عدد العمليات حسب الساعة · آخر 7 أيام · بتوقيت عمّان</p></div>'
      || '<div class="v-card"><h3>أكثر التجار مبيعاً</h3><p>آخر 30 يوماً</p>';
    l_n := 0;
    FOR m IN (SELECT shown_name, vol, cnt, RANK() OVER (ORDER BY vol DESC) rk FROM (
                SELECT w.shown_name, SUM(t.amount) vol, COUNT(*) cnt FROM wlt_transactions t
                  JOIN wlt_v_wallets w ON w.wallet_id = t.to_wallet_id
                 WHERE t.status = 'COMPLETED' AND t.created_at > SYSDATE - 30 AND w.user_type = 'MERCHANT'
                   AND t.txn_type IN ('MERCHANT_PAY','BNPL_PAY','ESCROW_REL','BILL_PAY')
                 GROUP BY w.shown_name) ORDER BY rk FETCH FIRST 5 ROWS ONLY) LOOP
      l_n := l_n + 1;
      l_h := l_h || '<div class="a-rank"><i>' || m.rk || '</i><span>' || esc(m.shown_name) || ' <small style="color:var(--w-muted)">· ' || m.cnt || ' عملية</small></span><b>' || money(m.vol) || '</b></div>';
    END LOOP;
    IF l_n = 0 THEN l_h := l_h || '<div class="w-empty">لا مبيعات بعد</div>'; END IF;
    l_h := l_h || '<div style="text-align:center;margin-top:10px"><button type="button" class="v-tgl" id="aRef">↻ تحديث الإحصاءات الآن</button></div></div></section>';

    -- الأمان
    l_h := l_h || '<section class="w-pane" id="tR">';
    l_n := 0;
    FOR c IN (SELECT c.*, f.shown_name fn, f.phone fp, t.shown_name tn FROM wlt_risk_cases c
                JOIN wlt_v_wallets f ON f.wallet_id = c.from_wallet_id JOIN wlt_v_wallets t ON t.wallet_id = c.to_wallet_id
               WHERE c.status = 'OPEN' ORDER BY c.score DESC, c.created_at) LOOP
      l_n := l_n + 1;
      l_h := l_h || '<div class="a-case"><div class="t"><div class="a-score ' || CASE WHEN c.score >= 70 THEN 'hi' WHEN c.score >= 40 THEN 'mid' ELSE 'lo' END || '">' || c.score
        || '</div><div style="flex:1"><h4>' || esc(c.fn) || ' ← ' || esc(c.tn) || '</h4><small>' || c.fp || ' · ' || money(c.amount) || ' د.أ · '
        || CASE c.txn_type WHEN 'CASH_OUT' THEN 'سحب نقدي' ELSE 'تحويل' END || ' · ' || TO_CHAR(wlt_local(c.created_at), 'DD/MM HH24:MI')
        || CASE WHEN c.held = 'Y' THEN ' · 🔒 محجوز' END || '</small><div class="a-why">';
      FOR w IN (SELECT REGEXP_SUBSTR(c.reasons, '[^·]+', 1, LEVEL) r FROM dual CONNECT BY REGEXP_SUBSTR(c.reasons, '[^·]+', 1, LEVEL) IS NOT NULL) LOOP
        l_h := l_h || '<span>' || esc(TRIM(w.r)) || '</span>';
      END LOOP;
      l_h := l_h || '</div></div></div><div class="a-acts"><button type="button" class="go" data-rk="approve" data-id="' || c.case_id || '">✓ اعتماد وتنفيذ</button>'
        || '<button type="button" data-rk="reject" data-id="' || c.case_id || '">رفض</button><button type="button" class="no" data-rk="freeze" data-id="' || c.case_id || '">رفض وتجميد الحساب</button></div></div>';
    END LOOP;
    IF l_n = 0 THEN l_h := l_h || '<div class="w-empty">✅ لا عمليات موقوفة للمراجعة</div>'; END IF;
    l_h := l_h || '<div class="w-sec" style="margin-top:18px"><h2>تحت المراقبة</h2><span>لم تُوقف، سُجّلت فقط</span></div>';
    FOR c IN (SELECT c.*, f.shown_name fn, t.shown_name tn FROM wlt_risk_cases c
                JOIN wlt_v_wallets f ON f.wallet_id = c.from_wallet_id JOIN wlt_v_wallets t ON t.wallet_id = c.to_wallet_id
               WHERE c.status <> 'OPEN' ORDER BY c.created_at DESC FETCH FIRST 8 ROWS ONLY) LOOP
      l_h := l_h || '<div class="a-rank"><i style="background:' || CASE WHEN c.score >= 70 THEN '#f6d5d1' ELSE '#fdf1d6' END || '">' || c.score || '</i><span>' || esc(c.fn) || ' ← ' || esc(c.tn)
        || ' <small style="color:var(--w-muted)">· ' || CASE c.status WHEN 'WATCH' THEN 'مراقبة' WHEN 'APPROVED' THEN 'اعتُمدت' ELSE 'رُفضت' END || '</small></span><b>' || money(c.amount) || '</b></div>';
    END LOOP;
    l_h := l_h || '<div class="w-err" id="rErr"></div></section>';

    -- الضمان
    l_h := l_h || '<section class="w-pane" id="tE">';
    l_n := 0;
    FOR d IN (SELECT d.*, b.shown_name bn, s.shown_name sn FROM wlt_escrow_deals d
                JOIN wlt_v_wallets b ON b.user_id = d.buyer_user_id AND b.wallet_type = 'MAIN'
                JOIN wlt_v_wallets s ON s.user_id = d.seller_user_id AND s.wallet_type = 'MAIN'
               WHERE d.status = 'DISPUTED' ORDER BY d.created_at) LOOP
      l_n := l_n + 1;
      l_h := l_h || '<div class="a-case"><h4>' || esc(d.title) || ' · ' || money(d.amount) || ' د.أ</h4><small>المشتري ' || esc(d.bn) || ' · البائع ' || esc(d.sn) || ' · ' || d.code
        || '</small><div class="w-note" style="margin-top:8px">«' || esc(d.dispute_reason) || '»</div><div class="a-acts">'
        || '<button type="button" data-es="REFUND" data-id="' || d.deal_id || '">↩️ إرجاع للمشتري</button><button type="button" class="go" data-es="RELEASE" data-id="' || d.deal_id || '">تحرير للبائع</button></div></div>';
    END LOOP;
    IF l_n = 0 THEN l_h := l_h || '<div class="w-empty">⚖️ لا اعتراضات مفتوحة</div>'; END IF;
    l_h := l_h || '<div class="w-err" id="eErr"></div></section>'

    -- المستخدمون
      || '<section class="w-pane" id="tU"><div class="a-row"><label class="w-field"><span>رقم المستخدم</span><input class="w-in ltr" id="uPh" inputmode="tel" placeholder="07X XXX XXXX"></label>'
      || '<button type="button" id="uGo">بحث</button></div><div class="w-err" id="uErr"></div><div class="a-user" id="uBox"></div></section>'

    -- الأسعار
      || '<section class="w-pane" id="tF">';
    FOR r IN (SELECT currency_code, per_jod, updated_at FROM wlt_fx_rates WHERE currency_code <> 'JOD' ORDER BY currency_code DESC) LOOP
      l_h := l_h || '<div class="a-row"><label class="w-field"><span>1 د.أ = ؟ ' || r.currency_code || ' · آخر تحديث ' || TO_CHAR(wlt_local(r.updated_at), 'DD/MM HH24:MI')
        || '</span><input class="w-in ltr" data-cur="' || r.currency_code || '" inputmode="decimal" value="' || TO_CHAR(r.per_jod, 'FM990D0000', 'NLS_NUMERIC_CHARACTERS=''.,''') || '"></label>'
        || '<button type="button" data-rate="' || r.currency_code || '">حفظ</button></div>';
    END LOOP;
    l_h := l_h || '<div class="w-err" id="fErr"></div><div class="w-note">كل تعديل يُحفظ في سجل الأسعار ويظهر في رسم العملات عند العملاء.</div></section></div>';

    -- بيانات الرسوم
    l_d := '{"vol":[';
    l_n := 0;
    FOR x IN (SELECT dd.d, NVL(SUM(m.volume), 0) v, NVL(SUM(m.cnt), 0) c
                FROM (SELECT TRUNC(CAST(wlt_local(SYSTIMESTAMP) AS DATE)) - LEVEL + 1 d FROM dual CONNECT BY LEVEL <= 14) dd
                LEFT JOIN wlt_mv_daily m ON m.day = dd.d AND m.txn_type NOT IN ('FEE','SAVE','SAVE_OUT','ROUNDUP','FX')
               GROUP BY dd.d ORDER BY dd.d) LOOP
      l_d := l_d || CASE WHEN l_n > 0 THEN ',' END || '{"l":"' || TO_CHAR(x.d, 'DD/MM') || '","t":"' || TO_CHAR(x.d, 'DD/MM/YYYY') || ' · ' || x.c || ' عملية","v":' || num(x.v) || '}';
      l_n := l_n + 1;
    END LOOP;
    l_d := l_d || '],"mix":[';
    l_n := 0;
    FOR x IN (SELECT tt.name_ar, SUM(m.volume) v FROM wlt_mv_daily m JOIN wlt_txn_types tt ON tt.txn_type = m.txn_type
               WHERE m.day > TRUNC(SYSDATE) - 30 AND m.txn_type NOT IN ('FEE','SAVE','SAVE_OUT','ROUNDUP','FX')
               GROUP BY tt.name_ar HAVING SUM(m.volume) > 0) LOOP
      l_d := l_d || CASE WHEN l_n > 0 THEN ',' END || '{"l":"' || js(x.name_ar) || '","v":' || num(x.v) || '}';
      l_n := l_n + 1;
    END LOOP;
    l_d := l_d || '],"hour":[';
    l_n := 0;
    FOR x IN (SELECT h.h, COUNT(t.txn_id) c FROM (SELECT LEVEL - 1 h FROM dual CONNECT BY LEVEL <= 24) h
                LEFT JOIN wlt_transactions t ON TO_NUMBER(TO_CHAR(wlt_local(t.created_at), 'HH24')) = h.h
                     AND t.created_at > SYSDATE - 7 AND t.status = 'COMPLETED'
               GROUP BY h.h ORDER BY h.h) LOOP
      l_d := l_d || CASE WHEN l_n > 0 THEN ',' END || '{"l":"' || x.h || '","t":"الساعة ' || x.h || ':00","v":' || x.c || '}';
      l_n := l_n + 1;
    END LOOP;
    l_d := l_d || ']}';

    RETURN l_h || '<script>window.ADM=' || l_d || ';</script>' || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)};W.tabs();
  V.bars($('cVol'),ADM.vol,[{name:'الحجم',key:'v',color:'var(--s1)'}],'د.أ');
  if(ADM.mix.length)V.donut($('cMix'),ADM.mix,'د.أ');else $('cMix').insertAdjacentHTML('beforeend','<div class="w-empty">لا بيانات</div>');
  V.bars($('cHour'),ADM.hour,[{name:'العمليات',key:'v',color:'var(--s3)'}],'عملية');
  function A(a,x){var p={x01:a};Object.keys(x||{}).forEach(function(k){p[k]=String(x[k])});
    return new Promise(function(res){apex.server.process('WLT_ADMIN',p,{success:res,error:function(){res({ok:false,msg:'تعذّر الاتصال'})}})})}
  $('aRef').onclick=function(){this.textContent='جارٍ التحديث…';A('refresh',{}).then(function(){location.reload()})};
  document.querySelectorAll('[data-rk]').forEach(function(b){b.onclick=function(){var a=b.dataset.rk;
    W.confirm(a==='approve'?'اعتماد العملية وتنفيذها':a==='freeze'?'رفض وتجميد حساب المرسل':'رفض العملية',[['الحالة','#'+b.dataset.id]],'تأكيد',function(){
      A('risk',{x02:a,x03:b.dataset.id}).then(function(r){r.ok?location.reload():W.fail('rErr',r)})})}});
  document.querySelectorAll('[data-es]').forEach(function(b){b.onclick=function(){
    W.confirm(b.dataset.es==='REFUND'?'إرجاع المبلغ للمشتري':'تحرير المبلغ للبائع',[['الصفقة','#'+b.dataset.id]],'تأكيد القرار',function(){
      A('escrow',{x02:b.dataset.id,x03:b.dataset.es}).then(function(r){r.ok?location.reload():W.fail('eErr',r)})})}});
  document.querySelectorAll('[data-rate]').forEach(function(b){b.onclick=function(){var c=b.dataset.rate,v=document.querySelector('[data-cur="'+c+'"]').value;b.disabled=true;
    A('rate',{x02:c,x03:v}).then(function(r){b.disabled=false;if(r.ok){b.textContent='✓';setTimeout(function(){b.textContent='حفظ'},1500)}else W.err('fErr',r.msg)})}});
  function user(){W.err('uErr');A('user',{x02:$('uPh').value}).then(function(r){var bx=$('uBox');if(!r.ok){bx.classList.remove('on');W.err('uErr',r.msg);return}
    bx.innerHTML='<h4 style="margin:0;font-family:var(--w-disp)">'+W.esc(r.name)+'</h4><dl><dt>الرقم</dt><dd>'+r.phone+'</dd><dt>النوع</dt><dd>'+r.type+'</dd><dt>الحالة</dt><dd>'+(r.status==='ACTIVE'?'✅ فعّال':'⛔ موقوف')+'</dd>'
      +'<dt>المستوى</dt><dd>'+r.tier+'</dd><dt>الرصيد</dt><dd>'+r.bal+' د.أ (محجوز '+r.held+')</dd><dt>عمليات 30 يوماً</dt><dd>'+r.cnt+'</dd><dt>بلاغات أمان</dt><dd>'+r.cases+'</dd><dt>منذ</dt><dd>'+r.since+'</dd></dl>'
      +'<div class="a-row"><label class="w-field"><span>مستوى التوثيق</span><select id="uTier"><option>BASIC</option><option>VERIFIED</option><option>PREMIUM</option></select></label><button type="button" id="uTierGo">ترقية</button></div>'
      +'<div class="a-acts"><button type="button" class="'+(r.status==='ACTIVE'?'no':'go')+'" id="uSt">'+(r.status==='ACTIVE'?'⛔ تجميد الحساب':'✅ إعادة التفعيل')+'</button></div>';
    bx.classList.add('on');$('uTier').value=r.tier;
    $('uTierGo').onclick=function(){A('tier',{x02:r.phone,x03:$('uTier').value}).then(function(x){x.ok?user():W.err('uErr',x.msg)})};
    $('uSt').onclick=function(){A('status',{x02:r.phone,x03:r.status==='ACTIVE'?'SUSPENDED':'ACTIVE'}).then(function(x){x.ok?user():W.err('uErr',x.msg)})}})}
  $('uGo').onclick=user;$('uPh').addEventListener('keydown',function(e){if(e.key==='Enter')user()});
})();
</script>~';
  END render_admin;

  -- -----------------------------------------------------------------
  -- 22) تحليل مصاريفي
  -- -----------------------------------------------------------------
  FUNCTION render_insights RETURN CLOB IS
    l      wlt_v_wallets%ROWTYPE := me;
    l_h    CLOB;
    l_d    CLOB;
    l_n    PLS_INTEGER := 0;
    l_m0   DATE := TRUNC(CAST(wlt_local(SYSTIMESTAMP) AS DATE), 'MM');
    l_this NUMBER; l_last NUMBER; l_days NUMBER; l_dim NUMBER; l_chg NUMBER;
    l_top  VARCHAR2(200); l_topv NUMBER;
  BEGIN
    -- مصروفات هذا الشهر والشهر الماضي حتى نفس اليوم (مقارنة عادلة)
    l_days := TRUNC(CAST(wlt_local(SYSTIMESTAMP) AS DATE)) - l_m0 + 1;
    l_dim  := LAST_DAY(l_m0) - l_m0 + 1;
    SELECT NVL(SUM(CASE WHEN CAST(t.created_at AS DATE) + 3/24 >= l_m0 THEN t.amount END), 0),
           NVL(SUM(CASE WHEN CAST(t.created_at AS DATE) + 3/24 <  l_m0
                         AND CAST(t.created_at AS DATE) + 3/24 < ADD_MONTHS(l_m0, -1) + l_days THEN t.amount END), 0)
      INTO l_this, l_last
      FROM wlt_transactions t
     WHERE t.from_wallet_id = l.wallet_id AND t.status = 'COMPLETED'
       AND t.created_at >= CAST(ADD_MONTHS(l_m0, -1) - 3/24 AS TIMESTAMP)
       AND t.txn_type NOT IN ('SAVE','ROUNDUP','FX','FEE');
    l_chg := CASE WHEN l_last > 0 THEN ROUND((l_this - l_last) / l_last * 100) END;

    l_h := wallet_ui2_pkg.common || css || charts || '<div class="w-app v-root">'
      || head('تحليل مصاريفي', 'أين يذهب مالك هذا الشهر؟')
      || '<div class="i-hero"><small>صرفت منذ بداية ' || TO_CHAR(l_m0, 'MM/YYYY') || '</small><b class="big">' || money(l_this) || '</b><div class="row">'
      || CASE WHEN l_chg IS NOT NULL THEN '<span class="i-chg ' || CASE WHEN l_chg > 0 THEN 'up' ELSE 'down' END || '">' || ABS(l_chg) || '% عن نفس الفترة الشهر الماضي</span>' END
      || '<span>المعدّل اليومي ' || money(l_this / l_days) || '</span><span>المتوقع للشهر ' || money(l_this / l_days * l_dim) || '</span></div></div>'
      || '<div class="i-tips" id="iTips"></div>'
      || '<div class="v-card" id="cCat"><h3>حسب الفئة</h3><p>هذا الشهر · بالدينار</p></div>'
      || '<div class="v-card" id="cMon"><h3>دخلك ومصروفك</h3><p>آخر 6 أشهر · بالدينار</p></div>'
      || '<div class="v-card"><h3>أكثر من دفعت لهم</h3><p>هذا الشهر</p>';

    -- أكثر المستلمين: ترتيب بالدوال التحليلية
    FOR r IN (SELECT who, v, c, RANK() OVER (ORDER BY v DESC) rk FROM (
                SELECT CASE WHEN o.user_type = 'SYSTEM' THEN tt.name_ar ELSE o.shown_name END who, SUM(t.amount) v, COUNT(*) c
                  FROM wlt_transactions t JOIN wlt_v_wallets o ON o.wallet_id = t.to_wallet_id JOIN wlt_txn_types tt ON tt.txn_type = t.txn_type
                 WHERE t.from_wallet_id = l.wallet_id AND t.status = 'COMPLETED' AND CAST(t.created_at AS DATE) + 3/24 >= l_m0
                   AND t.txn_type NOT IN ('SAVE','ROUNDUP','FX','FEE')
                 GROUP BY CASE WHEN o.user_type = 'SYSTEM' THEN tt.name_ar ELSE o.shown_name END)
               ORDER BY rk FETCH FIRST 5 ROWS ONLY) LOOP
      l_n := l_n + 1;
      IF l_n = 1 THEN l_top := r.who; l_topv := r.v; END IF;
      l_h := l_h || '<div class="a-rank"><i>' || r.rk || '</i><span>' || esc(r.who) || ' <small style="color:var(--w-muted)">· ' || r.c || ' مرة</small></span><b>' || money(r.v) || '</b></div>';
    END LOOP;
    IF l_n = 0 THEN l_h := l_h || '<div class="w-empty">لا مصاريف هذا الشهر بعد</div>'; END IF;
    l_h := l_h || '</div></div>';

    -- الفئات هذا الشهر + التغيّر عن الشهر الماضي بـ LAG
    l_d := '{"cat":[';
    l_n := 0;
    FOR c IN (SELECT cat, mon, v, LAG(v) OVER (PARTITION BY cat ORDER BY mon) prev FROM (
                SELECT CASE t.txn_type
                         WHEN 'MERCHANT_PAY' THEN NVL(mp.category, 'متاجر')
                         WHEN 'BILL_PAY' THEN 'فواتير' WHEN 'RECHARGE' THEN 'شحن خطوط' WHEN 'TRANSFER' THEN 'تحويلات'
                         WHEN 'JAMIYA' THEN 'جمعيات' WHEN 'EIDIYA' THEN 'هدايا وعيديات' WHEN 'CASH_OUT' THEN 'سحب نقدي'
                         WHEN 'BNPL_REPAY' THEN 'أقساط' WHEN 'ESCROW_REL' THEN 'مشتريات مضمونة' WHEN 'ALLOWANCE' THEN 'مصروف الأبناء'
                         ELSE 'أخرى' END cat,
                       TRUNC(CAST(t.created_at AS DATE) + 3/24, 'MM') mon, SUM(t.amount) v
                  FROM wlt_transactions t
                  JOIN wlt_wallets w2 ON w2.wallet_id = t.to_wallet_id
                  LEFT JOIN wlt_merchant_profiles mp ON mp.user_id = w2.user_id
                 WHERE t.from_wallet_id = l.wallet_id AND t.status = 'COMPLETED'
                   AND t.created_at >= CAST(ADD_MONTHS(l_m0, -1) - 3/24 AS TIMESTAMP)
                   AND t.txn_type NOT IN ('SAVE','ROUNDUP','FX','FEE')
                 GROUP BY CASE t.txn_type
                         WHEN 'MERCHANT_PAY' THEN NVL(mp.category, 'متاجر')
                         WHEN 'BILL_PAY' THEN 'فواتير' WHEN 'RECHARGE' THEN 'شحن خطوط' WHEN 'TRANSFER' THEN 'تحويلات'
                         WHEN 'JAMIYA' THEN 'جمعيات' WHEN 'EIDIYA' THEN 'هدايا وعيديات' WHEN 'CASH_OUT' THEN 'سحب نقدي'
                         WHEN 'BNPL_REPAY' THEN 'أقساط' WHEN 'ESCROW_REL' THEN 'مشتريات مضمونة' WHEN 'ALLOWANCE' THEN 'مصروف الأبناء'
                         ELSE 'أخرى' END, TRUNC(CAST(t.created_at AS DATE) + 3/24, 'MM'))
              ORDER BY v DESC) LOOP
      IF c.mon = l_m0 THEN
        l_d := l_d || CASE WHEN l_n > 0 THEN ',' END || '{"l":"' || js(c.cat) || '","v":' || num(c.v) || ',"p":' || CASE WHEN c.prev IS NULL THEN 'null' ELSE num(c.prev) END || '}';
        l_n := l_n + 1;
      END IF;
    END LOOP;
    l_d := l_d || '],"mon":[';
    l_n := 0;
    FOR m IN (SELECT mm.m,
                     NVL(SUM(CASE WHEN t.from_wallet_id = l.wallet_id AND t.txn_type NOT IN ('SAVE','ROUNDUP','FX','FEE') THEN t.amount END), 0) sp,
                     NVL(SUM(CASE WHEN t.to_wallet_id = l.wallet_id AND t.txn_type NOT IN ('SAVE_OUT','FX') THEN t.amount END), 0) inc
                FROM (SELECT ADD_MONTHS(l_m0, 1 - LEVEL) m FROM dual CONNECT BY LEVEL <= 6) mm
                LEFT JOIN wlt_transactions t ON (t.from_wallet_id = l.wallet_id OR t.to_wallet_id = l.wallet_id) AND t.status = 'COMPLETED'
                     AND TRUNC(CAST(t.created_at AS DATE) + 3/24, 'MM') = mm.m
               GROUP BY mm.m ORDER BY mm.m) LOOP
      l_d := l_d || CASE WHEN l_n > 0 THEN ',' END || '{"l":"' || TO_CHAR(m.m, 'MM/YY') || '","t":"' || TO_CHAR(m.m, 'MM/YYYY') || '","i":' || num(m.inc) || ',"s":' || num(m.sp) || '}';
      l_n := l_n + 1;
    END LOOP;
    l_d := l_d || '],"top":"' || js(l_top) || '","topv":' || num(l_topv) || ',"chg":' || NVL(TO_CHAR(l_chg), 'null') || '}';

    RETURN l_h || '<script>window.INS=' || l_d || ';</script>' || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)},tips=[];
  if(INS.cat.length)V.donut($('cCat'),INS.cat.map(function(c){return {l:c.l,v:c.v}}),'د.أ');else $('cCat').insertAdjacentHTML('beforeend','<div class="w-empty">لا مصاريف هذا الشهر بعد</div>');
  V.bars($('cMon'),INS.mon,[{name:'الدخل',key:'i',color:'var(--s1)'},{name:'المصروف',key:'s',color:'var(--s2)'}],'د.أ');
  if(INS.cat.length){var b=INS.cat[0];tips.push(['🥇','أكبر فئة صرف هذا الشهر: <b>'+W.esc(b.l)+'</b> بـ '+b.v.toFixed(3)+' د.أ'])}
  INS.cat.forEach(function(c){if(c.p&&c.p>0){var ch=Math.round((c.v-c.p)/c.p*100);if(Math.abs(ch)>=25)tips.push([ch>0?'📈':'📉','صرفك على <b>'+W.esc(c.l)+'</b> '+(ch>0?'ارتفع':'انخفض')+' '+Math.abs(ch)+'% عن الشهر الماضي'])}});
  if(INS.chg!==null&&INS.chg<0)tips.push(['👏','مصروفك أقل من الشهر الماضي بـ '+Math.abs(INS.chg)+'%. استمر!']);
  if(INS.chg!==null&&INS.chg>20)tips.push(['💡','مصروفك أعلى من المعتاد. جرّب قاعدة «تنبيه حد الصرف» من الحصّالات']);
  if(!tips.length)tips.push(['🌱','كلما استخدمت المحفظة أكثر، صارت التحليلات أدق']);
  $('iTips').innerHTML=tips.slice(0,4).map(function(t){return '<div><span>'+t[0]+'</span><div>'+t[1]+'</div></div>'}).join('');
})();
</script>~';
  END render_insights;

  -- -----------------------------------------------------------------
  PROCEDURE api IS
    a    VARCHAR2(20)   := apex_application.g_x01;
    x2   VARCHAR2(4000) := apex_application.g_x02;
    x3   VARCHAR2(4000) := apex_application.g_x03;
    u    VARCHAR2(20)   := v('APP_USER');
    l_s  VARCHAR2(100);
    l_t  VARCHAR2(10);
    r    wlt_v_wallets%ROWTYPE;
    l_n  NUMBER; l_c NUMBER;
    l_since TIMESTAMP;
    l_msg VARCHAR2(4000);
  BEGIN
    SELECT user_type INTO l_t FROM wlt_users WHERE phone = u;
    IF l_t <> 'ADMIN' THEN RAISE_APPLICATION_ERROR(-20180, 'للإدارة فقط'); END IF;
    CASE a
      WHEN 'risk' THEN
        IF x2 = 'approve' THEN l_s := wallet_risk_pkg.approve(u, TO_NUMBER(x3));
        ELSE wallet_risk_pkg.reject(u, TO_NUMBER(x3), CASE WHEN x2 = 'freeze' THEN 'Y' ELSE 'N' END);
        END IF;
      WHEN 'escrow' THEN l_s := wallet_escrow_pkg.resolve(u, TO_NUMBER(x2), x3);
      WHEN 'rate'   THEN wallet_fx_pkg.set_rate(u, x2, TO_NUMBER(x3, '99990D999999', 'NLS_NUMERIC_CHARACTERS=''.,'''));
      WHEN 'status' THEN wallet_risk_pkg.set_user_status(u, x2, x3);
      WHEN 'tier'   THEN wallet_risk_pkg.set_user_tier(u, x2, x3);
      WHEN 'refresh' THEN DBMS_MVIEW.REFRESH('WLT_MV_DAILY', 'C');
      WHEN 'user' THEN
        BEGIN
          SELECT * INTO r FROM wlt_v_wallets WHERE phone = wallet_otp_pkg.normalize_phone(x2) AND wallet_type = 'MAIN' AND currency_code = 'JOD';
        EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20180, 'لا يوجد مستخدم بهذا الرقم');
        END;
        SELECT status, created_at INTO l_t, l_since FROM wlt_users WHERE user_id = r.user_id;
        SELECT COUNT(*) INTO l_n FROM wlt_transactions WHERE (from_wallet_id = r.wallet_id OR to_wallet_id = r.wallet_id) AND created_at > SYSDATE - 30;
        SELECT COUNT(*) INTO l_c FROM wlt_risk_cases WHERE from_user_id = r.user_id OR to_user_id = r.user_id;
        apex_json.open_object;
        apex_json.write('ok', TRUE);
        apex_json.write('name', r.shown_name); apex_json.write('phone', r.phone); apex_json.write('type', r.user_type);
        apex_json.write('tier', r.kyc_tier); apex_json.write('status', l_t);
        apex_json.write('bal', money(r.balance)); apex_json.write('held', money(r.held_amount));
        apex_json.write('cnt', l_n); apex_json.write('cases', l_c); apex_json.write('since', TO_CHAR(wlt_local(l_since), 'DD/MM/YYYY'));
        apex_json.close_object;
        RETURN;
      ELSE RAISE_APPLICATION_ERROR(-20199, 'عملية غير معروفة');
    END CASE;
    apex_json.open_object;
    apex_json.write('ok', TRUE);
    apex_json.close_object;
  EXCEPTION WHEN OTHERS THEN
    l_msg := CASE WHEN SQLCODE BETWEEN -20999 AND -20000
                  THEN REGEXP_REPLACE(REGEXP_SUBSTR(SQLERRM, '^[^' || CHR(10) || ']+'), '^ORA-\d+: ', '')
                  WHEN SQLCODE IN (-6502, -1722) THEN 'تحقق من القيم المدخلة'
                  ELSE 'حدث خطأ غير متوقع' END;
    apex_json.open_object;
    apex_json.write('ok', FALSE);
    apex_json.write('msg', l_msg);
    apex_json.close_object;
  END api;

END wallet_ui7_pkg;
/

BEGIN
  wwv_flow_imp.import_begin(
    p_version_yyyy_mm_dd   => '2026.04.07',
    p_release              => '26.2.0',
    p_default_workspace_id => 33112972745115671678,
    p_default_application_id => 179352,
    p_default_id_offset    => 0,
    p_default_owner        => 'WKSP_MOHAMMADAPEX');
  FOR p IN (SELECT 21 id, 'Admin' n, 'ADMIN' al, 'لوحة الإدارة' t, 'render_admin' f FROM dual
            UNION ALL SELECT 22, 'Insights', 'INSIGHTS', 'تحليل مصاريفي', 'render_insights' FROM dual) LOOP
    wwv_flow_imp_page.create_page(p_id => p.id, p_name => p.n, p_alias => p.al,
      p_step_title => p.t, p_autocomplete_on_off => 'OFF', p_step_template => 2982503008768810240,
      p_page_template_options => '#DEFAULT#', p_protection_level => 'C', p_page_component_map => '25');
    wwv_flow_imp_page.create_page_plug(p_id => wwv_flow_imp.id(9090000000000000000 + p.id * 10), p_plug_name => 'WLT ' || p.n,
      p_static_id => 'wlt-' || LOWER(p.al), p_region_template_options => '#DEFAULT#', p_plug_template => 3374665444246510938,
      p_plug_display_sequence => 10, p_function_body_language => 'PLSQL',
      p_plug_source => 'return wallet_ui7_pkg.' || p.f || ';', p_plug_source_type => 'NATIVE_DYNAMIC_CONTENT');
  END LOOP;
  wwv_flow_imp_shared.create_flow_process(p_id => wwv_flow_imp.id(9090000000000000300),
    p_process_sequence => 1, p_process_point => 'ON_DEMAND', p_process_type => 'NATIVE_PLSQL',
    p_process_name => 'WLT_ADMIN', p_process_sql_clob => 'wallet_ui7_pkg.api;', p_process_clob_language => 'PLSQL',
    p_security_scheme => 'MUST_NOT_BE_PUBLIC_USER');
  wwv_flow_imp.import_end(p_auto_install_sup_obj => FALSE);
  COMMIT;
END;
/
