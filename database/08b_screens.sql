-- =====================================================================
--  محفظتي · الجلسة 8 · شاشات الضمان (17) وادفع لاحقاً (18) والعملات (19) والنقاط (20)
-- =====================================================================
CREATE OR REPLACE PACKAGE wallet_ui6_pkg AS
  FUNCTION render_escrow RETURN CLOB;
  FUNCTION render_bnpl   RETURN CLOB;
  FUNCTION render_fx     RETURN CLOB;
  FUNCTION render_points RETURN CLOB;
  PROCEDURE api;
END wallet_ui6_pkg;
/

CREATE OR REPLACE PACKAGE BODY wallet_ui6_pkg AS

  FUNCTION esc (p VARCHAR2) RETURN VARCHAR2 IS BEGIN RETURN apex_escape.html(p); END;
  FUNCTION money (p NUMBER, p_dec NUMBER DEFAULT 3) RETURN VARCHAR2 IS
  BEGIN
    RETURN TO_CHAR(p, CASE p_dec WHEN 2 THEN 'FM999G999G990D00' ELSE 'FM999G999G990D000' END, 'NLS_NUMERIC_CHARACTERS=''.,''');
  END;

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
.m-hero{position:relative;overflow:hidden;border-radius:24px;padding:20px;margin-bottom:18px;color:#f3efe2;
  background:radial-gradient(120% 90% at 100% 0%,rgba(233,197,111,.28),transparent 55%),linear-gradient(140deg,var(--w-g9),var(--w-g7));box-shadow:0 22px 40px -22px rgba(5,30,25,.6)}
