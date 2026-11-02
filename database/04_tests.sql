-- =====================================================================
--  محفظتي · الجلسة 4 · اختبارات الدفع للتجار والفواتير والوكلاء
--  شغّله في SQL Commands. كل سطر يبدأ بـ OK أو FAIL
-- =====================================================================
DECLARE
  l_ref  VARCHAR2(40);
  l_ref2 VARCHAR2(40);
  l_tok  VARCHAR2(40);
  l_code VARCHAR2(10);
  l_a    NUMBER;
  l_b    NUMBER;
  l_bill NUMBER;
  l_svg  CLOB;
  PROCEDURE ok (p VARCHAR2) IS BEGIN DBMS_OUTPUT.PUT_LINE('OK   | ' || p); END;
  PROCEDURE bad (p VARCHAR2) IS BEGIN DBMS_OUTPUT.PUT_LINE('FAIL | ' || p); END;
  FUNCTION bal (p VARCHAR2) RETURN NUMBER IS l NUMBER;
  BEGIN SELECT balance INTO l FROM wlt_wallets WHERE wallet_id = wallet_core_pkg.main_wallet(p); RETURN l; END;
  PROCEDURE expect (p_name VARCHAR2, p_code NUMBER, p_sql VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE p_sql;
    bad(p_name || ' : passed');
  EXCEPTION WHEN OTHERS THEN
    IF SQLCODE = p_code THEN ok(p_name || ' : ' || SQLCODE || ' ' || SUBSTR(SQLERRM, 12, 80));
    ELSE bad(p_name || ' : ' || SQLERRM); END IF;
  END;
BEGIN
  -- 1) دفع لتاجر بكوده الثابت
  l_a := bal('0796789012');
  l_ref := wallet_pay_pkg.pay_merchant('0794567890', 'M2041', 3.5, 'S4-M1');
  IF bal('0796789012') = l_a + 3.5 THEN ok('Q01 pay merchant code M2041 3.500 : ' || l_ref); ELSE bad('Q01'); END IF;

  -- 2) QR ديناميكي: التاجر يولّد، العميل يدفع، ثم محاولة ثانية من عميل آخر
  l_tok := wallet_pay_pkg.create_qr('0796789012', 4.75, 'قهوة × 2');
  l_a := bal('0791234567');
  l_ref := wallet_pay_pkg.pay_merchant('0791234567', 'WLT:' || l_tok, NULL, 'S4-Q1');
  IF bal('0791234567') = l_a - 4.75 THEN ok('Q02 dynamic QR 4.750 paid : ' || l_ref); ELSE bad('Q02'); END IF;
  l_ref2 := wallet_pay_pkg.pay_merchant('0791234567', l_tok, NULL, 'S4-Q1-retry');
  IF l_ref2 = l_ref THEN ok('Q03 same payer retry returns same receipt'); ELSE bad('Q03'); END IF;
  expect('Q04 QR reused by another payer', -20120,
         'DECLARE r VARCHAR2(40); BEGIN r := wallet_pay_pkg.pay_merchant(''0782345678'', ''' || l_tok || '''); END;');
  expect('Q05 customer cannot create QR', -20123,
         'DECLARE r VARCHAR2(40); BEGIN r := wallet_pay_pkg.create_qr(''0791234567'', 5); END;');
  expect('Q06 unknown merchant code', -20121,
         'DECLARE r VARCHAR2(40); BEGIN r := wallet_pay_pkg.pay_merchant(''0791234567'', ''M9999'', 1); END;');

  -- 3) فاتورة الكهرباء: دفع، ثم محاولة دفعها مرة ثانية
  SELECT MIN(bill_id) INTO l_bill FROM wlt_bills WHERE biller_code = 'ELEC' AND account_no = '10023' AND status = 'UNPAID';
  l_a := bal('0794567890');
  l_ref := wallet_pay_pkg.pay_bill('0794567890', l_bill, 'S4-B1');
  IF bal('0794567890') = l_a - 18.45 - 0.25 THEN ok('Q07 electricity bill 18.450 + fee 0.250 : ' || l_ref); ELSE bad('Q07 ' || (l_a - bal('0794567890'))); END IF;
  expect('Q08 bill paid twice by another payer', -20122,
         'DECLARE r VARCHAR2(40); BEGIN r := wallet_pay_pkg.pay_bill(''0791234567'', ' || l_bill || '); END;');

  -- 4) شحن خط
  l_a := bal('0791234567');
  l_ref := wallet_pay_pkg.recharge('0791234567', 'TEL', '0791234567', 5, 'S4-R1');
  IF bal('0791234567') = l_a - 5 THEN ok('Q09 line recharge 5 : ' || l_ref); ELSE bad('Q09'); END IF;
  expect('Q10 recharge odd value 7', -20107,
         'DECLARE r VARCHAR2(40); BEGIN r := wallet_pay_pkg.recharge(''0791234567'', ''TEL'', ''0791234567'', 7); END;');

  -- 5) إيداع نقدي عند الوكيل
  l_a := bal('0785678901'); l_b := bal('0798901234');
  l_ref := wallet_pay_pkg.cash_in('0798901234', '0785678901', 40, 'S4-CI1');
  IF bal('0785678901') = l_a + 40 AND bal('0798901234') = l_b - 40 THEN ok('Q11 agent cash-in 40 : ' || l_ref); ELSE bad('Q11'); END IF;
  expect('Q12 customer acting as agent', -20123,
         'DECLARE r VARCHAR2(40); BEGIN r := wallet_pay_pkg.cash_in(''0791234567'', ''0785678901'', 5); END;');

  -- 6) سحب بكود لمرة واحدة
  l_code := wallet_pay_pkg.new_cashout_code('0785678901', 20);
  l_a := bal('0785678901'); l_b := bal('0798901234');
  IF l_a = bal('0785678901') THEN ok('Q13 code ' || SUBSTR(l_code, 1, 2) || '•••• created, nothing deducted yet'); END IF;
  expect('Q14 wrong cashout code', -20124,
         'DECLARE r VARCHAR2(40); BEGIN r := wallet_pay_pkg.redeem_cashout(''0798901234'', ''000000''); END;');
  l_ref := wallet_pay_pkg.redeem_cashout('0798901234', l_code, 'S4-CO1');
  IF bal('0785678901') = l_a - 20.25 AND bal('0798901234') = l_b + 20 THEN ok('Q15 cash-out 20 + fee 0.250 at agent : ' || l_ref); ELSE bad('Q15'); END IF;
  expect('Q16 same code used twice', -20124,
         'DECLARE r VARCHAR2(40); BEGIN r := wallet_pay_pkg.redeem_cashout(''0798901234'', ''' || l_code || '''); END;');
  expect('Q17 cashout code above balance', -20101,
         'DECLARE r VARCHAR2(40); BEGIN r := wallet_pay_pkg.new_cashout_code(''0785678901'', 500); END;');

  -- 7) QR كصورة SVG
  l_svg := apex_barcode.get_qrcode_svg(p_value => 'WLT:test');
  IF DBMS_LOB.INSTR(l_svg, '<svg') > 0 THEN ok('Q18 QR SVG generated, ' || DBMS_LOB.GETLENGTH(l_svg) || ' chars'); ELSE bad('Q18'); END IF;

  -- 8) السلامة
  SELECT COUNT(*) INTO l_a FROM wlt_v_check_unbalanced_txns;
  IF l_a = 0 THEN ok('C1 all balanced'); ELSE bad('C1 ' || l_a); END IF;
  SELECT COUNT(*) INTO l_a FROM wlt_v_check_wallet_drift;
  IF l_a = 0 THEN ok('C2 no drift'); ELSE bad('C2 ' || l_a); END IF;
  SELECT SUM(balance) INTO l_a FROM wlt_wallets;
  IF l_a = 0 THEN ok('C3 total 0'); ELSE bad('C3 ' || l_a); END IF;
END;
