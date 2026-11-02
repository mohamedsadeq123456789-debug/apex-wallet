-- =====================================================================
--  محفظتي · الجلسة 6 · شاشات الجمعية (12) والعيدية (13)
-- =====================================================================
CREATE OR REPLACE PACKAGE wallet_ui4_pkg AS
  FUNCTION render_jamiya RETURN CLOB;
  FUNCTION render_eidiya RETURN CLOB;
  PROCEDURE api;
END wallet_ui4_pkg;
/

CREATE OR REPLACE PACKAGE BODY wallet_ui4_pkg AS

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
.w-pill{display:inline-block;font-size:11px;font-weight:600;border-radius:999px;padding:1px 9px;background:var(--w-rule);color:var(--w-ink)}
.w-pill.active{background:#fdf1d6;color:#8a6110}.w-pill.done{background:var(--w-mint-s);color:var(--w-mint)}.w-pill.expired{background:var(--w-red-s);color:var(--w-red)}
.w-card2{border:1px solid var(--w-rule);background:var(--w-paper);border-radius:18px;padding:14px;margin-bottom:10px;animation:w-in .35s both}
.w-card2 .t{display:flex;justify-content:space-between;align-items:flex-start;gap:10px}
.w-card2 .amt{font-family:var(--w-mono);font-weight:700;font-size:18px;direction:ltr;white-space:nowrap}
.w-card2 small{display:block;color:var(--w-muted);font-size:12px;margin-top:2px}
.w-card2 .acts{display:flex;gap:8px;margin-top:12px}
.w-card2 .acts button{flex:1;border-radius:12px;padding:10px;font-family:var(--w-disp);font-weight:600;font-size:14px;cursor:pointer;border:1.5px solid var(--w-rule);background:var(--w-paper);color:var(--w-ink)}
.w-prog{height:8px;border-radius:4px;background:var(--w-rule);overflow:hidden;margin:6px 0 8px}
.w-prog span{display:block;height:100%;background:linear-gradient(90deg,var(--w-mint),#2fae8e);border-radius:4px}
.w-preview{background:var(--w-g8);color:#f3efe2;border-radius:16px;padding:12px 16px;margin:6px 0 14px;font-size:13px;display:flex;justify-content:space-between;align-items:center}
.w-preview b{font-family:var(--w-mono);color:var(--w-gold);font-size:18px}
.w-row2{display:flex;gap:8px}.w-row2 .w-in{flex:1}
.j-card{border-radius:22px;overflow:hidden;border:1px solid var(--w-rule);background:var(--w-paper);margin-bottom:14px;animation:w-in .4s both}
.j-top{background:linear-gradient(135deg,var(--w-g9),var(--w-g7));color:#f3efe2;padding:16px 18px;position:relative}
.j-top h3{font-family:var(--w-disp);font-size:18px;margin:0}
.j-top small{opacity:.75;font-size:12px}
.j-top .pot{position:absolute;left:18px;top:14px;text-align:left}
.j-top .pot b{display:block;font-family:var(--w-mono);font-size:20px;color:var(--w-gold);direction:ltr}
.j-body{padding:14px 16px}
.j-code{display:flex;align-items:center;justify-content:space-between;gap:10px;background:var(--w-mint-s);border:1.5px dashed var(--w-mint);border-radius:16px;padding:12px 14px;margin-bottom:12px}
.j-code b{font-family:var(--w-mono);font-size:26px;letter-spacing:.18em;color:var(--w-g8);direction:ltr}
.j-code button{border:0;background:var(--w-mint);color:#fff;border-radius:10px;padding:8px 14px;font-family:var(--w-body);cursor:pointer}
.j-wheel{display:flex;gap:6px;overflow-x:auto;padding:4px 0 10px;scrollbar-width:thin}
.j-turn{flex:none;width:84px;border-radius:14px;border:1.5px solid var(--w-rule);padding:8px 6px;text-align:center;font-size:11.5px;background:#fff}
.j-turn i{display:block;font-style:normal;font-family:var(--w-mono);font-size:18px;font-weight:700;color:var(--w-muted)}
.j-turn.done{background:var(--w-mint-s);border-color:var(--w-mint)}.j-turn.done i{color:var(--w-mint)}
.j-turn.now{border-color:var(--w-gold-d);box-shadow:0 0 0 3px rgba(233,197,111,.35)}.j-turn.now i{color:var(--w-gold-d)}
.j-turn.me{background:#fff8e6}
.j-turn span{display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.j-members{display:flex;flex-wrap:wrap;gap:6px;margin:8px 0 12px}
.j-members span{background:var(--w-bg);border:1px solid var(--w-rule);border-radius:999px;padding:3px 10px;font-size:12.5px}
.j-members span.paid{background:var(--w-mint-s);border-color:var(--w-mint);color:var(--w-g8)}
.e-env{position:relative;margin:6px auto 16px;width:min(300px,100%);aspect-ratio:1.45;border-radius:18px;overflow:hidden;box-shadow:0 22px 40px -18px rgba(0,0,0,.4);color:#fff;display:grid;place-items:center;text-align:center;padding:20px}
.e-env.EID{background:linear-gradient(150deg,#0f3a33,#1d6b5a)}.e-env.GRAD{background:linear-gradient(150deg,#1f2a5a,#3d55a8)}.e-env.BDAY{background:linear-gradient(150deg,#7a1f4a,#c8487a)}
.e-env::before{content:"";position:absolute;inset:0 0 52% 0;background:rgba(255,255,255,.08);clip-path:polygon(0 0,100% 0,50% 100%)}
.e-env .seal{position:absolute;top:34%;left:50%;transform:translate(-50%,-50%);width:58px;height:58px;border-radius:50%;background:radial-gradient(circle at 35% 30%,#f6e2a8,#b8861b);display:grid;place-items:center;font-size:26px;box-shadow:0 6px 14px rgba(0,0,0,.3);transition:transform .5s}
.e-env .txt{position:relative;margin-top:58px;font-family:var(--w-disp);font-size:15px;line-height:1.6}
.e-env .amt{font-family:var(--w-mono);font-size:34px;font-weight:700;color:var(--w-gold);direction:ltr;display:none}
.e-env.open .seal{transform:translate(-50%,-140%) scale(.6) rotate(-20deg);opacity:.0;transition:transform .6s,opacity .6s}
.e-env.open .amt{display:block;animation:w-pop .5s .2s both}
.e-confetti{position:fixed;inset:0;pointer-events:none;z-index:1000}
.e-confetti i{position:absolute;top:-10px;width:8px;height:14px;border-radius:2px;animation:e-fall linear forwards}
@keyframes e-fall{to{transform:translateY(110vh) rotate(720deg)}}
.e-themes{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-bottom:14px}
.e-themes button{border:2px solid transparent;border-radius:14px;padding:12px 6px;color:#fff;font-family:var(--w-body);font-weight:600;cursor:pointer}
.e-themes button.on{border-color:var(--w-gold);box-shadow:0 0 0 3px rgba(233,197,111,.35)}
.e-claims{display:grid;gap:4px;margin-top:8px}
.e-claims div{display:flex;justify-content:space-between;font-size:13px;padding:6px 0;border-top:1px dashed var(--w-rule)}
.e-claims b{font-family:var(--w-mono);direction:ltr}
.e-luck{font-size:10.5px;background:var(--w-gold);color:#3a2a00;border-radius:999px;padding:1px 7px;margin-inline-start:6px}
</style>~';
  END css;

  -- -----------------------------------------------------------------
  -- 12) الجمعية
  -- -----------------------------------------------------------------
  FUNCTION render_jamiya RETURN CLOB IS
    l     wlt_v_wallets%ROWTYPE := me;
    l_h   CLOB;
    l_n   PLS_INTEGER := 0;
    l_cnt NUMBER;
    l_paid NUMBER;
    l_mine NUMBER;
  BEGIN
    l_h := wallet_ui2_pkg.common || css || '<div class="w-app">'
      || head('الجمعية', 'جمعية بين الأصحاب، المحفظة تجمع الأقساط وتسلّم الدور')
      || '<div class="w-tabs"><button type="button" class="on" data-p="pMine">جمعياتي</button><button type="button" data-p="pNew">جمعية جديدة</button><button type="button" data-p="pJoin">انضم بكود</button></div>'
      || '<section class="w-pane on" id="pMine">';

    FOR j IN (SELECT jm.*, o.shown_name AS owner_name,
                     (SELECT COUNT(*) FROM wlt_jamiya_members x WHERE x.jam_id = jm.jam_id) AS joined
                FROM wlt_jamiyas jm JOIN wlt_v_wallets o ON o.user_id = jm.owner_user_id AND o.wallet_type = 'MAIN'
               WHERE jm.jam_id IN (SELECT jam_id FROM wlt_jamiya_members WHERE user_id = l.user_id)
                 AND jm.status <> 'CANCELLED'
               ORDER BY CASE jm.status WHEN 'ACTIVE' THEN 1 WHEN 'FORMING' THEN 2 ELSE 3 END, jm.created_at DESC) LOOP
      l_n := l_n + 1;
      l_cnt := CASE WHEN j.status = 'FORMING' THEN j.joined ELSE j.members_target END;
      l_h := l_h || '<div class="j-card"><div class="j-top"><h3>' || esc(j.name) || '</h3><small>'
        || CASE j.frequency WHEN 'WEEKLY' THEN 'أسبوعية' ELSE 'شهرية' END || ' · القسط ' || money(j.installment)
        || ' · ' || l_cnt || ' أعضاء · المنظّم ' || esc(j.owner_name) || '</small>'
        || '<div class="pot"><small>كل دور يستلم</small><b>' || money(j.installment * l_cnt) || '</b></div></div><div class="j-body">';

      IF j.status = 'FORMING' THEN
        l_h := l_h || '<div class="j-code"><div><small class="w-sub" style="margin:0">كود الدعوة · ' || j.joined || ' من ' || j.members_target || '</small><b>'
          || j.invite_code || '</b></div><button type="button" data-copy="' || j.invite_code || '">نسخ</button></div><div class="j-members">';
        FOR m IN (SELECT u.shown_name FROM wlt_jamiya_members mm JOIN wlt_v_wallets u ON u.user_id = mm.user_id AND u.wallet_type = 'MAIN'
                   WHERE mm.jam_id = j.jam_id ORDER BY mm.joined_at) LOOP
          l_h := l_h || '<span>' || esc(m.shown_name) || '</span>';
        END LOOP;
        l_h := l_h || '</div>'
          || CASE WHEN j.owner_user_id = l.user_id THEN
               '<button class="w-btn" type="button" data-start="' || j.jam_id || '"' || CASE WHEN j.joined < 2 THEN ' disabled' END
               || '>🎲 القرعة وابدأ الجمعية (' || j.joined || ' أعضاء)</button>'
             ELSE '<div class="w-note" style="margin:0">بانتظار المنظّم ليبدأ الجمعية</div>' END;
      ELSE
        SELECT COUNT(*) INTO l_paid FROM wlt_jamiya_payments WHERE jam_id = j.jam_id AND round_no = j.current_round;
        SELECT COUNT(*) INTO l_mine FROM wlt_jamiya_payments WHERE jam_id = j.jam_id AND round_no = j.current_round AND user_id = l.user_id;
        l_h := l_h || '<div class="j-wheel">';
        FOR r IN (SELECT r.*, u.shown_name FROM wlt_jamiya_rounds r JOIN wlt_v_wallets u ON u.user_id = r.receiver_user_id AND u.wallet_type = 'MAIN'
                   WHERE r.jam_id = j.jam_id ORDER BY r.round_no) LOOP
          l_h := l_h || '<div class="j-turn' || CASE WHEN r.status = 'PAID_OUT' THEN ' done' END
            || CASE WHEN r.round_no = j.current_round AND j.status = 'ACTIVE' THEN ' now' END
            || CASE WHEN r.receiver_user_id = l.user_id THEN ' me' END || '"><i>' || r.round_no || '</i><span>'
            || CASE WHEN r.receiver_user_id = l.user_id THEN 'أنت' ELSE esc(r.shown_name) END || '</span><span>'
            || TO_CHAR(r.due_date, 'DD/MM') || '</span></div>';
        END LOOP;
        l_h := l_h || '</div>';
        IF j.status = 'COMPLETED' THEN
          l_h := l_h || '<div class="w-note" style="margin:0">🎉 اكتملت الجمعية واستلم كل الأعضاء أدوارهم</div>';
        ELSE
          l_h := l_h || '<div class="w-sub" style="margin:0 0 6px">الدور ' || j.current_round || ': دفع ' || l_paid || ' من ' || j.members_target || '</div>'
            || '<div class="w-prog"><span style="width:' || ROUND(l_paid / j.members_target * 100) || '%"></span></div><div class="j-members">';
          FOR m IN (SELECT u.shown_name, mm.user_id,
                           (SELECT COUNT(*) FROM wlt_jamiya_payments p WHERE p.jam_id = j.jam_id AND p.round_no = j.current_round AND p.user_id = mm.user_id) AS paid
                      FROM wlt_jamiya_members mm JOIN wlt_v_wallets u ON u.user_id = mm.user_id AND u.wallet_type = 'MAIN'
                     WHERE mm.jam_id = j.jam_id ORDER BY mm.turn_no) LOOP
            l_h := l_h || '<span' || CASE WHEN m.paid > 0 THEN ' class="paid"' END || '>' || CASE WHEN m.paid > 0 THEN '✓ ' END
              || CASE WHEN m.user_id = l.user_id THEN 'أنت' ELSE esc(m.shown_name) END || '</span>';
          END LOOP;
          l_h := l_h || '</div>'
            || CASE WHEN l_mine = 0 THEN '<button class="w-btn" type="button" data-pay="' || j.jam_id || '" data-a="' || money(j.installment)
                    || '" data-n="' || esc(j.name) || '">ادفع قسط الدور ' || j.current_round || ' · ' || money(j.installment) || ' د.أ</button>'
                    ELSE '<div class="w-note" style="margin:0">✓ دفعت قسط هذا الدور. يُخصم القسط تلقائياً في موعد كل دور.</div>' END;
        END IF;
      END IF;
      l_h := l_h || '</div></div>';
    END LOOP;
    IF l_n = 0 THEN l_h := l_h || '<div class="w-empty">لست في أي جمعية بعد. أنشئ واحدة أو انضم بكود.</div>'; END IF;
    l_h := l_h || '<div class="w-err" id="jErr"></div></section>'

      || '<section class="w-pane" id="pNew">'
      || '<label class="w-field"><span>اسم الجمعية</span><input class="w-in" id="jName" maxlength="80" placeholder="مثلاً: جمعية الشلة"></label>'
      || '<div class="w-row2" style="margin-bottom:14px"><label class="w-field" style="flex:1;margin:0"><span>القسط (د.أ)</span><input class="w-in ltr" id="jAmt" inputmode="decimal" placeholder="100"></label>'
      || '<label class="w-field" style="width:120px;margin:0"><span>عدد الأعضاء</span><input class="w-in ltr" id="jCnt" inputmode="numeric" placeholder="10"></label></div>'
      || '<div class="w-grid" id="jFreq" style="grid-template-columns:1fr 1fr"><button class="w-tile on" type="button" data-f="MONTHLY">شهرية</button><button class="w-tile" type="button" data-f="WEEKLY">أسبوعية</button></div>'
      || '<label class="w-field"><span>تاريخ أول دور</span><input class="w-in ltr" id="jStart" type="date"></label>'
      || '<div class="w-preview" id="jPrev" style="display:none"><span>كل عضو يستلم مرة واحدة</span><b id="jPot"></b></div>'
      || '<div class="w-err" id="jErr2"></div><button class="w-btn" id="jGo" type="button" disabled>أنشئ الجمعية</button>'
      || '<div class="w-note">الأقساط تُجمع في حساب ضمان داخل المحفظة، لا عند المنظّم. عندما يدفع الجميع يُحوَّل المبلغ لصاحب الدور فوراً. ترتيب الأدوار بقرعة عشوائية عند البدء.</div></section>'

      || '<section class="w-pane" id="pJoin">'
      || '<label class="w-field"><span>كود الدعوة</span><input class="w-in ltr" id="jCode" maxlength="6" placeholder="JXXXXX" style="font-size:26px;text-align:center;letter-spacing:.2em;text-transform:uppercase"></label>'
      || '<div class="w-err" id="jErr3"></div><button class="w-btn" id="jJoin" type="button" disabled>انضم</button></section></div>'

      || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)};W.tabs();
  var freq='MONTHLY',d=new Date();d.setDate(d.getDate()+1);$('jStart').value=d.toISOString().slice(0,10);
  function J(a,x){var p={x01:a};Object.keys(x).forEach(function(k){p[k]=String(x[k])});
    return new Promise(function(res){apex.server.process('WLT_CIRCLE',p,{success:res,error:function(){res({ok:false,msg:'تعذّر الاتصال'})}})})}
  function v(){var a=parseFloat($('jAmt').value),n=parseInt($('jCnt').value,10);
    if(a>0&&n>=2){$('jPrev').style.display='flex';$('jPot').textContent=(a*n).toFixed(3)+' د.أ'}else $('jPrev').style.display='none';
    $('jGo').disabled=!(a>0&&n>=2&&n<=24&&$('jName').value.trim())}
  ['jAmt','jCnt','jName'].forEach(function(i){$(i).addEventListener('input',function(){W.err('jErr2');v()})});
  document.querySelectorAll('#jFreq .w-tile').forEach(function(b){b.onclick=function(){document.querySelectorAll('#jFreq .w-tile').forEach(function(x){x.classList.toggle('on',x===b)});freq=b.dataset.f}});
  $('jGo').onclick=function(){var b=this;b.disabled=true;
    J('create',{x02:$('jName').value,x03:Number($('jAmt').value).toFixed(3),x04:$('jCnt').value,x05:freq,x06:$('jStart').value}).then(function(r){
      if(r.ok)location.reload();else{b.disabled=false;W.err('jErr2',r.msg)}})};
  $('jCode').addEventListener('input',function(){this.value=this.value.toUpperCase().replace(/[^A-Z0-9]/g,'');W.err('jErr3');$('jJoin').disabled=this.value.length!==6});
  $('jJoin').onclick=function(){var b=this;b.disabled=true;J('join',{x02:$('jCode').value}).then(function(r){if(r.ok)location.reload();else{b.disabled=false;W.err('jErr3',r.msg)}})};
  document.querySelectorAll('[data-copy]').forEach(function(b){b.onclick=function(){try{navigator.clipboard.writeText(b.dataset.copy).then(function(){b.textContent='✓'})}catch(e){}}});
  document.querySelectorAll('[data-start]').forEach(function(b){b.onclick=function(){b.disabled=true;b.textContent='🎲 جارٍ القرعة…';
    J('start',{x02:b.dataset.start}).then(function(r){if(r.ok)location.reload();else{b.disabled=false;W.err('jErr',r.msg)}})}});
  document.querySelectorAll('[data-pay]').forEach(function(b){b.onclick=function(){var idem=W.uuid();
    W.confirm('قسط '+b.dataset.n,[['القسط',b.dataset.a+' د.أ',1]],'ادفع القسط',function(){
      J('pay',{x02:b.dataset.pay,x03:idem}).then(function(r){r.ok?W.receipt(r,'تمّ دفع القسط',b.dataset.n):W.fail('jErr',r)})})}});
})();
</script>~';
    RETURN l_h;
  END render_jamiya;

  -- -----------------------------------------------------------------
  -- 13) العيدية
  -- -----------------------------------------------------------------
  FUNCTION render_eidiya RETURN CLOB IS
    l    wlt_v_wallets%ROWTYPE := me;
    l_h  CLOB;
    l_n  PLS_INTEGER := 0;
    l_max NUMBER;
  BEGIN
    l_h := wallet_ui2_pkg.common || css || '<div class="w-app">' || head('العيدية', 'ظرف هدية يُقسَّم على أحبابك، بالتساوي أو بالحظ')
      || '<div class="w-tabs"><button type="button" class="on" data-p="pOpen">افتح عيدية</button><button type="button" data-p="pSend">أرسل عيدية</button><button type="button" data-p="pMine">عيدياتي</button></div>'

      || '<section class="w-pane on" id="pOpen"><div class="e-env EID" id="eEnv"><div class="seal">🎁</div><div class="txt" id="eTxt">اكتب كود العيدية وافتح الظرف</div><div class="amt" id="eAmt"></div></div>'
      || '<label class="w-field"><input class="w-in ltr" id="eCode" maxlength="6" placeholder="EXXXXX" style="font-size:26px;text-align:center;letter-spacing:.2em;text-transform:uppercase"></label>'
      || '<div class="w-err" id="eErr"></div><button class="w-btn" id="eOpen" type="button" disabled>افتح الظرف</button></section>'

      || '<section class="w-pane" id="pSend">'
      || '<div class="e-themes" id="eTheme"><button type="button" class="on" data-t="EID" style="background:linear-gradient(150deg,#0f3a33,#1d6b5a)">🌙 عيد</button>'
      || '<button type="button" data-t="GRAD" style="background:linear-gradient(150deg,#1f2a5a,#3d55a8)">🎓 تخرّج</button>'
      || '<button type="button" data-t="BDAY" style="background:linear-gradient(150deg,#7a1f4a,#c8487a)">🎂 عيد ميلاد</button></div>'
      || '<div class="w-row2" style="margin-bottom:14px"><label class="w-field" style="flex:1;margin:0"><span>المبلغ الكلي (د.أ)</span><input class="w-in ltr" id="sTot" inputmode="decimal" placeholder="20"></label>'
      || '<label class="w-field" style="width:120px;margin:0"><span>كم شخص؟</span><input class="w-in ltr" id="sCnt" inputmode="numeric" placeholder="5"></label></div>'
      || '<div class="w-grid" id="sMode" style="grid-template-columns:1fr 1fr"><button class="w-tile on" type="button" data-m="RANDOM"><b>🎲</b>بالحظ</button><button class="w-tile" type="button" data-m="EQUAL"><b>⚖️</b>بالتساوي</button></div>'
      || '<label class="w-field"><span>رسالة</span><input class="w-in" id="sMsg" maxlength="150" placeholder="كل عام وأنتم بخير 🌙"></label>'
      || '<div class="w-err" id="sErr"></div><button class="w-btn" id="sGo" type="button" disabled>جهّز العيدية</button>'
      || '<div class="w-note">المبلغ يُحجز في حساب ضمان. أي حصة لا تُفتح خلال 24 ساعة ترجع لك تلقائياً.</div></section>'

      || '<section class="w-pane" id="pMine">';
    FOR e IN (SELECT e.*, (SELECT COUNT(*) FROM wlt_envelope_shares s WHERE s.env_id = e.env_id AND s.claimed_by IS NOT NULL) AS opened
                FROM wlt_envelopes e WHERE e.sender_user_id = l.user_id ORDER BY e.created_at DESC FETCH FIRST 10 ROWS ONLY) LOOP
      l_n := l_n + 1;
      SELECT MAX(amount) INTO l_max FROM wlt_envelope_shares WHERE env_id = e.env_id AND claimed_by IS NOT NULL;
      l_h := l_h || '<div class="w-card2"><div class="t"><div><b>' || CASE e.theme WHEN 'EID' THEN '🌙' WHEN 'GRAD' THEN '🎓' ELSE '🎂' END
        || ' ' || e.code || '</b><small>' || esc(NVL(e.message, 'عيدية')) || ' · فُتحت ' || e.opened || ' من ' || e.shares
        || ' · ' || CASE e.split_mode WHEN 'RANDOM' THEN 'بالحظ' ELSE 'بالتساوي' END || '</small></div><div style="text-align:left"><div class="amt">'
        || money(e.total_amount) || '</div><span class="w-pill ' || CASE e.status WHEN 'ACTIVE' THEN 'active' WHEN 'FINISHED' THEN 'done' ELSE 'expired' END || '">'
        || CASE e.status WHEN 'ACTIVE' THEN 'مفتوحة' WHEN 'FINISHED' THEN 'اكتملت' ELSE 'استُرجع الباقي' END || '</span></div></div><div class="e-claims">';
      FOR c IN (SELECT s.amount, u.shown_name FROM wlt_envelope_shares s JOIN wlt_v_wallets u ON u.user_id = s.claimed_by AND u.wallet_type = 'MAIN'
                 WHERE s.env_id = e.env_id ORDER BY s.claimed_at) LOOP
        l_h := l_h || '<div><span>' || esc(c.shown_name) || CASE WHEN e.split_mode = 'RANDOM' AND c.amount = l_max AND e.opened > 1 THEN '<span class="e-luck">الأوفر حظاً</span>' END
          || '</span><b>' || money(c.amount) || '</b></div>';
      END LOOP;
      l_h := l_h || '</div>' || CASE WHEN e.status = 'ACTIVE' THEN '<div class="acts"><button type="button" data-share="' || e.code || '">مشاركة الكود</button></div>' END || '</div>';
    END LOOP;
    IF l_n = 0 THEN l_h := l_h || '<div class="w-empty">لم ترسل عيديات بعد</div>'; END IF;

    RETURN l_h || '</section></div>' || q'~<script>
(function(){
  var $=function(i){return document.getElementById(i)};W.tabs();
  function J(a,x){var p={x01:a};Object.keys(x).forEach(function(k){p[k]=String(x[k])});
    return new Promise(function(res){apex.server.process('WLT_CIRCLE',p,{success:res,error:function(){res({ok:false,msg:'تعذّر الاتصال'})}})})}
  function confetti(){var c=document.createElement('div');c.className='e-confetti';var cols=['#e9c56f','#0e7a63','#c8487a','#3d55a8','#fff'];
    for(var i=0;i<70;i++){var x=document.createElement('i');x.style.left=Math.random()*100+'%';x.style.background=cols[i%5];
      x.style.animationDuration=(1.6+Math.random()*1.6)+'s';x.style.animationDelay=(Math.random()*.4)+'s';c.appendChild(x)}
    document.body.appendChild(c);setTimeout(function(){c.remove()},3800)}
  var code=$('eCode'),ob=$('eOpen');
  code.addEventListener('input',function(){code.value=code.value.toUpperCase().replace(/[^A-Z0-9]/g,'');W.err('eErr');ob.disabled=code.value.length!==6});
  ob.onclick=function(){ob.disabled=true;ob.textContent='جارٍ الفتح…';
    J('claim',{x02:code.value,x03:W.uuid()}).then(function(r){ob.textContent='افتح الظرف';
      if(!r.ok){ob.disabled=false;W.err('eErr',r.msg);return}
      var env=$('eEnv');env.className='e-env '+r.theme;$('eTxt').textContent=(r.message||'عيدية')+' · من '+r.from;$('eAmt').textContent=r.amount;
      setTimeout(function(){env.classList.add('open');confetti()},150);
      ob.style.display='none';code.style.display='none'})};
  var theme='EID',mode='RANDOM';
  document.querySelectorAll('#eTheme button').forEach(function(b){b.onclick=function(){document.querySelectorAll('#eTheme button').forEach(function(x){x.classList.toggle('on',x===b)});theme=b.dataset.t}});
  document.querySelectorAll('#sMode .w-tile').forEach(function(b){b.onclick=function(){document.querySelectorAll('#sMode .w-tile').forEach(function(x){x.classList.toggle('on',x===b)});mode=b.dataset.m}});
  function sv(){$('sGo').disabled=!(parseFloat($('sTot').value)>0&&parseInt($('sCnt').value,10)>0)}
  ['sTot','sCnt'].forEach(function(i){$(i).addEventListener('input',function(){W.err('sErr');sv()})});
  function share(c){W.sheet('<div class="w-receipt"><h3>العيدية جاهزة 🎁</h3><div class="j-code" style="justify-content:center"><b>'+c+'</b></div>'
    +'<p class="w-sub">أرسل الكود لمن تحب. يفتحه من «العيدية» ← «افتح عيدية».</p><button class="w-btn" type="button" id="eCp">نسخ الكود</button>'
    +'<div style="height:8px"></div><button class="w-btn ghost" type="button" onclick="location.reload()">تمّ</button></div>');
    $('eCp').onclick=function(){var b=this;try{navigator.clipboard.writeText(c).then(function(){b.textContent='✓ تمّ النسخ'})}catch(e){}}}
  $('sGo').onclick=function(){var t=Number($('sTot').value).toFixed(3),n=$('sCnt').value;
    W.confirm('تأكيد العيدية',[['عدد الأشخاص',n],['التوزيع',mode==='RANDOM'?'بالحظ':'بالتساوي'],['المجموع',t+' د.أ',1]],'جهّز العيدية',function(){
      J('envelope',{x02:t,x03:n,x04:mode,x05:$('sMsg').value,x06:theme}).then(function(r){r.ok?share(r.code):W.fail('sErr',r)})})};
  document.querySelectorAll('[data-share]').forEach(function(b){b.onclick=function(){share(b.dataset.share)}});
  var h=location.hash.replace('#','').toUpperCase();if(/^E[A-Z0-9]{5}$/.test(h)){code.value=h;ob.disabled=false}
})();
</script>~';
  END render_eidiya;

  -- -----------------------------------------------------------------
  PROCEDURE receipt (p_ref VARCHAR2, p_extra BOOLEAN DEFAULT FALSE, p_env_code VARCHAR2 DEFAULT NULL) IS
    l_t wlt_transactions%ROWTYPE;
    l   wlt_v_wallets%ROWTYPE := me;
    l_e wlt_envelopes%ROWTYPE;
    l_from VARCHAR2(200);
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
    IF p_env_code IS NOT NULL THEN
      SELECT * INTO l_e FROM wlt_envelopes WHERE code = p_env_code;
      SELECT shown_name INTO l_from FROM wlt_v_wallets WHERE user_id = l_e.sender_user_id AND wallet_type = 'MAIN';
      apex_json.write('theme', l_e.theme);
      apex_json.write('message', l_e.message);
      apex_json.write('from', l_from);
    END IF;
    apex_json.close_object;
  END receipt;

  PROCEDURE api IS
    a   VARCHAR2(20)   := apex_application.g_x01;
    x2  VARCHAR2(4000) := apex_application.g_x02;
    x3  VARCHAR2(4000) := apex_application.g_x03;
    x4  VARCHAR2(4000) := apex_application.g_x04;
    x5  VARCHAR2(4000) := apex_application.g_x05;
    x6  VARCHAR2(4000) := apex_application.g_x06;
    u   VARCHAR2(20)   := v('APP_USER');
    l_s VARCHAR2(40);
    l_n NUMBER;
    l_msg VARCHAR2(4000);
    FUNCTION num (p VARCHAR2) RETURN NUMBER IS
    BEGIN RETURN TO_NUMBER(p, '999999990D999', 'NLS_NUMERIC_CHARACTERS=''.,'''); END;
  BEGIN
    CASE a
      WHEN 'create' THEN
        l_s := wallet_circle_pkg.create_jamiya(u, x2, num(x3), TO_NUMBER(x4), x5, TO_DATE(x6, 'YYYY-MM-DD'));
      WHEN 'join'   THEN l_n := wallet_circle_pkg.join_jamiya(u, x2);
      WHEN 'start'  THEN wallet_circle_pkg.start_jamiya(u, TO_NUMBER(x2), TRUE);
      WHEN 'pay'    THEN l_s := wallet_circle_pkg.pay_installment(u, TO_NUMBER(x2), x3);
      WHEN 'envelope' THEN l_s := wallet_circle_pkg.create_envelope(u, num(x2), TO_NUMBER(x3), x4, x5, x6);
      WHEN 'claim'  THEN l_s := wallet_circle_pkg.claim_envelope(u, x2, x3);
      ELSE RAISE_APPLICATION_ERROR(-20199, 'عملية غير معروفة');
    END CASE;

    IF a IN ('pay') THEN receipt(l_s);
    ELSIF a = 'claim' THEN receipt(l_s, p_env_code => UPPER(TRIM(x2)));
    ELSE
      apex_json.open_object;
      apex_json.write('ok', TRUE);
      IF a IN ('create','envelope') THEN apex_json.write('code', l_s); END IF;
      apex_json.close_object;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    l_msg := CASE WHEN SQLCODE BETWEEN -20999 AND -20000
                  THEN REGEXP_REPLACE(REGEXP_SUBSTR(SQLERRM, '^[^' || CHR(10) || ']+'), '^ORA-\d+: ', '')
                  WHEN SQLCODE IN (-6502, -1722, -1830, -1843, -1847, -1858) THEN 'تحقق من القيم المدخلة'
                  ELSE 'حدث خطأ غير متوقع. لم يُخصم أي مبلغ.' END;
    apex_json.open_object;
    apex_json.write('ok', FALSE);
    apex_json.write('msg', l_msg);
    apex_json.close_object;
  END api;

END wallet_ui4_pkg;
/