.m-hero small{opacity:.75;font-size:12.5px}
.m-hero .big{display:block;font-family:var(--w-mono);font-size:32px;font-weight:700;direction:ltr;text-align:right;color:var(--w-gold);line-height:1.2;margin:4px 0 8px}
.m-hero .row{display:flex;gap:8px;flex-wrap:wrap}.m-hero .row span{background:rgba(255,255,255,.1);border-radius:999px;padding:3px 11px;font-size:12px}
.m-ic{position:absolute;left:16px;top:14px;font-size:44px;opacity:.9;filter:drop-shadow(0 6px 10px rgba(0,0,0,.3))}
.m-card{border:1px solid var(--w-rule);background:var(--w-paper);border-radius:22px;padding:16px;margin-bottom:12px;animation:w-in .4s both}
.m-top{display:flex;justify-content:space-between;gap:10px;align-items:flex-start}
.m-top h3{font-family:var(--w-disp);font-size:16px;margin:0}
.m-top small{display:block;color:var(--w-muted);font-size:12px;margin-top:2px}
.m-amt{font-family:var(--w-mono);font-weight:700;font-size:19px;direction:ltr;white-space:nowrap}
.m-role{display:inline-block;font-size:11px;border-radius:999px;padding:1px 9px;margin-inline-start:6px;background:var(--w-bg);border:1px solid var(--w-rule)}
.m-steps{display:flex;align-items:center;margin:16px 4px 6px}
.m-steps .s{display:grid;justify-items:center;gap:4px;font-size:11px;color:var(--w-muted);width:64px;text-align:center}
.m-steps .s i{width:34px;height:34px;border-radius:50%;display:grid;place-items:center;font-style:normal;font-size:15px;background:var(--w-bg);border:2px solid var(--w-rule)}
.m-steps .s.on{color:var(--w-ink);font-weight:600}.m-steps .s.on i{background:var(--w-mint-s);border-color:var(--w-mint)}
.m-steps .s.bad i{background:var(--w-red-s);border-color:var(--w-red)}
.m-steps .ln{flex:1;height:3px;border-radius:2px;background:var(--w-rule);margin-bottom:18px}.m-steps .ln.on{background:var(--w-mint)}
.m-note{font-size:12px;color:var(--w-muted);text-align:center;margin-top:4px}
.m-acts{display:flex;gap:8px;margin-top:12px}
.m-acts button{flex:1;border-radius:12px;padding:10px;font-family:var(--w-disp);font-weight:600;font-size:14px;cursor:pointer;border:1.5px solid var(--w-rule);background:var(--w-paper);color:var(--w-ink)}
.m-acts button.go{background:var(--w-g8);border-color:var(--w-g8);color:#fff}
.m-acts button.warn{color:var(--w-red);border-color:var(--w-red-s)}
.m-who{font-size:13px;color:var(--w-mint);margin:-8px 0 12px;min-height:18px}
.b-gauge{display:grid;grid-template-columns:120px 1fr;gap:16px;align-items:center}
.b-ring{--p:0;width:120px;height:120px;border-radius:50%;display:grid;place-items:center;background:conic-gradient(var(--w-gold) calc(var(--p)*1%),rgba(255,255,255,.12) 0);transition:--p 1s}
.b-ring div{width:96px;height:96px;border-radius:50%;background:var(--w-g8);display:grid;place-items:center;text-align:center;line-height:1.1}
.b-ring b{font-family:var(--w-mono);font-size:28px;color:var(--w-gold)}.b-ring small{font-size:10.5px}
.b-parts{display:grid;gap:7px;font-size:11.5px}
.b-parts div{display:grid;grid-template-columns:70px 1fr 34px;gap:6px;align-items:center}
.b-parts i{height:6px;border-radius:3px;background:rgba(255,255,255,.14);overflow:hidden;display:block}
.b-parts i span{display:block;height:100%;background:var(--w-gold);border-radius:3px}
.b-parts em{font-style:normal;font-family:var(--w-mono);text-align:left;opacity:.85}
.b-lim{display:flex;justify-content:space-between;margin-top:14px;padding-top:12px;border-top:1px solid rgba(255,255,255,.12);font-size:12px}
.b-lim b{display:block;font-family:var(--w-mono);font-size:18px;color:#fff;direction:ltr;text-align:right}
.b-sched{display:grid;gap:6px;margin:4px 0 14px}
.b-sched div{display:flex;justify-content:space-between;background:var(--w-paper);border:1px dashed var(--w-rule);border-radius:12px;padding:8px 12px;font-size:13px}
.b-sched b{font-family:var(--w-mono);direction:ltr}
.b-dots{display:flex;gap:6px;margin:12px 0 4px}
.b-dots span{flex:1;text-align:center;font-size:10.5px;color:var(--w-muted)}
.b-dots span i{display:block;height:8px;border-radius:4px;background:var(--w-rule);margin-bottom:4px}
.b-dots span.PAID i{background:var(--w-mint)}.b-dots span.LATE i{background:var(--w-red)}.b-dots span.next i{background:var(--w-gold)}
.b-merch{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px}
.b-merch button{border:1.5px solid var(--w-rule);background:var(--w-paper);border-radius:14px;padding:8px 12px;font-family:var(--w-body);font-size:13px;cursor:pointer;color:var(--w-ink)}
.b-merch button.on{border-color:var(--w-mint);background:var(--w-mint-s)}
.b-merch button small{display:block;font-family:var(--w-mono);font-size:10.5px;color:var(--w-muted)}
.f-wal{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-bottom:16px}
.f-wal div{border-radius:18px;padding:12px;color:#fff;position:relative;overflow:hidden;min-height:86px}
.f-wal div:nth-child(1){background:linear-gradient(140deg,#0f3a33,#1d6b5a)}.f-wal div:nth-child(2){background:linear-gradient(140deg,#1f3d2a,#3c7a4a)}.f-wal div:nth-child(3){background:linear-gradient(140deg,#1f2a5a,#3d55a8)}
.f-wal small{opacity:.75;font-size:11px}.f-wal b{display:block;font-family:var(--w-mono);font-size:17px;direction:ltr;text-align:right;margin-top:14px}
.f-wal i{position:absolute;left:10px;top:6px;font-style:normal;font-size:26px;opacity:.35;font-family:var(--w-mono);font-weight:700}
.f-rate{display:grid;grid-template-columns:auto 1fr auto;gap:12px;align-items:center;border:1px solid var(--w-rule);background:var(--w-paper);border-radius:16px;padding:10px 14px;margin-bottom:8px}
.f-rate b{font-family:var(--w-mono);direction:ltr}.f-rate small{display:block;color:var(--w-muted);font-size:11px}
.f-rate svg{width:100%;height:30px}
.f-ex{display:grid;grid-template-columns:1fr auto 1fr;gap:8px;align-items:end;margin-bottom:12px}
.f-ex select{width:100%;border:1.5px solid var(--w-rule);border-radius:14px;padding:12px;font-family:var(--w-body);font-size:15px;background:var(--w-paper);color:var(--w-ink)}
.f-ex button{width:44px;height:46px;border-radius:14px;border:1.5px solid var(--w-rule);background:var(--w-paper);font-size:18px;cursor:pointer}
.f-quote{background:var(--w-g8);color:#f3efe2;border-radius:18px;padding:14px 16px;margin:4px 0 14px;display:none}
.f-quote.on{display:block;animation:w-in .3s}
.f-quote b{display:block;font-family:var(--w-mono);font-size:26px;color:var(--w-gold);direction:ltr;text-align:right}
.f-quote small{opacity:.75;font-size:12px}
.p-lvl{display:inline-flex;align-items:center;gap:6px;border-radius:999px;padding:3px 12px;font-size:12.5px;font-weight:700;color:#3a2a00}
.p-lvl.BRONZE{background:linear-gradient(90deg,#d9a273,#b07447);color:#fff}.p-lvl.SILVER{background:linear-gradient(90deg,#e6e9ec,#aab3bb)}.p-lvl.GOLD{background:linear-gradient(90deg,#f6e2a8,#d4a63a)}
.p-prog{height:8px;border-radius:4px;background:rgba(255,255,255,.14);overflow:hidden;margin:10px 0 4px}
.p-prog span{display:block;height:100%;background:var(--w-gold);border-radius:4px;width:0;transition:width 1s}
.p-red{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-bottom:16px}
.p-red button{border:1.5px solid var(--w-rule);background:var(--w-paper);border-radius:16px;padding:12px 6px;font-family:var(--w-body);cursor:pointer;color:var(--w-ink)}
.p-red button b{display:block;font-family:var(--w-mono);font-size:17px}.p-red button small{color:var(--w-mint);font-size:12px}
.p-red button:disabled{opacity:.4;cursor:not-allowed}
.p-off{display:flex;gap:12px;align-items:center;border:1px solid var(--w-rule);background:linear-gradient(135deg,#fff8e6,var(--w-paper));border-radius:18px;padding:12px 14px;margin-bottom:10px}
.p-off .pct{width:56px;height:56px;border-radius:16px;background:var(--w-g8);color:var(--w-gold);display:grid;place-items:center;font-family:var(--w-mono);font-weight:700;font-size:17px;flex:none}
.p-off small{display:block;color:var(--w-muted);font-size:12px}
.p-hist div{display:flex;justify-content:space-between;padding:9px 2px;border-bottom:1px dashed var(--w-rule);font-size:13px}
.p-hist b{font-family:var(--w-mono);direction:ltr}.p-hist b.plus{color:var(--w-mint)}.p-hist b.minus{color:var(--w-red)}
.p-hist small{display:block;color:var(--w-muted);font-size:11px}
</style>~';
  END css;

  FUNCTION js_api RETURN VARCHAR2 IS
  BEGIN
    RETURN q'~<script>
window.M=function(a,x){var p={x01:a};Object.keys(x||{}).forEach(function(k){p[k]=String(x[k])});
  return new Promise(function(res){apex.server.process('WLT_MONEY',p,{success:res,error:function(){res({ok:false,msg:'تعذّر الاتصال. لم يُخصم أي مبلغ.'})}})})};
window.Mreceipt=function(r,t,s){W.receipt(r,t,s);var a=document.querySelector('.w-receipt a');if(a){a.href=location.href;a.textContent='تمّ'}};
</script>~';
  END js_api;

  -- -----------------------------------------------------------------
  -- 17) الضمان
  -- -----------------------------------------------------------------
  FUNCTION render_escrow RETURN CLOB IS
    l     wlt_v_wallets%ROWTYPE := me;
    l_h   CLOB;
    l_n   PLS_INTEGER := 0;
    l_buy BOOLEAN;
    l_st  NUMBER;
    l_bad BOOLEAN;
  BEGIN
    l_h := wallet_ui2_pkg.common || css || js_api || '<div class="w-app">'
      || head('الضمان', 'اشترِ من أي شخص بأمان: مالك محجوز حتى تستلم')
      || '<div class="m-hero"><span class="m-ic">🛡️</span><small>محجوز في صفقات مفتوحة</small><span class="big">' || money(l.held_amount) || '</span>'
      || '<div class="row"><span>المتاح للصرف ' || money(l.available_balance) || ' د.أ</span><span>تحرير تلقائي بعد 3 أيام من التسليم</span></div></div>'
      || '<div class="w-tabs"><button type="button" class="on" data-p="pDeals">صفقاتي</button><button type="button" data-p="pNew">صفقة جديدة</button></div>'
      || '<section class="w-pane on" id="pDeals">';

    FOR d IN (SELECT d.*, CASE WHEN d.buyer_user_id = l.user_id THEN s.shown_name ELSE b.shown_name END AS other
                FROM wlt_escrow_deals d
                JOIN wlt_v_wallets b ON b.user_id = d.buyer_user_id  AND b.wallet_type = 'MAIN' AND b.currency_code = 'JOD'
                JOIN wlt_v_wallets s ON s.user_id = d.seller_user_id AND s.wallet_type = 'MAIN' AND s.currency_code = 'JOD'
               WHERE l.user_id IN (d.buyer_user_id, d.seller_user_id)
               ORDER BY CASE WHEN d.status IN ('HELD','SHIPPED','DISPUTED') THEN 0 ELSE 1 END, d.created_at DESC
               FETCH FIRST 15 ROWS ONLY) LOOP
      l_n := l_n + 1;
      l_buy := d.buyer_user_id = l.user_id;
      l_st  := CASE d.status WHEN 'HELD' THEN 1 WHEN 'SHIPPED' THEN 2 WHEN 'DISPUTED' THEN 2 ELSE 3 END;
      l_bad := d.status IN ('REFUNDED','CANCELLED','DISPUTED');
      l_h := l_h || '<div class="m-card" style="animation-delay:' || (l_n * 50) || 'ms"><div class="m-top"><div><h3>' || esc(d.title)
        || '<span class="m-role">' || CASE WHEN l_buy THEN 'أنت المشتري' ELSE 'أنت البائع' END || '</span></h3><small>'
        || CASE WHEN l_buy THEN 'البائع ' ELSE 'المشتري ' END || esc(d.other) || ' · ' || d.code || '</small></div>'
        || '<div class="m-amt">' || money(d.amount) || '</div></div>'
        || '<div class="m-steps"><div class="s on"><i>🔒</i>محجوز</div><div class="ln' || CASE WHEN l_st >= 2 THEN ' on' END || '"></div>'
        || '<div class="s' || CASE WHEN l_st >= 2 THEN ' on' END || CASE WHEN d.status = 'DISPUTED' THEN ' bad' END || '"><i>'
        || CASE WHEN d.status = 'DISPUTED' THEN '⚠️' ELSE '📦' END || '</i>' || CASE WHEN d.status = 'DISPUTED' THEN 'اعتراض' ELSE 'سُلّم' END || '</div>'
        || '<div class="ln' || CASE WHEN l_st >= 3 THEN ' on' END || '"></div>'
        || '<div class="s' || CASE WHEN l_st >= 3 THEN ' on' END || CASE WHEN d.status IN ('REFUNDED','CANCELLED') THEN ' bad' END || '"><i>'
        || CASE d.status WHEN 'RELEASED' THEN '✅' WHEN 'REFUNDED' THEN '↩️' WHEN 'CANCELLED' THEN '✕' ELSE '✅' END || '</i>'
        || CASE d.status WHEN 'REFUNDED' THEN 'استُرد' WHEN 'CANCELLED' THEN 'أُلغي' ELSE 'اكتمل' END || '</div></div>'
        || '<div class="m-note">'
        || CASE
             WHEN d.status = 'HELD' AND l_buy THEN 'بانتظار تسليم البائع · تُلغى تلقائياً ' || TO_CHAR(d.expires_at, 'DD/MM')
             WHEN d.status = 'HELD' THEN 'المبلغ محجوز لك. سلّم الطلب ثم أخبر المشتري'
             WHEN d.status = 'SHIPPED' AND l_buy THEN 'تحقّق من الطلب · يُحرَّر تلقائياً ' || TO_CHAR(d.auto_release_at, 'DD/MM HH24:MI')
             WHEN d.status = 'SHIPPED' THEN 'بانتظار تأكيد المشتري · تحرير تلقائي ' || TO_CHAR(d.auto_release_at, 'DD/MM HH24:MI')
             WHEN d.status = 'DISPUTED' THEN 'المبلغ مجمّد حتى تراجع الإدارة: ' || esc(d.dispute_reason)
             ELSE TO_CHAR(NVL(d.closed_at, d.created_at), 'DD/MM/YYYY') END || '</div>';
      IF d.status IN ('HELD','SHIPPED') THEN
        l_h := l_h || '<div class="m-acts">'
          || CASE
               WHEN l_buy AND d.status = 'HELD'    THEN '<button type="button" class="warn" data-cancel="' || d.deal_id || '">إلغاء الصفقة</button>'
               WHEN l_buy AND d.status = 'SHIPPED' THEN '<button type="button" class="go" data-ok="' || d.deal_id || '" data-a="' || money(d.amount) || '" data-t="' || esc(d.title) || '">✓ استلمت، حرّر المبلغ</button>'
                                                    || '<button type="button" class="warn" data-disp="' || d.deal_id || '">اعتراض</button>'
               WHEN d.status = 'HELD'              THEN '<button type="button" class="go" data-ship="' || d.deal_id || '">📦 تمّ التسليم</button>'
                                                    || '<button type="button" class="warn" data-cancel="' || d.deal_id || '" data-seller="1">اعتذار وإرجاع</button>'
               ELSE '<button type="button" class="warn" data-cancel="' || d.deal_id || '" data-seller="1">إرجاع المبلغ للمشتري</button>'
             END || '</div>';
      END IF;
      l_h := l_h || '</div>';
    END LOOP;
    IF l_n = 0 THEN l_h := l_h || '<div class="w-empty">🛡️ لا صفقات بعد.<br>اشترِ من صفحة أو شخص لا تعرفه، والمال يبقى معك حتى تستلم.</div>'; END IF;

    l_h := l_h || '<div class="w-err" id="dErr"></div></section>'
      || '<section class="w-pane" id="pNew">'
      || '<label class="w-field"><span>رقم البائع</span><input class="w-in ltr" id="nPh" inputmode="tel" placeholder="07X XXX XXXX"></label><div class="m-who" id="nWho"></div>'
      || '<label class="w-field"><span>ماذا تشتري؟</span><input class="w-in" id="nTitle" maxlength="100" placeholder="مثلاً: سماعات مستعملة"></label>'
      || '<label class="w-field"><span>المبلغ (د.أ)</span><input class="w-in ltr" id="nAmt" inputmode="decimal" placeholder="0.000" style="font-size:22px"></label>'
      || '<div class="w-err" id="nErr"></div><button class="w-btn" id="nGo" type="button" disabled>احجز المبلغ</button>'
      || '<div class="w-note">المبلغ يُحجز في رصيدك ولا يصل للبائع حتى تضغط «استلمت». إذا لم يسلّم خلال 7 أيام يُفك الحجز تلقائياً، وإن سلّم ولم تعترض خلال 3 أيام يُحرَّر له.</div>'
      || '</section></div>'
      || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)},who=null,t;W.tabs();W.num($('nAmt'));
  function v(){$('nGo').disabled=!(who&&$('nTitle').value.trim()&&parseFloat($('nAmt').value)>0);W.err('nErr')}
  $('nPh').addEventListener('input',function(){who=null;$('nWho').textContent='';v();clearTimeout(t);var p=this.value;
    t=setTimeout(function(){if(p.replace(/\D/g,'').length<9)return;M('who',{x02:p}).then(function(r){
      if(r.ok){who=r.name;$('nWho').textContent='✓ '+r.name}else $('nWho').textContent=r.msg;v()})},350)});
  ['nTitle','nAmt'].forEach(function(i){$(i).addEventListener('input',v)});
  $('nGo').onclick=function(){var a=Number($('nAmt').value).toFixed(3);
    W.confirm('صفقة مضمونة',[['البائع',who],['الطلب',$('nTitle').value],['يُحجز من رصيدك',a+' د.أ',1]],'احجز المبلغ',function(){
      M('deal',{x02:$('nPh').value,x03:a,x04:$('nTitle').value}).then(function(r){if(r.ok)location.reload();else W.fail('nErr',r)})})};
  function act(sel,a,title,rows,label,msg){document.querySelectorAll(sel).forEach(function(b){b.onclick=function(){var id=b.getAttribute(sel.slice(1,-1));
    W.confirm(title,rows(b),label,function(){M(a,{x02:id}).then(function(r){if(!r.ok){W.fail('dErr',r);return}
      if(r.ref)Mreceipt(r,msg,b.dataset.t);else location.reload()})})}})}
  act('[data-ship]','ship','تأكيد التسليم',function(){return [['بعد التأكيد','للمشتري 3 أيام للمراجعة']]},'نعم، سلّمت');
  act('[data-ok]','confirm','تحرير المبلغ للبائع',function(b){return [['الطلب',b.dataset.t],['يُحوَّل للبائع',b.dataset.a+' د.أ',1]]},'استلمت، حرّر المبلغ','اكتملت الصفقة 🛡️');
  act('[data-cancel]','cancel','إلغاء الصفقة',function(b){return [['النتيجة',b.dataset.seller?'يُفك الحجز ويعود المبلغ للمشتري':'يُفك الحجز عن مبلغك']]},'تأكيد الإلغاء');
  document.querySelectorAll('[data-disp]').forEach(function(b){b.onclick=function(){
    W.sheet('<h3>اعتراض على الصفقة</h3><p class="w-sub">المبلغ يُجمَّد ولا يصل للبائع حتى تراجع الإدارة.</p><textarea class="w-in" id="dR" rows="3" maxlength="300" placeholder="ما المشكلة؟ مثلاً: الطلب لم يصل أو مختلف عن الوصف"></textarea>'
      +'<div class="w-err" id="dE"></div><button class="w-btn" id="dGo" type="button">أرسل الاعتراض</button><div style="height:8px"></div><button class="w-btn ghost" type="button" onclick="W.close()">إلغاء</button>');
    $('dGo').onclick=function(){var o=this;o.disabled=true;M('dispute',{x02:b.dataset.disp,x03:$('dR').value}).then(function(r){if(r.ok)location.reload();else{o.disabled=false;W.err('dE',r.msg)}})}}});
})();
</script>~';
    RETURN l_h;
  END render_escrow;

  -- -----------------------------------------------------------------
  -- 18) ادفع لاحقاً
  -- -----------------------------------------------------------------
  FUNCTION render_bnpl RETURN CLOB IS
    l   wlt_v_wallets%ROWTYPE := me;
    e   wallet_bnpl_pkg.t_elig;
    l_h CLOB;
    l_n PLS_INTEGER := 0;
    l_next NUMBER;
    FUNCTION part (p_lbl VARCHAR2, p_v NUMBER, p_max NUMBER) RETURN VARCHAR2 IS
    BEGIN
      RETURN '<div><span>' || p_lbl || '</span><i><span style="width:' || ROUND(p_v / p_max * 100) || '%"></span></i><em>' || p_v || '/' || p_max || '</em></div>';
    END;
  BEGIN
    e := wallet_bnpl_pkg.eligibility(l.user_id);
    l_h := wallet_ui2_pkg.common || css || js_api || '<div class="w-app">'
      || head('ادفع لاحقاً', 'اشترِ الآن وقسّط على 3 أو 4 أشهر، بدون فوائد')
      || '<div class="m-hero"><div class="b-gauge"><div class="b-ring" id="bRing" data-p="' || e.score || '"><div><span><b>' || e.score
      || '</b><br><small>من 100</small></span></div></div><div class="b-parts">'
      || part('عمر الحساب', e.p_age, 20) || part('النشاط', e.p_activity, 30) || part('الدخل', e.p_inflow, 40) || part('الالتزام', e.p_punctual, 10)
      || '</div></div><div class="b-lim"><div><small>حدّك</small><b>' || money(e.credit_limit) || '</b></div><div><small>مستخدم</small><b>' || money(e.used)
      || '</b></div><div><small>متاح الآن</small><b style="color:var(--w-gold)">' || money(e.available) || '</b></div></div></div>';

    IF e.eligible = 'Y' THEN
      l_h := l_h || '<div class="w-sec"><h2>اشترِ بالتقسيط</h2></div><div class="b-merch" id="bM">';
      FOR m IN (SELECT m.merchant_code, w.shown_name, m.category FROM wlt_merchant_profiles m
                  JOIN wlt_v_wallets w ON w.user_id = m.user_id AND w.wallet_type = 'MAIN' ORDER BY m.merchant_code) LOOP
        l_h := l_h || '<button type="button" data-m="' || m.merchant_code || '">' || esc(m.shown_name) || '<small>' || m.merchant_code || ' · ' || esc(m.category) || '</small></button>';
      END LOOP;
      l_h := l_h || '</div><label class="w-field"><span>المبلغ (د.أ) — من 10 حتى ' || money(e.available) || '</span><input class="w-in ltr" id="bAmt" inputmode="decimal" placeholder="0.000" style="font-size:22px"></label>'
        || '<div class="w-grid" id="bN" style="grid-template-columns:1fr 1fr"><button class="w-tile on" type="button" data-n="3"><b>3</b>أقساط</button><button class="w-tile" type="button" data-n="4"><b>4</b>أقساط</button></div>'
        || '<div class="b-sched" id="bSched"></div><div class="w-err" id="bErr"></div><button class="w-btn" id="bGo" type="button" disabled>اشترِ الآن</button>'
        || '<div class="w-note">التاجر يستلم المبلغ كاملاً فوراً، وأنت تدفع أقساطاً شهرية تُخصم تلقائياً. بدون فوائد ولا غرامات تأخير؛ لكن القسط المتأخر يوقف الخدمة حتى تسدّده.</div>';
    ELSE
      l_h := l_h || '<div class="w-note" style="margin-top:0">🔒 ' || esc(e.reason) || '</div>';
    END IF;

    l_h := l_h || '<div class="w-sec" style="margin-top:22px"><h2>تقسيطاتي</h2></div>';
    FOR ln IN (SELECT ln.*, w.shown_name FROM wlt_bnpl_loans ln JOIN wlt_v_wallets w ON w.user_id = ln.merchant_user_id AND w.wallet_type = 'MAIN'
                WHERE ln.user_id = l.user_id ORDER BY CASE ln.status WHEN 'ACTIVE' THEN 0 ELSE 1 END, ln.created_at DESC FETCH FIRST 8 ROWS ONLY) LOOP
      l_n := l_n + 1;
      SELECT MIN(inst_no) INTO l_next FROM wlt_bnpl_installments WHERE loan_id = ln.loan_id AND status <> 'PAID';
      l_h := l_h || '<div class="m-card"><div class="m-top"><div><h3>' || esc(ln.shown_name) || '</h3><small>' || TO_CHAR(ln.created_at, 'DD/MM/YYYY')
        || ' · ' || ln.installments || ' أقساط</small></div><div class="m-amt">' || money(ln.amount) || '</div></div><div class="b-dots">';
      FOR i IN (SELECT * FROM wlt_bnpl_installments WHERE loan_id = ln.loan_id ORDER BY inst_no) LOOP
        l_h := l_h || '<span class="' || i.status || CASE WHEN i.inst_no = l_next AND i.status = 'DUE' THEN ' next' END || '"><i></i>'
          || CASE i.status WHEN 'PAID' THEN '✓ ' WHEN 'LATE' THEN '⏰ ' END || TO_CHAR(i.due_date, 'DD/MM') || '<br>' || money(i.amount) || '</span>';
      END LOOP;
      l_h := l_h || '</div>' || CASE WHEN l_next IS NOT NULL THEN '<div class="m-acts"><button type="button" class="go" data-pay="' || ln.loan_id || '">سدّد القسط القادم الآن</button></div>'
                                     ELSE '<div class="m-note">🎉 مسدّد بالكامل</div>' END || '</div>';
    END LOOP;
    IF l_n = 0 THEN l_h := l_h || '<div class="w-empty">لا تقسيطات بعد</div>'; END IF;

    RETURN l_h || '<div class="w-err" id="lErr"></div></div>' || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)},merch=null,n=3,idem=W.uuid();
  var r=$('bRing');setTimeout(function(){var p=0,t=+r.dataset.p,iv=setInterval(function(){p=Math.min(t,p+2);r.style.setProperty('--p',p);if(p>=t)clearInterval(iv)},16)},150);
  document.querySelectorAll('[data-pay]').forEach(function(b){b.onclick=function(){
    W.confirm('سداد قسط',[['يُخصم من رصيدك','القسط القادم',1]],'سدّد الآن',function(){
      M('paynext',{x02:b.dataset.pay}).then(function(x){x.ok?Mreceipt(x,'تمّ سداد القسط ✓'):W.fail('lErr',x)})})}});
  if(!$('bGo'))return;W.num($('bAmt'));
  function sched(){var a=parseFloat($('bAmt').value),h='';$('bGo').disabled=!(merch&&a>=10);W.err('bErr');
    if(a>=10){var p=Math.floor(a/n*1000)/1000;for(var i=1;i<=n;i++){var d=new Date();d.setMonth(d.getMonth()+i);
      var v=i===n?(a-p*(n-1)):p;h+='<div><span>القسط '+i+' · '+d.toLocaleDateString('ar-JO',{day:'numeric',month:'long'})+'</span><b>'+v.toFixed(3)+'</b></div>'}}
    $('bSched').innerHTML=h}
  document.querySelectorAll('#bM button').forEach(function(b){b.onclick=function(){document.querySelectorAll('#bM button').forEach(function(x){x.classList.toggle('on',x===b)});merch=b.dataset.m;sched()}});
  document.querySelectorAll('#bN .w-tile').forEach(function(b){b.onclick=function(){document.querySelectorAll('#bN .w-tile').forEach(function(x){x.classList.toggle('on',x===b)});n=+b.dataset.n;sched()}});
  $('bAmt').addEventListener('input',sched);
  $('bGo').onclick=function(){var a=Number($('bAmt').value).toFixed(3);
    W.confirm('شراء بالتقسيط',[['التاجر',merch],['عدد الأقساط',n+' شهرية'],['المبلغ',a+' د.أ',1]],'أكّد الشراء',function(){
      M('buy',{x02:merch,x03:a,x04:n,x05:idem}).then(function(x){if(x.ok)Mreceipt(x,'تمّ الشراء 🛍️',n+' أقساط بدون فوائد');else{W.fail('bErr',x);idem=W.uuid()}})})};
})();
</script>~';
  END render_bnpl;

  -- -----------------------------------------------------------------
  -- 19) العملات
  -- -----------------------------------------------------------------
  FUNCTION render_fx RETURN CLOB IS
    l    wlt_v_wallets%ROWTYPE := me;
    l_h  CLOB;
    l_b  NUMBER;
    l_pts VARCHAR2(2000);
    l_min NUMBER; l_max NUMBER; l_i NUMBER;
  BEGIN
    l_h := wallet_ui2_pkg.common || css || js_api || '<div class="w-app">'
      || head('العملات', 'احتفظ بالدولار واليورو وحوّل بينها بلحظة')
      || '<div class="f-wal"><div><i>د.أ</i><small>دينار</small><b id="wJOD">' || money(l.available_balance) || '</b></div>';
    FOR c IN (SELECT currency_code, symbol FROM wlt_currencies WHERE currency_code IN ('USD','EUR') ORDER BY currency_code DESC) LOOP
      SELECT NVL(MAX(balance), 0) INTO l_b FROM wlt_wallets WHERE user_id = l.user_id AND wallet_type = 'FX' AND currency_code = c.currency_code;
      l_h := l_h || '<div><i>' || c.symbol || '</i><small>' || CASE c.currency_code WHEN 'USD' THEN 'دولار' ELSE 'يورو' END
        || '</small><b id="w' || c.currency_code || '">' || money(l_b, 2) || '</b></div>';
    END LOOP;
    l_h := l_h || '</div><div class="w-sec"><h2>الأسعار</h2><span>تجريبية · تحدّثها الإدارة</span></div>';

    FOR r IN (SELECT f.currency_code, f.per_jod, f.updated_at, c.symbol FROM wlt_fx_rates f JOIN wlt_currencies c ON c.currency_code = f.currency_code
               WHERE f.currency_code <> 'JOD' ORDER BY f.currency_code DESC) LOOP
      SELECT MIN(per_jod), MAX(per_jod) INTO l_min, l_max FROM wlt_fx_history WHERE currency_code = r.currency_code AND recorded_at >= SYSDATE - 20;
      l_pts := NULL; l_i := 0;
      FOR p IN (SELECT per_jod FROM (SELECT per_jod, recorded_at FROM wlt_fx_history WHERE currency_code = r.currency_code
                                      ORDER BY recorded_at DESC FETCH FIRST 14 ROWS ONLY) ORDER BY recorded_at) LOOP
        l_pts := l_pts || ROUND(l_i * 100 / 13, 1) || ',' || ROUND(26 - CASE WHEN l_max = l_min THEN 11 ELSE (p.per_jod - l_min) / (l_max - l_min) * 22 END, 1) || ' ';
        l_i := l_i + 1;
      END LOOP;
      l_h := l_h || '<div class="f-rate"><div><b>' || r.symbol || '</b><small>' || r.currency_code || '</small></div>'
        || '<svg viewBox="0 0 100 30" preserveAspectRatio="none"><polyline points="' || l_pts || '" fill="none" stroke="var(--w-mint)" stroke-width="2" vector-effect="non-scaling-stroke"/></svg>'
        || '<div style="text-align:left"><b>1 د.أ = ' || TO_CHAR(r.per_jod, 'FM990D000', 'NLS_NUMERIC_CHARACTERS=''.,''') || ' ' || r.symbol
        || '</b><small>' || TO_CHAR(r.updated_at, 'DD/MM HH24:MI') || '</small></div></div>';
    END LOOP;

    l_h := l_h || '<div class="w-sec" style="margin-top:20px"><h2>حوّل بين العملات</h2></div>'
      || '<div class="f-ex"><label class="w-field" style="margin:0"><span>من</span><select id="xF"><option value="JOD">دينار د.أ</option><option value="USD">دولار $</option><option value="EUR">يورو €</option></select></label>'
      || '<button type="button" id="xSw" title="تبديل">⇄</button>'
      || '<label class="w-field" style="margin:0"><span>إلى</span><select id="xT"><option value="JOD">دينار د.أ</option><option value="USD" selected>دولار $</option><option value="EUR">يورو €</option></select></label></div>'
      || '<label class="w-field"><span>المبلغ</span><input class="w-in ltr" id="xA" inputmode="decimal" placeholder="0.00" style="font-size:22px"></label>'
      || '<div class="f-quote" id="xQ"><small>ستحصل على</small><b id="xOut"></b><small id="xRate"></small></div>'
      || '<div class="w-err" id="xErr"></div><button class="w-btn" id="xGo" type="button" disabled>حوّل الآن</button>'
      || '<div class="w-note">التحويل فوري وبساقين في عملية واحدة: لا يُخصم مبلغ دون أن يصل الآخر. هامش الصرافة 0.5% ظاهر في السعر قبل التأكيد.</div></div>'
      || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)},t,last=null,idem=W.uuid();W.num($('xA'));
  var sym={JOD:'د.أ',USD:'$',EUR:'€'};
  function q(){clearTimeout(t);last=null;$('xGo').disabled=true;W.err('xErr');var a=parseFloat($('xA').value),f=$('xF').value,to=$('xT').value;
    if(!(a>0)||f===to){$('xQ').classList.remove('on');if(f===to)W.err('xErr','اختر عملتين مختلفتين');return}
    t=setTimeout(function(){M('quote',{x02:f,x03:to,x04:$('xA').value}).then(function(r){if(!r.ok){W.err('xErr',r.msg);$('xQ').classList.remove('on');return}
      last=r;$('xOut').textContent=r.out+' '+sym[to];$('xRate').textContent=r.rate;$('xQ').classList.add('on');$('xGo').disabled=false})},300)}
  ['xF','xT'].forEach(function(i){$(i).addEventListener('change',q)});$('xA').addEventListener('input',q);
  $('xSw').onclick=function(){var f=$('xF').value;$('xF').value=$('xT').value;$('xT').value=f;q()};
  $('xGo').onclick=function(){if(!last)return;var f=$('xF').value,to=$('xT').value,a=$('xA').value;
    W.confirm('تحويل عملة',[['تدفع',a+' '+sym[f]],['السعر',last.rate],['تستلم',last.out+' '+sym[to],1]],'حوّل الآن',function(){
      M('fx',{x02:f,x03:to,x04:a,x05:idem}).then(function(r){if(!r.ok){W.fail('xErr',r);idem=W.uuid();return}
        W.sheet('<div class="w-receipt"><div class="w-check"><svg viewBox="0 0 24 24"><path d="M5 12.5 10 17 19 7"/></svg></div><h3>تمّ التحويل 💱</h3>'
          +'<div class="big">'+r.out+' <small style="font-size:14px">'+sym[to]+'</small></div><div class="w-ref">'+r.ref+'</div>'
          +'<a class="w-btn" style="display:block;text-decoration:none;text-align:center;margin-top:16px" href="'+location.href+'">تمّ</a></div>');W.busy=true})})};
})();
</script>~';
    RETURN l_h;
  END render_fx;

  -- -----------------------------------------------------------------
  -- 20) النقاط والكاش باك
  -- -----------------------------------------------------------------
  FUNCTION render_points RETURN CLOB IS
    l     wlt_v_wallets%ROWTYPE := me;
    l_h   CLOB;
    l_pts NUMBER;
    l_e90 NUMBER;
    l_lvl VARCHAR2(10);
    l_nxt NUMBER;
    l_n   PLS_INTEGER := 0;
    l_cb  NUMBER;
  BEGIN
    wallet_save_pkg.process_wallet(l.wallet_id);
    l_pts := wallet_reward_pkg.balance_of(l.user_id);
    l_e90 := wallet_reward_pkg.earned_90(l.user_id);
    l_lvl := wallet_reward_pkg.level_of(l.user_id);
    l_nxt := CASE l_lvl WHEN 'BRONZE' THEN 50 WHEN 'SILVER' THEN 200 END;
    SELECT NVL(SUM(t.amount), 0) INTO l_cb FROM wlt_transactions t
     WHERE t.to_wallet_id = l.wallet_id AND t.txn_type = 'CASHBACK' AND t.status = 'COMPLETED';

    l_h := wallet_ui2_pkg.common || css || js_api || '<div class="w-app">'
      || head('النقاط والكاش باك', 'كل دينار تدفعه لتاجر أو فاتورة = نقطة')
      || '<div class="m-hero"><span class="m-ic">🏆</span><span class="p-lvl ' || l_lvl || '">'
      || CASE l_lvl WHEN 'GOLD' THEN '★ ذهبي · ×1.5' WHEN 'SILVER' THEN '◆ فضي · ×1.25' ELSE '● برونزي · ×1' END || '</span>'
      || '<span class="big">' || l_pts || ' <small style="font-size:14px">نقطة</small></span>'
      || '<div class="row"><span>تساوي ' || money(TRUNC(l_pts / 100)) || ' د.أ</span><span>كاش باك حصلت عليه ' || money(l_cb) || ' د.أ</span></div>'
      || CASE WHEN l_nxt IS NOT NULL THEN '<div class="p-prog"><span data-w="' || LEAST(100, ROUND(l_e90 / l_nxt * 100)) || '"></span></div><small>'
             || (l_nxt - l_e90) || ' نقطة خلال 90 يوماً لتصل للمستوى ' || CASE l_lvl WHEN 'BRONZE' THEN 'الفضي' ELSE 'الذهبي' END || '</small>'
              ELSE '<small style="display:block;margin-top:8px">أعلى مستوى ✨ نقاطك تتضاعف ×1.5</small>' END
      || '</div><div class="w-sec"><h2>استبدل برصيد</h2><span>100 نقطة = 1 د.أ</span></div><div class="p-red">';
    FOR r IN (SELECT COLUMN_VALUE p FROM TABLE(sys.odcinumberlist(100, 500, 1000))) LOOP
      l_h := l_h || '<button type="button" data-r="' || r.p || '"' || CASE WHEN r.p > l_pts THEN ' disabled' END || '><b>' || r.p
        || '</b><small>+' || money(r.p / 100) || ' د.أ</small></button>';
    END LOOP;
    l_h := l_h || '</div><div class="w-err" id="rErr"></div><div class="w-sec"><h2>عروض الكاش باك</h2><span>يُضاف لرصيدك فوراً</span></div>';
    FOR o IN (SELECT o.*, w.shown_name, m.merchant_code FROM wlt_cashback_offers o
                JOIN wlt_v_wallets w ON w.user_id = o.merchant_user_id AND w.wallet_type = 'MAIN'
                JOIN wlt_merchant_profiles m ON m.user_id = o.merchant_user_id
               WHERE o.is_active = 'Y' AND SYSDATE BETWEEN o.starts_at AND o.ends_at + 1 ORDER BY o.pct DESC) LOOP
      l_h := l_h || '<div class="p-off"><div class="pct">' || o.pct || '%</div><div><b>' || esc(o.title) || '</b><small>' || esc(o.shown_name)
        || ' · ' || o.merchant_code || ' · حتى ' || money(o.max_amount) || ' د.أ للعملية · باقي ' || TRUNC(o.ends_at - SYSDATE) || ' يوم</small></div></div>';
    END LOOP;
    l_h := l_h || '<div class="w-sec" style="margin-top:18px"><h2>سجل النقاط</h2></div><div class="p-hist">';
    FOR p IN (SELECT * FROM wlt_points_ledger WHERE user_id = l.user_id ORDER BY created_at DESC FETCH FIRST 10 ROWS ONLY) LOOP
      l_n := l_n + 1;
      l_h := l_h || '<div><span>' || esc(NVL(p.note, CASE p.reason WHEN 'REDEEM' THEN 'استبدال' ELSE 'نقاط' END)) || '<small>' || TO_CHAR(p.created_at, 'DD/MM HH24:MI')
        || '</small></span><b class="' || CASE WHEN p.points > 0 THEN 'plus">+' ELSE 'minus">' END || p.points || '</b></div>';
    END LOOP;
    IF l_n = 0 THEN l_h := l_h || '<div class="w-empty" style="display:block">ادفع لأي تاجر أو فاتورة وتبدأ نقاطك 🌱</div>'; END IF;
    RETURN l_h || '</div></div>' || q'~<script>
