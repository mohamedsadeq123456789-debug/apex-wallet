-- =====================================================================
--  محفظتي · الواجهة الإنجليزية
--  القاموس في جدول wlt_i18n (يعدّله الفريق بدون لمس الكود)، والمحرك يترجم الصفحة في المتصفح
--  ويلتقط أي نص يظهر لاحقاً (نوافذ، رسائل، نتائج Ajax). لا يُحمَّل للمستخدم العربي إطلاقاً.
-- =====================================================================
CREATE OR REPLACE PACKAGE wallet_i18n_pkg AS
  FUNCTION wants_en RETURN BOOLEAN;
  FUNCTION engine RETURN CLOB;
  FUNCTION prefix RETURN CLOB;
END wallet_i18n_pkg;
/

CREATE OR REPLACE PACKAGE BODY wallet_i18n_pkg AS
  g_js CLOB;

  FUNCTION wants_en RETURN BOOLEAN IS
    c owa_cookie.cookie;
  BEGIN
    c := owa_cookie.get('WLT_LANG');
    RETURN c.num_vals > 0 AND c.vals(1) = 'en';
  EXCEPTION WHEN OTHERS THEN RETURN FALSE;
  END wants_en;

  FUNCTION engine RETURN CLOB IS
    l_pairs CLOB;
  BEGIN
    IF g_js IS NULL THEN
      SELECT JSON_ARRAYAGG(JSON_ARRAY(ar, en) RETURNING CLOB) INTO l_pairs FROM wlt_i18n;
      g_js := q'~<style>
html.wen body *:not(input):not(textarea){direction:ltr!important}
html.wen .sd-per,html.wen .sd-tb th,html.wen .tq-row small{text-align:left!important}
html.wen .sd-tb .n,html.wen .h-tx .amt{text-align:right!important}
</style>
<script>
window.wI18n=(function(){
  var P=~' || l_pairs || q'~,D={},T={},FB=[],M={},RX=null,
      AR=/[\u0600-\u06FF]/,NUM=/[0-9\u0660-\u0669][0-9\u0660-\u0669.,:\/]*/g,ATT=['placeholder','title','aria-label'];
  function nk(s){return String(s).replace(/\s+/g,' ').trim()}
  P.forEach(function(p){var a=nk(p[0]),e=p[1];D[a]=e;
    if(a.indexOf('#')>=0)T[a]=e;
    else{var n1=(a.match(NUM)||[]).length,n2=(e.match(NUM)||[]).length;if(n1&&n1===n2)T[a.replace(NUM,'#')]=e.replace(NUM,'#')}
    if(a.length>=4&&a.indexOf('#')<0)FB.push(a)});
  FB.sort(function(x,y){return y.length-x.length});
  RX=new RegExp('(^|[^\u0621-\u064A])('+FB.map(function(s){return s.replace(/[.*+?^$\{\}()|[\]\\]/g,'\\$&')}).join('|')+')(?![\u0621-\u064A])','g');
  function tr(v){var k=nk(v);if(!k||!AR.test(k))return null;var e=D[k],t=null;
    if(e==null){var nums=[];t=k.replace(NUM,function(m){nums.push(m);return '#'});var te=T[t];
      if(te!=null){var i=0;e=te.replace(/#/g,function(){return nums[i++]||''})}}
    if(e==null){var f=k.replace(RX,function(m,pre,w){return pre+D[w]});
      if(f===k){M[t||k]=1;return null}e=f;if(AR.test(f))M[t||k]=1}
    var lead=(v.match(/^\s*/)||[''])[0],trail=(v.match(/\s*$/)||[''])[0];return lead+e+trail}
  function attrs(n){ATT.forEach(function(a){var v=n.getAttribute(a);if(v&&AR.test(v)){var r=tr(v);if(r!=null)n.setAttribute(a,r)}});
    if(n.nodeName==='INPUT'&&(n.type==='button'||n.type==='submit')&&AR.test(n.value)){var r=tr(n.value);if(r!=null)n.value=r}}
  function node(n){
    if(n.nodeType===3){var p=n.parentNode;if(!p||p.nodeName==='SCRIPT'||p.nodeName==='STYLE'||p.nodeName==='TEXTAREA')return;
      if(AR.test(n.nodeValue)){var r=tr(n.nodeValue);if(r!=null&&r!==n.nodeValue)n.nodeValue=r}return}
    if(n.nodeType!==1||n.nodeName==='SCRIPT'||n.nodeName==='STYLE')return;
    attrs(n);for(var c=n.firstChild;c;c=c.nextSibling)node(c)}
  function start(){var h=document.documentElement;h.classList.add('wen');h.setAttribute('lang','en');
    node(h);
    var tt=tr(document.title);if(tt)document.title=tt;
    new MutationObserver(function(ms){ms.forEach(function(m){
      if(m.type==='characterData')node(m.target);
      else if(m.type==='attributes')attrs(m.target);
      else for(var i=0;i<m.addedNodes.length;i++)node(m.addedNodes[i])})})
      .observe(h,{subtree:true,childList:true,characterData:true,attributes:true,attributeFilter:ATT});
    document.addEventListener('DOMContentLoaded',function(){var tt=tr(document.title);if(tt)document.title=tt})}
  return {start:start,tr:tr,missing:function(){return Object.keys(M)}};
})();
</script>~';
    END IF;
    RETURN g_js;
  END engine;

  FUNCTION prefix RETURN CLOB IS
    l CLOB;
  BEGIN
    IF wants_en THEN l := engine; ELSE l := TO_CLOB(' '); END IF;
    RETURN l;
  END prefix;
END wallet_i18n_pkg;
/

DECLARE
  l CLOB;
BEGIN
  FOR r IN (SELECT text FROM user_source WHERE name = 'WALLET_SEC_PKG' AND type = 'PACKAGE BODY' ORDER BY line) LOOP l := l || r.text; END LOOP;
  IF INSTR(l, 'wallet_i18n_pkg') = 0 THEN
    IF INSTR(l, q'#RETURN q'~<style>#') = 0 THEN RAISE_APPLICATION_ERROR(-20000, 'sec anchor'); END IF;
    l := REPLACE(l, q'#RETURN q'~<style>#', q'#RETURN wallet_i18n_pkg.prefix || TO_CLOB(q'~<style>#');
    l := REGEXP_REPLACE(l, '</script>~'';(\s*)END global_js;', '</script>~'');\1END global_js;');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE ' || l;
  END IF;
END;
/
