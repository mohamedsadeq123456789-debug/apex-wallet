-- =====================================================================
--  محفظة APEX · سكربت التنظيف
--  شغّله فقط إذا أردت حذف كل شيء وإعادة تشغيل 01_foundation.sql من جديد.
--  تحذير: يحذف كل الجداول والبيانات الخاصة بالمحفظة.
-- =====================================================================
BEGIN
  FOR r IN (
    SELECT object_name, object_type
      FROM user_objects
     WHERE object_name LIKE 'WLT\_%' ESCAPE '\'
       AND object_type IN ('VIEW','TABLE','SEQUENCE')
     ORDER BY DECODE(object_type,'VIEW',1,'TABLE',2,'SEQUENCE',3)
  ) LOOP
    BEGIN
      IF r.object_type = 'TABLE' THEN
        EXECUTE IMMEDIATE 'DROP TABLE ' || r.object_name || ' CASCADE CONSTRAINTS PURGE';
      ELSE
        EXECUTE IMMEDIATE 'DROP ' || r.object_type || ' ' || r.object_name;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN NULL;  -- قد يكون حُذف مسبقاً مع جدوله
    END;
  END LOOP;
END;
/