(function(){
  setTimeout(function(){document.querySelectorAll('.p-prog span').forEach(function(s){s.style.width=s.dataset.w+'%'})},150);
  document.querySelectorAll('[data-r]').forEach(function(b){b.onclick=function(){var idem=W.uuid(),p=b.dataset.r;
    W.confirm('استبدال النقاط',[['النقاط',p],['يُضاف لرصيدك',(p/100).toFixed(3)+' د.أ',1]],'استبدل الآن',function(){
      M('redeem',{x02:p,x03:idem}).then(function(r){r.ok?Mreceipt(r,'أُضيف لرصيدك 🎁',p+' نقطة'):W.fail('rErr',r)})})}});
})();
</script>~';
  END render_points;

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
    apex_json.write('fee', '0.000');
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
    u    VARCHAR2(20)   := v('APP_USER');
    l_s  VARCHAR2(400);
    l_n  NUMBER;
    l_r1 NUMBER; l_r2 NUMBER;
    l_d  NUMBER;
    l_msg VARCHAR2(4000);
    FUNCTION num (p VARCHAR2) RETURN NUMBER IS
    BEGIN RETURN TO_NUMBER(p, '999999990D999', 'NLS_NUMERIC_CHARACTERS=''.,'''); END;
    PROCEDURE ok IS BEGIN apex_json.open_object; apex_json.write('ok', TRUE); END;
  BEGIN
    CASE a
      WHEN 'who' THEN
        BEGIN
          SELECT shown_name INTO l_s FROM wlt_v_wallets
           WHERE phone = wallet_otp_pkg.normalize_phone(x2) AND wallet_type = 'MAIN' AND currency_code = 'JOD'
             AND user_type IN ('CUSTOMER','MERCHANT','AGENT') AND phone <> u;
        EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20170, 'الرقم غير مسجّل في المحفظة');
        END;
        ok; apex_json.write('name', l_s); apex_json.close_object;
      WHEN 'deal'    THEN l_s := wallet_escrow_pkg.create_deal(u, x2, num(x3), x4); ok; apex_json.write('code', l_s); apex_json.close_object;
      WHEN 'ship'    THEN wallet_escrow_pkg.mark_shipped(u, TO_NUMBER(x2)); ok; apex_json.close_object;
      WHEN 'confirm' THEN receipt(wallet_escrow_pkg.confirm(u, TO_NUMBER(x2)));
      WHEN 'cancel'  THEN wallet_escrow_pkg.cancel(u, TO_NUMBER(x2)); ok; apex_json.close_object;
      WHEN 'dispute' THEN wallet_escrow_pkg.dispute(u, TO_NUMBER(x2), x3); ok; apex_json.close_object;
      WHEN 'buy'     THEN receipt(wallet_bnpl_pkg.purchase(u, x2, num(x3), TO_NUMBER(x4), x5));
      WHEN 'paynext' THEN receipt(wallet_bnpl_pkg.pay_next(u, TO_NUMBER(x2)));
      WHEN 'quote'   THEN
        l_n := wallet_fx_pkg.quote(x2, x3, num(x4));
        SELECT per_jod INTO l_r1 FROM wlt_fx_rates WHERE currency_code = x2;
        SELECT per_jod INTO l_r2 FROM wlt_fx_rates WHERE currency_code = x3;
        SELECT decimals INTO l_d FROM wlt_currencies WHERE currency_code = x3;
        ok; apex_json.write('out', money(l_n, l_d));
        apex_json.write('rate', '1 ' || x2 || ' = ' || TO_CHAR(l_r2 / l_r1 * 0.995, 'FM990D0000', 'NLS_NUMERIC_CHARACTERS=''.,''') || ' ' || x3 || ' (شامل الهامش)');
        apex_json.close_object;
      WHEN 'fx' THEN
        l_s := wallet_fx_pkg.exchange(u, x2, x3, num(x4), x5);
        SELECT t2.amount, c.decimals INTO l_n, l_d FROM wlt_transactions t1
          JOIN wlt_transactions t2 ON t2.idempotency_key = REPLACE(t1.idempotency_key, '-A', '-B')
          JOIN wlt_wallets w ON w.wallet_id = t2.to_wallet_id JOIN wlt_currencies c ON c.currency_code = w.currency_code
         WHERE t1.txn_ref = l_s;
        ok; apex_json.write('ref', l_s); apex_json.write('out', money(l_n, l_d)); apex_json.close_object;
      WHEN 'redeem' THEN receipt(wallet_reward_pkg.redeem(u, TO_NUMBER(x2), x3));
      ELSE RAISE_APPLICATION_ERROR(-20199, 'عملية غير معروفة');
    END CASE;
  EXCEPTION WHEN OTHERS THEN
    l_msg := CASE WHEN SQLCODE BETWEEN -20999 AND -20000
                  THEN REGEXP_REPLACE(REGEXP_SUBSTR(SQLERRM, '^[^' || CHR(10) || ']+'), '^ORA-\d+: ', '')
                  WHEN SQLCODE IN (-6502, -1722) THEN 'تحقق من القيم المدخلة'
                  ELSE 'حدث خطأ غير متوقع. لم يُخصم أي مبلغ.' END;
    apex_json.open_object;
    apex_json.write('ok', FALSE);
    apex_json.write('msg', l_msg);
    apex_json.close_object;
  END api;

