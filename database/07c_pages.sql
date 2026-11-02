-- =====================================================================
--  محفظتي · الجلسة 7 · الصفحات 14 و 15 و 16 + عملية WLT_PLUS
-- =====================================================================
BEGIN
  wwv_flow_imp.import_begin(
    p_version_yyyy_mm_dd   => '2026.04.07',
    p_release              => '26.2.0',
    p_default_workspace_id => 33112972745115671678,
    p_default_application_id => 179352,
    p_default_id_offset    => 0,
    p_default_owner        => 'WKSP_MOHAMMADAPEX');

  wwv_flow_imp_page.create_page(p_id => 14, p_name => 'Savings', p_alias => 'SAVINGS',
    p_step_title => 'الحصّالات', p_autocomplete_on_off => 'OFF', p_step_template => 2982503008768810240,
    p_page_template_options => '#DEFAULT#', p_protection_level => 'C', p_page_component_map => '25');
  wwv_flow_imp_page.create_page_plug(p_id => wwv_flow_imp.id(9070000000000000141), p_plug_name => 'WLT Savings',
    p_static_id => 'wlt-savings', p_region_template_options => '#DEFAULT#', p_plug_template => 3374665444246510938,
    p_plug_display_sequence => 10, p_function_body_language => 'PLSQL',
    p_plug_source => 'return wallet_ui5_pkg.render_save;', p_plug_source_type => 'NATIVE_DYNAMIC_CONTENT');

  wwv_flow_imp_page.create_page(p_id => 15, p_name => 'Pay Code', p_alias => 'PAYCODE',
    p_step_title => 'كود الدفع', p_autocomplete_on_off => 'OFF', p_step_template => 2982503008768810240,
    p_page_template_options => '#DEFAULT#', p_protection_level => 'C', p_page_component_map => '25');
  wwv_flow_imp_page.create_page_plug(p_id => wwv_flow_imp.id(9070000000000000151), p_plug_name => 'WLT Pay Code',
    p_static_id => 'wlt-paycode', p_region_template_options => '#DEFAULT#', p_plug_template => 3374665444246510938,
    p_plug_display_sequence => 10, p_function_body_language => 'PLSQL',
    p_plug_source => 'return wallet_ui5_pkg.render_code;', p_plug_source_type => 'NATIVE_DYNAMIC_CONTENT');

  wwv_flow_imp_page.create_page(p_id => 16, p_name => 'Family', p_alias => 'FAMILY',
    p_step_title => 'العائلة', p_autocomplete_on_off => 'OFF', p_step_template => 2982503008768810240,
    p_page_template_options => '#DEFAULT#', p_protection_level => 'C', p_page_component_map => '25');
  wwv_flow_imp_page.create_page_plug(p_id => wwv_flow_imp.id(9070000000000000161), p_plug_name => 'WLT Family',
    p_static_id => 'wlt-family', p_region_template_options => '#DEFAULT#', p_plug_template => 3374665444246510938,
    p_plug_display_sequence => 10, p_function_body_language => 'PLSQL',
    p_plug_source => 'return wallet_ui5_pkg.render_family;', p_plug_source_type => 'NATIVE_DYNAMIC_CONTENT');

  wwv_flow_imp_shared.create_flow_process(p_id => wwv_flow_imp.id(9070000000000000170),
    p_process_sequence => 1, p_process_point => 'ON_DEMAND', p_process_type => 'NATIVE_PLSQL',
    p_process_name => 'WLT_PLUS', p_process_sql_clob => 'wallet_ui5_pkg.api;', p_process_clob_language => 'PLSQL',
    p_security_scheme => 'MUST_NOT_BE_PUBLIC_USER');

  wwv_flow_imp.import_end(p_auto_install_sup_obj => FALSE);
  COMMIT;
END;
/