END wallet_ui6_pkg;
/

BEGIN
  wwv_flow_imp.import_begin(
    p_version_yyyy_mm_dd   => '2026.04.07',
    p_release              => '26.2.0',
    p_default_workspace_id => 33112972745115671678,
    p_default_application_id => 179352,
    p_default_id_offset    => 0,
    p_default_owner        => 'WKSP_MOHAMMADAPEX');
  FOR p IN (SELECT 17 id, 'Escrow' n, 'ESCROW' al, 'الضمان' t, 'render_escrow' f FROM dual
            UNION ALL SELECT 18, 'Pay Later', 'PAYLATER', 'ادفع لاحقاً', 'render_bnpl' FROM dual
            UNION ALL SELECT 19, 'Currencies', 'FX', 'العملات', 'render_fx' FROM dual
            UNION ALL SELECT 20, 'Points', 'POINTS', 'النقاط', 'render_points' FROM dual) LOOP
    wwv_flow_imp_page.create_page(p_id => p.id, p_name => p.n, p_alias => p.al,
      p_step_title => p.t, p_autocomplete_on_off => 'OFF', p_step_template => 2982503008768810240,
      p_page_template_options => '#DEFAULT#', p_protection_level => 'C', p_page_component_map => '25');
    wwv_flow_imp_page.create_page_plug(p_id => wwv_flow_imp.id(9080000000000000000 + p.id * 10), p_plug_name => 'WLT ' || p.n,
      p_static_id => 'wlt-' || LOWER(p.al), p_region_template_options => '#DEFAULT#', p_plug_template => 3374665444246510938,
      p_plug_display_sequence => 10, p_function_body_language => 'PLSQL',
      p_plug_source => 'return wallet_ui6_pkg.' || p.f || ';', p_plug_source_type => 'NATIVE_DYNAMIC_CONTENT');
  END LOOP;
  wwv_flow_imp_shared.create_flow_process(p_id => wwv_flow_imp.id(9080000000000000300),
    p_process_sequence => 1, p_process_point => 'ON_DEMAND', p_process_type => 'NATIVE_PLSQL',
    p_process_name => 'WLT_MONEY', p_process_sql_clob => 'wallet_ui6_pkg.api;', p_process_clob_language => 'PLSQL',
    p_security_scheme => 'MUST_NOT_BE_PUBLIC_USER');
  wwv_flow_imp.import_end(p_auto_install_sup_obj => FALSE);
  COMMIT;
END;
/

-- قائمة «المزيد»: 4 أعمدة، أيقونة فوق النص، وإضافة خدمات الجلسة 8 (الإشعارات لها جرس في الأعلى)
DECLARE
  l CLOB;
  c_fam CONSTANT VARCHAR2(300) := q'#'<a href="' || apex_page.get_url(p_page => 16) || '"><span>👨‍👩‍👧</span>العائلة</a>'#';
BEGIN
  FOR r IN (SELECT text FROM user_source WHERE name = 'WALLET_UI3_PKG' AND type = 'PACKAGE BODY' ORDER BY line) LOOP
    l := l || r.text;
  END LOOP;
  IF INSTR(l, 'p_page => 17') = 0 THEN
    IF INSTR(l, c_fam) = 0 THEN RAISE_APPLICATION_ERROR(-20000, 'menu anchor'); END IF;
    l := REPLACE(l, 'grid-template-columns:repeat(3,1fr);gap:10px;margin:-8px 0 22px', 'grid-template-columns:repeat(4,1fr);gap:8px;margin:-8px 0 22px');
    l := REPLACE(l, '.w-more a{display:flex;align-items:center;gap:8px;justify-content:center;',
                    '.w-more a{display:flex;flex-direction:column;align-items:center;gap:3px;justify-content:center;text-align:center;line-height:1.3;');
    l := REPLACE(l, '.w-more span{font-size:16px}', '.w-more span{font-size:21px}');
    l := REPLACE(l, c_fam, c_fam || CHR(10)
      || q'#      || '<a href="' || apex_page.get_url(p_page => 17) || '"><span>🛡️</span>الضمان</a>'#' || CHR(10)
      || q'#      || '<a href="' || apex_page.get_url(p_page => 18) || '"><span>🛍️</span>ادفع لاحقاً</a>'#' || CHR(10)
      || q'#      || '<a href="' || apex_page.get_url(p_page => 19) || '"><span>💱</span>العملات</a>'#' || CHR(10)
      || q'#      || '<a href="' || apex_page.get_url(p_page => 20) || '"><span>🏆</span>النقاط</a>'#');
    l := REGEXP_REPLACE(l, '\|\|\s*''<a href="''\s*\|\|\s*apex_page\.get_url\(p_page\s*=>\s*11\)\s*\|\|\s*''"><span>[^<]*</span>[^<]*</a>''', '');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE ' || l;
  END IF;
END;
/
