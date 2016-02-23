--------------------------------------------------------
--  File created - Monday-February-22-2016   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Package Body WFL_FELLOWSHIP
--------------------------------------------------------

  CREATE OR REPLACE PACKAGE BODY "WWW_RGS"."WFL_FELLOWSHIP" 
is

-------------------------------
--Title: WFL_FELLOWSHIP
--Created : Spring 2013
--Author : Jolene Singh
--Purpose: New system of fellowships
--MODIFICATIONS
-- 04/30/2013 Jolene S. : Edited "reset_sessions" to cater to NULL award years.
-- 05/02/2013 Jolene S. : Changed the order of the last three columns of TGRDFELLOW_SESS in processing packages
--                        as I had accidently changed the order when creating new tables
-- 05/02/2013 Jolene S. : Added javascript function for updating total_award_amt. Changed all parseInt to parseFloat
-- 05/05/2013 Jolene S. : Replaced all owa_utils to refer to wgb_dispstd.disp_grad
-- 05/07/2013 Jolene S. : Corrected javascript function CopyFromprevious. the table name had been set as "Gradsch.tgrfellow_sess"
--                        resulting in NULL rows being returned. "Gradsch" has now been removed.
-- 05/08/2013 Jolene S. : Added a call to print_funding_summary at the end of print_funding.
-- 05/09/2013 Jolene S. : Added Javascript calls to ensire that duration is an integer and amount fields don't accept characters
--                        except a decimal.
-- 05/10/2013 Jolene S. : Increased the length of textbox for flb_sponsor.
-- 05/10/2013 Jolene S. : Modified proc_create_fellowship.
-- 05/31/2013 Romina    : Modified print_session_details to allow decimal numbers in "Total Months Paid" field
-- 06/10/2013 Romina    : Modified selectlist_tgrdrefer to allow "Copy from Previous" in Chrome and Firefox 
--                        Modified print_java_copy_from_previous to include "Total Insurance"
-- 06/27/2013 Romina    : Modified print_funding, proc_update_fel to change "Begin Date" and "End Date" treatment 
--                        and resolve date conversion errors 
-- 12/20/2013 Vinod     : Modified proc_update_academic_year,proc_update_session and proc_create_fellowship to add 
--                        new column CalTerm
-- 11/12/2013 Vinod     : Modified print_session_details,proc_create_fellowship,proc_update_academic_year,proc_update_session to add
--                        new Remarks field
-- 3/21/2014  Vinod     : Modified Print funding to Add "Delete Row" button for the session
-- 3/21/2014  Vinod     : Added new procedure disp_delete_session for deleting a session row
-- 3/21/2014  Vinod     : Modified proc_create_fellowship to create the fellowship with "active" status when fellowship is started in spring
-- 07/24/2014 Venkata   : Modified proc_update_session and  proc_update_academic_year to enable extend_for_hold option for 'ACTIVE-HOLD' Status
-- 07/24/2014 Venkata   : Modified print_funding for tution display to show up for both Assistantship and Fellowship 
-- 11/17/2014 Shanmukesh: Modified print_funding & extend_for_hold
------------------------------------


--Type t_budget_list is used in javascript function check_budget_year to ensure that a duplicate budget year row is not added
type t_budget_list is table of GRADSCH.TGRDFELLOW_BUDGET%ROWTYPE index by binary_integer;
empty_budget_list t_budget_list;

type t_session_list is table of GRADSCH.TGRDFELLOW_SESS%ROWTYPE index by binary_integer;
v_session_list t_session_list;

--Author: Jolene Singh
--Function: This function is triggered when the "Copy from previous" button is clicked in session blocks
--          this fucntion copies over all data from the previous session block into the new session block to avoid retyping
--          in case of multiple sessions having similar information.
-- Modifications
-- 06/10/2013 Romina : Modified to include "Total Insurance"
procedure print_java_copy_from_previous
is
begin
htp.print('<script type = "text/javascript" language = "javascript">');
htp.print('function CopyFromPrevious(i)');
htp.print('{');
htp.print('var sourceElement="";');
htp.print('var destElement="";');
for a in (select column_name from all_tab_cols
          where table_name='TGRDFELLOW_SESS'
          and column_name not in ('FLS_SEQNUM','FLS_UNIQUE','FLS_CALYEAR','FLS_SESSION','FLS_STATUS','FLS_BUDGET_YEAR',
                                  'FLS_TUIT_ONLY', 'FLS_TUIT_AIDCODE','FLS_TUIT_CHRG_SCH','FLS_SUPP','FLS_SUPP_OTHER_FUND_ACCT','FLS_SUPP_OTHER_FUND_AMT')
          order by column_id)
loop
  htp.print('sourceElement="in_'||a.column_name||'_'||'"+(i-1);');
  htp.print('destElement="in_'||a.column_name||'_'||'"+i;');
--htp.print('alert(document.getElementById(sourceElement).value)');
  htp.print('document.getElementById(destElement).value=document.getElementById(sourceElement).value;');
end loop;
--_special cases

htp.print('var sourceRadio = document.getElementById("in_FLS_SUPP_N_"+(i-1));');
htp.print('var destRadio = document.getElementById("in_FLS_SUPP_N_"+i);');
htp.print('if (sourceRadio.checked)');
htp.print('{ destRadio.checked=true;}');
htp.print('var sourceRadio = document.getElementById("in_FLS_SUPP_Y_"+(i-1));');
htp.print('var destRadio = document.getElementById("in_FLS_SUPP_Y_"+i);');
htp.print('if (sourceRadio.checked)');
htp.print('{ destRadio.checked=true;}');

htp.print('update_total_insurance(i)'); -- added by romina 06/10/2013


--htp.print('var sourceRadio = document.getElementById("in_FLS_SUPP_O_"+(i-1));');
--htp.print('var destRadio = document.getElementById("in_FLS_SUPP_O_"+i);');
--htp.print('if (sourceRadio.checked)');
--htp.print('{ destRadio.checked=true;}');
/*
htp.print('var sourceRadio = document.getElementsByName("in_FLS_SUPP_"+(i-1));');
htp.print('var destRadio = document.getElementsByName("in_FLS_SUPP_"+i);');
htp.print('for (var j=0; j < sourceRadio.length; j++)');
htp.print('{');
htp.print('if (sourceRadio[j].checked)');
htp.print('{');
htp.print('destRadio.checked = true;');
htp.print('}');
htp.print('}');
*/

htp.print('}');


htp.print('</script>');
end;

--Author: Jolene Singh
--Function : This function contains all the validation javascripts
procedure print_java_alert
is
begin
htp.print('<script type = "text/javascript" language = "javascript">');
htp.print('function check_basecode()');
htp.print('{');
htp.print('var basecode=document.getElementById("in_flb_code").value;');
htp.print('basecode=basecode.replace(/^\s\s*/, '''').replace(/\s\s*$/, '''');');
htp.print('var awardyear=document.getElementById("in_flb_award_year").value;');
htp.print('awardyear=awardyear.replace(/^\s\s*/, '''').replace(/\s\s*$/, '''');');
htp.print('var duration=document.getElementById("in_flb_duration").value;');
htp.print('duration=duration.replace(/^\s\s*/, '''').replace(/\s\s*$/, '''');');
htp.print('var startsession=document.getElementById("in_flb_start_session").value;');
htp.print('startsession=startsession.replace(/^\s\s*/, '''').replace(/\s\s*$/, '''');');
htp.print('var startcalyear=document.getElementById("in_flb_start_calyear").value;');
htp.print('startcalyear=startcalyear.replace(/^\s\s*/, '''').replace(/\s\s*$/, '''');');
htp.print('if (basecode != '''' && duration != '''' && awardyear != '''' && startsession != '''' && startcalyear!='''')');
htp.print('return true;');
htp.print('else');
htp.print('{');
htp.print('alert("Please make sure the following fields are completed: Fellowship name, Award Year, Duration and Starting session");');
htp.print('return false;');
htp.print('}');
htp.print('}');

htp.print('function check_budget_year(budget_year_list)');
htp.print('{');
htp.print('var bgselectlist=document.getElementById("in_fbg_budget_year");');
htp.print('var bgyear=bgselectlist.options[bgselectlist.selectedIndex].text;');
htp.print('bgyear=bgyear.replace(/^\s\s*/, '''').replace(/\s\s*$/, '''');');
htp.print('if (bgyear != '''') {');
--htp.print('var bg_list=budget_year_list.split(",");');
--htp.print('alert(bg_list.length);');
--htp.print('return false;');
--htp.print('for ( var i = 0; i<bg_list.length; i++) {');
--htp.print('alert(bg_list(i));');
--htp.print('if (bg_list(i)==bgyear){');
htp.print('if (budget_year_list.indexOf(bgyear) >=0) {');
htp.print('alert("This budget year already exists. You cannot create a duplicate budget year.");');
htp.print('return false;');
htp.print('}');
--htp.print('}');
htp.print('return true;}');
htp.print('else');
htp.print('{');
htp.print('alert("Please make sure the following fields are completed: Budget Year");');
htp.print('return false;');
htp.print('}');
htp.print('}');

--Update supplementary award amount
htp.print('function update_supp_amt(i)');
htp.print('{');
htp.print('var radioBtn = document.getElementById("in_FLS_SUPP_N_"+(i));');
htp.print('if(radioBtn.checked)');
htp.print('document.getElementById("in_FLS_SUPP_AMOUNT_"+i).value="0";');
htp.print('var radioBtn = document.getElementById("in_FLS_SUPP_Y_"+(i));');
htp.print('if(radioBtn.checked)');
htp.print('{');
htp.print('var amount=document.getElementById("in_FLS_SUPP_PAYROLL_AMT_"+i).value;');
htp.print('if (amount=='''') { amount="0";}');
htp.print('var destValue=(parseFloat(amount)).toFixed(2).toString();');
htp.print('document.getElementById("in_FLS_SUPP_AMOUNT_"+i).value=destValue;');
htp.print('}');
htp.print('}');

--Update fringe benefits
htp.print('function update_fringe_benefits(i)');
htp.print('{');
--htp.print('var med_insurance="in_FLS_MED_INSURANCE_"+(i);');
htp.print('var value=document.getElementById("in_FLS_MED_INSURANCE_"+(i)).value;');
htp.print('var amount=document.getElementById("in_FLS_TOTAL_SPONSOR_STIPEND_"+i).value;');
htp.print('if (amount=='''') {amount="0";}');
htp.print('if (value!= "CHARGE_ACCOUNT") {amount="0";}');
htp.print('var destValue=(parseFloat(amount)*0.0041).toFixed(2).toString();');
htp.print('document.getElementById("in_FLS_FRINGE_BENEFIT_AMOUNT_"+i).value=destValue;');
htp.print('}');

--Update total insurance
htp.print('function update_total_insurance(i)');
htp.print('{');
htp.print('var amount=document.getElementById("in_FLS_MED_AMT_"+i).value;');
htp.print('if (amount=='''') {amount="0";}');
htp.print('var destValue=(parseFloat(amount)).toFixed(2).toString();');
htp.print('document.getElementById("in_FLS_TOTAL_INSURANCE_"+i).innerHTML=destValue;');
htp.print('}');

--Update Annual Stipend
htp.print('function update_annual_stipend(i)');
htp.print('{');
htp.print('var sponsor_stipend=document.getElementById("in_FLS_TOTAL_SPONSOR_STIPEND_"+i).value;');
--str = str.replace(/^\s+|\s+$/g,'')
htp.print('sponsor_stipend = sponsor_stipend.replace(/^\s+|\s+$/g,'''');');
htp.print('if(sponsor_stipend==''''){sponsor_stipend="0";}');
htp.print('var supp_amt=document.getElementById("in_FLS_SUPP_AMOUNT_"+i).value;');
htp.print('supp_amt = supp_amt.replace(/^\s+|\s+$/g,'''');');
htp.print('if(supp_amt==''''){supp_amt="0";}');
htp.print('var fringe=document.getElementById("in_FLS_FRINGE_BENEFIT_AMOUNT_"+i).value;');
htp.print('fringe = fringe.replace(/^\s+|\s+$/g,'''');');
htp.print('if(fringe==''''){fringe="0";}');
htp.print('var insurance=document.getElementById("in_FLS_MED_AMT_"+i).value;');
htp.print('insurance = insurance.replace(/^\s+|\s+$/g,'''');');
htp.print('if(insurance==''''){insurance="0";}');
htp.print('var stipend=parseFloat(sponsor_stipend)+parseFloat(supp_amt)+parseFloat(fringe)+parseInt(insurance);');
htp.print('stipend=stipend.toFixed(2).toString();');
htp.print('document.getElementById("in_FLS_ANNUAL_STIPEND_"+i).value=stipend;');
htp.print('}');

--Update Monthly Stipend
htp.print('function update_monthly_stipend(i)');
htp.print('{');
htp.print('var sponsor_stipend=document.getElementById("in_FLS_TOTAL_SPONSOR_STIPEND_"+i).value;');
--str = str.replace(/^\s+|\s+$/g,'')
htp.print('sponsor_stipend = sponsor_stipend.replace(/^\s+|\s+$/g,'''');');
htp.print('if(sponsor_stipend==''''){sponsor_stipend="0";}');
htp.print('var supp_amt=document.getElementById("in_FLS_SUPP_AMOUNT_"+i).value;');
htp.print('supp_amt = supp_amt.replace(/^\s+|\s+$/g,'''');');
htp.print('if(supp_amt==''''){supp_amt="0";}');
htp.print('var months=document.getElementById("in_FLS_MONTHS_STIPEND_"+i).value;');
htp.print('months = months.replace(/^\s+|\s+$/g,'''');');
htp.print('if(months==''''){months="0";}');
htp.print('var stipend="0";');
htp.print('if(months!="0"){');
htp.print('stipend=((parseFloat(sponsor_stipend)+parseFloat(supp_amt))/parseFloat(months)).toFixed(2).toString();}');
--htp.print('stipend=stipend.toFixed(2).toString();');
htp.print('document.getElementById("in_FLS_MONTHLY_STIPEND_"+i).value=stipend;');
htp.print('}');

--Update Total Award Amount
htp.print('function update_award_amt(i)');
htp.print('{');
htp.print('var sponsor_stipend=document.getElementById("in_FLS_TOTAL_SPONSOR_STIPEND_"+i).value;');
htp.print('sponsor_stipend = sponsor_stipend.replace(/^\s+|\s+$/g,'''');');
htp.print('if(sponsor_stipend==''''){sponsor_stipend="0";}');
htp.print('var fringe=document.getElementById("in_FLS_FRINGE_BENEFIT_AMOUNT_"+i).value;');
htp.print('fringe = fringe.replace(/^\s+|\s+$/g,'''');');
htp.print('if(fringe==''''){fringe="0";}');
htp.print('var insurance=document.getElementById("in_FLS_MED_AMT_"+i).value;');
htp.print('insurance = insurance.replace(/^\s+|\s+$/g,'''');');
htp.print('if(insurance==''''){insurance="0";}');
htp.print('var award=parseFloat(sponsor_stipend)+parseFloat(fringe)+parseFloat(insurance);');
htp.print('award=award.toFixed(2).toString();');
htp.print('document.getElementById("in_FLS_TOTAL_AWARD_AMOUNT_"+i).value=award;');
htp.print('}');


--Check flb_duration is only numbers
htp.print('function isNumberKey(evt)');
htp.print('{');
htp.print('var charCode = (evt.which) ? evt.which : event.keyCode;');
htp.print('if(charCode > 31 && (charCode<48 || charCode>57))');
htp.print('   return false;');
htp.print('return true;');
htp.print('}');


--Check if input is an amount value
htp.print('function isAmountKey(evt)');
htp.print('{');
htp.print('var charCode = (evt.which) ? evt.which : event.keyCode;');
htp.print('if(charCode !=46 && charCode > 31 && (charCode<48 || charCode>57))');
htp.print('   return false;');
htp.print('return true;');
htp.print('}');

htp.print('</script>');
end;

--Author: Jolene Singh
--Function : Prompt user to confirm their action.  
procedure print_java_areyousure--"Are you sure you want to delete the selected fellowship? This action is irreversible."
is
begin
htp.print('<script type = "text/javascript" language = "javascript">');
htp.print('function confirm_proceed(message)');
htp.print('{');
htp.print('if (confirm(message)==true)');
htp.print('return true;');
htp.print('else');
htp.print('return false;');
htp.print('}');


--Check Reset
htp.print('function checkReset(award_year)');
htp.print('{');
htp.print('award_year=award_year.replace(/^\s+|\s+$/g,'''');');
htp.print('if(award_year==''''){alert("Award Year is blank. Cannot reset budget years");');
htp.print('return false;}');
htp.print('return true;');
htp.print('}');

htp.print('</script>');
end;


--Author: Jolene Singh
--Function: Based on ref_name, returns a selectlist from TGRDREFER table. The main addition is the use of ID attribute.
-- Modifications
-- 06/10/2013 Romina : Modified to include the ID attribute in the select list
function selectlist_tgrdrefer (in_id in varchar2,
                           in_selected in varchar2,
                           in_ref_name in varchar2)
return VARCHAR2
is
temp_list varchar2(32767);
CURSOR refer_ptr IS
SELECT *   
FROM tgrdrefer
WHERE lower(ref_name) = in_ref_name
ORDER BY ref_sequence;

begin
 temp_list := '<select id='||in_id||' name='||in_id||'>'; -- re-added by romina 06/10/2013
  -- temp_list := '<select name='||in_id||'>'; -- removed by romina 06/10/2013
 temp_list := temp_list || htf.formSelectOption(' ');
 for a IN refer_ptr  loop
  IF in_selected = a.ref_code
    THEN
      temp_list := temp_list || htf.formSelectOption(a.ref_literal, 'SELECTED','VALUE="' || a.ref_code || '"');
    ELSE
      temp_list := temp_list || htf.formSelectOption(a.ref_literal, NULL,'VALUE="' || a.ref_code || '"');
    END if;
  end loop;
 temp_list := temp_list || htf.formSelectClose;
 return temp_list;
end;

-- Title: selectlist_tgrdrefer1
-- Author: Shanmukesh Vankayala
-- Date: 02/28/2015
-- Description: 

function selectlist_tgrdrefer1 (in_id in varchar2,
                           in_selected in varchar2,
                           in_ref_name in varchar2)
return VARCHAR2
is
temp_list varchar2(32767);
CURSOR refer_ptr IS
SELECT *   
FROM tgrdrefer
WHERE lower(ref_name) = in_ref_name
ORDER BY ref_sequence;

begin
 temp_list := '<select style="background-color:#C0C0C0;" id='||in_id||' name='||in_id||'>'; 
 temp_list := temp_list || htf.formSelectOption(' ');
 for a IN refer_ptr  loop
  IF in_selected = a.ref_code
    THEN
      temp_list := temp_list || htf.formSelectOption(a.ref_literal, 'SELECTED','VALUE="' || a.ref_code || '"');
    ELSE
      temp_list := temp_list || htf.formSelectOption(a.ref_literal, NULL,'VALUE="' || a.ref_code || '"');
    END if;
  end loop;
 temp_list := temp_list || htf.formSelectClose;
 return temp_list;
end;

--Author: Jolene Singh
--Function : Displays Student Information module
procedure print_student_details(in_seqnum in number default 0)
IS
v_puid TGRDBASE.B_PUID%TYPE;
v_name TGRDBASE.B_NAME%TYPE;
cur_reg TGRDREG%ROWTYPE;
BEGIN
  select b_puid,b_name into v_puid,v_name from tgrdbase
  where b_seqnum=in_seqnum;
  
  cur_reg := wps_shared.get_most_recent_registration(in_seqnum);
  
  htp.header(3,'Student Details',null,null,null,'style="color:#0000CC;"');
  htp.tableopen(null,null,null,null,'style="width=50%"');
    htp.tablerowopen;
      htp.tabledata('Name');
      htp.tabledata(v_name);
      htp.tabledata('PUID');
      htp.tabledata(v_puid);
    htp.tablerowclose;
    htp.tablerowopen;
      htp.tabledata('Department');
      htp.tabledata(wgb_functions.dept_of(cur_reg.rg_dept, cur_reg.rg_campus)||'('||cur_reg.rg_dept||')');
    htp.tablerowclose;
  htp.tableclose;
END;

--Author: Jolene singh
--Function : Returns a 20 year long YYYY-YY selectlist starting from sysdata-10. Use of ID attribute.
function selectlist_acadyear (in_id in varchar2,
                           in_selected in varchar2)
return VARCHAR2
is
temp_list varchar2(32767);
begin
  temp_list := '<select id='||in_id||' name='||in_id||'>';
  temp_list := temp_list || htf.formSelectOption(' ');
  for i in (to_number(TO_CHAR(sysdate,'yyyy'))-10)..(to_number(TO_CHAR(sysdate,'yyyy'))+10)
  loop
    if i=substr(in_selected,1,4) then
      temp_list := temp_list || htf.formSelectOption(i||'-'||substr(i+1,3,2), 'SELECTED','VALUE="' || i||'-'||substr(i+1,3,2) || '"');
    else
      temp_list := temp_list || htf.formSelectOption(i||'-'||substr(i+1,3,2), null,'VALUE="' || i||'-'||substr(i+1,3,2) || '"');
    end if;
  end loop;
  temp_list := temp_list || htf.formSelectClose;
return temp_list;
end;

--Author: Jolene singh
--Function : Returns a YYYY selectlist. Use of ID attribute.
function get_years_selectlist(in_id in varchar2 default null,
			     in_currentyear IN number DEFAULT null,
                 in_number_of_years IN NUMBER DEFAULT(10),
                 in_start_year IN number DEFAULT to_number(to_char(sysdate,'YYYY')))
	return VARCHAR2
is
 temp_list varchar2(32767);
begin
  temp_list := '<select id='||in_id||' name='||in_id||'>';
  temp_list := temp_list || htf.formSelectOption(' ');
  for i in in_start_year..in_start_year+in_number_of_years
  loop
    if i=in_currentyear then
      temp_list := temp_list || htf.formSelectOption(i, 'SELECTED','VALUE="' || i || '"');
    else
      temp_list := temp_list || htf.formSelectOption(i, null,'VALUE="' || i || '"');
    end if;
  end loop;
  temp_list := temp_list || htf.formSelectClose;
return temp_list;
end;  -- get_years_selectlist

--Author: jolene Singh
--Function: returns a selectlist of options for Medical Insurance -> How will it be handled?
function get_med_insurance_selectlist(in_id in varchar2 default null,
                                      in_selected IN varchar2 DEFAULT null,
                                      in_param IN varchar2 default null)
return VARCHAR2
is
temp_list varchar2(32767);
 
begin
  temp_list := '<select id='||in_id||' name='||in_id||' '||in_param||' >';
  temp_list := temp_list || htf.formSelectOption(' ');
  temp_list := temp_list || htf.formSelectOption('ADD_TO_STIPEND', case in_selected when 'ADD_TO_STIPEND' then 'SELECTED' else null end,'VALUE="ADD_TO_STIPEND"');
  temp_list := temp_list || htf.formSelectOption('CHARGE_ACCOUNT', case in_selected when 'CHARGE_ACCOUNT' then 'SELECTED' else null end,'VALUE="CHARGE_ACCOUNT"');
  temp_list := temp_list || htf.formSelectOption('OTHER', case in_selected when 'OTHER' then 'SELECTED' else null end,'VALUE="OTHER"');
  temp_list := temp_list || htf.formSelectClose;
  return temp_list;
end;

--Author: Jolene Singh
--Function: displays Fellowship Details module. Can be editable display or uneditable display basaed on if a new 
--           fellowship is being created or an existing fellowship is being viewed.
procedure print_fellowship_details( in_var1 in number default 0,
                                    in_var2 in number default 0,
                                    in_seqnum in number default 0,
                                    in_unique in number default null--,
                                    --in_tgrdfellow_base in GRADSCH.TGRDFELLOW_BASE%ROWTYPE default null
                                    )
IS
v_tgrdfellow_base GRADSCH.TGRDFELLOW_BASE%ROWTYPE default null;
v_fel_name TGRDFELLCD.FL_FELNAME%TYPE default null;

BEGIN
  if in_unique is not null then--Display existing fellowship
    select * into v_tgrdfellow_base from GRADSCH.TGRDFELLOW_BASE
    where flb_seqnum=in_seqnum
    and flb_unique=in_unique;
    
    select fl_felname into v_fel_name from TGRDFELLCD
    where fl_felcode=v_tgrdfellow_base.FLB_CODE;
  end if;  
  --v_tgrdfellow_base:=in_tgrdfellow_base;
  
  htp.header(3,'Fellowship Details',null,null,null,'style="color:#0000CC;"');
  
  if in_unique is not null then
    htp.tableopen(null,null,null,null,'style="width=100%"');
      htp.tablerowopen;
        htp.tabledata('Name');
        htp.tabledata(v_fel_name,null,null,null,null,3);
      htp.tablerowclose;
      htp.tablerowopen;
        htp.tabledata('Award Year');
        htp.tabledata(v_tgrdfellow_base.flb_award_year);
        htp.tabledata('Duration');
        htp.tabledata(v_tgrdfellow_base.flb_duration);
      htp.tablerowclose;
      htp.tablerowopen;
        htp.tabledata('Starting session');
        htp.tabledata(case v_tgrdfellow_base.flb_start_session when 10 then 'Fall' when 20 then 'Spring' when 30 then 'Summer' else 'N/A' end ||'-'||v_tgrdfellow_base.flb_start_calyear);
        htp.tabledata('Sponsor');
        htp.tabledata(v_tgrdfellow_base.flb_sponsor);
      htp.tablerowclose;
      htp.tablerowopen;
        htp.tabledata('Begin Date');
        htp.tabledata(v_tgrdfellow_base.flb_begin_date);
        htp.tabledata('End Date');
        htp.tabledata(v_tgrdfellow_base.flb_end_date);
      htp.tablerowclose;
      
      htp.tablerowopen;
        htp.tabledata('Comments');
        htp.tabledata('<pre>'||v_tgrdfellow_base.flb_comments||'</pre>',null,null,null,null,3);
      htp.tablerowclose;
    htp.tableclose;
  else
    htp.tableopen(null,null,null,null,'style="width=100%"');
      htp.tablerowopen;
        htp.tabledata('Name*');
        htp.tabledata(wgb_shared.fellowship_list('in_flb_code',v_tgrdfellow_base.flb_code,'Y','Y'),null,null,null,null,3);
      htp.tablerowclose;
      htp.tablerowopen;
        htp.tabledata('Award Year*');
        --htp.tabledata(htf.formtext('in_flb_award_year',v_tgrdfellow_base.flb_award_year));
        htp.tabledata(selectlist_acadyear('in_flb_award_year',v_tgrdfellow_base.flb_award_year));
        htp.tabledata('Duration*');
        htp.tabledata(htf.formtext('in_flb_duration',10,10,v_tgrdfellow_base.flb_duration,'onkeypress="return isNumberKey(event)"'));
      htp.tablerowclose;
      htp.tablerowopen;
        htp.tabledata('Starting session*');
        --htp.tabledata(selectlist_sess('in_flb_start_session',null,'term')||htf.formtext('in_flb_start_calyear',4,4,null,'onkeyup="this.value=this.value.replace(/[^0-9]/g, '''')"'));
        htp.tabledata(selectlist_tgrdrefer('in_flb_start_session',null,'term')||get_years_selectlist('in_flb_start_calyear',null,15,to_char(sysdate,'YYYY')-5));
        htp.tabledata('Sponsor');
        htp.tabledata(htf.formtext('in_flb_sponsor',null,null,v_tgrdfellow_base.flb_sponsor)); --05/10/2013 Jolene.S. : unlimited size for this field
      htp.tablerowclose;
      htp.tablerowopen;
        htp.tabledata('Begin Date (MM/DD/YY)');
        htp.tabledata(htf.formtext('in_flb_begin_date',10,10,v_tgrdfellow_base.flb_begin_date, 'onchange="check_date(this,this.value)"'));
        htp.tabledata('End Date (MM/DD/YY)');
        htp.tabledata(htf.formtext('in_flb_end_date',10,10,v_tgrdfellow_base.flb_end_date,' onchange="check_date(this,this.value)"'));
      htp.tablerowclose;
      htp.tablerowopen;
        htp.tabledata('Comments');
        htp.tabledata(htf.formTextareaOpen('in_flb_comments',5,40,null,'style="width: 100%; -webkit-box-sizing: border-box; -moz-box-sizing: border-box; box-sizing: border-box;"')||v_tgrdfellow_base.flb_comments||htf.formTextareaClose,null,null,null,null,3,null);
      htp.tablerowclose;
    htp.tableclose;
  end if;
END;


--Author: Jolene Singh
--Function: Displays Budget year module. If create new fellowship -> single row of budget year
--          If display all budget years-> All budget years with a checkbox for deleting any
--          If Update one budget year-> Display all budget years with only the year in question being editable
--          If add a budget year -> Display all budget years and add one new editale row at the bottom.
procedure print_budget_details(in_var1 in number default 0,
                              in_var2 in number default 0,
                              in_seqnum in number default 0,
                              in_unique in number default null,
                              in_budget_year in GRADSCH.TGRDFELLOW_BUDGET.FBG_BUDGET_YEAR%TYPE default null,
                              in_action in varchar2 default 'CREATE')
IS
v_stmt varchar2(32767);
type t_cur_ref is ref cursor;
v_cur_list t_cur_ref;
v_TGRDFELLOW_BUDGET GRADSCH.TGRDFELLOW_BUDGET%ROWTYPE;
v_budget_list t_budget_list:=empty_budget_list;
begin
--If unique=null, new fellowship = one empty row
--If unique is not null but budget_year is null  -- display all budget years for the fellowship + one empty row
--If unique is not null and budget year is not null -- display all budget years, with the requested budget year as editable
  htp.header(3,'Budget Year Account Details',null,null,null,'style="color:#0000CC;"');
  htp.print('<TABLE id="budgetTable" width=100% border="1">');
    htp.tablerowopen;
      htp.tableheader('Budget Year');
      htp.tableheader('SAP Acct Fund');
      --htp.tableheader('SAP Acct Internal Order');       -- removed by vinod 10/7/2013
      --htp.tableheader('SAP Acct Resp Cost Center');     -- removed by vinod 10/7/2013
      htp.tableheader('SAP Acct Resp Cost Center');       -- added by vinod 10/7/2013
      htp.tableheader('SAP Acct Internal Order');         -- added by vinod 10/7/2013
      htp.tableheader('Grant Account');
      if upper(in_action)='DISP' then
        htp.tableheader('Delete selected');
      else
        htp.tableheader;
      end if;
    htp.tablerowclose;
    
    v_stmt:='Select * from GRADSCH.TGRDFELLOW_BUDGET ';
    v_stmt:=v_stmt||' where fbg_seqnum='||in_seqnum;
    v_stmt:=v_stmt||' and fbg_unique'|| case when in_unique is null then ' is null ' else ' = '||in_unique end;
    v_stmt:=v_stmt||' order by fbg_budget_year';
    
    --insert into cand_audit_log values(v_stmt,systimestamp);
    open v_cur_list for v_stmt;
    loop
      fetch v_cur_list into v_TGRDFELLOW_BUDGET;
      exit when v_cur_list%notfound;
      if(v_TGRDFELLOW_BUDGET.fbg_budget_year != NVL(in_budget_year,'9999-99')) then
        htp.tablerowopen;
          htp.tabledata(v_TGRDFELLOW_BUDGET.fbg_budget_year);
          htp.tabledata(NVL(v_TGRDFELLOW_BUDGET.FBG_SAP_ACCT_FUND,'&nbsp;'));
          --htp.tabledata(NVL(v_TGRDFELLOW_BUDGET.FBG_SAP_ACCT_INTERNAL_ORDER,'&nbsp;'));         -- removed by vinod 10/7/2013
          --htp.tabledata(NVL(v_TGRDFELLOW_BUDGET.FBG_SAP_ACCT_RESP_COST_CENTER,'&nbsp;'));       -- removed by vinod 10/7/2013
          htp.tabledata(NVL(v_TGRDFELLOW_BUDGET.FBG_SAP_ACCT_RESP_COST_CENTER,'&nbsp;'));         -- added by vinod 10/7/2013
          htp.tabledata(NVL(v_TGRDFELLOW_BUDGET.FBG_SAP_ACCT_INTERNAL_ORDER,'&nbsp;'));           -- added by vinod 10/7/2013
          htp.tabledata(NVL(v_TGRDFELLOW_BUDGET.FBG_GRANT_ACCT,'&nbsp;'));
          if upper(in_action)='DISP' then
            htp.tabledata(htf.formcheckbox('in_budget_delete',v_TGRDFELLOW_BUDGET.fbg_budget_year));
          else
            htp.tabledata(' ');
          end if;
        htp.tablerowclose;
      else
        htp.tablerowopen(null,null,null,null,'style="background-color:#FF85C2;"');
          htp.tabledata(v_TGRDFELLOW_BUDGET.fbg_budget_year);
          htp.tabledata(htf.formText('in_FBG_SAP_ACCT_FUND',20,20,v_TGRDFELLOW_BUDGET.FBG_SAP_ACCT_FUND));
          --htp.tabledata(htf.formText('in_FBG_SAP_ACCT_INTERNAL_ORDER',20,20,v_TGRDFELLOW_BUDGET.FBG_SAP_ACCT_INTERNAL_ORDER));   -- removed by vinod 10/7/2013
          --htp.tabledata(htf.formText('in_FBG_SAP_ACCT_RESP_CC',20,20,v_TGRDFELLOW_BUDGET.FBG_SAP_ACCT_RESP_COST_CENTER));        -- removed by vinod 10/7/2013
          htp.tabledata(htf.formText('in_FBG_SAP_ACCT_RESP_CC',20,20,v_TGRDFELLOW_BUDGET.FBG_SAP_ACCT_RESP_COST_CENTER));          -- added by vinod 10/7/2013
          htp.tabledata(htf.formText('in_FBG_SAP_ACCT_INTERNAL_ORDER',20,20,v_TGRDFELLOW_BUDGET.FBG_SAP_ACCT_INTERNAL_ORDER));     -- added by vinod 10/7/2013       
          htp.tabledata(htf.formText('in_FBG_GRANT_ACCT',20,20,v_TGRDFELLOW_BUDGET.FBG_GRANT_ACCT));
           htp.tabledata(' ');
        htp.tablerowclose;
      end if;
    end loop;
    close v_cur_list;
    
    if upper(in_action)='CREATE' and in_budget_year is null then --create new budget_year
      htp.tablerowopen(null,null,null,null,'style="background-color:#FF85C2;"');
      htp.tabledata(wps_shared.get_academic_years_selectlist('in_fbg_budget_year',null,20,TO_CHAR(to_number(TO_CHAR(sysdate,'yyyy'))-10)));
      htp.tabledata(htf.formText('in_FBG_SAP_ACCT_FUND',20,20));
      htp.tabledata(htf.formText('in_FBG_SAP_ACCT_INTERNAL_ORDER',20,20));
      htp.tabledata(htf.formText('in_FBG_SAP_ACCT_RESP_CC',20,20));
      htp.tabledata(htf.formText('in_FBG_GRANT_ACCT',20,20));
       htp.tabledata(' ');
      htp.tablerowclose;
    end if;
    
  htp.tableclose;
end;



--Author ; Jolene Singh
--Fuction : Display session details module.
--          If create new: display three new blocks
--          If update academic year : display three blocks with existing information
--          If update one session : display one block with existing information
-- Modifications
-- 05/31/2013 Romina    : Modified to allow decimal numbers in "Total Months Paid" field

procedure print_session_details (in_var1 in number default 0,
                              in_var2 in number default 0,
                              in_seqnum in number default 0,
                              in_unique in number default null,
                              in_acadyear in varchar2 default null,
                              in_session in number default null,
                              in_action in varchar2 default 'CREATE')
is
i number default 1;
v_stmt varchar2(32767);
type t_cur_ref is ref cursor;
v_cur_list t_cur_ref;
v_tgrdfellow_sess GRADSCH.TGRDFELLOW_SESS%ROWTYPE;
v_session_literal TGRDREFER.REF_LITERAL%TYPE;
begin
  --If in_session is not null, display one session
  --if in_session is null, but in_acadyear is not null, display all three sessions
  --If acad_year is null and session is null, then this is a create new fellowship page. Display all three rows with null values.
  htp.header(3,'Session Details',null,null,null,'style="color:#0000CC;"');
  /*if in_session is not null then
    select * into v_tgrdfellow_sess 
    from GRADSCH.TGRDFELLOW_SESS
    where fls_seqnum=in_seqnum
    and fls_unique=in_unique
    and fls_session=in_session
    and fls_calyear=case in_session when 10 then substr(in_acadyear,1,4) else substr(in_acadyear,1,4)+1 end;
    */
    
  for i in 1..3 loop
    v_stmt:='select * from GRADSCH.TGRDFELLOW_SESS ';
    v_stmt:=v_stmt||' where fls_seqnum = '||in_seqnum;
    v_stmt:=v_stmt||' and fls_unique '||case when in_unique is null then 'is null ' else '='||in_unique end;
    if(in_acadyear is not null) then
      v_stmt:=v_stmt||' and fls_calyear||fls_session in ('||substr(in_acadyear,1,4)||'10'||','||(substr(in_acadyear,1,4)+1)||'20'||','||(substr(in_acadyear,1,4)+1)||'30'||')';
    end if;
    if(in_session is not null) then
      v_stmt:=v_stmt||' and fls_session = '||in_session;
    elsif (in_acadyear is not null) then
      v_stmt:=v_stmt||' and fls_session = '||case i when 1 then 10 when 2 then 20 else 30 end;
    end if;
    --v_stmt:=v_stmt||' order by fls_session)';
    --v_stmt:=v_stmt||' where rownum='||i;
    
    --insert into cand_audit_log values (v_stmt,systimestamp);
    --dbms_output.put_line(v_stmt);
    
    open v_cur_list for v_stmt;
    fetch v_cur_list into v_tgrdfellow_sess;
    if(v_cur_list%notfound) then
      v_tgrdfellow_sess:=null;
    end if;
    htp.print('<div name='||i||' style="border-width:3px; border-color:#CED8F6; border-style:double">');
      htp.print('<TABLE width=100% border="1">');
        htp.tablerowopen(null,null,null,null,'style="background-color:#CED8F6;"');
          if lower(in_action)='create' then
            htp.tableheader('Term '||selectlist_tgrdrefer('in_FLS_session_'||i,v_tgrdfellow_sess.fls_session,'term')||'&nbsp;&nbsp;&nbsp;&nbsp;'
                          --||'Cal. Year <input type="text" id="in_FLS_calyear_'||i||'" name="in_FLS_calyear_'||i||'" size="4" maxlength="4" value="'||v_tgrdfellow_sess.fls_calyear||'">'||
                          ||'Cal. Year '||get_years_selectlist('in_FLS_calyear_'||i,v_tgrdfellow_sess.fls_calyear,15,to_char(sysdate,'YYYY')-5)||
                          --get_years_selectlist
                          'Status '||selectlist_tgrdrefer('in_FLS_status_'||i,v_tgrdfellow_sess.fls_status,'fellowship_status'),null,null,null,null,2);
          else
            htp.formhidden('in_FLS_session_'||i,v_tgrdfellow_sess.fls_session);
            htp.formhidden('in_FLS_calyear_'||i,v_tgrdfellow_sess.fls_calyear);
            htp.tableheader('Term '||case v_tgrdfellow_sess.fls_session when 10 then 'Fall' when 20 then 'Spring' else 'Summer' end||'&nbsp;&nbsp;&nbsp;&nbsp;'
                          ||'Cal. Year '||v_tgrdfellow_sess.fls_calyear||'&nbsp;&nbsp;&nbsp;&nbsp;'||
                          'Status '||selectlist_tgrdrefer('in_FLS_status_'||i,v_tgrdfellow_sess.fls_status,'fellowship_status'),null,null,null,null,2);
          end if;                        
          htp.tableheader('Principal Investigator '||htf.formtext('in_FLS_PRIN_INVESTIGATOR_'||i,10,20,v_tgrdfellow_sess.FLS_PRIN_INVESTIGATOR,'id="in_FLS_PRIN_INVESTIGATOR_'||i||'"'),null,null,null,null,2);
          htp.tableheader('Budget year '||selectlist_acadyear('in_FLS_budget_year_'||i,v_tgrdfellow_sess.fls_budget_year),null,null,null,null,2);
          if(i>1) then
            htp.tableheader('<input type="button" value="Copy from previous" onClick="CopyFromPrevious('||i||')">',null,null,null,null,2);
          else
            htp.tableheader('&nbsp;',null,null,null,null,2);
          end if;
        htp.tablerowclose;
        
        htp.tablerowopen;--(null,null,null,null,'style="background-color:#A4A4A4;"') ;
          htp.tableheader('Tuition',null,null,null,null,2);
          htp.tableheader('Fees',null,null,null,null,6);
        htp.tablerowclose;
        
        htp.tablerowopen;
          htp.tabledata('Fellowship'||htf.nl||selectlist_tgrdrefer('in_FLS_TUIT_'||i,v_tgrdfellow_sess.fls_tuit,'fellowship_tuit_code'));
          htp.tabledata('Assistantship'||htf.nl||selectlist_tgrdrefer('in_FLS_ADMIN_ASST_'||i,v_tgrdfellow_sess.fls_admin_asst,'fellowship_tuit_code'));
          htp.tabledata('Grad Appt'||htf.nl||selectlist_tgrdrefer('in_FLS_GRAD_APPT_FEE_'||i,v_tgrdfellow_sess.fls_grad_appt_fee,'fellowship_tuit_code'));
          htp.tabledata('Tech'||htf.nl||selectlist_tgrdrefer('in_FLS_TECH_FEE_'||i,v_tgrdfellow_sess.fls_tech_fee,'fellowship_tuit_code'));
          htp.tabledata('R &amp; R'||htf.nl||selectlist_tgrdrefer('in_FLS_R_AND_R_FEE_'||i,v_tgrdfellow_sess.fls_R_AND_R_FEE,'fellowship_tuit_code'));
          htp.tabledata('International'||htf.nl||selectlist_tgrdrefer('in_FLS_INTERNATIONAL_FEE_'||i,v_tgrdfellow_sess.fls_INTERNATIONAL_FEE,'fellowship_tuit_code'));
          htp.tabledata('Differential'||htf.nl||selectlist_tgrdrefer('in_FLS_DIFFERENTIAL_FEE_'||i,v_tgrdfellow_sess.FLS_DIFFERENTIAL_FEE,'fellowship_tuit_code'));
          htp.tabledata('Wellness'||htf.nl||selectlist_tgrdrefer('in_FLS_WELLNESS_FEE_'||i,v_tgrdfellow_sess.FLS_WELLNESS_FEE,'fellowship_tuit_code'));
        htp.tablerowclose;
        
        --List Tuit code instructions
        htp.tablerowopen;
          htp.print('<TD colspan=8>');
          htp.print('</TD>');
        htp.tablerowclose;
        
        htp.tablerowopen;--(null,null,null,null,'style="background-color:#A4A4A4;"') ;
          htp.tableheader('Supplementary Award Info',null,null,null,null,2);
          htp.tableheader('Medical Insurance',null,null,null,null,3);
          htp.tableheader('Stipend Calculations',null,null,null,null,3);
        htp.tablerowclose;
        
        htp.tablerowopen;
          htp.tabledata('Will this award be supplemented'||htf.nl||
                        htf.formRadio('in_FLS_SUPP_'||i,'N',case v_tgrdfellow_sess.fls_supp when 'N' then 'CHECKED' else null end, 'id="in_FLS_SUPP_N_'||i||'" onClick="update_supp_amt('''||i||''');update_annual_stipend('''||i||''');update_monthly_stipend('''||i||''')"')||' No'||htf.nl||
                        htf.formRadio('in_FLS_SUPP_'||i,'Y',case v_tgrdfellow_sess.fls_supp when 'Y' then 'CHECKED' when 'P' then 'CHECKED' when 'O' then 'CHECKED' else null end, 'id="in_FLS_SUPP_Y_'||i||'" onClick="update_supp_amt('''||i||''');update_annual_stipend('''||i||''');update_monthly_stipend('''||i||''')"')||' Yes'||--htf.nl||
                        '&nbsp;&nbsp;&nbsp;&nbsp'||htf.formtext('in_FLS_SUPP_PAYROLL_AMT_'||i,10,20,case v_tgrdfellow_sess.fls_supp when 'O' then v_tgrdfellow_sess.FLS_SUPP_OTHER_FUND_AMT else v_tgrdfellow_sess.FLS_SUPP_PAYROLL_AMT end,'id="in_FLS_SUPP_PAYROLL_AMT_'||i||'" onkeypress="return isAmountKey(event);" onChange="update_supp_amt('''||i||''');update_annual_stipend('''||i||''');update_monthly_stipend('''||i||''')"')--||htf.nl||
                        --htf.formRadio('in_FLS_SUPP_'||i,'O',case v_tgrdfellow_sess.fls_supp when 'O' then 'CHECKED' else null end, 'id="in_FLS_SUPP_O_'||i||'"')||' Other'||htf.nl||
                        --'&nbsp;&nbsp;&nbsp;&nbsp;Acct&nbsp;&nbsp;&nbsp;'||htf.formtext('in_FLS_SUPP_OTHER_FUND_ACCT_'||i,10,20,v_tgrdfellow_sess.FLS_SUPP_OTHER_FUND_ACCT,'id="in_FLS_SUPP_OTHER_FUND_ACCT_'||i||'"')||htf.nl||
                        --'&nbsp;&nbsp;&nbsp;&nbsp;Amt&nbsp;&nbsp;&nbsp;&nbsp;'||htf.formtext('in_FLS_SUPP_OTHER_FUND_AMT_'||i,10,20,v_tgrdfellow_sess.FLS_SUPP_OTHER_FUND_AMT,'id="in_FLS_SUPP_OTHER_FUND_AMT_'||i||'"')
                        ,null,null,null,null,2);
          htp.print('<TD colspan="3">');
            htp.tableopen(null,null,null,null,'style="width=100%"');
              htp.tablerowopen;
                htp.tabledata('How will it be handled?');
                --htp.tabledata(htf.formtext('in_FLS_MED_INSURANCE_'||i,10,20,v_tgrdfellow_sess.FLS_MED_INSURANCE,'id="in_FLS_MED_INSURANCE_'||i||'"'));
                htp.tabledata(get_med_insurance_selectlist('in_FLS_MED_INSURANCE_'||i,v_tgrdfellow_sess.FLS_MED_INSURANCE,'onChange="update_fringe_benefits('''||i||''');update_annual_stipend('''||i||''')"'));
              htp.tablerowclose;
              htp.tablerowopen;
                htp.tabledata('Amount');
                htp.tabledata(htf.formtext('in_FLS_MED_AMT_'||i,10,20,v_tgrdfellow_sess.FLS_MED_AMT,'id="in_FLS_MED_AMT_'||i||'" onkeypress="return isAmountKey(event);" onChange="update_total_insurance('''||i||''');update_annual_stipend('''||i||''');update_award_amt('''||i||''')"'));--onBlur="document.getElementById(in_FLS_MED_INSURANCE_'||i||').value =123"'));
              htp.tablerowclose;
              htp.tablerowopen;
                htp.tabledata('Comments');
                htp.tabledata(htf.formTextareaOpen('in_FLS_MED_INSURANCE_COMMENT_'||i,5,10,null,'id="in_FLS_MED_INSURANCE_COMMENT_'||i||'" style="width: 100%; "')||v_tgrdfellow_sess.FLS_MED_INSURANCE_COMMENT||htf.formTextareaClose);
              htp.tablerowclose;
            htp.tableclose;
          htp.print('</td>');
          
          htp.print('<TD colspan="3">');
            htp.tableopen(null,null,null,null,'style="width=100%"');
              htp.tablerowopen;
                htp.tabledata('Total Sponsor Stipend');
                htp.tabledata(htf.formtext('in_FLS_TOTAL_SPONSOR_STIPEND_'||i,10,20,v_tgrdfellow_sess.fls_total_sponsor_stipend,'id="in_FLS_TOTAL_SPONSOR_STIPEND_'||i||'" onkeypress="return isAmountKey(event);" onChange="update_fringe_benefits('''||i||''');update_annual_stipend('''||i||''');update_monthly_stipend('''||i||''');update_award_amt('''||i||''')"  '));
              htp.tablerowclose;
              htp.tablerowopen;
                htp.tabledata('Supp Amt');
                htp.tabledata(htf.formtext('in_FLS_SUPP_AMOUNT_'||i,10,20,v_tgrdfellow_sess.FLS_SUPP_AMOUNT,'id="in_FLS_SUPP_AMOUNT_'||i||'" onkeypress="return isAmountKey(event);"'));  
              htp.tablerowclose;
              htp.tablerowopen;
                htp.tabledata('Fringe Benefits');
                htp.tabledata(htf.formtext('in_FLS_FRINGE_BENEFIT_AMOUNT_'||i,10,20,v_tgrdfellow_sess.FLS_FRINGE_BENEFIT_AMOUNT,'id="in_FLS_FRINGE_BENEFIT_AMOUNT_'||i||'" onkeypress="return isAmountKey(event);"'));  
              htp.tablerowclose;
              htp.tablerowopen;
                htp.tabledata('Total Insurance');
                htp.print('<TD id="in_FLS_TOTAL_INSURANCE_'||i||'" >'||NVL(to_char(v_tgrdfellow_sess.FLS_MED_AMT),'0')||'</TD>');
              htp.tablerowclose;
              htp.tablerowopen;
                htp.tabledata('Total Annual Stipend');
                htp.tabledata(htf.formtext('in_FLS_ANNUAL_STIPEND_'||i,10,20,v_tgrdfellow_sess.FLS_ANNUAL_STIPEND,'id="in_FLS_ANNUAL_STIPEND_'||i||'" onkeypress="return isAmountKey(event);"'));
              htp.tablerowclose;
              htp.tablerowopen;
                htp.tabledata('Total Months Paid');
                -- Romina: isNumberKey is replaced by isAmountKey to allow decimal numbers
                htp.tabledata(htf.formtext('in_FLS_MONTHS_STIPEND_'||i,10,20,v_tgrdfellow_sess.FLS_MONTHS_STIPEND,'id="in_FLS_MONTHS_STIPEND_'||i||'" onkeypress="return isAmountKey(event);" onChange="update_monthly_stipend('''||i||''');"'));  -- added by romina 05/31/2013
                  -- htp.tabledata(htf.formtext('in_FLS_MONTHS_STIPEND_'||i,10,20,v_tgrdfellow_sess.FLS_MONTHS_STIPEND,'id="in_FLS_MONTHS_STIPEND_'||i||'" onkeypress="return isNumberKey(event);" onChange="update_monthly_stipend('''||i||''');"')); -- removed by romina 05/31/2013
              htp.tablerowclose;
              htp.tablerowopen;
                htp.tabledata('Total Monthly Stipend');
                htp.tabledata(htf.formtext('in_FLS_MONTHLY_STIPEND_'||i,10,20,v_tgrdfellow_sess.FLS_MONTHLY_STIPEND,'id="in_FLS_MONTHLY_STIPEND_'||i||'" onkeypress="return isAmountKey(event);"'));
              htp.tablerowclose;
              htp.tablerowopen;
                htp.tabledata('Total Award Amount');
                htp.tabledata(htf.formtext('in_FLS_TOTAL_AWARD_AMOUNT_'||i,10,20,v_tgrdfellow_sess.FLS_TOTAL_AWARD_AMOUNT,'id="in_FLS_TOTAL_AWARD_AMOUNT_'||i||'" onkeypress="return isAmountKey(event);"'));
              htp.tablerowclose;
         
            htp.tableclose;
          htp.print('</TD>');
          htp.tablerowopen;   -- Added By Vinod on 11/12/2013 for remarks field
                htp.tabledata('Remarks');  -- Added By Vinod on 11/12/2013 for remarks field
                htp.tabledata(htf.formTextareaOpen('in_FLS_REMARKS_'||i,5,10,null,'id="in_FLS_REMARKS_'||i||'" style="width: 100%; "')||v_tgrdfellow_sess.FLS_REMARKS||htf.formTextareaClose);  -- Added By Vinod on 11/12/2013 for remarks field
              htp.tablerowclose; -- Added By Vinod on 11/12/2013 for remarks field
        htp.tablerowclose;
      htp.tableclose;
      htp.print('</div>');

      --i:=i+1;
      htp.nl;
      htp.nl;
      if v_tgrdfellow_sess.fls_status in ('WITHDRAWN','DECLINED','GRADUATED') then
        close v_cur_list;
        exit;
      else
        close v_cur_list;
      end if;
      
      if in_session is not null then --exit after first row
        exit;
      end if; 
  end loop;
end;

--Author: Jolene Singh
--Function: Displays book-keeping module. Simply asks if its a new form and inputs dates.
procedure print_form_questions (in_var1 in number default 0,
                              in_var2 in number default 0,
                              in_seqnum in number default 0,
                              in_unique in number default null)
IS
BEGIN
htp.header(3,'Book-keeping',null,null,null,'style="color:#0000CC;"');
htp.tableopen;
htp.tablerowopen;
htp.tabledata('Is this a new form90?&nbsp;&nbsp;&nbsp;&nbsp;'||htf.formCheckbox('in_new_form','YES'));
htp.tabledata('Form Begin Date');
htp.tabledata(htf.formText('in_form_begin_date',10,10,null,'id="in_form_begin_date" onchange="check_date(this,this.value)"'));
htp.tabledata('Form End Date');
htp.tabledata(htf.formText('in_form_end_date',10,10,null,'id="in_form_end_date" onchange="check_date(this,this.value)"'));
htp.tablerowclose;
htp.tableclose;
htp.print('The form begin&#47;end dates will be ignored if the checkbox is not checked');
END;



--Author: Jolene Singh
--Funtion: This contains the form open and close tags for displaying "create new fellowship page" and essentially calls the 5 display
--          modules as required.
procedure create_fellowship( in_var1 in number default 0,
                          in_var2 in number default 0,
                          in_seqnum in number default 0
                          )
IS
cur_user twwwuser1%rowtype;
cur_base tgrdbase%rowtype;

cursor base_data is
select * from tgrdbase
where b_seqnum=in_seqnum;

BEGIN
  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is  null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;
  open base_data;
  fetch base_data into cur_base;
  if (base_data%notfound) then
    close base_data;
    wgb_lists.disp_qry_appl(1015 , in_var1, in_var2, cur_base.b_puid, cur_base.b_sid,
                          null, null, null, null,
                          null, null, null, null,
                          null);
    return;
  end if;
  close base_data;
  
  wgb_shared.form_start('Graduate School Intranet Database');
  -- insert body tags and toolbar
  wgb_shared.body_start2('Create New Fellowship',null,null, in_var1,in_var2, cur_user);
  
  --Add javascript calls
  wgb_shared.print_java_date();
  wgb_shared.print_java_numeric;
  print_java_copy_from_previous();
  print_java_alert();
  --Add all application specific code here
  print_student_details(in_seqnum);
  htp.formopen('www_rgs.wfl_fellowship.proc_create_fellowship','POST');
    htp.formhidden('in_var1',in_var1);
    htp.formhidden('in_var2',in_var2);
    htp.formhidden('in_seqnum',in_seqnum);
    print_fellowship_details(in_var1,in_var2,in_seqnum,null);
    print_budget_details(in_var1,in_var2,in_seqnum,null,null,'CREATE');
    print_session_details(in_var1,in_var2,in_seqnum,null,null,null,'CREATE');
    print_form_questions(in_var1,in_var2,in_seqnum,null);
  htp.nl;
  htp.formsubmit('in_action','Create','onClick="return check_basecode()"');
  htp.print('&nbsp;&nbsp;');
  htp.formsubmit('in_action','Cancel');
  htp.formclose;
  --Code ends here
  htp.bodyClose;
  htp.htmlClose;
END;

--Author: Jolene Singh
--Function: Resets the budget year assignment to sessions based on the business rules
--          1. Based on award year(AY) and duration(n) we will have n budget years with the fellowship strating from AY
--          2. Each budget year can support two major sessions(Fall/Spring) and one minor session(Summer)
--          3. Starting from the first session, this procedure asisgns budget years in increasing order to consecutively available
--          sessions that are not on HOLD.
procedure reset_sessions(in_seqnum in number default 0,
                         in_unique in number default 1)
is
v_flb_duration GRADSCH.TGRDFELLOW_BASE.FLB_DURATION%TYPE;
v_flb_award_year GRADSCH.TGRDFELLOW_BASE.FLB_AWARD_YEAR%TYPE;
v_fbg_budget_year GRADSCH.TGRDFELLOW_BUDGET.FBG_BUDGET_YEAR%TYPE;
v_count number default 0;
begin
  --First clear all budget year assignments
  --This will remove any previous assignments to sessions on HOLD
  update GRADSCH.TGRDFELLOW_SESS
  set fls_budget_year=null
  where fls_seqnum=in_seqnum
  and fls_unique=in_unique;
  
  --Now check if all budget years exist
  select flb_duration, flb_award_year into v_flb_duration, v_flb_award_year
  from GRADSCH.TGRDFELLOW_BASE
  where flb_seqnum=in_seqnum
  and flb_unique=in_unique;
  
  if v_flb_award_year is not null AND v_flb_duration is not null then
    for i in 0..v_flb_duration-1 loop
      v_fbg_budget_year:=(substr(v_flb_award_year,1,4)+i)||'-'||lpad((substr(v_flb_award_year,6,2)+i),2,'0');
      select count(*) into v_count
      from GRADSCH.TGRDFELLOW_BUDGET
      where fbg_seqnum=in_seqnum
      and fbg_unique=in_unique
      and fbg_budget_year=v_fbg_budget_year;
           
      if v_count=0 then
        insert into GRADSCH.TGRDFELLOW_BUDGET 
        (FBG_SEQNUM,FBG_UNIQUE,FBG_BUDGET_YEAR)
        values
        (in_seqnum,in_unique,v_fbg_budget_year);
      end if;
    end loop;
  end if;
  
  for each_session in (select * from GRADSCH.TGRDFELLOW_SESS
                       where fls_seqnum=in_seqnum
                       and fls_unique=in_unique
                       and upper(NVL(fls_status,'HOLD'))!='HOLD' 
                       order by fls_calyear,decode(fls_session,20,1,30,2,10,3))
  loop
    exit when upper(each_session.fls_status)in ('WITHDRAWN','DECLINED','GRADUATED') ;
    
    if each_session.fls_session in (10,20) then --major session
      update GRADSCH.TGRDFELLOW_SESS s1
      set s1.fls_budget_year=(select min(fbg_budget_year) 
                              from GRADSCH.TGRDFELLOW_BUDGET
                              left join (select s2.fls_seqnum, s2.fls_unique, s2.fls_budget_year, count(*) as fls_count
                                        from GRADSCH.TGRDFELLOW_SESS s2
                                        where s2.fls_session in (10,20)
                                        group by s2.fls_seqnum, s2.fls_unique, s2.fls_budget_year) s3
                              on s3.fls_seqnum=fbg_seqnum
                              and s3.fls_unique=fbg_unique
                              and s3.fls_budget_year=fbg_budget_year
                              where fbg_seqnum=in_seqnum
                              and fbg_unique=in_unique
                              and NVL(fls_count,0)<2)
      where s1.fls_seqnum=in_seqnum
      and s1.fls_unique=in_unique
      and s1.fls_calyear=each_session.fls_calyear
      and s1.fls_session=each_session.fls_session;
    else
      update GRADSCH.TGRDFELLOW_SESS s1
      set s1.fls_budget_year=(select min(fbg_budget_year) 
                              from GRADSCH.TGRDFELLOW_BUDGET
                              left join (select s2.fls_seqnum, s2.fls_unique, s2.fls_budget_year, count(*) as fls_count
                                        from GRADSCH.TGRDFELLOW_SESS s2
                                        where s2.fls_session = 30
                                        group by s2.fls_seqnum, s2.fls_unique, s2.fls_budget_year) s3
                              on s3.fls_seqnum=fbg_seqnum
                              and s3.fls_unique=fbg_unique
                              and s3.fls_budget_year=fbg_budget_year
                              where fbg_seqnum=in_seqnum
                              and fbg_unique=in_unique
                              and NVL(fls_count,0)<1)
      where s1.fls_seqnum=in_seqnum
      and s1.fls_unique=in_unique
      and s1.fls_calyear=each_session.fls_calyear
      and s1.fls_session=each_session.fls_session;
    end if; 
  end loop;
end;

--Author: Jolene Singh
--Function: Whenever a session is placed on HOLD, this function add a new session to the fellowship and marks it as EXPECTED
-- Modifications:
-- 11/17/2014 Shanmukesh Made changes to copy data from one session to another when a session is kept on hold
procedure extend_for_hold( in_seqnum in number default 0,
                           in_unique in number default 1,
                           in_calyear in number default 0,
                           in_session in number default 0
                          )
is
v_max_calyear GRADSCH.TGRDFELLOW_SESS.FLS_CALYEAR%TYPE;
v_max_session GRADSCH.TGRDFELLOW_SESS.FLS_SESSION%TYPE;
v_mid_calyear GRADSCH.TGRDFELLOW_SESS.FLS_CALYEAR%TYPE;
v_mid_session GRADSCH.TGRDFELLOW_SESS.FLS_SESSION%TYPE;
v_last_status GRADSCH.TGRDFELLOW_SESS.FLS_STATUS%TYPE;
v_count number default 0;
v_each_row GRADSCH.TGRDFELLOW_SESS%ROWTYPE; -- added 11/17/2014
begin

  select * into v_each_row
  from TGRDFELLOW_SESS
  where fls_session = in_session
  and fls_calyear= in_calyear
  and fls_seqnum=in_seqnum
  and fls_unique=in_unique; -- added 11/17/2014
  
  select 
  substr(max(fls_calyear||decode(fls_session,20,1,30,2,10,3)),1,4), 
  decode(substr(max(fls_calyear||decode(fls_session,20,1,30,2,10,3)),5),1,20,2,30,3,10)
  into v_max_calyear,v_max_session
  from GRADSCH.TGRDFELLOW_SESS
  where fls_seqnum=in_seqnum
  and fls_unique=in_unique
  and fls_calyear||decode(fls_session,20,1,30,2,10,3) >= in_calyear||decode(in_session,20,1,30,2,10,3)
  and fls_status is not null;
  
  --Check if between the last non-null session and the current session there is any session which is null due to maybe a previous summer hold
  select count(*) into v_count
  from GRADSCH.TGRDFELLOW_SESS
  where fls_seqnum=in_seqnum
  and fls_unique=in_unique
  and fls_calyear||decode(fls_session,20,1,30,2,10,3) > in_calyear||decode(in_session,20,1,30,2,10,3)
  and fls_calyear||decode(fls_session,20,1,30,2,10,3) < v_max_calyear||decode(v_max_session,20,1,30,2,10,3)
  and ((in_session in (10,20) and fls_session in (10,20)) OR (in_session=30 and fls_session=30))
  and fls_status is null;
  
  
  if v_count>0 then
    select substr(min(fls_calyear||decode(fls_session,20,1,30,2,10,3)),1,4), 
    decode(substr(min(fls_calyear||decode(fls_session,20,1,30,2,10,3)),5),1,20,2,30,3,10)
    into v_mid_calyear,v_mid_session
    from GRADSCH.TGRDFELLOW_SESS
    where fls_seqnum=in_seqnum
    and fls_unique=in_unique
    and fls_calyear||decode(fls_session,20,1,30,2,10,3) > in_calyear||decode(in_session,20,1,30,2,10,3)
    and ((in_session in (10,20) and fls_session in (10,20)) OR (in_session=30 and fls_session=30))
    and fls_status is null; 
    
    
    update GRADSCH.TGRDFELLOW_SESS 
    set fls_status='EXPECTED'
    -- added 11/17/2014 Start
            ,FLS_TUIT_ONLY						=v_each_row.FLS_TUIT_ONLY
            ,FLS_TUIT_AIDCODE					=v_each_row.FLS_TUIT_AIDCODE
            ,FLS_TUIT_CHRG_SCH				=v_each_row.FLS_TUIT_CHRG_SCH
            ,FLS_TUIT							    =v_each_row.FLS_TUIT
            ,FLS_ADMIN_ASST						=v_each_row.FLS_ADMIN_ASST
            ,FLS_GRAD_APPT_FEE				=v_each_row.FLS_GRAD_APPT_FEE
            ,FLS_TECH_FEE						  =v_each_row.FLS_TECH_FEE
            ,FLS_R_AND_R_FEE					=v_each_row.FLS_R_AND_R_FEE
            ,FLS_INTERNATIONAL_FEE		=v_each_row.FLS_INTERNATIONAL_FEE
            ,FLS_DIFFERENTIAL_FEE			=v_each_row.FLS_DIFFERENTIAL_FEE
            ,FLS_WELLNESS_FEE					=v_each_row.FLS_WELLNESS_FEE
            ,FLS_SUPP							    =v_each_row.FLS_SUPP
            ,FLS_SUPP_PAYROLL_AMT			=v_each_row.FLS_SUPP_PAYROLL_AMT
            ,FLS_SUPP_OTHER_FUND_ACCT	=v_each_row.FLS_SUPP_OTHER_FUND_ACCT
            ,FLS_SUPP_OTHER_FUND_AMT	=v_each_row.FLS_SUPP_OTHER_FUND_AMT
            ,FLS_MED_INSURANCE				=v_each_row.FLS_MED_INSURANCE
            ,FLS_MED_AMT						  =v_each_row.FLS_MED_AMT
            ,FLS_MED_INSURANCE_COMMENT			=v_each_row.FLS_MED_INSURANCE_COMMENT
            ,FLS_TOTAL_SPONSOR_STIPEND			=v_each_row.FLS_TOTAL_SPONSOR_STIPEND
            ,FLS_SUPP_AMOUNT					      =v_each_row.FLS_SUPP_AMOUNT
            ,FLS_FRINGE_BENEFIT_AMOUNT			=v_each_row.FLS_FRINGE_BENEFIT_AMOUNT
            ,FLS_ANNUAL_STIPEND					    =v_each_row.FLS_ANNUAL_STIPEND
            ,FLS_MONTHS_STIPEND					    =v_each_row.FLS_MONTHS_STIPEND
            ,FLS_MONTHLY_STIPEND				    =v_each_row.FLS_MONTHLY_STIPEND
            ,FLS_TOTAL_AWARD_AMOUNT				  =v_each_row.FLS_TOTAL_AWARD_AMOUNT
            ,FLS_BUDGET_YEAR					      =v_each_row.FLS_BUDGET_YEAR
            ,FLS_PRIN_INVESTIGATOR				  =v_each_row.FLS_PRIN_INVESTIGATOR
            ,FLS_CALTERM						        =v_each_row.FLS_CALTERM
            ,FLS_BANTERM						        =v_each_row.FLS_BANTERM
            ,FLS_REMARKS						        =v_each_row.FLS_REMARKS
           -- added 11/17/2014 End
    where fls_session=v_mid_session
    and fls_calyear=v_mid_calyear
    and fls_seqnum=in_seqnum
    and fls_unique=in_unique;
  else
  
    select fls_status into v_last_status
    from GRADSCH.TGRDFELLOW_SESS
    where fls_seqnum=in_seqnum
    and fls_unique=in_unique
    and fls_calyear=v_max_calyear
    and fls_session=v_max_session;
    --If a fellowship has been withdrawn, all session after the withdrawn session will have a NULL status
    --therefore, a WITHDRAWN sem HAS to be the last sem with a non-null status in a withdrawn fellowship
    
    
    if v_last_status in ('WITHDRAWN','DECLINED','GRADUATED')  then
      return;
    end if;
    
    if in_session in (10,20) then
      if v_max_session=10 then
        update GRADSCH.TGRDFELLOW_SESS 
        set fls_status='EXPECTED'
           -- added 11/17/2014 Start
            ,FLS_TUIT_ONLY						=v_each_row.FLS_TUIT_ONLY
            ,FLS_TUIT_AIDCODE					=v_each_row.FLS_TUIT_AIDCODE
            ,FLS_TUIT_CHRG_SCH				=v_each_row.FLS_TUIT_CHRG_SCH
            ,FLS_TUIT							    =v_each_row.FLS_TUIT
            ,FLS_ADMIN_ASST						=v_each_row.FLS_ADMIN_ASST
            ,FLS_GRAD_APPT_FEE				=v_each_row.FLS_GRAD_APPT_FEE
            ,FLS_TECH_FEE						  =v_each_row.FLS_TECH_FEE
            ,FLS_R_AND_R_FEE					=v_each_row.FLS_R_AND_R_FEE
            ,FLS_INTERNATIONAL_FEE		=v_each_row.FLS_INTERNATIONAL_FEE
            ,FLS_DIFFERENTIAL_FEE			=v_each_row.FLS_DIFFERENTIAL_FEE
            ,FLS_WELLNESS_FEE					=v_each_row.FLS_WELLNESS_FEE
            ,FLS_SUPP							    =v_each_row.FLS_SUPP
            ,FLS_SUPP_PAYROLL_AMT			=v_each_row.FLS_SUPP_PAYROLL_AMT
            ,FLS_SUPP_OTHER_FUND_ACCT	=v_each_row.FLS_SUPP_OTHER_FUND_ACCT
            ,FLS_SUPP_OTHER_FUND_AMT	=v_each_row.FLS_SUPP_OTHER_FUND_AMT
            ,FLS_MED_INSURANCE				=v_each_row.FLS_MED_INSURANCE
            ,FLS_MED_AMT						  =v_each_row.FLS_MED_AMT
            ,FLS_MED_INSURANCE_COMMENT			=v_each_row.FLS_MED_INSURANCE_COMMENT
            ,FLS_TOTAL_SPONSOR_STIPEND			=v_each_row.FLS_TOTAL_SPONSOR_STIPEND
            ,FLS_SUPP_AMOUNT					      =v_each_row.FLS_SUPP_AMOUNT
            ,FLS_FRINGE_BENEFIT_AMOUNT			=v_each_row.FLS_FRINGE_BENEFIT_AMOUNT
            ,FLS_ANNUAL_STIPEND					    =v_each_row.FLS_ANNUAL_STIPEND
            ,FLS_MONTHS_STIPEND					    =v_each_row.FLS_MONTHS_STIPEND
            ,FLS_MONTHLY_STIPEND				    =v_each_row.FLS_MONTHLY_STIPEND
            ,FLS_TOTAL_AWARD_AMOUNT				  =v_each_row.FLS_TOTAL_AWARD_AMOUNT
            ,FLS_BUDGET_YEAR					      =v_each_row.FLS_BUDGET_YEAR
            ,FLS_PRIN_INVESTIGATOR				  =v_each_row.FLS_PRIN_INVESTIGATOR
            ,FLS_CALTERM						        =v_each_row.FLS_CALTERM
            ,FLS_BANTERM						        =v_each_row.FLS_BANTERM
            ,FLS_REMARKS						        =v_each_row.FLS_REMARKS
           -- added 11/17/2014 End 
        where fls_session=20
        and fls_calyear=v_max_calyear+1
        and fls_seqnum=in_seqnum
        and fls_unique=in_unique;
      else
       
        insert all 
        --into GRADSCH.TGRDFELLOW_SESS (fls_seqnum, fls_unique, fls_calyear, fls_session, fls_status) values (in_seqnum, in_unique, v_max_calyear,10,'EXPECTED') -- removed 11/17/2014
        into GRADSCH.TGRDFELLOW_SESS (FLS_SEQNUM,FLS_UNIQUE,FLS_CALYEAR,FLS_SESSION,FLS_STATUS,FLS_TUIT_ONLY,FLS_TUIT_AIDCODE,FLS_TUIT_CHRG_SCH,FLS_TUIT,FLS_ADMIN_ASST,FLS_GRAD_APPT_FEE,FLS_TECH_FEE,FLS_R_AND_R_FEE,FLS_INTERNATIONAL_FEE,FLS_DIFFERENTIAL_FEE,FLS_WELLNESS_FEE,FLS_SUPP,FLS_SUPP_PAYROLL_AMT,FLS_SUPP_OTHER_FUND_ACCT,FLS_SUPP_OTHER_FUND_AMT,FLS_MED_INSURANCE,FLS_MED_AMT,FLS_MED_INSURANCE_COMMENT,FLS_TOTAL_SPONSOR_STIPEND,FLS_SUPP_AMOUNT,FLS_FRINGE_BENEFIT_AMOUNT,FLS_ANNUAL_STIPEND,FLS_MONTHS_STIPEND,FLS_MONTHLY_STIPEND,FLS_TOTAL_AWARD_AMOUNT,FLS_BUDGET_YEAR,FLS_PRIN_INVESTIGATOR,FLS_CALTERM,FLS_BANTERM,FLS_REMARKS) 
        values (in_seqnum, in_unique, v_max_calyear,10,'EXPECTED',v_each_row.FLS_TUIT_ONLY,v_each_row.FLS_TUIT_AIDCODE,v_each_row.FLS_TUIT_CHRG_SCH,v_each_row.FLS_TUIT,v_each_row.FLS_ADMIN_ASST,v_each_row.FLS_GRAD_APPT_FEE,v_each_row.FLS_TECH_FEE,v_each_row.FLS_R_AND_R_FEE,v_each_row.FLS_INTERNATIONAL_FEE,v_each_row.FLS_DIFFERENTIAL_FEE,v_each_row.FLS_WELLNESS_FEE,v_each_row.FLS_SUPP,v_each_row.FLS_SUPP_PAYROLL_AMT,v_each_row.FLS_SUPP_OTHER_FUND_ACCT,v_each_row.FLS_SUPP_OTHER_FUND_AMT,v_each_row.FLS_MED_INSURANCE,v_each_row.FLS_MED_AMT,v_each_row.FLS_MED_INSURANCE_COMMENT,v_each_row.FLS_TOTAL_SPONSOR_STIPEND,v_each_row.FLS_SUPP_AMOUNT,v_each_row.FLS_FRINGE_BENEFIT_AMOUNT,v_each_row.FLS_ANNUAL_STIPEND,v_each_row.FLS_MONTHS_STIPEND,v_each_row.FLS_MONTHLY_STIPEND,v_each_row.FLS_TOTAL_AWARD_AMOUNT,v_each_row.FLS_BUDGET_YEAR,v_each_row.FLS_PRIN_INVESTIGATOR,v_each_row.FLS_CALTERM,v_each_row.FLS_BANTERM,v_each_row.FLS_REMARKS) -- added 11/17/2014
        into GRADSCH.TGRDFELLOW_SESS (fls_seqnum, fls_unique, fls_calyear, fls_session, fls_status) values (in_seqnum, in_unique, v_max_calyear+1,20,null)
        into GRADSCH.TGRDFELLOW_SESS (fls_seqnum, fls_unique, fls_calyear, fls_session, fls_status) values (in_seqnum, in_unique, v_max_calyear+1,30,null)
        select * from dual;
      end if;
    else
      if v_max_session = 10 then
        update GRADSCH.TGRDFELLOW_SESS 
        set fls_status='EXPECTED'
        -- added 11/17/2014 Start
            ,FLS_TUIT_ONLY						=v_each_row.FLS_TUIT_ONLY
            ,FLS_TUIT_AIDCODE					=v_each_row.FLS_TUIT_AIDCODE
            ,FLS_TUIT_CHRG_SCH				=v_each_row.FLS_TUIT_CHRG_SCH
            ,FLS_TUIT							    =v_each_row.FLS_TUIT
            ,FLS_ADMIN_ASST						=v_each_row.FLS_ADMIN_ASST
            ,FLS_GRAD_APPT_FEE				=v_each_row.FLS_GRAD_APPT_FEE
            ,FLS_TECH_FEE						  =v_each_row.FLS_TECH_FEE
            ,FLS_R_AND_R_FEE					=v_each_row.FLS_R_AND_R_FEE
            ,FLS_INTERNATIONAL_FEE		=v_each_row.FLS_INTERNATIONAL_FEE
            ,FLS_DIFFERENTIAL_FEE			=v_each_row.FLS_DIFFERENTIAL_FEE
            ,FLS_WELLNESS_FEE					=v_each_row.FLS_WELLNESS_FEE
            ,FLS_SUPP							    =v_each_row.FLS_SUPP
            ,FLS_SUPP_PAYROLL_AMT			=v_each_row.FLS_SUPP_PAYROLL_AMT
            ,FLS_SUPP_OTHER_FUND_ACCT	=v_each_row.FLS_SUPP_OTHER_FUND_ACCT
            ,FLS_SUPP_OTHER_FUND_AMT	=v_each_row.FLS_SUPP_OTHER_FUND_AMT
            ,FLS_MED_INSURANCE				=v_each_row.FLS_MED_INSURANCE
            ,FLS_MED_AMT						  =v_each_row.FLS_MED_AMT
            ,FLS_MED_INSURANCE_COMMENT			=v_each_row.FLS_MED_INSURANCE_COMMENT
            ,FLS_TOTAL_SPONSOR_STIPEND			=v_each_row.FLS_TOTAL_SPONSOR_STIPEND
            ,FLS_SUPP_AMOUNT					      =v_each_row.FLS_SUPP_AMOUNT
            ,FLS_FRINGE_BENEFIT_AMOUNT			=v_each_row.FLS_FRINGE_BENEFIT_AMOUNT
            ,FLS_ANNUAL_STIPEND					    =v_each_row.FLS_ANNUAL_STIPEND
            ,FLS_MONTHS_STIPEND					    =v_each_row.FLS_MONTHS_STIPEND
            ,FLS_MONTHLY_STIPEND				    =v_each_row.FLS_MONTHLY_STIPEND
            ,FLS_TOTAL_AWARD_AMOUNT				  =v_each_row.FLS_TOTAL_AWARD_AMOUNT
            ,FLS_BUDGET_YEAR					      =v_each_row.FLS_BUDGET_YEAR
            ,FLS_PRIN_INVESTIGATOR				  =v_each_row.FLS_PRIN_INVESTIGATOR
            ,FLS_CALTERM						        =v_each_row.FLS_CALTERM
            ,FLS_BANTERM						        =v_each_row.FLS_BANTERM
            ,FLS_REMARKS						        =v_each_row.FLS_REMARKS
           -- added 11/17/2014 End
        where fls_session=30
        and fls_calyear=v_max_calyear+1
        and fls_seqnum=in_seqnum
        and fls_unique=in_unique;
      elsif v_max_session=20 then
        update GRADSCH.TGRDFELLOW_SESS 
        set fls_status='EXPECTED'
        -- added 11/17/2014 Start
            ,FLS_TUIT_ONLY						=v_each_row.FLS_TUIT_ONLY
            ,FLS_TUIT_AIDCODE					=v_each_row.FLS_TUIT_AIDCODE
            ,FLS_TUIT_CHRG_SCH				=v_each_row.FLS_TUIT_CHRG_SCH
            ,FLS_TUIT							    =v_each_row.FLS_TUIT
            ,FLS_ADMIN_ASST						=v_each_row.FLS_ADMIN_ASST
            ,FLS_GRAD_APPT_FEE				=v_each_row.FLS_GRAD_APPT_FEE
            ,FLS_TECH_FEE						  =v_each_row.FLS_TECH_FEE
            ,FLS_R_AND_R_FEE					=v_each_row.FLS_R_AND_R_FEE
            ,FLS_INTERNATIONAL_FEE		=v_each_row.FLS_INTERNATIONAL_FEE
            ,FLS_DIFFERENTIAL_FEE			=v_each_row.FLS_DIFFERENTIAL_FEE
            ,FLS_WELLNESS_FEE					=v_each_row.FLS_WELLNESS_FEE
            ,FLS_SUPP							    =v_each_row.FLS_SUPP
            ,FLS_SUPP_PAYROLL_AMT			=v_each_row.FLS_SUPP_PAYROLL_AMT
            ,FLS_SUPP_OTHER_FUND_ACCT	=v_each_row.FLS_SUPP_OTHER_FUND_ACCT
            ,FLS_SUPP_OTHER_FUND_AMT	=v_each_row.FLS_SUPP_OTHER_FUND_AMT
            ,FLS_MED_INSURANCE				=v_each_row.FLS_MED_INSURANCE
            ,FLS_MED_AMT						  =v_each_row.FLS_MED_AMT
            ,FLS_MED_INSURANCE_COMMENT			=v_each_row.FLS_MED_INSURANCE_COMMENT
            ,FLS_TOTAL_SPONSOR_STIPEND			=v_each_row.FLS_TOTAL_SPONSOR_STIPEND
            ,FLS_SUPP_AMOUNT					      =v_each_row.FLS_SUPP_AMOUNT
            ,FLS_FRINGE_BENEFIT_AMOUNT			=v_each_row.FLS_FRINGE_BENEFIT_AMOUNT
            ,FLS_ANNUAL_STIPEND					    =v_each_row.FLS_ANNUAL_STIPEND
            ,FLS_MONTHS_STIPEND					    =v_each_row.FLS_MONTHS_STIPEND
            ,FLS_MONTHLY_STIPEND				    =v_each_row.FLS_MONTHLY_STIPEND
            ,FLS_TOTAL_AWARD_AMOUNT				  =v_each_row.FLS_TOTAL_AWARD_AMOUNT
            ,FLS_BUDGET_YEAR					      =v_each_row.FLS_BUDGET_YEAR
            ,FLS_PRIN_INVESTIGATOR				  =v_each_row.FLS_PRIN_INVESTIGATOR
            ,FLS_CALTERM						        =v_each_row.FLS_CALTERM
            ,FLS_BANTERM						        =v_each_row.FLS_BANTERM
            ,FLS_REMARKS						        =v_each_row.FLS_REMARKS
           -- added 11/17/2014 End
        where fls_session=30
        and fls_calyear=v_max_calyear
        and fls_seqnum=in_seqnum
        and fls_unique=in_unique;
      else
      
        insert all 
        into GRADSCH.TGRDFELLOW_SESS (fls_seqnum, fls_unique, fls_calyear, fls_session, fls_status) values (in_seqnum, in_unique, v_max_calyear,10,null)
        into GRADSCH.TGRDFELLOW_SESS (fls_seqnum, fls_unique, fls_calyear, fls_session, fls_status) values (in_seqnum, in_unique, v_max_calyear+1,20,null)
        --into GRADSCH.TGRDFELLOW_SESS (fls_seqnum, fls_unique, fls_calyear, fls_session, fls_status) values (in_seqnum, in_unique, v_max_calyear+1,30,'EXPECTED') -- removed 11/17/2014
        into GRADSCH.TGRDFELLOW_SESS (FLS_SEQNUM,FLS_UNIQUE,FLS_CALYEAR,FLS_SESSION,FLS_STATUS,FLS_TUIT_ONLY,FLS_TUIT_AIDCODE,FLS_TUIT_CHRG_SCH,FLS_TUIT,FLS_ADMIN_ASST,FLS_GRAD_APPT_FEE,FLS_TECH_FEE,FLS_R_AND_R_FEE,FLS_INTERNATIONAL_FEE,FLS_DIFFERENTIAL_FEE,FLS_WELLNESS_FEE,FLS_SUPP,FLS_SUPP_PAYROLL_AMT,FLS_SUPP_OTHER_FUND_ACCT,FLS_SUPP_OTHER_FUND_AMT,FLS_MED_INSURANCE,FLS_MED_AMT,FLS_MED_INSURANCE_COMMENT,FLS_TOTAL_SPONSOR_STIPEND,FLS_SUPP_AMOUNT,FLS_FRINGE_BENEFIT_AMOUNT,FLS_ANNUAL_STIPEND,FLS_MONTHS_STIPEND,FLS_MONTHLY_STIPEND,FLS_TOTAL_AWARD_AMOUNT,FLS_BUDGET_YEAR,FLS_PRIN_INVESTIGATOR,FLS_CALTERM,FLS_BANTERM,FLS_REMARKS) 
        values (in_seqnum, in_unique, v_max_calyear+1,30,'EXPECTED',v_each_row.FLS_TUIT_ONLY,v_each_row.FLS_TUIT_AIDCODE,v_each_row.FLS_TUIT_CHRG_SCH,v_each_row.FLS_TUIT,v_each_row.FLS_ADMIN_ASST,v_each_row.FLS_GRAD_APPT_FEE,v_each_row.FLS_TECH_FEE,v_each_row.FLS_R_AND_R_FEE,v_each_row.FLS_INTERNATIONAL_FEE,v_each_row.FLS_DIFFERENTIAL_FEE,v_each_row.FLS_WELLNESS_FEE,v_each_row.FLS_SUPP,v_each_row.FLS_SUPP_PAYROLL_AMT,v_each_row.FLS_SUPP_OTHER_FUND_ACCT,v_each_row.FLS_SUPP_OTHER_FUND_AMT,v_each_row.FLS_MED_INSURANCE,v_each_row.FLS_MED_AMT,v_each_row.FLS_MED_INSURANCE_COMMENT,v_each_row.FLS_TOTAL_SPONSOR_STIPEND,v_each_row.FLS_SUPP_AMOUNT,v_each_row.FLS_FRINGE_BENEFIT_AMOUNT,v_each_row.FLS_ANNUAL_STIPEND,v_each_row.FLS_MONTHS_STIPEND,v_each_row.FLS_MONTHLY_STIPEND,v_each_row.FLS_TOTAL_AWARD_AMOUNT,v_each_row.FLS_BUDGET_YEAR,v_each_row.FLS_PRIN_INVESTIGATOR,v_each_row.FLS_CALTERM,v_each_row.FLS_BANTERM,v_each_row.FLS_REMARKS) -- added 11/17/2014
        select * from dual;
      end if;
    end if; 
  end if;
end;

--Author: Jolene Singh
--Function: Whenever a fellowhsip is DECLINED, WITHDRAWN, or GRADUATED, the remaining sessions after that session are deleted
procedure fellowship_withdrawn( in_seqnum in number default 0,
                           in_unique in number default 1,
                           in_calyear in number default 0,
                           in_session in number default 0
                          )
is
i number;
begin
  delete from GRADSCH.TGRDFELLOW_SESS
  where fls_seqnum=in_seqnum
  and fls_unique=in_unique
  and fls_calyear||decode(fls_session,20,1,30,2,10,3) > in_calyear||decode(in_session,20,1,30,2,10,3);
end;

--Author: Jolene Singh
--Function: This procedure receives all data from "cfreate new fellowship" screen. No validation is being done at this stage
--          All validation must be done via javascript on the create new fellowship screen itself.
--          1. This function first creates a fellowship in TGRDFELLOW_BASE
--          2. Create sessions and BYs based on starting session, award year and duration
--          3. Assign BY to sessions based on business rules
--          4. Update BY info as eneterd through "create new session". If the input BY is not in the automatically created
--            list in (2), then insert.
--          5. Update/Insert sessions into session table. If sesison is associated with a BY not in TGRDELLOW_BUDGET, insert BY.
procedure proc_create_fellowship (in_var1 in number default 0,
                                  in_var2 in number default 0,
                                  in_seqnum in number default 0,
                                  in_FLB_CODE in GRADSCH.TGRDFELLOW_BASE.FLB_CODE%TYPE default null,
                                  in_FLB_START_SESSION in GRADSCH.TGRDFELLOW_BASE.FLB_START_SESSION%TYPE default null,
                                  in_FLB_START_CALYEAR in GRADSCH.TGRDFELLOW_BASE.FLB_START_CALYEAR%TYPE default null,
                                  in_FLB_BEGIN_DATE in varchar2 default null,
                                  in_FLB_END_DATE in varchar2 default null,
                                  in_FLB_DURATION in GRADSCH.TGRDFELLOW_BASE.FLB_DURATION%TYPE default null,
                                  in_FLB_AWARD_YEAR in GRADSCH.TGRDFELLOW_BASE.FLB_AWARD_YEAR%TYPE default null,
                                  in_FLB_SPONSOR in GRADSCH.TGRDFELLOW_BASE.FLB_SPONSOR%TYPE default null,
                                  in_FLB_COMMENTS in GRADSCH.TGRDFELLOW_BASE.FLB_COMMENTS%TYPE default null,
                                  
                                  in_FBG_SEQNUM in GRADSCH.TGRDFELLOW_BUDGET.FBG_SEQNUM%TYPE default null,                                         
                                  in_FBG_UNIQUE in GRADSCH.TGRDFELLOW_BUDGET.FBG_UNIQUE%TYPE default null,                                         
                                  in_FBG_BUDGET_YEAR in GRADSCH.TGRDFELLOW_BUDGET.FBG_BUDGET_YEAR%TYPE default null,                               
                                  in_FBG_SAP_ACCT_FUND in GRADSCH.TGRDFELLOW_BUDGET.FBG_SAP_ACCT_FUND%TYPE default null,                           
                                  in_FBG_SAP_ACCT_INTERNAL_ORDER in GRADSCH.TGRDFELLOW_BUDGET.FBG_SAP_ACCT_INTERNAL_ORDER%TYPE default null,       
                                  in_FBG_SAP_ACCT_RESP_CC in GRADSCH.TGRDFELLOW_BUDGET.FBG_SAP_ACCT_RESP_COST_CENTER%TYPE default null,   
                                  in_FBG_GRANT_ACCT in GRADSCH.TGRDFELLOW_BUDGET.FBG_GRANT_ACCT%TYPE default null,                                 
                                  
                                  in_FLS_CALYEAR_1 in GRADSCH.TGRDFELLOW_SESS.FLS_CALYEAR%TYPE default null,                                       
                                  in_FLS_SESSION_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SESSION%TYPE default null,                                       
                                  in_FLS_STATUS_1 in GRADSCH.TGRDFELLOW_SESS.FLS_STATUS%TYPE default null,                                         
                                  in_FLS_TUIT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT%TYPE default null,                                             
                                  in_FLS_ADMIN_ASST_1 in GRADSCH.TGRDFELLOW_SESS.FLS_ADMIN_ASST%TYPE default null,                                 
                                  in_FLS_GRAD_APPT_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_GRAD_APPT_FEE%TYPE default null,                           
                                  in_FLS_TECH_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_TECH_FEE%TYPE default null,                                     
                                  in_FLS_R_AND_R_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_R_AND_R_FEE%TYPE default null,                               
                                  in_FLS_INTERNATIONAL_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_INTERNATIONAL_FEE%TYPE default null,                   
                                  in_FLS_DIFFERENTIAL_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_DIFFERENTIAL_FEE%TYPE default null,                     
                                  in_FLS_WELLNESS_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_WELLNESS_FEE%TYPE default null,                             
                                  in_FLS_SUPP_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP%TYPE default null,                                             
                                  in_FLS_SUPP_PAYROLL_AMT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_PAYROLL_AMT%TYPE default null,                     
                                  in_FLS_SUPP_OTHER_FUND_ACCT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_ACCT%TYPE default null,             
                                  in_FLS_SUPP_OTHER_FUND_AMT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_AMT%TYPE default null,               
                                  in_FLS_MED_INSURANCE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE%TYPE default null,                           
                                  in_FLS_MED_AMT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_AMT%TYPE default null,                                       
                                  in_FLS_MED_INSURANCE_COMMENT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE_COMMENT%TYPE default null,           
                                  in_FLS_TOTAL_SPONSOR_STIPEND_1 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_SPONSOR_STIPEND%TYPE default null,           
                                  in_FLS_SUPP_AMOUNT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_AMOUNT%TYPE default null,                               
                                  in_FLS_FRINGE_BENEFIT_AMOUNT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_FRINGE_BENEFIT_AMOUNT%TYPE default null,           
                                  in_FLS_ANNUAL_STIPEND_1 in GRADSCH.TGRDFELLOW_SESS.FLS_ANNUAL_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHS_STIPEND_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHS_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHLY_STIPEND_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHLY_STIPEND%TYPE default null,                       
                                  in_FLS_BUDGET_YEAR_1 in GRADSCH.TGRDFELLOW_SESS.FLS_BUDGET_YEAR%TYPE default null,                               
                                  in_FLS_PRIN_INVESTIGATOR_1 in GRADSCH.TGRDFELLOW_SESS.FLS_PRIN_INVESTIGATOR%TYPE default null,                   
                                  in_FLS_TOTAL_AWARD_AMOUNT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_AWARD_AMOUNT%TYPE default null,   
                                  in_FLS_CALTERM_1 in GRADSCH.TGRDFELLOW_SESS.FLS_CALTERM%TYPE default null,       -- Added by Vinod for new cal term 12/20/2013
                                  in_FLS_REMARKS_1 in GRADSCH.TGRDFELLOW_SESS.FLS_REMARKS%TYPE default null, -- Added by Vinod on 11/12/2013 for Remarks Field
                                  
                                  in_FLS_CALYEAR_2 in GRADSCH.TGRDFELLOW_SESS.FLS_CALYEAR%TYPE default null,                                       
                                  in_FLS_SESSION_2 in GRADSCH.TGRDFELLOW_SESS.FLS_SESSION%TYPE default null,                                       
                                  in_FLS_STATUS_2 in GRADSCH.TGRDFELLOW_SESS.FLS_STATUS%TYPE default null,                                         
                                  in_FLS_TUIT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT%TYPE default null,                                             
                                  in_FLS_ADMIN_ASST_2 in GRADSCH.TGRDFELLOW_SESS.FLS_ADMIN_ASST%TYPE default null,                                 
                                  in_FLS_GRAD_APPT_FEE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_GRAD_APPT_FEE%TYPE default null,                           
                                  in_FLS_TECH_FEE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_TECH_FEE%TYPE default null,                                     
                                  in_FLS_R_AND_R_FEE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_R_AND_R_FEE%TYPE default null,                               
                                  in_FLS_INTERNATIONAL_FEE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_INTERNATIONAL_FEE%TYPE default null,                   
                                  in_FLS_DIFFERENTIAL_FEE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_DIFFERENTIAL_FEE%TYPE default null,                     
                                  in_FLS_WELLNESS_FEE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_WELLNESS_FEE%TYPE default null,                             
                                  in_FLS_SUPP_2 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP%TYPE default null,                                             
                                  in_FLS_SUPP_PAYROLL_AMT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_PAYROLL_AMT%TYPE default null,                     
                                  in_FLS_SUPP_OTHER_FUND_ACCT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_ACCT%TYPE default null,             
                                  in_FLS_SUPP_OTHER_FUND_AMT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_AMT%TYPE default null,               
                                  in_FLS_MED_INSURANCE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE%TYPE default null,                           
                                  in_FLS_MED_AMT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_AMT%TYPE default null,                                       
                                  in_FLS_MED_INSURANCE_COMMENT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE_COMMENT%TYPE default null,           
                                  in_FLS_TOTAL_SPONSOR_STIPEND_2 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_SPONSOR_STIPEND%TYPE default null,           
                                  in_FLS_SUPP_AMOUNT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_AMOUNT%TYPE default null,                               
                                  in_FLS_FRINGE_BENEFIT_AMOUNT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_FRINGE_BENEFIT_AMOUNT%TYPE default null,           
                                  in_FLS_ANNUAL_STIPEND_2 in GRADSCH.TGRDFELLOW_SESS.FLS_ANNUAL_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHS_STIPEND_2 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHS_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHLY_STIPEND_2 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHLY_STIPEND%TYPE default null,                       
                                  in_FLS_BUDGET_YEAR_2 in GRADSCH.TGRDFELLOW_SESS.FLS_BUDGET_YEAR%TYPE default null,                               
                                  in_FLS_PRIN_INVESTIGATOR_2 in GRADSCH.TGRDFELLOW_SESS.FLS_PRIN_INVESTIGATOR%TYPE default null,                   
                                  in_FLS_TOTAL_AWARD_AMOUNT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_AWARD_AMOUNT%TYPE default null,  
                                  in_FLS_CALTERM_2 in GRADSCH.TGRDFELLOW_SESS.FLS_CALTERM%TYPE default null,       -- Added by Vinod for new cal term 12/20/2013
                                  in_FLS_REMARKS_2 in GRADSCH.TGRDFELLOW_SESS.FLS_REMARKS%TYPE default null, -- Added by Vinod on 11/12/2013 for Remarks Field
                                  
                                  in_FLS_CALYEAR_3 in GRADSCH.TGRDFELLOW_SESS.FLS_CALYEAR%TYPE default null,                                       
                                  in_FLS_SESSION_3 in GRADSCH.TGRDFELLOW_SESS.FLS_SESSION%TYPE default null,                                       
                                  in_FLS_STATUS_3 in GRADSCH.TGRDFELLOW_SESS.FLS_STATUS%TYPE default null,                                         
                                  in_FLS_TUIT_ONLY_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT_ONLY%TYPE default null,                                   
                                  in_FLS_TUIT_AIDCODE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT_AIDCODE%TYPE default null,                             
                                  in_FLS_TUIT_CHRG_SCH_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT_CHRG_SCH%TYPE default null,                           
                                  in_FLS_TUIT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT%TYPE default null,                                             
                                  in_FLS_ADMIN_ASST_3 in GRADSCH.TGRDFELLOW_SESS.FLS_ADMIN_ASST%TYPE default null,                                 
                                  in_FLS_GRAD_APPT_FEE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_GRAD_APPT_FEE%TYPE default null,                           
                                  in_FLS_TECH_FEE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TECH_FEE%TYPE default null,                                     
                                  in_FLS_R_AND_R_FEE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_R_AND_R_FEE%TYPE default null,                               
                                  in_FLS_INTERNATIONAL_FEE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_INTERNATIONAL_FEE%TYPE default null,                   
                                  in_FLS_DIFFERENTIAL_FEE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_DIFFERENTIAL_FEE%TYPE default null,                     
                                  in_FLS_WELLNESS_FEE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_WELLNESS_FEE%TYPE default null,                             
                                  in_FLS_SUPP_3 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP%TYPE default null,                                             
                                  in_FLS_SUPP_PAYROLL_AMT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_PAYROLL_AMT%TYPE default null,                     
                                  in_FLS_SUPP_OTHER_FUND_ACCT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_ACCT%TYPE default null,             
                                  in_FLS_SUPP_OTHER_FUND_AMT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_AMT%TYPE default null,               
                                  in_FLS_MED_INSURANCE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE%TYPE default null,                           
                                  in_FLS_MED_AMT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_AMT%TYPE default null,                                       
                                  in_FLS_MED_INSURANCE_COMMENT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE_COMMENT%TYPE default null,           
                                  in_FLS_TOTAL_SPONSOR_STIPEND_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_SPONSOR_STIPEND%TYPE default null,           
                                  in_FLS_SUPP_AMOUNT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_AMOUNT%TYPE default null,                               
                                  in_FLS_FRINGE_BENEFIT_AMOUNT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_FRINGE_BENEFIT_AMOUNT%TYPE default null,           
                                  in_FLS_ANNUAL_STIPEND_3 in GRADSCH.TGRDFELLOW_SESS.FLS_ANNUAL_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHS_STIPEND_3 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHS_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHLY_STIPEND_3 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHLY_STIPEND%TYPE default null,                       
                                  in_FLS_BUDGET_YEAR_3 in GRADSCH.TGRDFELLOW_SESS.FLS_BUDGET_YEAR%TYPE default null,                               
                                  in_FLS_PRIN_INVESTIGATOR_3 in GRADSCH.TGRDFELLOW_SESS.FLS_PRIN_INVESTIGATOR%TYPE default null,                   
                                  in_FLS_TOTAL_AWARD_AMOUNT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_AWARD_AMOUNT%TYPE default null,
                                  in_FLS_CALTERM_3 in GRADSCH.TGRDFELLOW_SESS.FLS_CALTERM%TYPE default null,       -- Added by Vinod for new cal term 12/20/2013
                                  in_FLS_REMARKS_3 in GRADSCH.TGRDFELLOW_SESS.FLS_REMARKS%TYPE default null, -- Added by Vinod on 11/12/2013 for Remarks Field
                                  
                                  in_new_form in varchar2 default null,
                                  in_form_begin_date in varchar2 default null,
                                  in_form_end_date in varchar2 default null,
                                  
                                  in_action in varchar2 default 'Cancel')
                                  
                                  
  

is
v_unique number;
cur_reg TGRDREG%ROWTYPE;
v_dept GRADSCH.TGRDFELLOW_BASE.FLB_DEPT%TYPE;
v_status GRADSCH.TGRDFELLOW_SESS.FLS_STATUS%TYPE;
v_count number;
v_count2 number;
type t_insert_sess is varray(50) of number;
type t_insert_calyear is varray(50) of number;
v_insert_sess t_insert_sess:=t_insert_sess();
v_insert_calyear t_insert_calyear:=t_insert_calyear();
i number;
j number;
z1 number;
z2 number;
type t_tgrdfellow_sess is varray(3) of GRADSCH.TGRDFELLOW_SESS%rowtype;
varray_tgrdfellow_sess t_tgrdfellow_sess:=t_tgrdfellow_sess();

v_tgrdfellow_sess GRADSCH.TGRDFELLOW_SESS%rowtype;
v_start_session GRADSCH.TGRDFELLOW_SESS.fls_session%type;
v_start_calyear GRADSCH.TGRDFELLOW_SESS.fls_calyear%type;
v_end_session GRADSCH.TGRDFELLOW_SESS.fls_session%type;
v_end_calyear GRADSCH.TGRDFELLOW_SESS.fls_calyear%type;
v_session GRADSCH.TGRDFELLOW_SESS.fls_session%type;
v_calyear GRADSCH.TGRDFELLOW_SESS.fls_calyear%type;

v_stmt varchar2(32767);
begin
  
  if lower(in_action)='cancel' then
    --owa_util.redirect_url('www_rgs.wfl_fellowship.disp_new_view?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum);
    owa_util.redirect_url('www_rgs.wgb_dispstd.disp_grad?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum||'&in_view=6');
    return;
  end if;

  --Create record for main fellowship
  select (NVL(max(flb_unique),0)+1) into v_unique
  from GRADSCH.TGRDFELLOW_BASE
  where flb_seqnum=in_seqnum;
  
  cur_reg := wps_shared.get_most_recent_registration(in_seqnum);
  
  insert into GRADSCH.TGRDFELLOW_BASE
  (FLB_SEQNUM, FLB_UNIQUE, FLB_CODE, FLB_BEGIN_DATE,FLB_END_DATE,FLB_DURATION,FLB_AWARD_YEAR,FLB_DEPT,FLB_SPONSOR,FLB_COMMENTS,FLB_CREATE_DATE,FLB_LAST_REVISED_DATE,FLB_START_SESSION, FLB_START_CALYEAR)
  values
  (in_seqnum,v_unique,in_flb_code,to_date(to_date(in_flb_begin_date,'MM/DD/RR'),'DD-MON-RR'),to_date(to_date(in_flb_end_date,'MM/DD/RR'),'DD-MON-RR'),in_flb_duration,in_flb_award_year,cur_reg.rg_dept,in_flb_sponsor,in_flb_comments,sysdate,sysdate, in_flb_start_session, in_flb_start_calyear);
  
  --Based on award-year and duration create budget year list
  for i in 0..in_flb_duration-1 loop
    insert into GRADSCH.TGRDFELLOW_BUDGET 
    (FBG_SEQNUM,FBG_UNIQUE,FBG_BUDGET_YEAR)
    values
    (in_seqnum,v_unique,(substr(in_flb_award_year,1,4)+i)||'-'||lpad((substr(in_flb_award_year,6,2)+i),2,'0'));
  end loop;
  
  --Based on start session  and duration, create a list of sessions
  v_insert_sess:=t_insert_sess();
  v_insert_calyear:=t_insert_calyear();
  v_session:=in_flb_start_session;
  v_calyear:=in_flb_start_calyear;
  v_start_session:=in_flb_start_session;
  v_start_calyear:=in_flb_start_calyear;
  for i in 1..(in_flb_duration*3) loop
    if i=1 then
      if v_session = 20 then
        v_insert_sess.extend();
        v_insert_calyear.extend();
        v_insert_sess(v_insert_sess.count):=10;
        v_insert_calyear(v_insert_calyear.count):=v_calyear-1;
      elsif v_session =30 then
        v_insert_sess.extend(2);
        v_insert_calyear.extend(2);
        v_insert_sess(v_insert_sess.count-1):=10;
        v_insert_calyear(v_insert_calyear.count-1):=v_calyear-1;
        v_insert_sess(v_insert_sess.count):=20;
        v_insert_calyear(v_insert_calyear.count):=v_calyear;
      end if;
    end if;
    v_insert_sess.extend();
    v_insert_calyear.extend();
    v_insert_sess(v_insert_sess.count):= v_session;
    v_insert_calyear(v_insert_calyear.count):=v_calyear;
    
    if i=in_flb_duration*3 then
      v_end_session:=v_session;
      v_end_calyear:=v_calyear;
      if v_session = 20 then
        v_insert_sess.extend();
        v_insert_calyear.extend();
        v_insert_sess(v_insert_sess.count):=30;
        v_insert_calyear(v_insert_calyear.count):=v_calyear;
      elsif v_session =10 then
        v_insert_sess.extend(2);
        v_insert_calyear.extend(2);
        v_insert_sess(v_insert_sess.count-1):=20;
        v_insert_calyear(v_insert_calyear.count-1):=v_calyear+1;
        v_insert_sess(v_insert_sess.count):=30;
        v_insert_calyear(v_insert_calyear.count):=v_calyear+1;
      end if;
    end if;
    select case v_session when 10 then v_calyear+1 else v_calyear end into v_calyear from dual; 
    select case v_session when 10 then 20 when 20 then 30 else 10 end into v_session from dual;
    
  end loop;
   
    for i in 1..v_insert_sess.count loop
    insert into GRADSCH.TGRDFELLOW_SESS
    (fls_seqnum, fls_unique, fls_calyear, fls_session, fls_status,fls_calterm)
    values
    (in_seqnum, v_unique, v_insert_calyear(i), v_insert_sess(i),case when v_insert_calyear(i)|| (case v_insert_sess(i) when 20 then 1 when 30 then 2 else 3 end) < v_start_calyear||(case v_start_session when 20 then 1 when 30 then 2 else 3 end) then null
                                                                     when v_insert_calyear(i)|| (case v_insert_sess(i) when 20 then 1 when 30 then 2 else 3 end) > v_end_calyear||(case v_end_session when 20 then 1 when 30 then 2 else 3 end) then null
                                                                     else 'EXPECTED' end,v_insert_calyear(i)||v_insert_sess(i));
                                                                     
  end loop;

 
  
  --update sessions with all info except budget year
  varray_tgrdfellow_sess.extend(3);
  select in_seqnum,v_unique,in_fls_calyear_1,in_fls_session_1,in_fls_status_1,null,null,null,in_FLS_TUIT_1,in_FLS_ADMIN_ASST_1,in_FLS_GRAD_APPT_FEE_1,in_FLS_TECH_FEE_1,
      in_FLS_R_AND_R_FEE_1,in_FLS_INTERNATIONAL_FEE_1,in_FLS_DIFFERENTIAL_FEE_1, in_FLS_WELLNESS_FEE_1,in_FLS_SUPP_1,in_FLS_SUPP_PAYROLL_AMT_1,in_FLS_SUPP_OTHER_FUND_ACCT_1,in_FLS_SUPP_OTHER_FUND_AMT_1,in_FLS_MED_INSURANCE_1,
      in_FLS_MED_AMT_1,in_FLS_MED_INSURANCE_COMMENT_1,in_FLS_TOTAL_SPONSOR_STIPEND_1,in_FLS_SUPP_AMOUNT_1,in_FLS_FRINGE_BENEFIT_AMOUNT_1,in_FLS_ANNUAL_STIPEND_1, in_FLS_MONTHS_STIPEND_1 ,in_FLS_MONTHLY_STIPEND_1,in_FLS_TOTAL_AWARD_AMOUNT_1,null,                               
      in_FLS_PRIN_INVESTIGATOR_1,in_FLS_CALTERM_1,null,in_FLS_Remarks_1 into varray_tgrdfellow_sess(1)
  from dual;
  
  select in_seqnum,v_unique,in_fls_calyear_2,in_fls_session_2,in_fls_status_2,null,null,null,in_FLS_TUIT_2,in_FLS_ADMIN_ASST_2,in_FLS_GRAD_APPT_FEE_2,in_FLS_TECH_FEE_2,
      in_FLS_R_AND_R_FEE_2,in_FLS_INTERNATIONAL_FEE_2,in_FLS_DIFFERENTIAL_FEE_2, in_FLS_WELLNESS_FEE_2,in_FLS_SUPP_2,in_FLS_SUPP_PAYROLL_AMT_2,in_FLS_SUPP_OTHER_FUND_ACCT_2,in_FLS_SUPP_OTHER_FUND_AMT_2,in_FLS_MED_INSURANCE_2,
      in_FLS_MED_AMT_2,in_FLS_MED_INSURANCE_COMMENT_2,in_FLS_TOTAL_SPONSOR_STIPEND_2,in_FLS_SUPP_AMOUNT_2,in_FLS_FRINGE_BENEFIT_AMOUNT_2,in_FLS_ANNUAL_STIPEND_2, in_FLS_MONTHS_STIPEND_2 ,in_FLS_MONTHLY_STIPEND_2,in_FLS_TOTAL_AWARD_AMOUNT_2,null,                               
      in_FLS_PRIN_INVESTIGATOR_2,in_FLS_CALTERM_2,null,in_FLS_Remarks_2 into varray_tgrdfellow_sess(2)
  from dual;
  
  select in_seqnum,v_unique,in_fls_calyear_3,in_fls_session_3,in_fls_status_3,null,null,null,in_FLS_TUIT_3,in_FLS_ADMIN_ASST_3,in_FLS_GRAD_APPT_FEE_3,in_FLS_TECH_FEE_3,
      in_FLS_R_AND_R_FEE_3,in_FLS_INTERNATIONAL_FEE_3,in_FLS_DIFFERENTIAL_FEE_3, in_FLS_WELLNESS_FEE_3,in_FLS_SUPP_3,in_FLS_SUPP_PAYROLL_AMT_3,in_FLS_SUPP_OTHER_FUND_ACCT_3,in_FLS_SUPP_OTHER_FUND_AMT_3,in_FLS_MED_INSURANCE_3,
      in_FLS_MED_AMT_3,in_FLS_MED_INSURANCE_COMMENT_3,in_FLS_TOTAL_SPONSOR_STIPEND_3,in_FLS_SUPP_AMOUNT_3,in_FLS_FRINGE_BENEFIT_AMOUNT_3,in_FLS_ANNUAL_STIPEND_3, in_FLS_MONTHS_STIPEND_3 ,in_FLS_MONTHLY_STIPEND_3,in_FLS_TOTAL_AWARD_AMOUNT_3,null,                               
      in_FLS_PRIN_INVESTIGATOR_3,in_FLS_CALTERM_3,null,in_FLS_Remarks_3 into varray_tgrdfellow_sess(3)
  from dual;
  
-- Start: Code fix done by vinod to create the fellowship with "active" status when fellowship is started in spring  
  for i in 1..varray_tgrdfellow_sess.count loop
  
  if varray_tgrdfellow_sess(i).fls_session = 20 then
    Z1 := 1;
    elsif varray_tgrdfellow_sess(i).fls_session = 30 then
      Z1 := 2;
    else
      Z1:=3;
  end if;
  
  if v_end_session = 20 then
    Z2 := 1;
    elsif v_end_session = 30 then
      Z2 := 2;
    else
      Z2 :=3;
  end if;
-- End: Code fix done by vinod to create the fellowship with "active" status when fellowship is started in spring

    if (    (varray_tgrdfellow_sess(i).fls_session is not null) 
        and (varray_tgrdfellow_sess(i).fls_calyear is not null)
        and (varray_tgrdfellow_sess(i).fls_calyear||varray_tgrdfellow_sess(i).fls_session >=  v_start_calyear||v_start_session)
        and (varray_tgrdfellow_sess(i).fls_calyear||Z1 <=  v_end_calyear||Z2)   -- Bugfix done by vinod to create the fellowship with "active" status when fellowship is started in spring  
        )then
      if varray_tgrdfellow_sess(i).fls_status is null then
        varray_tgrdfellow_sess(i).fls_status:='EXPECTED';
      end if;
      
      update GRADSCH.TGRDFELLOW_SESS
      set row=varray_tgrdfellow_sess(i)
      where fls_seqnum=varray_tgrdfellow_sess(i).fls_seqnum
      and fls_unique=varray_tgrdfellow_sess(i).fls_unique
      and fls_calyear=varray_tgrdfellow_sess(i).fls_calyear
      and fls_session=varray_tgrdfellow_sess(i).fls_session;
      
      if varray_tgrdfellow_sess(i).fls_status='HOLD' then
        extend_for_hold(in_seqnum,v_unique,varray_tgrdfellow_sess(i).fls_calyear, varray_tgrdfellow_sess(i).fls_session);
      end if;
    end if;
  end loop;
  
  --Check for fellowship withdrawn --though highly unexpected in start itself
  for i in 1..varray_tgrdfellow_sess.count loop
    if (    (varray_tgrdfellow_sess(i).fls_session is not null) 
        and (varray_tgrdfellow_sess(i).fls_calyear is not null)
        and (varray_tgrdfellow_sess(i).fls_calyear||varray_tgrdfellow_sess(i).fls_session >=  v_start_calyear||v_start_session)
        and (varray_tgrdfellow_sess(i).fls_calyear||varray_tgrdfellow_sess(i).fls_session <=  v_end_calyear||v_end_session) 
        )then
      if varray_tgrdfellow_sess(i).fls_status in ('WITHDRAWN','DECLINED','GRADUATED')  then
        fellowship_withdrawn(in_seqnum,v_unique,varray_tgrdfellow_sess(i).fls_calyear, varray_tgrdfellow_sess(i).fls_session);
        exit;
      end if;
    end if;
  end loop;
  
  --Now reset budget years. This will account for HOLDs that may have been added by user
  reset_sessions(in_seqnum,v_unique);
  
  --Once it has been reset, we can reassociate all sessions with user-defined budget years
  --and create additional budget years
  --Add budget account information in create form
  if(in_fbg_budget_year is not null) then
    select count(*) into v_count from GRADSCH.TGRDFELLOW_BUDGET
    where fbg_seqnum=in_seqnum
    and fbg_unique=v_unique
    and fbg_budget_year=in_fbg_budget_year;
    
    if v_count=0 then
      insert into GRADSCH.TGRDFELLOW_BUDGET
      (FBG_SEQNUM,FBG_UNIQUE,FBG_BUDGET_YEAR,FBG_SAP_ACCT_FUND,FBG_SAP_ACCT_INTERNAL_ORDER,FBG_SAP_ACCT_RESP_COST_CENTER,FBG_GRANT_ACCT)
      values
      (in_seqnum,v_unique,in_fbg_budget_year,in_fbg_sap_acct_fund,in_fbg_sap_acct_internal_order, in_fbg_sap_acct_resp_cc, in_fbg_grant_acct);
    else
      update GRADSCH.TGRDFELLOW_BUDGET
      set fbg_sap_acct_fund=in_fbg_sap_acct_fund,
          fbg_sap_acct_internal_order=in_fbg_sap_acct_internal_order, 
          fbg_sap_acct_resp_cost_center=in_fbg_sap_acct_resp_cc, 
          fbg_grant_acct=in_fbg_grant_acct
      where fbg_seqnum=in_seqnum
      and fbg_unique=v_unique
      and fbg_budget_year=in_fbg_budget_year;
    end if;
  end if;
  
  --Associate sessions with user defined budget years
  for i in 1..varray_tgrdfellow_sess.count loop
    if (    (varray_tgrdfellow_sess(i).fls_session is not null) 
        and (varray_tgrdfellow_sess(i).fls_calyear is not null)
        and (varray_tgrdfellow_sess(i).fls_calyear||varray_tgrdfellow_sess(i).fls_session >=  v_start_calyear||v_start_session)
        and (varray_tgrdfellow_sess(i).fls_calyear||varray_tgrdfellow_sess(i).fls_session <=  v_end_calyear||v_end_session) 
        )then
       -- 05/10/2013 Jolene S. Budget year was not getting updated.Earlier the code was a static update using varray_tgrdfellow_sess(i)
      update GRADSCH.TGRDFELLOW_SESS 
      set fls_budget_year = case i when 1 then in_fls_budget_year_1
                                   when 2 then in_fls_budget_year_2
                                   else in_fls_budget_year_3 end
      where fls_seqnum=varray_tgrdfellow_sess(i).fls_seqnum 
      and fls_unique=varray_tgrdfellow_sess(i).fls_unique
      and fls_calyear=varray_tgrdfellow_sess(i).fls_calyear
      and fls_session=varray_tgrdfellow_sess(i).fls_session ;
      
    end if;
  end loop;
  
  --Insert form book keeping info
  if in_new_form='YES' then
    insert into GRADSCH.TGRDFELLOW_FORM_HISTORY values
    (in_seqnum,v_unique,sysdate, to_date(to_date(in_form_begin_date,'MM/DD/RR'),'DD-MON-RR'), to_date(to_date(in_form_end_date,'MM/DD/RR'),'DD-MON-RR'));
  end if;
  commit;
  --owa_util.redirect_url('www_rgs.wfl_fellowship.disp_new_view?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum);
  owa_util.redirect_url('www_rgs.wgb_dispstd.disp_grad?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum||'&in_view=6');
end;

--Author: Jolene Singh
--Function: Accepts the input when a fellowship base information is updated on the main page.
--Modifications
-- 06/27/2013 Romina : Changed "Begin Date" and "End Date" treatment to resolve date conversion errors 
procedure proc_update_fel(in_var1 in number default 0,
                          in_var2 in number default 0,
                          in_seqnum in number default 0,
                          in_unique in number default 0,
                          in_flb_begin_date in varchar2 default null, -- added by romina 06/27/2013
                            -- in_flb_begin_date in GRADSCH.TGRDFELLOW_BASE.FLB_BEGIN_DATE%TYPE default null, -- removed by romina 06/27/2013
                          in_flb_end_date in varchar2 default null, -- added by romina 06/27/2013
                            -- in_flb_end_date in GRADSCH.TGRDFELLOW_BASE.FLB_END_DATE%TYPE default null, -- removed by romina 06/27/2013
                          in_flb_sponsor in GRADSCH.TGRDFELLOW_BASE.FLB_SPONSOR%TYPE default null,
                          in_flb_comments in GRADSCH.TGRDFELLOW_BASE.FLB_COMMENTS%TYPE default null,
                          in_action in varchar2 default 'update')
IS
BEGIN
  if lower(in_action)='update' then
    update GRADSCH.TGRDFELLOW_BASE
    set flb_begin_date=to_date(to_date(in_flb_begin_date,'MM/DD/RR'),'DD-MON-RR'), -- added by romina 06/27/2013
      -- set flb_begin_date=in_flb_begin_date, -- removed by romina 06/27/2013
    flb_end_date=to_date(to_date(in_flb_end_date,'MM/DD/RR'),'DD-MON-RR'), -- added by romina 06/27/2013
      -- flb_end_date=in_flb_end_date, -- removed by romina 06/27/2013
    flb_sponsor=in_flb_sponsor,
    flb_comments=in_flb_comments,
    flb_last_revised_date=sysdate
    where flb_seqnum=in_seqnum
    and flb_unique=in_unique;
  elsif lower(in_action)='delete' then
    delete from GRADSCH.TGRDFELLOW_FORM_HISTORY
    where ffh_seqnum=in_seqnum
    and ffh_unique=in_unique;
    
    delete from GRADSCH.TGRDFELLOW_SESS
    where fls_seqnum=in_seqnum
    and fls_unique=in_unique;
  
    delete from GRADSCH.TGRDFELLOW_BUDGET
    where fbg_seqnum=in_seqnum
    and fbg_unique=in_unique;
    
    delete from GRADSCH.TGRDFELLOW_BASE
    where flb_seqnum=in_seqnum
    and flb_unique=in_unique;
  end if;
  commit;
  --owa_util.redirect_url('www_rgs.wfl_fellowship.disp_new_view?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum);
  owa_util.redirect_url('www_rgs.wgb_dispstd.disp_grad?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum||'&in_view=6');
END;

--author: jolene singh
--function: has form open and close tags for "Display All BYs". Simply calls the BY diplay module with appropriate inputs
procedure disp_budget_years (in_var1 in number default 0,
                                  in_var2 in number default 0,
                                  in_seqnum in number default 0,
                                  in_unique in number default 0)
is
cur_user twwwuser1%rowtype;
cur_base tgrdbase%rowtype;

cursor base_data is
select * from tgrdbase
where b_seqnum=in_seqnum;
begin
  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is  null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;
  open base_data;
  fetch base_data into cur_base;
  if (base_data%notfound) then
    close base_data;
    wgb_lists.disp_qry_appl(1015 , in_var1, in_var2, cur_base.b_puid, cur_base.b_sid,
                          null, null, null, null,
                          null, null, null, null,
                          null);
    return;
  end if;
  close base_data;
  
  wgb_shared.form_start('Graduate School Intranet Database');
  -- insert body tags and toolbar
  wgb_shared.body_start2('Budget year list for fellowship',null,null, in_var1,in_var2, cur_user);
  
  --Add javascript calls
  wgb_shared.print_java_date();
  wgb_shared.print_java_numeric;
  print_java_copy_from_previous();
  print_java_alert();
  --Add all application specific code here
  print_student_details(in_seqnum);
  htp.formopen('www_rgs.wfl_fellowship.proc_disp_budget_year','POST');
    htp.formhidden('in_var1',in_var1);
    htp.formhidden('in_var2',in_var2);
    htp.formhidden('in_seqnum',in_seqnum);
    htp.formhidden('in_unique',in_unique);
    print_fellowship_details(in_var1,in_var2,in_seqnum,in_unique);
    print_budget_details(in_var1,in_var2,in_seqnum,in_unique,null,'DISP');
    print_form_questions(in_var1,in_var2,in_seqnum,in_unique);
  htp.nl;
  htp.formsubmit('in_action','Save');
  htp.print('&nbsp;&nbsp;');
  htp.formsubmit('in_action','Cancel');
  htp.formclose;
  --Code ends here
  htp.bodyClose;
  htp.htmlClose;
end;

--author: jolene singh
--function: receives information from disp_budget_years. essentially deletes BYs.
procedure proc_disp_budget_year(in_var1 in number default 0,
                          in_var2 in number default 0,
                          in_seqnum in number default 0,
                          in_unique in number default 0,
                          in_budget_delete in owa_util.ident_arr:=empty_arr,
                          in_new_form in varchar2 default null,
                          in_form_begin_date in varchar2 default null,
                          in_form_end_date in varchar2 default null,
                          in_action in varchar2 default 'Cancel')
is
v_budget_year_list varchar2(32767);
v_stmt varchar2(32767);
begin
  if lower(in_action)='cancel' then
    --owa_util.redirect_url('www_rgs.wfl_fellowship.disp_new_view?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum);
    owa_util.redirect_url('www_rgs.wgb_dispstd.disp_grad?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum||'&in_view=6');
    return;
  end if;
  
  v_budget_year_list:=null;
  for i in 1..in_budget_delete.count loop
    v_budget_year_list:=v_budget_year_list||''''||in_budget_delete(i)||''',';
  end loop;
  v_budget_year_list:=rtrim(v_budget_year_list,',');
  
  if v_budget_year_list is not null then
  
    v_stmt:='update GRADSCH.TGRDFELLOW_SESS 
             set fls_budget_year=null 
             where fls_seqnum='||in_seqnum||' '|| 
             'and fls_unique='||in_unique||' '||
             'and fls_budget_year in ('||v_budget_year_list||')';
    execute immediate v_stmt;
    
    v_stmt:='delete from GRADSCH.TGRDFELLOW_BUDGET 
             where fbg_seqnum='||in_seqnum||' '||
             'and fbg_unique='||in_unique||' '||
             'and fbg_budget_year in ('||v_budget_year_list||')';
    execute immediate v_stmt;
    
    update GRADSCH.TGRDFELLOW_BASE
    set flb_last_revised_date=sysdate
    where flb_seqnum=in_seqnum
    and flb_unique=in_unique;
    
    --Insert form book keeping info
    if in_new_form='YES' then
      insert into GRADSCH.TGRDFELLOW_FORM_HISTORY values
      (in_seqnum,in_unique,sysdate, to_date(to_date(in_form_begin_date,'MM/DD/RR'),'DD-MON-RR'), to_date(to_date(in_form_end_date,'MM/DD/RR'),'DD-MON-RR'));
  end if;
  end if;
  commit;
  --owa_util.redirect_url('www_rgs.wfl_fellowship.disp_new_view?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum);
  owa_util.redirect_url('www_rgs.wgb_dispstd.disp_grad?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum||'&in_view=6');
end;

--author: jolene singh
--function: calls form open and close for "Update budget Year" button
--          calls BY module with appropriate inputs.
procedure disp_update_budget_year(in_var1 in number default 0,
                          in_var2 in number default 0,
                          in_seqnum in number default 0,
                          in_unique in number default 0,
                          in_fbg_budget_year in GRADSCH.TGRDFELLOW_BUDGET.FBG_BUDGET_YEAR%TYPE default '9999-99',
                          in_action in varchar2 default 'Update')
is
cur_user twwwuser1%rowtype;
cur_base tgrdbase%rowtype;

cursor base_data is
select * from tgrdbase
where b_seqnum=in_seqnum;
begin
  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is  null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;
  open base_data;
  fetch base_data into cur_base;
  if (base_data%notfound) then
    close base_data;
    wgb_lists.disp_qry_appl(1015 , in_var1, in_var2, cur_base.b_puid, cur_base.b_sid,
                          null, null, null, null,
                          null, null, null, null,
                          null);
    return;
  end if;
  close base_data;
  
  wgb_shared.form_start('Graduate School Intranet Database');
  -- insert body tags and toolbar
  wgb_shared.body_start2('Update Budget Year',null,null, in_var1,in_var2, cur_user);
  
  --Add javascript calls
  wgb_shared.print_java_date();
  wgb_shared.print_java_numeric;
  print_java_copy_from_previous();
  print_java_alert();
  --Add all application specific code here
  print_student_details(in_seqnum);
  htp.formopen('www_rgs.wfl_fellowship.proc_update_budget_year','POST');
    htp.formhidden('in_var1',in_var1);
    htp.formhidden('in_var2',in_var2);
    htp.formhidden('in_seqnum',in_seqnum);
    htp.formhidden('in_unique',in_unique);
    htp.formhidden('in_fbg_budget_year',in_fbg_budget_year);
    print_fellowship_details(in_var1,in_var2,in_seqnum,in_unique);
    print_budget_details(in_var1,in_var2,in_seqnum,in_unique,in_fbg_budget_year,'UPDATE');
    print_form_questions(in_var1,in_var2,in_seqnum,in_unique);
  htp.nl;
  htp.formsubmit('in_action','Save');
  htp.print('&nbsp;&nbsp;');
  htp.formsubmit('in_action','Cancel');
  htp.formclose;
  --Code ends here
  htp.bodyClose;
  htp.htmlClose;
end;

--author: jolene singh
--fucntion: receives the updated budget year information from disp_update_budget_year
procedure proc_update_budget_year(in_var1 in number default 0,
                          in_var2 in number default 0,
                          in_seqnum in number default 0,
                          in_unique in number default 0,
                          in_fbg_budget_year in GRADSCH.TGRDFELLOW_BUDGET.FBG_BUDGET_YEAR%TYPE default '9999-99',
                          in_FBG_SAP_ACCT_FUND in GRADSCH.TGRDFELLOW_BUDGET.FBG_SAP_ACCT_FUND%TYPE default null,                           
                          in_FBG_SAP_ACCT_INTERNAL_ORDER in GRADSCH.TGRDFELLOW_BUDGET.FBG_SAP_ACCT_INTERNAL_ORDER%TYPE default null,       
                          in_FBG_SAP_ACCT_RESP_CC in GRADSCH.TGRDFELLOW_BUDGET.FBG_SAP_ACCT_RESP_COST_CENTER%TYPE default null,   
                          in_FBG_GRANT_ACCT in GRADSCH.TGRDFELLOW_BUDGET.FBG_GRANT_ACCT%TYPE default null,                                 
                          in_new_form in varchar2 default null,
                          in_form_begin_date in varchar2 default null,
                          in_form_end_date in varchar2 default null,
                          in_action in varchar2 default 'cancel')
is
begin
  if lower(in_action)='cancel' then
    --owa_util.redirect_url('www_rgs.wfl_fellowship.disp_new_view?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum);
    owa_util.redirect_url('www_rgs.wgb_dispstd.disp_grad?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum||'&in_view=6');
    return;
  end if;
  
  update GRADSCH.TGRDFELLOW_BUDGET
  set FBG_SAP_ACCT_FUND=in_FBG_SAP_ACCT_FUND,
      FBG_SAP_ACCT_INTERNAL_ORDER=in_FBG_SAP_ACCT_INTERNAL_ORDER,
      FBG_SAP_ACCT_RESP_Cost_center=in_FBG_SAP_ACCT_RESP_CC,
      FBG_GRANT_ACCT=in_FBG_GRANT_ACCT
  where fbg_seqnum=in_seqnum
  and fbg_unique=in_unique
  and fbg_budget_year=in_fbg_budget_year;
  
  update GRADSCH.TGRDFELLOW_BASE
  set flb_last_revised_date=sysdate
  where flb_seqnum=in_seqnum
  and flb_unique=in_unique;
  
  --Insert form book keeping info
  if in_new_form='YES' then
    insert into GRADSCH.TGRDFELLOW_FORM_HISTORY values
    (in_seqnum,in_unique,sysdate, to_date(to_date(in_form_begin_date,'MM/DD/RR'),'DD-MON-RR'), to_date(to_date(in_form_end_date,'MM/DD/RR'),'DD-MON-RR'));
  end if;
  commit;
  --owa_util.redirect_url('www_rgs.wfl_fellowship.disp_new_view?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum);
  owa_util.redirect_url('www_rgs.wgb_dispstd.disp_grad?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum||'&in_view=6');
end;

--author: jolene singh
--function: has form open and close tags for adding a new BY to a fellowship. Calls BY display module with appropriate inputs.
procedure add_budget_year(in_var1 in number default 0,
                          in_var2 in number default 0,
                          in_seqnum in number default 0,
                          in_unique in number default 0)
is
cur_user twwwuser1%rowtype;
cur_base tgrdbase%rowtype;

cursor base_data is
select * from tgrdbase
where b_seqnum=in_seqnum;

v_budget_year_list varchar2(32767);

begin
  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is  null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;
  open base_data;
  fetch base_data into cur_base;
  if (base_data%notfound) then
    close base_data;
    wgb_lists.disp_qry_appl(1015 , in_var1, in_var2, cur_base.b_puid, cur_base.b_sid,
                          null, null, null, null,
                          null, null, null, null,
                          null);
    return;
  end if;
  close base_data;
  
  wgb_shared.form_start('Graduate School Intranet Database');
  -- insert body tags and toolbar
  wgb_shared.body_start2('Add Budget Year to Fellowship',null,null, in_var1,in_var2, cur_user);
  
  --Add javascript calls
  wgb_shared.print_java_date();
  wgb_shared.print_java_numeric;
  print_java_copy_from_previous();
  print_java_alert();
  --Add all application specific code here
  select listagg(fbg_budget_year,',') within group (order by fbg_budget_year) into v_budget_year_list
  from GRADSCH.TGRDFELLOW_BUDGET
  where fbg_seqnum=in_seqnum
  and fbg_unique=in_unique;
  
  print_student_details(in_seqnum);
  htp.formopen('www_rgs.wfl_fellowship.proc_add_budget_year','POST');
    htp.formhidden('in_var1',in_var1);
    htp.formhidden('in_var2',in_var2);
    htp.formhidden('in_seqnum',in_seqnum);
    htp.formhidden('in_unique',in_unique);
    print_fellowship_details(in_var1,in_var2,in_seqnum,in_unique);
    print_budget_details(in_var1,in_var2,in_seqnum,in_unique,null,'CREATE');
    print_form_questions(in_var1,in_var2,in_seqnum,in_unique);
  htp.nl;
  htp.formsubmit('in_action','Save','onClick="return check_budget_year('''||v_budget_year_list||''')"');
  htp.formsubmit('in_action','Cancel');
  htp.formclose;
  --Code ends here
  htp.bodyClose;
  htp.htmlClose;
end;

--author: jolene singh
--function: adds a budget year to a fellowship. receives input from add_budget_year
procedure proc_add_budget_year (in_var1 in number default 0,
                          in_var2 in number default 0,
                          in_seqnum in number default 0,
                          in_unique in number default 0,
                          in_fbg_budget_year in GRADSCH.TGRDFELLOW_BUDGET.FBG_BUDGET_YEAR%TYPE default null,
                          in_FBG_SAP_ACCT_FUND in GRADSCH.TGRDFELLOW_BUDGET.FBG_SAP_ACCT_FUND%TYPE default null,                           
                          in_FBG_SAP_ACCT_INTERNAL_ORDER in GRADSCH.TGRDFELLOW_BUDGET.FBG_SAP_ACCT_INTERNAL_ORDER%TYPE default null,       
                          in_FBG_SAP_ACCT_RESP_CC in GRADSCH.TGRDFELLOW_BUDGET.FBG_SAP_ACCT_RESP_COST_CENTER%TYPE default null,   
                          in_FBG_GRANT_ACCT in GRADSCH.TGRDFELLOW_BUDGET.FBG_GRANT_ACCT%TYPE default null,                                 
                          in_new_form in varchar2 default null,
                          in_form_begin_date in varchar2 default null,
                          in_form_end_date in varchar2 default null,
                          in_action in varchar2 default 'Cancel')
is
begin
  if (lower(in_action)='save') then
    insert into GRADSCH.TGRDFELLOW_BUDGET
    (fbg_seqnum, fbg_unique, fbg_budget_year, FBG_SAP_ACCT_FUND,FBG_SAP_ACCT_INTERNAL_ORDER, FBG_SAP_ACCT_RESP_Cost_center,
    FBG_GRANT_ACCT)
    values
    (in_seqnum, in_unique, in_fbg_budget_year,in_FBG_SAP_ACCT_FUND,in_FBG_SAP_ACCT_INTERNAL_ORDER,in_FBG_SAP_ACCT_RESP_CC,
    in_FBG_GRANT_ACCT);
    
    update GRADSCH.TGRDFELLOW_BASE
    set flb_last_revised_date=sysdate
    where flb_seqnum=in_seqnum
    and flb_unique=in_unique;
    
    --Insert form book keeping info
    if in_new_form='YES' then
      insert into GRADSCH.TGRDFELLOW_FORM_HISTORY values
      (in_seqnum,in_unique,sysdate, to_date(to_date(in_form_begin_date,'MM/DD/RR'),'DD-MON-RR'), to_date(to_date(in_form_end_date,'MM/DD/RR'),'DD-MON-RR'));
    end if;
  end if;
  commit;
  --owa_util.redirect_url('www_rgs.wfl_fellowship.disp_new_view?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum);
  owa_util.redirect_url('www_rgs.wgb_dispstd.disp_grad?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum||'&in_view=6');
end;

--author: jolene singh
--function: form open and close tags when "Update Academic year" button is presed on main screen. Calls display modules as approppriate
procedure disp_update_academic_year ( in_var1 in number default 0,
                                      in_var2 in number default 0,
                                      in_seqnum in number default 0,
                                      in_unique in number default 0,
                                      in_academic_year in varchar2 default null,
                                      in_action in varchar2 default 'Update')
is 
cur_user twwwuser1%rowtype;
cur_base tgrdbase%rowtype;

cursor base_data is
select * from tgrdbase
where b_seqnum=in_seqnum;

v_budget_year_list varchar2(32767);

begin
  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is  null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;
  open base_data;
  fetch base_data into cur_base;
  if (base_data%notfound) then
    close base_data;
    wgb_lists.disp_qry_appl(1015 , in_var1, in_var2, cur_base.b_puid, cur_base.b_sid,
                          null, null, null, null,
                          null, null, null, null,
                          null);
    return;
  end if;
  close base_data;
  
  wgb_shared.form_start('Graduate School Intranet Database');
  -- insert body tags and toolbar
  wgb_shared.body_start2('Update Academic Year - Three Sessions',null,null, in_var1,in_var2, cur_user);
  
  --Add javascript calls
  wgb_shared.print_java_date();
  wgb_shared.print_java_numeric;
  print_java_copy_from_previous();
  print_java_alert();
  --Add all application specific code here
  
  print_student_details(in_seqnum);
  htp.formopen('www_rgs.wfl_fellowship.proc_update_academic_year','POST');
    htp.formhidden('in_var1',in_var1);
    htp.formhidden('in_var2',in_var2);
    htp.formhidden('in_seqnum',in_seqnum);
    htp.formhidden('in_unique',in_unique);
    print_fellowship_details(in_var1,in_var2,in_seqnum,in_unique);
    print_session_details(in_var1,in_var2,in_seqnum,in_unique,in_academic_year,null,'UPDATE');
    print_form_questions(in_var1,in_var2,in_seqnum,in_unique);
  htp.nl;
  htp.formsubmit('in_action','Save');
  htp.formsubmit('in_action','Cancel');
  htp.formclose;
  --Code ends here
  htp.bodyClose;
  htp.htmlClose;
end;

--author: jolene singh
--function: when a HOLD is removed, the appropriate numbers of sessions after this session must be reinstated.
procedure remove_hold (in_seqnum in number default 0,
                       in_unique in number default 0,
                       in_fls_calyear in GRADSCH.TGRDFELLOW_SESS.FLS_CALYEAR%TYPE default null,
                       in_fls_session in GRADSCH.TGRDFELLOW_SESS.FLS_SESSION%TYPE default null
                       )
is
v_max_calyear GRADSCH.TGRDFELLOW_SESS.FLS_CALYEAR%TYPE default null;
v_max_session GRADSCH.TGRDFELLOW_SESS.FLS_SESSION%TYPE default null;
v_last_status GRADSCH.TGRDFELLOW_SESS.FLS_STATUS%TYPE default null;
v_max_acad_year varchar2(10) default null;
v_count number default 0;
begin
  select
  substr(max(fls_calyear||decode(fls_session,20,1,30,2,10,3)),1,4),
  decode(substr(max(fls_calyear||decode(fls_session,20,1,30,2,10,3)),5),1,20,2,30,3,10) 
  into v_max_calyear,v_max_session
  from GRADSCH.TGRDFELLOW_SESS
  where fls_seqnum=in_seqnum
  and fls_unique=in_unique
  and fls_calyear||decode(fls_session,20,1,30,2,10,3) > in_fls_calyear||decode(in_fls_session,20,1,30,2,10,3)
  and ((in_fls_session in (10,20) and fls_session in (10,20)) OR (in_fls_session=30 and fls_session=30))
  and fls_status is not null;
  
   
  select fls_status into v_last_status
  from GRADSCH.TGRDFELLOW_SESS
  where fls_seqnum=in_seqnum
  and fls_unique=in_unique
  and fls_calyear=v_max_calyear
  and fls_session=v_max_session;
  --If a fellowship has been withdrawn, all session after the withdrawn session will have a NULL status
  --therefore, a WITHDRAWN sem HAS to be the last sem with a non-null status in a withdrawn fellowship
  if v_last_status in ('WITHDRAWN','DECLINED','GRADUATED')  then
    return;
  end if;
  
  
  update GRADSCH.TGRDFELLOW_SESS
  set fls_status=null
  where  fls_seqnum=in_seqnum
  and fls_unique=in_unique
  and fls_calyear=v_max_calyear
  and fls_session=v_max_session;
  
  
  --Check if this last update reduced the final academic year row to all nulls.
  v_max_acad_year:=case v_max_session when 10 then v_max_calyear||'-'||substr(v_max_calyear+1,3,2)
                                      else v_max_calyear-1 ||'-'||substr(v_max_calyear,3,2) end;
  
  select count(*) into v_count
  from GRADSCH.TGRDFELLOW_SESS
  where fls_seqnum=in_seqnum
  and fls_unique=in_unique
  and case fls_session when 10 then fls_calyear||'-'||substr(fls_calyear+1,3,2)
                                      else fls_calyear-1 ||'-'||substr(fls_calyear,3,2) end=v_max_acad_year
  and fls_status is not null;
  
  if v_count=0 then
    delete from GRADSCH.TGRDFELLOW_SESS
    where fls_seqnum=in_seqnum
    and fls_unique=in_unique
    and case fls_session when 10 then fls_calyear||'-'||substr(fls_calyear+1,3,2)
                                      else fls_calyear-1 ||'-'||substr(fls_calyear,3,2) end=v_max_acad_year;
  end if;
end;


--author:jolene singh
--function: when a WITHDRAWN, DECLINED, GRADUATED is removed the sessions have to be reinstated.
procedure fellowship_reinstated( in_seqnum in number default 0,
                       in_unique in number default 0,
                       in_fls_calyear in GRADSCH.TGRDFELLOW_SESS.FLS_CALYEAR%TYPE default null,
                       in_fls_session in GRADSCH.TGRDFELLOW_SESS.FLS_SESSION%TYPE default null
                       )
is
v_duration GRADSCH.TGRDFELLOW_BASE.FLB_DURATION%TYPE default null;
v_start_session GRADSCH.TGRDFELLOW_BASE.FLB_START_SESSION%TYPE default null;
v_start_calyear GRADSCH.TGRDFELLOW_BASE.FLB_START_CALYEAR%TYPE default null;
i number default 0;
type t_insert_sess is varray(50) of number;
type t_insert_calyear is varray(50) of number;
v_insert_sess t_insert_sess:=t_insert_sess();
v_insert_calyear t_insert_calyear:=t_insert_calyear();
v_session GRADSCH.TGRDFELLOW_BASE.FLB_START_SESSION%TYPE default null;
v_calyear GRADSCH.TGRDFELLOW_BASE.FLB_START_CALYEAR%TYPE default null;
v_end_session GRADSCH.TGRDFELLOW_BASE.FLB_START_SESSION%TYPE default null;
v_end_calyear GRADSCH.TGRDFELLOW_BASE.FLB_START_CALYEAR%TYPE default null;
v_count number default 0;

begin
  --recreate sessions that were deleted
  select flb_duration, flb_start_session, flb_start_calyear
  into v_duration, v_start_session, v_start_calyear
  from GRADSCH.TGRDFELLOW_BASE
  where flb_seqnum=in_seqnum
  and flb_unique=in_unique;
  
    --Based on start session  and duration, create a list of sessions
  v_insert_sess:=t_insert_sess();
  v_insert_calyear:=t_insert_calyear();
  v_session:=v_start_session;
  v_calyear:=v_start_calyear;
  for i in 1..(v_duration*3) loop
    if i=1 then
      if v_session = 20 then
        v_insert_sess.extend();
        v_insert_calyear.extend();
        v_insert_sess(v_insert_sess.count):=10;
        v_insert_calyear(v_insert_calyear.count):=v_calyear-1;
      elsif v_session =30 then
        v_insert_sess.extend(2);
        v_insert_calyear.extend(2);
        v_insert_sess(v_insert_sess.count-1):=10;
        v_insert_calyear(v_insert_calyear.count-1):=v_calyear-1;
        v_insert_sess(v_insert_sess.count):=20;
        v_insert_calyear(v_insert_calyear.count):=v_calyear;
      end if;
    end if;
    v_insert_sess.extend();
    v_insert_calyear.extend();
    v_insert_sess(v_insert_sess.count):= v_session;
    v_insert_calyear(v_insert_calyear.count):=v_calyear;
    
    if i=v_duration*3 then
      v_end_session:=v_session;
      v_end_calyear:=v_calyear;
      if v_session = 20 then
        v_insert_sess.extend();
        v_insert_calyear.extend();
        v_insert_sess(v_insert_sess.count):=30;
        v_insert_calyear(v_insert_calyear.count):=v_calyear;
      elsif v_session =10 then
        v_insert_sess.extend(2);
        v_insert_calyear.extend(2);
        v_insert_sess(v_insert_sess.count-1):=20;
        v_insert_calyear(v_insert_calyear.count-1):=v_calyear+1;
        v_insert_sess(v_insert_sess.count):=30;
        v_insert_calyear(v_insert_calyear.count):=v_calyear+1;
      end if;
    end if;
    select case v_session when 10 then v_calyear+1 else v_calyear end into v_calyear from dual; 
    select case v_session when 10 then 20 when 20 then 30 else 10 end into v_session from dual;
    
  end loop;
  
  for i in 1..v_insert_sess.count loop
    select count(*) into v_count
    from GRADSCH.TGRDFELLOW_SESS
    where fls_seqnum=in_seqnum
    and fls_unique=in_unique
    and fls_calyear=v_insert_calyear(i)
    and fls_session=v_insert_sess(i);
    
    if v_count=0 then
      insert into GRADSCH.TGRDFELLOW_SESS
      (fls_seqnum, fls_unique, fls_calyear, fls_session, fls_status)
      values
      (in_seqnum, in_unique, v_insert_calyear(i), v_insert_sess(i),case when v_insert_calyear(i)|| (case v_insert_sess(i) when 20 then 1 when 30 then 2 else 3 end) < v_start_calyear||(case v_start_session when 20 then 1 when 30 then 2 else 3 end) then null
                                                                       when v_insert_calyear(i)|| (case v_insert_sess(i) when 20 then 1 when 30 then 2 else 3 end) > v_end_calyear||(case v_end_session when 20 then 1 when 30 then 2 else 3 end) then null
                                                                       else 'EXPECTED' end);
    end if;                                                                 
  end loop;
  
  for each_sess in (select * from GRADSCH.TGRDFELLOW_SESS 
                       where fls_seqnum=in_seqnum
                       and fls_unique=in_unique
                       order by fls_calyear, decode(fls_session,20,1,30,2,10,3))
  loop
    if each_sess.fls_status='HOLD' then
      extend_for_hold(in_seqnum,in_unique,each_sess.fls_calyear, each_sess.fls_session);
    end if;
  end loop;
end;

--author: jolene singh
--function: receives input from disp_update_academic_year. Simple upadtes three rows in session table.\
--07/24/2014 Venkata   : Added option to enable extend_for_hold option for 'ACTIVE-HOLD' Status
  procedure proc_update_academic_year ( in_var1 in number default 0,
                                  in_var2 in number default 0,
                                  in_seqnum in number default 0,
                                  in_unique in number default 0,

                                  in_FLS_CALYEAR_1 in GRADSCH.TGRDFELLOW_SESS.FLS_CALYEAR%TYPE default null,                                       
                                  in_FLS_SESSION_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SESSION%TYPE default null,                                       
                                  in_FLS_STATUS_1 in GRADSCH.TGRDFELLOW_SESS.FLS_STATUS%TYPE default null,                                         
                                  in_FLS_TUIT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT%TYPE default null,                                             
                                  in_FLS_ADMIN_ASST_1 in GRADSCH.TGRDFELLOW_SESS.FLS_ADMIN_ASST%TYPE default null,                                 
                                  in_FLS_GRAD_APPT_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_GRAD_APPT_FEE%TYPE default null,                           
                                  in_FLS_TECH_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_TECH_FEE%TYPE default null,                                     
                                  in_FLS_R_AND_R_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_R_AND_R_FEE%TYPE default null,                               
                                  in_FLS_INTERNATIONAL_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_INTERNATIONAL_FEE%TYPE default null,                   
                                  in_FLS_DIFFERENTIAL_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_DIFFERENTIAL_FEE%TYPE default null,                     
                                  in_FLS_WELLNESS_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_WELLNESS_FEE%TYPE default null,                             
                                  in_FLS_SUPP_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP%TYPE default null,                                             
                                  in_FLS_SUPP_PAYROLL_AMT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_PAYROLL_AMT%TYPE default null,                     
                                  in_FLS_SUPP_OTHER_FUND_ACCT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_ACCT%TYPE default null,             
                                  in_FLS_SUPP_OTHER_FUND_AMT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_AMT%TYPE default null,               
                                  in_FLS_MED_INSURANCE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE%TYPE default null,                           
                                  in_FLS_MED_AMT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_AMT%TYPE default null,                                       
                                  in_FLS_MED_INSURANCE_COMMENT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE_COMMENT%TYPE default null,           
                                  in_FLS_TOTAL_SPONSOR_STIPEND_1 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_SPONSOR_STIPEND%TYPE default null,           
                                  in_FLS_SUPP_AMOUNT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_AMOUNT%TYPE default null,                               
                                  in_FLS_FRINGE_BENEFIT_AMOUNT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_FRINGE_BENEFIT_AMOUNT%TYPE default null,           
                                  in_FLS_ANNUAL_STIPEND_1 in GRADSCH.TGRDFELLOW_SESS.FLS_ANNUAL_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHS_STIPEND_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHS_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHLY_STIPEND_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHLY_STIPEND%TYPE default null,                       
                                  in_FLS_BUDGET_YEAR_1 in GRADSCH.TGRDFELLOW_SESS.FLS_BUDGET_YEAR%TYPE default null,                               
                                  in_FLS_PRIN_INVESTIGATOR_1 in GRADSCH.TGRDFELLOW_SESS.FLS_PRIN_INVESTIGATOR%TYPE default null,                   
                                  in_FLS_TOTAL_AWARD_AMOUNT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_AWARD_AMOUNT%TYPE default null,   
                                  in_FLS_CALTERM_1 in GRADSCH.TGRDFELLOW_SESS.FLS_CALTERM%TYPE default null,       -- Added by Vinod for new cal term 12/20/2013
                                  in_FLS_REMARKS_1 in GRADSCH.TGRDFELLOW_SESS.FLS_REMARKS%TYPE default null, -- Added by Vinod on 11/12/2013 for Remarks Field
                                  
                                  in_FLS_CALYEAR_2 in GRADSCH.TGRDFELLOW_SESS.FLS_CALYEAR%TYPE default null,                                       
                                  in_FLS_SESSION_2 in GRADSCH.TGRDFELLOW_SESS.FLS_SESSION%TYPE default null,                                       
                                  in_FLS_STATUS_2 in GRADSCH.TGRDFELLOW_SESS.FLS_STATUS%TYPE default null,                                         
                                  in_FLS_TUIT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT%TYPE default null,                                             
                                  in_FLS_ADMIN_ASST_2 in GRADSCH.TGRDFELLOW_SESS.FLS_ADMIN_ASST%TYPE default null,                                 
                                  in_FLS_GRAD_APPT_FEE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_GRAD_APPT_FEE%TYPE default null,                           
                                  in_FLS_TECH_FEE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_TECH_FEE%TYPE default null,                                     
                                  in_FLS_R_AND_R_FEE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_R_AND_R_FEE%TYPE default null,                               
                                  in_FLS_INTERNATIONAL_FEE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_INTERNATIONAL_FEE%TYPE default null,                   
                                  in_FLS_DIFFERENTIAL_FEE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_DIFFERENTIAL_FEE%TYPE default null,                     
                                  in_FLS_WELLNESS_FEE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_WELLNESS_FEE%TYPE default null,                             
                                  in_FLS_SUPP_2 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP%TYPE default null,                                             
                                  in_FLS_SUPP_PAYROLL_AMT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_PAYROLL_AMT%TYPE default null,                     
                                  in_FLS_SUPP_OTHER_FUND_ACCT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_ACCT%TYPE default null,             
                                  in_FLS_SUPP_OTHER_FUND_AMT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_AMT%TYPE default null,               
                                  in_FLS_MED_INSURANCE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE%TYPE default null,                           
                                  in_FLS_MED_AMT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_AMT%TYPE default null,                                       
                                  in_FLS_MED_INSURANCE_COMMENT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE_COMMENT%TYPE default null,           
                                  in_FLS_TOTAL_SPONSOR_STIPEND_2 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_SPONSOR_STIPEND%TYPE default null,           
                                  in_FLS_SUPP_AMOUNT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_AMOUNT%TYPE default null,                               
                                  in_FLS_FRINGE_BENEFIT_AMOUNT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_FRINGE_BENEFIT_AMOUNT%TYPE default null,           
                                  in_FLS_ANNUAL_STIPEND_2 in GRADSCH.TGRDFELLOW_SESS.FLS_ANNUAL_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHS_STIPEND_2 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHS_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHLY_STIPEND_2 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHLY_STIPEND%TYPE default null,                       
                                  in_FLS_BUDGET_YEAR_2 in GRADSCH.TGRDFELLOW_SESS.FLS_BUDGET_YEAR%TYPE default null,                               
                                  in_FLS_PRIN_INVESTIGATOR_2 in GRADSCH.TGRDFELLOW_SESS.FLS_PRIN_INVESTIGATOR%TYPE default null,                   
                                  in_FLS_TOTAL_AWARD_AMOUNT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_AWARD_AMOUNT%TYPE default null,  
                                  in_FLS_CALTERM_2 in GRADSCH.TGRDFELLOW_SESS.FLS_CALTERM%TYPE default null,       -- Added by Vinod for new cal term 12/20/2013
                                  in_FLS_REMARKS_2 in GRADSCH.TGRDFELLOW_SESS.FLS_REMARKS%TYPE default null, -- Added by Vinod on 11/12/2013 for Remarks Field
                                  
                                  in_FLS_CALYEAR_3 in GRADSCH.TGRDFELLOW_SESS.FLS_CALYEAR%TYPE default null,                                       
                                  in_FLS_SESSION_3 in GRADSCH.TGRDFELLOW_SESS.FLS_SESSION%TYPE default null,                                       
                                  in_FLS_STATUS_3 in GRADSCH.TGRDFELLOW_SESS.FLS_STATUS%TYPE default null,                                         
                                  in_FLS_TUIT_ONLY_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT_ONLY%TYPE default null,                                   
                                  in_FLS_TUIT_AIDCODE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT_AIDCODE%TYPE default null,                             
                                  in_FLS_TUIT_CHRG_SCH_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT_CHRG_SCH%TYPE default null,                           
                                  in_FLS_TUIT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT%TYPE default null,                                             
                                  in_FLS_ADMIN_ASST_3 in GRADSCH.TGRDFELLOW_SESS.FLS_ADMIN_ASST%TYPE default null,                                 
                                  in_FLS_GRAD_APPT_FEE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_GRAD_APPT_FEE%TYPE default null,                           
                                  in_FLS_TECH_FEE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TECH_FEE%TYPE default null,                                     
                                  in_FLS_R_AND_R_FEE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_R_AND_R_FEE%TYPE default null,                               
                                  in_FLS_INTERNATIONAL_FEE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_INTERNATIONAL_FEE%TYPE default null,                   
                                  in_FLS_DIFFERENTIAL_FEE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_DIFFERENTIAL_FEE%TYPE default null,                     
                                  in_FLS_WELLNESS_FEE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_WELLNESS_FEE%TYPE default null,                             
                                  in_FLS_SUPP_3 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP%TYPE default null,                                             
                                  in_FLS_SUPP_PAYROLL_AMT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_PAYROLL_AMT%TYPE default null,                     
                                  in_FLS_SUPP_OTHER_FUND_ACCT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_ACCT%TYPE default null,             
                                  in_FLS_SUPP_OTHER_FUND_AMT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_AMT%TYPE default null,               
                                  in_FLS_MED_INSURANCE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE%TYPE default null,                           
                                  in_FLS_MED_AMT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_AMT%TYPE default null,                                       
                                  in_FLS_MED_INSURANCE_COMMENT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE_COMMENT%TYPE default null,           
                                  in_FLS_TOTAL_SPONSOR_STIPEND_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_SPONSOR_STIPEND%TYPE default null,           
                                  in_FLS_SUPP_AMOUNT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_AMOUNT%TYPE default null,                               
                                  in_FLS_FRINGE_BENEFIT_AMOUNT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_FRINGE_BENEFIT_AMOUNT%TYPE default null,           
                                  in_FLS_ANNUAL_STIPEND_3 in GRADSCH.TGRDFELLOW_SESS.FLS_ANNUAL_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHS_STIPEND_3 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHS_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHLY_STIPEND_3 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHLY_STIPEND%TYPE default null,                       
                                  in_FLS_BUDGET_YEAR_3 in GRADSCH.TGRDFELLOW_SESS.FLS_BUDGET_YEAR%TYPE default null,                               
                                  in_FLS_PRIN_INVESTIGATOR_3 in GRADSCH.TGRDFELLOW_SESS.FLS_PRIN_INVESTIGATOR%TYPE default null,                   
                                  in_FLS_TOTAL_AWARD_AMOUNT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_AWARD_AMOUNT%TYPE default null,
                                  in_FLS_CALTERM_3 in GRADSCH.TGRDFELLOW_SESS.FLS_CALTERM%TYPE default null,       -- Added by Vinod for new cal term 12/20/2013
                                  in_FLS_REMARKS_3 in GRADSCH.TGRDFELLOW_SESS.FLS_REMARKS%TYPE default null, -- Added by Vinod on 11/12/2013 for Remarks Field
                                  
                                  in_new_form in varchar2 default null,
                                  in_form_begin_date in varchar2 default null,
                                  in_form_end_date in varchar2 default null,
                                  
                                  in_action in varchar2 default 'Cancel')
is

type t_tgrdfellow_sess is varray(3) of GRADSCH.TGRDFELLOW_SESS%rowtype;
varray_tgrdfellow_sess t_tgrdfellow_sess:=t_tgrdfellow_sess();
v_count number default 0;
v_old_status GRADSCH.TGRDFELLOW_SESS.FLS_STATUS%TYPE default null;
begin
  if (lower(in_action)='save') then
    --update sessions with all info 
    varray_tgrdfellow_sess.extend(3);
    select in_seqnum,in_unique,in_fls_calyear_1,in_fls_session_1,in_fls_status_1,null,null,null,in_FLS_TUIT_1,in_FLS_ADMIN_ASST_1,in_FLS_GRAD_APPT_FEE_1,in_FLS_TECH_FEE_1,
        in_FLS_R_AND_R_FEE_1,in_FLS_INTERNATIONAL_FEE_1,in_FLS_DIFFERENTIAL_FEE_1, in_FLS_WELLNESS_FEE_1,in_FLS_SUPP_1,in_FLS_SUPP_PAYROLL_AMT_1,in_FLS_SUPP_OTHER_FUND_ACCT_1,in_FLS_SUPP_OTHER_FUND_AMT_1,in_FLS_MED_INSURANCE_1,
        in_FLS_MED_AMT_1,in_FLS_MED_INSURANCE_COMMENT_1,in_FLS_TOTAL_SPONSOR_STIPEND_1,in_FLS_SUPP_AMOUNT_1,in_FLS_FRINGE_BENEFIT_AMOUNT_1,in_FLS_ANNUAL_STIPEND_1, in_FLS_MONTHS_STIPEND_1 ,in_FLS_MONTHLY_STIPEND_1,in_FLS_TOTAL_AWARD_AMOUNT_1, 
        in_FLS_BUDGET_YEAR_1, in_FLS_PRIN_INVESTIGATOR_1,in_FLS_CALTERM_1,null,in_FLS_REMARKS_1 into varray_tgrdfellow_sess(1)
    from dual;
    
    select in_seqnum,in_unique,in_fls_calyear_2,in_fls_session_2,in_fls_status_2,null,null,null,in_FLS_TUIT_2,in_FLS_ADMIN_ASST_2,in_FLS_GRAD_APPT_FEE_2,in_FLS_TECH_FEE_2,
        in_FLS_R_AND_R_FEE_2,in_FLS_INTERNATIONAL_FEE_2,in_FLS_DIFFERENTIAL_FEE_2, in_FLS_WELLNESS_FEE_2,in_FLS_SUPP_2,in_FLS_SUPP_PAYROLL_AMT_2,in_FLS_SUPP_OTHER_FUND_ACCT_2,in_FLS_SUPP_OTHER_FUND_AMT_2,in_FLS_MED_INSURANCE_2,
        in_FLS_MED_AMT_2,in_FLS_MED_INSURANCE_COMMENT_2,in_FLS_TOTAL_SPONSOR_STIPEND_2,in_FLS_SUPP_AMOUNT_2,in_FLS_FRINGE_BENEFIT_AMOUNT_2,in_FLS_ANNUAL_STIPEND_2, in_FLS_MONTHS_STIPEND_2 ,in_FLS_MONTHLY_STIPEND_2,in_FLS_TOTAL_AWARD_AMOUNT_2,in_FLS_BUDGET_YEAR_2,                               
        in_FLS_PRIN_INVESTIGATOR_2,in_FLS_CALTERM_2,null,in_FLS_REMARKS_2 into varray_tgrdfellow_sess(2)
    from dual;
    
    select in_seqnum,in_unique,in_fls_calyear_3,in_fls_session_3,in_fls_status_3,null,null,null,in_FLS_TUIT_3,in_FLS_ADMIN_ASST_3,in_FLS_GRAD_APPT_FEE_3,in_FLS_TECH_FEE_3,
        in_FLS_R_AND_R_FEE_3,in_FLS_INTERNATIONAL_FEE_3,in_FLS_DIFFERENTIAL_FEE_3, in_FLS_WELLNESS_FEE_3,in_FLS_SUPP_3,in_FLS_SUPP_PAYROLL_AMT_3,in_FLS_SUPP_OTHER_FUND_ACCT_3,in_FLS_SUPP_OTHER_FUND_AMT_3,in_FLS_MED_INSURANCE_3,
        in_FLS_MED_AMT_3,in_FLS_MED_INSURANCE_COMMENT_3,in_FLS_TOTAL_SPONSOR_STIPEND_3,in_FLS_SUPP_AMOUNT_3,in_FLS_FRINGE_BENEFIT_AMOUNT_3,in_FLS_ANNUAL_STIPEND_3, in_FLS_MONTHS_STIPEND_3 ,in_FLS_MONTHLY_STIPEND_3,in_FLS_TOTAL_AWARD_AMOUNT_3,in_FLS_BUDGET_YEAR_3,                               
        in_FLS_PRIN_INVESTIGATOR_3,in_FLS_CALTERM_3,null,in_FLS_REMARKS_3 into varray_tgrdfellow_sess(3)
    from dual;
  
    for i in 1..varray_tgrdfellow_sess.count loop
      if (    (varray_tgrdfellow_sess(i).fls_session is not null) 
        and (varray_tgrdfellow_sess(i).fls_calyear is not null) )then
      --Check if a new budget year has been added. For foreign key
        if trim(varray_tgrdfellow_sess(i).fls_budget_year) is not null then
          select count(*) into v_count
          from  GRADSCH.TGRDFELLOW_BUDGET
          where fbg_seqnum=in_seqnum
          and fbg_unique=in_unique
          and fbg_budget_year=varray_tgrdfellow_sess(i).fls_budget_year;
          
          if v_count=0 then
            insert into GRADSCH.TGRDFELLOW_BUDGET (fbg_seqnum, fbg_unique, fbg_budget_year) values
            (in_seqnum, in_unique,varray_tgrdfellow_sess(i).fls_budget_year);
          end if;
        end if;
        
        --Now check how the status has changed
        select fls_status into v_old_status
        from GRADSCH.TGRDFELLOW_SESS
        where fls_seqnum=in_seqnum
        and fls_unique=in_unique
        and fls_calyear=varray_tgrdfellow_sess(i).fls_calyear
        and fls_session=varray_tgrdfellow_sess(i).fls_session;
        
        update GRADSCH.TGRDFELLOW_SESS
        set row=varray_tgrdfellow_sess(i)
        where fls_seqnum=in_seqnum
        and fls_unique=in_unique
        and fls_calyear=varray_tgrdfellow_sess(i).fls_calyear
        and fls_session=varray_tgrdfellow_sess(i).fls_session;
        
        if((v_old_status in ('WITHDRAWN','DECLINED','GRADUATED') ) AND (varray_tgrdfellow_sess(i).fls_status not in ('WITHDRAWN','DECLINED','GRADUATED') )) then
          fellowship_reinstated(in_seqnum,in_unique,varray_tgrdfellow_sess(i).fls_calyear, varray_tgrdfellow_sess(i).fls_session);
        elsif ((v_old_status='HOLD') AND (varray_tgrdfellow_sess(i).fls_status!='HOLD')) then
          remove_hold(in_seqnum, in_unique,varray_tgrdfellow_sess(i).fls_calyear,varray_tgrdfellow_sess(i).fls_session);
        elsif((v_old_status!='HOLD') AND (varray_tgrdfellow_sess(i).fls_status='HOLD')) then
        extend_for_hold(in_seqnum,in_unique,varray_tgrdfellow_sess(i).fls_calyear, varray_tgrdfellow_sess(i).fls_session);
   
        elsif ((v_old_status='ACTIVE - HOLD') AND (varray_tgrdfellow_sess(i).fls_status!='ACTIVE - HOLD')) then    --added by Venkata 07/24/2014
          remove_hold(in_seqnum, in_unique,varray_tgrdfellow_sess(i).fls_calyear,varray_tgrdfellow_sess(i).fls_session); --added by Venkata 07/24/2014
        elsif((v_old_status!='ACTIVE - HOLD') AND (varray_tgrdfellow_sess(i).fls_status='ACTIVE - HOLD')) then            --added by Venkata 07/24/2014
          extend_for_hold(in_seqnum,in_unique,varray_tgrdfellow_sess(i).fls_calyear, varray_tgrdfellow_sess(i).fls_session); --added by Venkata 07/24/2014  
     
        elsif ((v_old_status not in ('WITHDRAWN','DECLINED','GRADUATED') ) AND (varray_tgrdfellow_sess(i).fls_status in ('WITHDRAWN','DECLINED','GRADUATED') )) then
          fellowship_withdrawn(in_seqnum,in_unique,varray_tgrdfellow_sess(i).fls_calyear, varray_tgrdfellow_sess(i).fls_session);
          exit;
        end if;
      end if;
    end loop; 
    
    update GRADSCH.TGRDFELLOW_BASE
    set flb_last_revised_date=sysdate
    where flb_seqnum=in_seqnum
    and flb_unique=in_unique;
  
    if in_new_form='YES' then
      insert into GRADSCH.TGRDFELLOW_FORM_HISTORY values
      (in_seqnum,in_unique,sysdate, to_date(to_date(in_form_begin_date,'MM/DD/RR'),'DD-MON-RR'), to_date(to_date(in_form_end_date,'MM/DD/RR'),'DD-MON-RR'));
    end if;
  end if;
  commit;
  --owa_util.redirect_url('www_rgs.wfl_fellowship.disp_new_view?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum);
  owa_util.redirect_url('www_rgs.wgb_dispstd.disp_grad?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum||'&in_view=6');
end;

--author: vinod penmetsa
--function: called when "Delete Row" button is pressed. 
--delete session start
procedure disp_delete_session (in_var1 in number default 0,
                                      in_var2 in number default 0,
                                      in_seqnum in number default 0,
                                      in_unique in number default 0,
                                      in_academic_year in varchar2 default null,
                                      in_action in varchar2 default 'Delete Row'
                                    )
is

char_academic_year varchar2(256); 
num_academic_year number default 0;
begin
char_academic_year := substr(in_academic_year,1,4);
num_academic_year := to_number(char_academic_year);
Delete From GRADSCH.TGRDFELLOW_SESS where FLS_SEQNUM = in_seqnum and FLS_UNIQUE = in_unique and FLS_CALYEAR = num_academic_year and FLS_Session = 10; 
Delete From GRADSCH.TGRDFELLOW_SESS where FLS_SEQNUM = in_seqnum and FLS_UNIQUE = in_unique and FLS_CALYEAR = num_academic_year+1 and FLS_Session in (20,30); 
commit;
owa_util.redirect_url('www_rgs.wgb_dispstd.disp_grad?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum||'&in_view=6');
end;
--delete session end


--author: vinod penmetsa
--function: called when "Add Row" button is pressed. 
--Add session start
procedure disp_add_session (in_var1 in number default 0,
                                      in_var2 in number default 0,
                                      in_seqnum in number default 0,
                                      in_unique in number default 0,
                                      in_action in varchar2 default 'Add Row'
                                    )
is

new_budget_year varchar2(256); 
num_budget_year1 number default 0;
num_budget_year2 number default 0;
current_budget_year varchar2(256);
num_calyear number default 0;
begin

Update GRADSCH.TGRDFELLOW_BASE Set FLB_DURATION = FLB_DURATION + 1 Where FLB_SEQNUM = in_seqnum and FLB_UNIQUE = in_unique; 
Commit;

Select FBG_BUDGET_YEAR into current_budget_year 
From (Select * from TGRDFELLOW_BUDGET Where FBG_SEQNUM = in_seqnum and FBG_UNIQUE = in_unique
      Order By FBG_BUDGET_YEAR Desc)
Where ROWNUM = 1;
              
commit;

num_budget_year1 := to_number(substr(current_budget_year,1,4))+1;
num_budget_year2 := to_number(substr(current_budget_year,6,7))+1;
new_budget_year := to_char(num_budget_year1)|| '-' || to_char(num_budget_year2);

Insert into tgrdfellow_budget(fbg_seqnum,fbg_unique,fbg_budget_year) values (in_seqnum,in_unique,new_budget_year);
commit;

Select FLS_CALYEAR into num_calyear
From (Select * From tgrdfellow_sess 
      Where fls_seqnum = in_seqnum and fls_unique = in_unique Order By fls_calyear Desc)
Where ROWNUM = 1;

for i in 1..3 loop
    insert into GRADSCH.TGRDFELLOW_SESS 
    (FLS_SEQNUM,FLS_UNIQUE,FLS_CALYEAR,FLS_SESSION,FLS_STATUS,FLS_BUDGET_YEAR,FLS_CALTERM)
    values(in_seqnum,in_unique,case i when 1 then num_calyear when 2 then num_calyear+1 else num_calyear+1 end,case i when 1 then 10 when 2 then 20 else 30 end,'EXPECTED',new_budget_year,
           case i when 1 then num_calyear when 2 then num_calyear+1 else num_calyear+1 end||case i when 1 then 10 when 2 then 20 else 30 end);
  end loop;
commit;  

owa_util.redirect_url('www_rgs.wgb_dispstd.disp_grad?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum||'&in_view=6');
end;
--add session end


--author: jolene singh
--function: called when "update sesison" button is pressed. has form open and close tags. Calls display modules as apt.
procedure disp_update_session (in_var1 in number default 0,
                                      in_var2 in number default 0,
                                      in_seqnum in number default 0,
                                      in_unique in number default 0,
                                      in_calyear in varchar2 default null,
                                      in_session in number default null,
                                      in_action in varchar2 default 'Update'
                                    )
is
cur_user twwwuser1%rowtype;
cur_base tgrdbase%rowtype;

cursor base_data is
select * from tgrdbase
where b_seqnum=in_seqnum;

v_academic_year varchar2(10) default '9999-99';

begin
  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is  null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;
  open base_data;
  fetch base_data into cur_base;
  if (base_data%notfound) then
    close base_data;
    wgb_lists.disp_qry_appl(1015 , in_var1, in_var2, cur_base.b_puid, cur_base.b_sid,
                          null, null, null, null,
                          null, null, null, null,
                          null);
    return;
  end if;
  close base_data;
  
  wgb_shared.form_start('Graduate School Intranet Database');
  -- insert body tags and toolbar
  wgb_shared.body_start2('Update Session',null,null, in_var1,in_var2, cur_user);
  
  --Add javascript calls
  wgb_shared.print_java_date();
  wgb_shared.print_java_numeric;
  print_java_copy_from_previous();
  print_java_alert();
  --Add all application specific code here
  v_academic_year:=case in_session when 10 then in_calyear||'-'||substr(in_calyear+1,3,2)
                                   else (in_calyear-1)||substr(in_calyear,3,2) end;
  print_student_details(in_seqnum);
  htp.formopen('www_rgs.wfl_fellowship.proc_update_session','POST');
    htp.formhidden('in_var1',in_var1);
    htp.formhidden('in_var2',in_var2);
    htp.formhidden('in_seqnum',in_seqnum);
    htp.formhidden('in_unique',in_unique);
    print_fellowship_details(in_var1,in_var2,in_seqnum,in_unique);
    print_session_details(in_var1,in_var2,in_seqnum,in_unique,v_academic_year,in_session,'UPDATE');
    print_form_questions(in_var1,in_var2,in_seqnum,in_unique);
  htp.nl;
  htp.formsubmit('in_action','Save');
  htp.formsubmit('in_action','Cancel');
  htp.formclose;
  --Code ends here
  htp.bodyClose;
  htp.htmlClose;
end;

--author: jolene singh
--function: receives input from disp_update_session. SImple updates one session instead of three. identical to update academic_year
----07/24/2014 Venkata   : Added option to enable extend_for_hold option for 'ACTIVE-HOLD' Status
procedure proc_update_session ( in_var1 in number default 0,
                                  in_var2 in number default 0,
                                  in_seqnum in number default 0,
                                  in_unique in number default 0,

                                  in_FLS_CALYEAR_1 in GRADSCH.TGRDFELLOW_SESS.FLS_CALYEAR%TYPE default null,                                       
                                  in_FLS_SESSION_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SESSION%TYPE default null,                                       
                                  in_FLS_STATUS_1 in GRADSCH.TGRDFELLOW_SESS.FLS_STATUS%TYPE default null,                                         
                                  in_FLS_TUIT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT%TYPE default null,                                             
                                  in_FLS_ADMIN_ASST_1 in GRADSCH.TGRDFELLOW_SESS.FLS_ADMIN_ASST%TYPE default null,                                 
                                  in_FLS_GRAD_APPT_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_GRAD_APPT_FEE%TYPE default null,                           
                                  in_FLS_TECH_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_TECH_FEE%TYPE default null,                                     
                                  in_FLS_R_AND_R_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_R_AND_R_FEE%TYPE default null,                               
                                  in_FLS_INTERNATIONAL_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_INTERNATIONAL_FEE%TYPE default null,                   
                                  in_FLS_DIFFERENTIAL_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_DIFFERENTIAL_FEE%TYPE default null,                     
                                  in_FLS_WELLNESS_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_WELLNESS_FEE%TYPE default null,                             
                                  in_FLS_SUPP_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP%TYPE default null,                                             
                                  in_FLS_SUPP_PAYROLL_AMT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_PAYROLL_AMT%TYPE default null,                     
                                  in_FLS_SUPP_OTHER_FUND_ACCT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_ACCT%TYPE default null,             
                                  in_FLS_SUPP_OTHER_FUND_AMT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_AMT%TYPE default null,               
                                  in_FLS_MED_INSURANCE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE%TYPE default null,                           
                                  in_FLS_MED_AMT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_AMT%TYPE default null,                                       
                                  in_FLS_MED_INSURANCE_COMMENT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE_COMMENT%TYPE default null,           
                                  in_FLS_TOTAL_SPONSOR_STIPEND_1 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_SPONSOR_STIPEND%TYPE default null,           
                                  in_FLS_SUPP_AMOUNT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_AMOUNT%TYPE default null,                               
                                  in_FLS_FRINGE_BENEFIT_AMOUNT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_FRINGE_BENEFIT_AMOUNT%TYPE default null,           
                                  in_FLS_ANNUAL_STIPEND_1 in GRADSCH.TGRDFELLOW_SESS.FLS_ANNUAL_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHS_STIPEND_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHS_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHLY_STIPEND_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHLY_STIPEND%TYPE default null,                       
                                  in_FLS_BUDGET_YEAR_1 in GRADSCH.TGRDFELLOW_SESS.FLS_BUDGET_YEAR%TYPE default null,                               
                                  in_FLS_PRIN_INVESTIGATOR_1 in GRADSCH.TGRDFELLOW_SESS.FLS_PRIN_INVESTIGATOR%TYPE default null,                   
                                  in_FLS_TOTAL_AWARD_AMOUNT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_AWARD_AMOUNT%TYPE default null,   
                                  in_FLS_CALTERM_1 in GRADSCH.TGRDFELLOW_SESS.FLS_CALTERM%TYPE default null,       -- Added by Vinod for new cal term 12/20/2013
                                  in_FLS_REMARKS_1 in GRADSCH.TGRDFELLOW_SESS.FLS_REMARKS%TYPE default null, -- Added by Vinod on 11/12/2013 for Remarks Field
                                  
                                  in_new_form in varchar2 default null,
                                  in_form_begin_date in varchar2 default null,
                                  in_form_end_date in varchar2 default null,
                                  
                                  in_action in varchar2 default 'Cancel')
is
i number default 1;
type t_tgrdfellow_sess is varray(3) of GRADSCH.TGRDFELLOW_SESS%rowtype;
varray_tgrdfellow_sess t_tgrdfellow_sess:=t_tgrdfellow_sess();
v_count number default 0;
v_old_status GRADSCH.TGRDFELLOW_SESS.FLS_STATUS%TYPE default null;
begin
if (lower(in_action)='save') then
    --update sessions with all info 
    varray_tgrdfellow_sess.extend(1);
    select in_seqnum,in_unique,in_fls_calyear_1,in_fls_session_1,in_fls_status_1,null,null,null,in_FLS_TUIT_1,in_FLS_ADMIN_ASST_1,in_FLS_GRAD_APPT_FEE_1,in_FLS_TECH_FEE_1,
        in_FLS_R_AND_R_FEE_1,in_FLS_INTERNATIONAL_FEE_1,in_FLS_DIFFERENTIAL_FEE_1, in_FLS_WELLNESS_FEE_1,in_FLS_SUPP_1,in_FLS_SUPP_PAYROLL_AMT_1,in_FLS_SUPP_OTHER_FUND_ACCT_1,in_FLS_SUPP_OTHER_FUND_AMT_1,in_FLS_MED_INSURANCE_1,
        in_FLS_MED_AMT_1,in_FLS_MED_INSURANCE_COMMENT_1,in_FLS_TOTAL_SPONSOR_STIPEND_1,in_FLS_SUPP_AMOUNT_1,in_FLS_FRINGE_BENEFIT_AMOUNT_1,in_FLS_ANNUAL_STIPEND_1, in_FLS_MONTHS_STIPEND_1 ,in_FLS_MONTHLY_STIPEND_1,in_FLS_TOTAL_AWARD_AMOUNT_1,in_FLS_BUDGET_YEAR_1,                               
        in_FLS_PRIN_INVESTIGATOR_1,in_FLS_CALTERM_1,null,in_FLS_REMARKS_1 into varray_tgrdfellow_sess(1)
    from dual;
    i:=1;
    if ((varray_tgrdfellow_sess(i).fls_session is not null) 
        and (varray_tgrdfellow_sess(i).fls_calyear is not null) )then
      --Check if a new budget year has been added. For foreign key
        if trim(varray_tgrdfellow_sess(i).fls_budget_year) is not null then
          select count(*) into v_count
          from  GRADSCH.TGRDFELLOW_BUDGET
          where fbg_seqnum=in_seqnum
          and fbg_unique=in_unique
          and fbg_budget_year=varray_tgrdfellow_sess(i).fls_budget_year;
          
          if v_count=0 then
            insert into GRADSCH.TGRDFELLOW_BUDGET (fbg_seqnum, fbg_unique, fbg_budget_year) values
            (in_seqnum, in_unique,varray_tgrdfellow_sess(i).fls_budget_year);
          end if;
        end if;
        
        --Now check how the status has changed
        select fls_status into v_old_status
        from GRADSCH.TGRDFELLOW_SESS
        where fls_seqnum=in_seqnum
        and fls_unique=in_unique
        and fls_calyear=varray_tgrdfellow_sess(i).fls_calyear
        and fls_session=varray_tgrdfellow_sess(i).fls_session;
        
        update GRADSCH.TGRDFELLOW_SESS
        set row=varray_tgrdfellow_sess(i)
        where fls_seqnum=in_seqnum
        and fls_unique=in_unique
        and fls_calyear=varray_tgrdfellow_sess(i).fls_calyear
        and fls_session=varray_tgrdfellow_sess(i).fls_session;
        
        if((v_old_status in ('WITHDRAWN','DECLINED','GRADUATED') ) AND (varray_tgrdfellow_sess(i).fls_status not in ('WITHDRAWN','DECLINED','GRADUATED') )) then
          fellowship_reinstated(in_seqnum,in_unique,varray_tgrdfellow_sess(i).fls_calyear, varray_tgrdfellow_sess(i).fls_session);
        elsif ((v_old_status='HOLD') AND (varray_tgrdfellow_sess(i).fls_status!='HOLD')) then
          remove_hold(in_seqnum, in_unique,varray_tgrdfellow_sess(i).fls_calyear,varray_tgrdfellow_sess(i).fls_session);
        elsif((v_old_status!='HOLD') AND (varray_tgrdfellow_sess(i).fls_status='HOLD')) then
          extend_for_hold(in_seqnum,in_unique,varray_tgrdfellow_sess(i).fls_calyear, varray_tgrdfellow_sess(i).fls_session);
      
        elsif ((v_old_status='ACTIVE - HOLD') AND (varray_tgrdfellow_sess(i).fls_status!='ACTIVE - HOLD')) then              --added by Venkata 07/24/2014
          remove_hold(in_seqnum, in_unique,varray_tgrdfellow_sess(i).fls_calyear,varray_tgrdfellow_sess(i).fls_session);      --added by Venkata 07/24/2014
        elsif((v_old_status!='ACTIVE - HOLD') AND (varray_tgrdfellow_sess(i).fls_status='ACTIVE - HOLD')) then                 --added by Venkata 07/24/2014
          extend_for_hold(in_seqnum,in_unique,varray_tgrdfellow_sess(i).fls_calyear, varray_tgrdfellow_sess(i).fls_session);    --added by Venkata 07/24/2014
     
        elsif ((v_old_status not in ('WITHDRAWN','DECLINED','GRADUATED') ) AND (varray_tgrdfellow_sess(i).fls_status in ('WITHDRAWN','DECLINED','GRADUATED') )) then
          fellowship_withdrawn(in_seqnum,in_unique,varray_tgrdfellow_sess(i).fls_calyear, varray_tgrdfellow_sess(i).fls_session);
        end if;
    end if;   
  
    update GRADSCH.TGRDFELLOW_BASE
    set flb_last_revised_date=sysdate
    where flb_seqnum=in_seqnum
    and flb_unique=in_unique;
  
    if in_new_form='YES' then
      insert into GRADSCH.TGRDFELLOW_FORM_HISTORY values
      (in_seqnum,in_unique,sysdate, to_date(to_date(in_form_begin_date,'MM/DD/RR'),'DD-MON-RR'), to_date(to_date(in_form_end_date,'MM/DD/RR'),'DD-MON-RR'));
    end if;
  end if;
  commit;
  --owa_util.redirect_url('www_rgs.wfl_fellowship.disp_new_view?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum);
  owa_util.redirect_url('www_rgs.wgb_dispstd.disp_grad?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum||'&in_view=6');
end;

--author: jolene singh
--function: called when the "reset<-> session" button is clicked on main screen.
procedure reset_session_click(in_var1 in number default 0,
                              in_var2 in number default 0,
                              in_seqnum in number default 0,
                              in_unique in number default 0)
is
begin
  reset_sessions(in_seqnum,in_unique);
  commit;
  
  update GRADSCH.TGRDFELLOW_BASE
  set flb_last_revised_date=sysdate
  where flb_seqnum=in_seqnum
  and flb_unique=in_unique;
  
  --owa_util.redirect_url('www_rgs.wfl_fellowship.disp_new_view?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum);
  owa_util.redirect_url('www_rgs.wgb_dispstd.disp_grad?in_var1='||in_var1||'&in_var2='||in_var2||'&in_seqnum='||in_seqnum||'&in_view=6');
end;


--author: jolene singh
--function: this function is identical to WGB_DISPSTD procedure. It is supposed to print the 
--          funding table summary at the borrom of fellowship display.
procedure print_funding_summary(in_var1 number default 0,
                        in_var2 number default 0,
                        in_seqnum number default 0)
is
  cur_user twwwuser1%rowtype;
  cursor fund_ptr is
	select * from tgrdfund
	where fund_seqnum=in_seqnum
	order by fund_payp desc;
  
  v_dept TGRDREFER.REF_CODE%TYPE;
begin
  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;
  
--print Purdue funding information which is read only by everyone
 htp.print(htf.bold('Funding Summary'));
 htp.tableopen;
 htp.tablerowopen;
  htp.tableheader('Session');
  htp.tableheader('Pay Period');
  htp.tableheader('FTE');
  htp.tableheader('Account','left');
  htp.tabledata(' '); -- 2/13/2008
  htp.tabledata(' '); -- 2/13/2008
  htp.tableheader('Department','left'); -- 2/13/2008
  htp.tabledata(' '); -- 2/13/2008
  htp.tabledata(' '); -- 2/13/2008
  htp.tableheader('Position','left');
  htp.tableheader('Monthly','left');  
 htp.tablerowclose;
 for b in fund_ptr loop
   htp.tablerowopen;
      htp.tabledata(b.fund_term || '/' || b.fund_acyear);
      htp.tabledata(b.fund_payp);
      htp.tabledata(b.fund_fte);
      
      -- Added 2/13/2008
      If b.fund_fund Is Null Then
        htp.tabledata(b.fund_account);
        htp.tabledata(' ');
        htp.tabledata(' ');
        htp.tabledata(b.fund_dept);
        htp.tabledata(' ');
        htp.tabledata(' ');
        htp.tabledata(b.fund_period || '  ' || b.fund_post);
      Else
        htp.tabledata(b.fund_fund ||' ' || b.fund_dept || '-' || b.fund_id );
        htp.tabledata(' ');
        htp.tabledata(' ');
        
        Select ref_code Into v_dept
        From tgrdrefer
        Where ref_name = 'dept_account'
            And ref_literal = b.fund_dept;
        htp.tabledata(Initcap(wgb_functions.dept_of(v_dept,'PWL'))); -- added 7/21/2008
        --htp.tabledata(Initcap(wgb_functions.dept_of(v_dept,'1'))); -- removed 7/21/2008
        htp.tabledata(' ');
        htp.tabledata(' ');
        htp.tabledata(b.fund_posc || ' ' || b.fund_post);
      End If;
      
      --htp.tabledata(b.fund_fund ||' ' || b.fund_dept || '-' || b.fund_id ); -- removed 2/13/2008
      --htp.tabledata(b.fund_posc || ' ' || b.fund_post); -- removed 2/13/2008
      
--      THE AMOUNT OF PAY IS NOT AVAILABLE TO THOSE OUTSIDE THE FELLOWSHIP AREA
      IF cur_user.us_role1 < 15 then
         htp.tabledata(b.fund_amount);
      ELSE
         htp.tabledata('n/a');      
      END IF;
    htp.tablerowclose;
 end loop;
 htp.tableclose;
end;



--author: jolene singh
--function: this is what prints the main screen.
--MODIFICATIONS:
--05/08/2013 Jolene S. : Added a call to print funding summary
--06/27/2013 Romina    : Changed "Begin Date" and "End Date" treatment to resolve date conversion errors
--07/24/2014 Venkata   : Changed Tution display to show up for both Assistantship and Fellowship 
-- 11/17/2014 Shanmukesh : Modified code to display funding info when status is on hold 
--                         Modified code to display total award amount for each budget year in the Budget year account information        
procedure print_funding ( in_var1 in number default 0,
                          in_var2 in number default 0,
                          in_seqnum in number default 0
                          )
IS
cur_user twwwuser1%rowtype;
cur_appl tappappl%rowtype;
cur_reg tgrdreg%rowtype;
v_tgrdfellow_base GRADSCH.TGRDFELLOW_BASE%ROWTYPE;
v_background_color varchar2(10);
v_tgrdfellow_sess GRADSCH.TGRDFELLOW_SESS%ROWTYPE;
cursor admit_ptr is
  select * from tappappl
  where ap_seqnum = in_seqnum
  and ap_action = 'A'
  order by ap_adm desc;

    
BEGIN
  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if wgb_functions.mask_and(cur_user.us_updflags,wgb_constants.constant_updflag_fellowship,8)=wgb_constants.constant_updflag_fellowship then
  -- add admission info and registration info to this display
  -- this info is needed for funding
  open admit_ptr;
  fetch admit_ptr into cur_appl;
  if admit_ptr%notfound then
    close admit_ptr;
    htp.bold('No admitted application found.');
  else
    close admit_ptr;
    htp.bold('Most recent admissions for ' || cur_appl.ap_term || '/' || cur_appl.ap_acyear ||
           '  (' || cur_appl.ap_dept || ') ' || wgb_functions.dept_of(cur_appl.ap_dept, cur_appl.ap_campus) ||
           ' at ' || wgb_functions.campus_of(cur_appl.ap_campus));
  end if;
  htp.nl;
  -- get/print most recent registration
  cur_reg := wps_shared.get_most_recent_registration(in_seqnum);
  if cur_reg.rg_term is null then
    htp.bold('No registration information found.');
  else
    htp.bold('Most recent registration for ' || cur_reg.rg_term || '/' || cur_reg.rg_acyear ||
           ' with class of ' || cur_reg.rg_class ||
           ' in (' || cur_reg.rg_dept || ') ' || wgb_functions.dept_of(cur_reg.rg_dept, cur_reg.rg_campus) ||
           ' at ' || wgb_functions.campus_of(cur_reg.rg_campus));

  end if;

  htp.nl;
  htp.nl;
     
  htp.print(htf.fontOpen('Purple','Bold',4) || '<B>Purdue Fellowships and Funding</B> ' ||
               htf.fontClose || '   ' ||
               htf.anchor(wgb_constants.constant_html_static_page || '/HELP_PAGES/fellows_help.htm',
	           	'  Fellowship Help ' ) || '   *** Do Not Use Refresh/Reload while processing fellowships');
  htp.nl;
  
  --The following temporary code is being removed altogether   
  --Jolene S. Temporary change for testing new package. Should be removed.
  --htp.print(htf.anchor('www_rgs.wgb_dispstd.disp_grad?in_var1='||in_var1||
  --   CHR(38) || 'in_var2=' || in_var2 ||
  --   CHR(38) || 'in_seqnum=' || in_seqnum ||
  --   CHR(38) || 'in_view=6', 'Switch to old view'));
  htp.nl;
  htp.nl;
  htp.print(htf.anchor('www_rgs.wfl_fellowship.create_fellowship?in_var1='||in_var1||
     CHR(38) || 'in_var2=' || in_var2 ||
     CHR(38) || 'in_seqnum=' || in_seqnum,'Create New Fellowship'));
  
 
     
  for each_fellowship in (select * from GRADSCH.TGRDFELLOW_BASE
                          left join tgrdfellcd on fl_felcode=FLB_CODE
                          where flb_seqnum=in_seqnum
                          order by flb_unique desc) loop
  htp.tableopen(null,null,null,null,'style="border:3px solid blue; background:white; width=60%"'); --main table
    htp.tablerowopen;
      htp.print('<TD>');
        --Open another table that will hold main fellowship details
      htp.formopen('www_rgs.WFL_FELLOWSHIP.proc_update_fel','POST');
      htp.formhidden('in_var1',in_var1);
      htp.formhidden('in_var2',in_var2);
      htp.formhidden('in_seqnum',in_seqnum);
      htp.formhidden('in_unique',each_fellowship.flb_unique);
      htp.tableopen(null,null,null,null,'style="border:1px solid black; background:white; width=100%"');
        htp.tablerowopen;
          htp.tabledata('Name',null,null,null,null,null,'style="font-weight:bold;"');
          htp.tabledata(each_fellowship.fl_felname,null,null,null,null,3,null);
        htp.tablerowclose;
        htp.tablerowopen;
          htp.tabledata('Award year',null,null,null,null,null,'style="font-weight:bold;"');
          --htp.tabledata(htf.formText('in_flb_award_year',10,10,each_fellowship.flb_award_year));
          htp.tabledata(each_fellowship.flb_award_year);
          htp.tabledata('Duration',null,null,null,null,null,'style="font-weight:bold;"');
          --htp.tabledata(htf.formText('in_flb_duration',10,10,each_fellowship.flb_duration));
          htp.tabledata(each_fellowship.flb_duration);
        htp.tablerowclose;
        htp.tablerowopen;
          htp.tabledata('Starting session',null,null,null,null,null,'style="font-weight:bold;"');
          htp.tabledata(case each_fellowship.flb_start_session when 10 then 'Fall' when 20 then 'Spring' when 30 then 'Summer' else 'N/A' end ||'-'||each_fellowship.flb_start_calyear);
          htp.tabledata('Sponsor',null,null,null,null,null,'style="font-weight:bold;"');
          htp.tabledata(htf.formText('in_flb_sponsor',40,20,each_fellowship.flb_sponsor));
        htp.tablerowclose;
        htp.tablerowopen;
          htp.tabledata('Begin Date',null,null,null,null,null,'style="font-weight:bold;"');
          htp.tabledata(htf.formText('in_flb_begin_date',10,10,to_char(each_fellowship.flb_begin_date,'mm/dd/yyyy'),'onchange="check_date(this,this.value)"')); -- added by romina 06/27/2013
            -- htp.tabledata(htf.formText('in_flb_begin_date',10,10,each_fellowship.flb_begin_date,'onchange="check_date(this,this.value)"')); -- removed by romina 06/27/2013
          htp.tabledata('End Date',null,null,null,null,null,'style="font-weight:bold;"');
          htp.tabledata(htf.formText('in_flb_end_date',10,10,to_char(each_fellowship.flb_end_date,'mm/dd/yyyy'),'onchange="check_date(this,this.value)"')); -- added by romina 06/27/2013
            -- htp.tabledata(htf.formText('in_flb_end_date',10,10,each_fellowship.flb_end_date,'onchange="check_date(this,this.value)"')); -- removed by romina 06/27/2013
        htp.tablerowclose; 
        --htp.tablerowopen;
        --  htp.tabledata('Sponsor');
        --  htp.tabledata(htf.formText('in_flb_sponsor',40,40,each_fellowship.flb_sponsor),null,null,null,null,3,null);
        --htp.tablerowclose;
        htp.tablerowopen;
          htp.tabledata('Comments',null,null,null,null,null,'style="font-weight:bold;"');
          htp.tabledata(htf.formTextareaOpen('in_flb_comments',5,40,null,'style="width: 100%; -webkit-box-sizing: border-box; -moz-box-sizing: border-box; box-sizing: border-box;"')||each_fellowship.flb_comments||htf.formTextareaClose,null,null,null,null,3,null);
        htp.tablerowclose;
        htp.tablerowopen;
          htp.tabledata('Created On',null,null,null,null,null,'style="font-weight:bold;"');
          htp.tabledata(each_fellowship.flb_create_date);
          htp.tabledata(htf.formSubmit('in_action','Delete','onClick="return confirm_proceed(''Are you sure you want to delete the selected fellowship? This action is irreversible.'')"'),'right');
          htp.tabledata(htf.formSubmit('in_action','Update'),'right');
        htp.tablerowclose;
        htp.tablerowopen;
          htp.tabledata('Last Updated On',null,null,null,null,null,'style="font-weight:bold;"');
          htp.tabledata(each_fellowship.flb_last_revised_date);
        htp.tablerowclose;
      htp.tableclose;
      htp.formclose;
    htp.print('</TD>');
    htp.tablerowclose;
    
    --Budget Years
    htp.tablerowopen;
      htp.tabledata('Budget Year Account Information',null,null,null,null,null,'style="font-weight:bold;"');
    htp.tablerowclose;
      htp.tablerowopen;
        htp.formopen('www_rgs.wfl_fellowship.disp_budget_years','POST');
        htp.formhidden('in_var1',in_var1);
        htp.formhidden('in_var2',in_var2);
        htp.formhidden('in_seqnum',in_seqnum);
        htp.formhidden('in_unique',each_fellowship.flb_unique);
        htp.tabledata('<button type="submit" style="background-color:#66C266; border:none;">Display all Budget years</button>');
        htp.formclose;
      htp.tablerowclose;
    htp.print('<TD>');
      htp.tableopen(null,null,null,null,'style="border:0px solid blue; background:white; width=100%"'); 
              /*for each_budget_year in (select * from GRADSCH.TGRDFELLOW_BUDGET
                                where fbg_seqnum=each_fellowship.flb_seqnum
                                and fbg_unique=each_fellowship.flb_unique
                                order by fbg_budget_year desc) loop                     -- Updated By Vinod 10/31/2013 from asc to desc */ -- removed 11/17/2014
         
        for each_budget_year in (select fls_budget_year, coalesce(max(fls_total_award_amount),0) as totalsum from tgrdfellow_sess 
                                where fls_seqnum=each_fellowship.flb_seqnum
                                and fls_unique=each_fellowship.flb_unique
                                group by fls_budget_year
                                order by fls_budget_year desc) loop -- added 11/17/2014
           
            htp.tablerowopen;
            htp.formopen('www_rgs.wfl_fellowship.disp_update_budget_year','POST');
            htp.formhidden('in_var1',in_var1);
            htp.formhidden('in_var2',in_var2);
            htp.formhidden('in_seqnum',in_seqnum);
            htp.formhidden('in_unique',each_fellowship.flb_unique);
            --htp.formhidden('in_fbg_budget_year',each_budget_year.fbg_budget_year); -- removed 11/17/2014
            --htp.tabledata(each_budget_year.fbg_budget_year||'&nbsp;&nbsp;&nbsp;&nbsp;'||htf.formSubmit('in_action','Update')); -- removed 11/17/2014
            
            -- added 11/17/2014 Start
            htp.formhidden('in_fbg_budget_year',each_budget_year.fls_budget_year); 
            if each_budget_year.fls_budget_year is not null then
            htp.tabledata(each_budget_year.fls_budget_year||'&nbsp;&nbsp;&nbsp;&nbsp;');
            else
            htp.tabledata('N/A &nbsp;&nbsp;&nbsp;&nbsp;');
            end if;
            htp.tabledata(to_char(each_budget_year.totalsum,'$99,999.99')||'&nbsp;&nbsp;&nbsp;&nbsp;');
            htp.tabledata(htf.formSubmit('in_action','Update'));
            -- added 11/17/2014 End
            
            --htp.tabledata(htf.formSubmit('in_action','Update'));
            htp.formclose;
          htp.tablerowclose;
        end loop;
      htp.tableclose;
    htp.print('</TD>');
    htp.tablerowopen;
      htp.formopen('www_rgs.wfl_fellowship.add_budget_year','POST');
        htp.formhidden('in_var1',in_var1);
        htp.formhidden('in_var2',in_var2);
        htp.formhidden('in_seqnum',in_seqnum);
        htp.formhidden('in_unique',each_fellowship.flb_unique);
        htp.tabledata('<button type="submit" style="background-color:#66C266; border:none;">Add New Budget Year</button>');
      htp.formclose;
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata(htf.nl);
    htp.tablerowclose;
    --Sessions
    htp.tablerowopen;
       htp.tabledata('Session-wise Activity',null,null,null,null,null,'style="font-weight:bold;"');
    htp.tablerowclose;
    htp.tablerowopen;
      htp.tabledata('First column is academic year');
    htp.tablerowclose;
    htp.tablerowopen;
    
     -- Add session start
              --htp.tablerowopen(null,null,null,null,'style="background-color:'||v_background_color||';"');
              htp.formopen('www_rgs.wfl_fellowship.disp_add_session','POST');
              htp.formhidden('in_var1',in_var1);
              htp.formhidden('in_var2',in_var2);
              htp.formhidden('in_seqnum',in_seqnum);
              htp.formhidden('in_unique',each_fellowship.flb_unique);
              htp.tabledata(htf.formSubmit('in_action','Add Row'));
              htp.formclose;              
              htp.tablerowclose;
      -- Add session end

    
      htp.formopen('www_rgs.wfl_fellowship.reset_session_click','POST');
        htp.formhidden('in_var1',in_var1);
        htp.formhidden('in_var2',in_var2);
        htp.formhidden('in_seqnum',in_seqnum);
        htp.formhidden('in_unique',each_fellowship.flb_unique);
        htp.tabledata('<button type="submit" onClick="return confirm_proceed(''This action will simply re-adjust all budget year to session assignments. Please refer to Business Rules. Do you want to continue?'');"><b>Reset sessions <-> budget years</b></button>','center');
      htp.formclose;
    htp.tablerowclose;
    htp.tablerowopen;
      htp.print('<TD>');
        htp.tableopen('border=1px',null,null,null,'border:1px solid black; style="background:white; width=100%"');
          v_background_color:='#FFFFFF';
          for each_academic_year in (select distinct fls_calyear||'-'||substr(fls_calyear+1,3) as academic_year from GRADSCH.TGRDFELLOW_SESS
                                      where fls_seqnum=each_fellowship.flb_seqnum
                                      and fls_unique=each_fellowship.flb_unique
                                      and fls_session=10
                                      order by fls_calyear||'-'||substr(fls_calyear+1,3) desc) loop
            htp.tablerowopen(null,null,null,null,'style="background-color:'||v_background_color||';"');
              htp.tabledata(each_academic_year.academic_year);
              for each_session in (select * from GRADSCH.TGRDFELLOW_SESS
                                   left join GRADSCH.TGRDFELLOW_BUDGET
                                   on fls_seqnum=fbg_seqnum
                                   and fls_unique=fbg_unique
                                   and fls_budget_year=fbg_budget_year
                                   where fls_seqnum=each_fellowship.flb_seqnum
                                   and fls_unique=each_fellowship.flb_unique
                                   and fls_session||fls_calyear in (10||substr(each_academic_year.academic_year,1,4),
                                                                    20||(substr(each_academic_year.academic_year,1,4)+1),
                                                                    30||(substr(each_academic_year.academic_year,1,4)+1))
                                   order by fls_session)
              loop
                htp.tabledata('<b>'||case each_session.fls_session when 10 then 'Fall' when 20 then 'Spring' else 'Summer' end||'&nbsp;'||each_session.fls_calyear||'</b>'||
                                 htf.nl||'Status :'||NVL(each_session.fls_status,'<font color=red><b>X</b></font>')||
                                   -- case when each_session.fls_status!= 'HOLD' then -- removed 11/17/2014
                                   htf.nl||'Budget year :'|| each_session.fls_budget_year||
                                   htf.nl||'SAP Acct : '||each_session.FBG_SAP_ACCT_FUND||'-'||each_session.FBG_SAP_ACCT_INTERNAL_ORDER||'-'||each_session.FBG_SAP_ACCT_RESP_COST_CENTER||
                                   htf.nl||'Annual Stipend : '||each_session.FLS_ANNUAL_STIPEND||
                                   htf.nl||'Monthly Stipend : '||each_session.FLS_MONTHLY_STIPEND||
                                   htf.nl||'Tuition : '||COALESCE(each_session.fls_admin_asst,each_session.fls_tuit,'N/A') -- added 11/17/2014
                                   -- htf.nl||'Tuition : '||COALESCE(each_session.fls_admin_asst,each_session.fls_tuit,'N/A') end   ------modified by Venkata  07/24/2014 -- removed 11/17/2014
                                  ,null,null,null,null,null,'style="vertical-align:top;"');
              end loop;
            htp.tablerowclose;
            htp.tablerowopen(null,null,null,null,'style="background-color:'||v_background_color||';"');
              htp.formopen('www_rgs.wfl_fellowship.disp_update_academic_year','POST');
              htp.formhidden('in_var1',in_var1);
              htp.formhidden('in_var2',in_var2);
              htp.formhidden('in_seqnum',in_seqnum);
              htp.formhidden('in_unique',each_fellowship.flb_unique);
              htp.formhidden('in_academic_year',each_academic_year.academic_year);
                htp.tabledata(htf.formSubmit('in_action','Update Row'));
              htp.formclose;
              for each_session in (select * from GRADSCH.TGRDFELLOW_SESS
                                   left join GRADSCH.TGRDFELLOW_BUDGET
                                   on fls_seqnum=fbg_seqnum
                                   and fls_unique=fbg_unique
                                   and fls_budget_year=fbg_budget_year
                                   where fls_seqnum=each_fellowship.flb_seqnum
                                   and fls_unique=each_fellowship.flb_unique
                                   and fls_session||fls_calyear in (10||substr(each_academic_year.academic_year,1,4),
                                                                    20||(substr(each_academic_year.academic_year,1,4)+1),
                                                                    30||(substr(each_academic_year.academic_year,1,4)+1))
                                   order by fls_session)
              loop
                htp.formopen('www_rgs.wfl_fellowship.disp_update_session','POST');
                htp.formhidden('in_var1',in_var1);
                htp.formhidden('in_var2',in_var2);
                htp.formhidden('in_seqnum',each_fellowship.flb_seqnum);
                htp.formhidden('in_unique',each_fellowship.flb_unique);
                htp.formhidden('in_session',each_session.fls_session);
                htp.formhidden('in_calyear',each_session.fls_calyear);
                  htp.tabledata(htf.formsubmit('in_action','Update'));
                htp.formclose;
              end loop;
              htp.tablerowclose;
              -- Delete session start
              htp.tablerowopen(null,null,null,null,'style="background-color:'||v_background_color||';"');
              htp.formopen('www_rgs.wfl_fellowship.disp_delete_session','POST');
              htp.formhidden('in_var1',in_var1);
              htp.formhidden('in_var2',in_var2);
              htp.formhidden('in_seqnum',in_seqnum);
              htp.formhidden('in_unique',each_fellowship.flb_unique);
              htp.formhidden('in_academic_year',each_academic_year.academic_year);
                htp.tabledata(htf.formSubmit('in_action','Delete Row'));
              htp.formclose;              
              htp.tablerowclose;
              -- Delete session end
            
            
            if v_background_color = '#FFFFFF' then
              v_background_color := '#CCCCFF';
            else
              v_background_color:='#FFFFFF';
            end if;
          end loop;
        htp.tableclose;
      htp.print('</TD>');
    htp.tablerowclose;
  htp.tableclose;
  htp.nl;
  htp.nl;
  htp.nl;
  end loop;
  print_funding_summary(in_var1,in_var2,in_seqnum);
  end if;
  
END;

--author: jolene singh
--function: this function is identical to print_grad_general in WGB_DISPSTD. It is no longer being used.
procedure print_grad_general (in_var1 in number default 0,
                              in_var2 in number default 0,
                              in_seqnum in number default 0, 
                              in_view in number default 0,
                              in_header in number default 0)
is
 v_fee_status varchar2(20) default null;
  v_fee_status_date varchar2(20) default null;
  cur_base TGRDBASE%ROWTYPE;
  cur_user twwwuser1%rowtype;
  -- added 12/6/2011
  cursor enrollment_ptr is
    select ban_prim_curmajor, ban_prim_curdeg
    from gradsch.tBanner_admits
    where ban_seqnum = cur_base.b_seqnum
    order by ban_term desc;
  
  v_major gradsch.tBanner_admits.ban_prim_curmajor%type; -- added 12/6/2011
  v_degree gradsch.tBanner_admits.ban_prim_curdeg%type; -- added 12/6/2011

v_sqlcode number default 0;
begin
  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;
  
  select * into cur_base from tgrdbase
  where b_seqnum=in_seqnum;
 
  htp.preOpen;
  if cur_base.b_rdl is not null then
     if cur_base.b_rdl = 'L' then
        htp.fontOpen('Red');
        htp.print(htf.bold('Restricted Directory Listing - only local address and local phone number'));
        htp.fontClose;
     elsif cur_base.b_rdl = 'H' then
        htp.fontOpen('Red');
        htp.print(htf.bold('Restricted Directory Listing - only home address and home phone number'));
        htp.fontClose;
     elsif cur_base.b_rdl = 'A' then
        htp.fontOpen('Red');
        htp.print(htf.bold('Restricted Directory Listing - all addresses and phone numbers'));
        htp.fontClose;
     elsif cur_base.b_rdl = 'P' then
        htp.fontOpen('Red');
        htp.print(htf.bold('Restricted Directory Listing - all phone numbers'));
        htp.fontClose;
     elsif cur_base.b_rdl = 'D' then
        htp.fontOpen('Red');
        htp.print(htf.bold('Restricted Directory Listing - only honors, degrees and awards'));
        htp.fontClose;
     elsif cur_base.b_rdl = 'S' then
        htp.fontOpen('Red');
        htp.print(htf.bold('Restricted Directory Listing - only school, curriculum, classification and credit hour load'));
        htp.fontClose;
     elsif cur_base.b_rdl = 'E' then
        htp.fontOpen('Red');
        htp.print(htf.bold('Restricted Directory Listing - e-mail address'));
        htp.fontClose;
     elsif cur_base.b_rdl = 'R' then
        htp.fontOpen('Red');
        htp.print(htf.bold('Restricted Directory Listing - all information'));
        htp.fontClose;
     end if;
  end if;

  -- get fee status and associated date
  v_fee_status := upper(wgb_functions.fee_status_of(cur_base.b_fee));
  if substr(v_fee_status,1,3)='SAT' then
     v_fee_status_date := '  (' || to_char(cur_base.b_feedate,'mm/dd/yyyy') || ')';
  else
     v_fee_status_date := null;
  end if;

  htp.print(htf.bold('Name              : ') || cur_base.b_name);
  htp.print(htf.bold('PUID              : ') || cur_base.b_puid);
 
  htp.print(htf.bold('Date Of Birth     : ') ||
            to_char(cur_base.b_dob,'mm/dd/yyyy'));
  IF cur_base.b_citz <> '299' and wgb_functions.all_digits_string(trim(cur_base.b_citz)) then
     -- if record has a native language then display
    if cur_base.b_englverf is not null then
        htp.print(htf.bold('Citizenship/Alien#: ') || rtrim(wgb_functions.citizen_of(cur_base.b_citz)) || ' (' || cur_base.b_citz || ')' 
 	           || htf.bold(' / ') || NVL(cur_base.b_alien,'N/A')
               || htf.bold(' / Native Language: ') || wgb_functions.reference_of('language_list', rtrim(cur_base.b_englverf)));    
    else
        -- conditions below added 12/6/2011
      If wgb_functions.all_digits_string(trim(cur_base.b_citz)) Then
            htp.print(htf.bold('Citizenship       : ') || rtrim(wgb_functions.citizen_of(cur_base.b_citz)) || ' (' || trim(cur_base.b_citz) || ')');
      Else
            htp.print(htf.bold('Citizenship       : ') || rtrim(wgb_functions.nation_of(cur_base.b_citz)) || ' (' || trim(cur_base.b_citz) || ')'); -- added 12/6/2011
      End If;
            --htp.print(htf.bold('Citizenship/Alien#: ') || rtrim(wgb_functions.citizen_of(cur_base.b_citz)) || ' (' || cur_base.b_citz || ')' -- removed 12/6/2011
 	          --     || htf.bold(' / ') || NVL(cur_base.b_alien,'N/A'));
    end if;
       --htp.print(htf.bold('Residency         : ') || rtrim(wgb_functions.citizen_of(cur_base.b_feeres)) || ' (' || cur_base.b_feeres || ')'); -- removed 4/6/2011     
  ELSE
     -- conditions below added 12/6/2011
    If wgb_functions.all_digits_string(trim(cur_base.b_citz)) Then
         htp.print(htf.bold('Citizenship       : ') || rtrim(wgb_functions.citizen_of(cur_base.b_citz)) || ' (' || trim(cur_base.b_citz) || ')');
    Else
         htp.print(htf.bold('Citizenship       : ') || rtrim(wgb_functions.nation_of(cur_base.b_citz)) || ' (' || trim(cur_base.b_citz) || ')'); -- added 12/6/2011
    End If;
       --htp.print(htf.bold('Residency         : ') || rtrim(wgb_functions.citizen_of(cur_base.b_feeres)) || ' (' || cur_base.b_feeres || ')'); -- removed 4/6/2011
  END IF;
    
  htp.print(htf.bold('Citizenship Type  : ') || rtrim(wgb_functions.citizenship_type_of(trim(cur_base.b_citztype))) || ' (' || trim(cur_base.b_citztype) || ')'); -- added 12/6/2011

  -- conditions added 4/6/2011 to show the new b_res residency info
  IF cur_base.b_feeres IS NOT NULL THEN
    htp.print(htf.bold('Residency         : ') || rtrim(wgb_functions.citizen_of(cur_base.b_feeres)) || ' (' || cur_base.b_feeres || ')');
  ELSIF cur_base.b_res IS NOT NULL THEN
    htp.print(htf.bold('Residency         : ') || rtrim(wgb_functions.residency_of(cur_base.b_res)));
  END IF;
    --htp.print(htf.bold('Residency         : ') || rtrim(wgb_functions.citizen_of(cur_base.b_feeres)) || ' (' || cur_base.b_feeres || ')'); -- removed 4/6/2011
  IF cur_base.b_racespec IS NOT NULL THEN
     htp.print(htf.bold('Gender / Race     : ') || 	upper(wgb_functions.gender_of(cur_base.b_gender))
            	|| htf.bold(' / ') || upper(wgb_functions.race_of(cur_base.b_race1))
                || ' (' || cur_base.b_racespec || ')');
  ELSE
     htp.print(htf.bold('Gender / Race     : ') || 	upper(wgb_functions.gender_of(cur_base.b_gender))
            	|| htf.bold(' / ') || upper(wgb_functions.race_of(cur_base.b_race1)));
  END IF;
  
    -- 12/1999: add noi received date and coe issued date
  htp.print(htf.bold('NOI Received      : ') ||
            NVL(to_char(cur_base.b_noi_received_date,'mm/dd/yyyy'),'N/A'));
  htp.print(htf.bold('ISS File Complete : ') ||
            NVL(to_char(cur_base.b_iss_complete_date,'mm/dd/yyyy'),'N/A'));
  htp.print(htf.bold('COE Issued        : ') ||
            NVL(to_char(cur_base.b_coe_issued_date,'mm/dd/yyyy'),'N/A'));
            
  -- added 12/6/2011
  open enrollment_ptr;
  fetch enrollment_ptr into v_major, v_degree;
  if enrollment_ptr%notfound then
    htp.nl;
    htp.print(htf.bold('Enrolled Major    : ') || 'Not Found');
    htp.print(htf.bold('Enrolled Degree   : ') || 'Not Found');
  else
    htp.nl;
    htp.print(htf.bold('Enrolled Major    : ') || v_major);
    htp.print(htf.bold('Enrolled Degree   : ') || v_degree);    
  end if;
            
  htp.preclose;
  
  -- if an error occurred put it after general information
  if in_header <> 0 then
     wgb_shared.disp_header(in_header);
  end if;
exception     
   WHEN OTHERS THEN
     v_sqlcode := sqlcode;
     wgb_shared.insert_twwwaudit(0,0,0,'Error wgb_dispstd.print_grad_general ' || v_sqlcode);
     return;


 end; 
 
-- Title: print_sess_details
-- Author: Shanmukesh Vankayala
-- Date: 02/28/2015
-- Description: Procedure for printing session details to be displayed on review form
procedure print_sess_details (in_var1 in number default 0,
                              in_var2 in number default 0,
                              in_CALYEAR NUMBER,                                       
                              in_SESSION NUMBER,                                       
                              in_STATUS VARCHAR2,
                              in_TUIT in VARCHAR2,                                             
                              in_ADMIN_ASST in VARCHAR2,                                 
                              in_GRAD_APPT_FEE in VARCHAR2,                           
                              in_TECH_FEE in VARCHAR2,                                     
                              in_R_AND_R_FEE in VARCHAR2,                               
                              in_INTERNATIONAL_FEE in VARCHAR2,                   
                              in_DIFFERENTIAL_FEE in VARCHAR2,                     
                              in_WELLNESS_FEE in VARCHAR2,                             
                              in_SUPP in VARCHAR2,                                             
                              in_SUPP_PAYROLL_AMT in NUMBER,                     
                              in_SUPP_OTHER_FUND_ACCT in VARCHAR2,             
                              in_SUPP_OTHER_FUND_AMT in NUMBER,               
                              in_MED_INSURANCE in VARCHAR2,                           
                              in_MED_AMT in NUMBER,                                       
                              in_MED_INSURANCE_COMMENT in VARCHAR2,           
                              in_TOTAL_SPONSOR_STIPEND in NUMBER,           
                              in_SUPP_AMOUNT in NUMBER,                               
                              in_FRINGE_BENEFIT_AMOUNT in NUMBER,           
                              in_ANNUAL_STIPEND in NUMBER,                         
                              in_MONTHS_STIPEND in NUMBER,                         
                              in_MONTHLY_STIPEND in NUMBER,                       
                              in_BUDGET_YEAR in VARCHAR2,                               
                              in_PRIN_INVESTIGATOR in VARCHAR2,                   
                              in_TOTAL_AWARD_AMOUNT in NUMBER,   
                              in_CALTERM in VARCHAR2,       
                              in_REMARKS in VARCHAR2)
is
begin
   htp.header(3,'Session Details',null,null,null,'style="color:#0000CC;"');
   htp.tableopen(null,null,null,null,'width="100%"  border="1"');
   htp.tablerowopen(null,null,null,null,'style="background-color:#CED8F6;"');
   htp.tableheader('Term '||case in_SESSION when 10 then 'Fall' when 20 then 'Spring' when 30 then 'Summer' else 'N/A' end||'&nbsp;&nbsp;&nbsp;&nbsp;'
                    ||'Cal. Year '|| in_CALYEAR ||
                    'Status '|| in_STATUS,null,null,null,null,3);
   htp.tableheader('Principal Investigator '|| in_PRIN_INVESTIGATOR  ,null,null,null,null,3);
   htp.tableheader('Budget year '||in_BUDGET_YEAR ,null,null,null,null,2);
   htp.tablerowclose;
   htp.tablerowopen;
   htp.tableheader('Tuition',null,null,null,null,2);
   htp.tableheader('Fees',null,null,null,null,6);
   htp.tablerowclose;
   htp.tablerowopen;
   htp.tabledata('Fellowship'||htf.nl||in_TUIT);
   htp.tabledata('Assistantship'||htf.nl||in_ADMIN_ASST);
   htp.tabledata('Grad Appt'||htf.nl||in_GRAD_APPT_FEE);
   htp.tabledata('Tech'||htf.nl||in_TECH_FEE);
   htp.tabledata('R &amp; R'||htf.nl||in_R_AND_R_FEE);
   htp.tabledata('International'||htf.nl||in_INTERNATIONAL_FEE);
   htp.tabledata('Differential'||htf.nl||in_DIFFERENTIAL_FEE);
   htp.tabledata('Wellness'||htf.nl||in_WELLNESS_FEE);
   htp.tablerowclose;
   htp.tablerowopen;
   htp.tabledata(null,null,null,null,null,8);
   htp.tablerowclose;
   htp.tablerowopen;
   htp.tableheader('Supplementary Award Info',null,null,null,null,2);
   htp.tableheader('Medical Insurance',null,null,null,null,3);
   htp.tableheader('Stipend Calculations',null,null,null,null,3);
   htp.tablerowclose;
   htp.tablerowopen;
   htp.tabledata('Will this award be supplemented'||htf.nl || case in_supp when 'N' then 'No' else 'Yes &nbsp;&nbsp;&nbsp;&nbsp'||in_SUPP_PAYROLL_AMT end,null,null,null,null,2);
   htp.print('<TD colspan="3">');
   htp.tableopen(null,null,null,null,'style="width=100%"');
   htp.tablerowopen;
   htp.tabledata('How will it be handled?');
   htp.tabledata(in_MED_INSURANCE);
   htp.tablerowclose;
   htp.tablerowopen;
   htp.tabledata('Amount');
   htp.tabledata(in_MED_AMT);
   htp.tablerowclose;
   htp.tablerowopen;
   htp.tabledata('Comments');
   htp.tabledata(in_MED_INSURANCE_COMMENT);
   htp.tablerowclose;
   htp.tableclose;
   htp.print('</TD>');
   htp.print('<TD colspan="3">');
   htp.tableopen(null,null,null,null,'style="width=100%"');
   htp.tablerowopen;
   htp.tabledata('Total Sponsor Stipend');
   htp.tabledata(in_TOTAL_SPONSOR_STIPEND);
   htp.tablerowclose;
   htp.tablerowopen;
   htp.tabledata('Supp Amt');
   htp.tabledata(in_SUPP_AMOUNT);  
   htp.tablerowclose;
   htp.tablerowopen;
   htp.tabledata('Fringe Benefits');
   htp.tabledata(in_FRINGE_BENEFIT_AMOUNT);  
   htp.tablerowclose;
   htp.tablerowopen;
   htp.tabledata('Total Insurance');
   htp.tabledata(in_MED_AMT);
   htp.tablerowclose;
   htp.tablerowopen;
   htp.tabledata('Total Annual Stipend');
   htp.tabledata(in_ANNUAL_STIPEND);
   htp.tablerowclose;
   htp.tablerowopen;
   htp.tabledata('Total Months Paid');
   htp.tabledata(in_MONTHS_STIPEND);
   htp.tablerowclose;
   htp.tablerowopen;
   htp.tabledata('Total Monthly Stipend');
   htp.tabledata(in_MONTHLY_STIPEND);
   htp.tablerowclose;
   htp.tablerowopen;
   htp.tabledata('Total Award Amount');
   htp.tabledata(in_TOTAL_AWARD_AMOUNT);
   htp.tablerowclose;
   htp.tableclose;
   htp.print('</TD>');
   htp.tablerowopen;   
   htp.tabledata('Remarks'||in_REMARKS,null,null,null,null,2);  
   htp.tablerowclose; 
   htp.tablerowclose;
   htp.tableclose;
   htp.nl;
   htp.nl;   

end;   

 
 
 
-- Title: proc_create_fellowship_stage
-- Author: Shanmukesh Vankayala
-- Date: 02/28/2015
-- Description: Procedure for storing the FORM 90 data in a staging table
procedure proc_create_fellowship_stage (in_var1 in number default 0,
                                  in_var2 in number default 0,
                                  in_seqnum in number default 0,
                                  in_FLB_CODE in GRADSCH.TGRDFELLOW_BASE.FLB_CODE%TYPE default null,
                                  in_FLB_START_SESSION in GRADSCH.TGRDFELLOW_BASE.FLB_START_SESSION%TYPE default null,
                                  in_FLB_START_CALYEAR in GRADSCH.TGRDFELLOW_BASE.FLB_START_CALYEAR%TYPE default null,
                                  in_FLB_BEGIN_DATE in varchar2 default null,
                                  in_FLB_END_DATE in varchar2 default null,
                                  in_FLB_DURATION in GRADSCH.TGRDFELLOW_BASE.FLB_DURATION%TYPE default null,
                                  in_FLB_AWARD_YEAR in GRADSCH.TGRDFELLOW_BASE.FLB_AWARD_YEAR%TYPE default null,
                                  in_FLB_SPONSOR in GRADSCH.TGRDFELLOW_BASE.FLB_SPONSOR%TYPE default null,
                                  in_FLB_COMMENTS in GRADSCH.TGRDFELLOW_BASE.FLB_COMMENTS%TYPE default null,
                                  in_FBG_SEQNUM in GRADSCH.TGRDFELLOW_BUDGET.FBG_SEQNUM%TYPE default null,                                         
                                  in_FBG_UNIQUE in GRADSCH.TGRDFELLOW_BUDGET.FBG_UNIQUE%TYPE default null,                                         
                                  in_FBG_BUDGET_YEAR in GRADSCH.TGRDFELLOW_BUDGET.FBG_BUDGET_YEAR%TYPE default null,                               
                                  in_FBG_SAP_ACCT_FUND in GRADSCH.TGRDFELLOW_BUDGET.FBG_SAP_ACCT_FUND%TYPE default null,                           
                                  in_FBG_SAP_ACCT_INTERNAL_ORDER in GRADSCH.TGRDFELLOW_BUDGET.FBG_SAP_ACCT_INTERNAL_ORDER%TYPE default null,       
                                  in_FBG_SAP_ACCT_RESP_CC in GRADSCH.TGRDFELLOW_BUDGET.FBG_SAP_ACCT_RESP_COST_CENTER%TYPE default null,   
                                  in_FBG_GRANT_ACCT in GRADSCH.TGRDFELLOW_BUDGET.FBG_GRANT_ACCT%TYPE default null,                                 
                                  in_FLS_CALYEAR_1 in GRADSCH.TGRDFELLOW_SESS.FLS_CALYEAR%TYPE default null,                                       
                                  in_FLS_SESSION_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SESSION%TYPE default null,                                       
                                  in_FLS_STATUS_1 in GRADSCH.TGRDFELLOW_SESS.FLS_STATUS%TYPE default null,                                         
                                  in_FLS_TUIT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT%TYPE default null,                                             
                                  in_FLS_ADMIN_ASST_1 in GRADSCH.TGRDFELLOW_SESS.FLS_ADMIN_ASST%TYPE default null,                                 
                                  in_FLS_GRAD_APPT_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_GRAD_APPT_FEE%TYPE default null,                           
                                  in_FLS_TECH_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_TECH_FEE%TYPE default null,                                     
                                  in_FLS_R_AND_R_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_R_AND_R_FEE%TYPE default null,                               
                                  in_FLS_INTERNATIONAL_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_INTERNATIONAL_FEE%TYPE default null,                   
                                  in_FLS_DIFFERENTIAL_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_DIFFERENTIAL_FEE%TYPE default null,                     
                                  in_FLS_WELLNESS_FEE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_WELLNESS_FEE%TYPE default null,                             
                                  in_FLS_SUPP_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP%TYPE default null,                                             
                                  in_FLS_SUPP_PAYROLL_AMT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_PAYROLL_AMT%TYPE default null,                     
                                  in_FLS_SUPP_OTHER_FUND_ACCT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_ACCT%TYPE default null,             
                                  in_FLS_SUPP_OTHER_FUND_AMT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_AMT%TYPE default null,               
                                  in_FLS_MED_INSURANCE_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE%TYPE default null,                           
                                  in_FLS_MED_AMT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_AMT%TYPE default null,                                       
                                  in_FLS_MED_INSURANCE_COMMENT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE_COMMENT%TYPE default null,           
                                  in_FLS_TOTAL_SPONSOR_STIPEND_1 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_SPONSOR_STIPEND%TYPE default null,           
                                  in_FLS_SUPP_AMOUNT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_AMOUNT%TYPE default null,                               
                                  in_FLS_FRINGE_BENEFIT_AMOUNT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_FRINGE_BENEFIT_AMOUNT%TYPE default null,           
                                  in_FLS_ANNUAL_STIPEND_1 in GRADSCH.TGRDFELLOW_SESS.FLS_ANNUAL_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHS_STIPEND_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHS_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHLY_STIPEND_1 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHLY_STIPEND%TYPE default null,                       
                                  in_FLS_BUDGET_YEAR_1 in GRADSCH.TGRDFELLOW_SESS.FLS_BUDGET_YEAR%TYPE default null,                               
                                  in_FLS_PRIN_INVESTIGATOR_1 in GRADSCH.TGRDFELLOW_SESS.FLS_PRIN_INVESTIGATOR%TYPE default null,                   
                                  in_FLS_TOTAL_AWARD_AMOUNT_1 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_AWARD_AMOUNT%TYPE default null,   
                                  in_FLS_CALTERM_1 in GRADSCH.TGRDFELLOW_SESS.FLS_CALTERM%TYPE default null,     
                                  in_FLS_REMARKS_1 in GRADSCH.TGRDFELLOW_SESS.FLS_REMARKS%TYPE default null, 
                                  in_FLS_CALYEAR_2 in GRADSCH.TGRDFELLOW_SESS.FLS_CALYEAR%TYPE default null,                                       
                                  in_FLS_SESSION_2 in GRADSCH.TGRDFELLOW_SESS.FLS_SESSION%TYPE default null,                                       
                                  in_FLS_STATUS_2 in GRADSCH.TGRDFELLOW_SESS.FLS_STATUS%TYPE default null,                                         
                                  in_FLS_TUIT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT%TYPE default null,                                             
                                  in_FLS_ADMIN_ASST_2 in GRADSCH.TGRDFELLOW_SESS.FLS_ADMIN_ASST%TYPE default null,                                 
                                  in_FLS_GRAD_APPT_FEE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_GRAD_APPT_FEE%TYPE default null,                           
                                  in_FLS_TECH_FEE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_TECH_FEE%TYPE default null,                                     
                                  in_FLS_R_AND_R_FEE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_R_AND_R_FEE%TYPE default null,                               
                                  in_FLS_INTERNATIONAL_FEE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_INTERNATIONAL_FEE%TYPE default null,                   
                                  in_FLS_DIFFERENTIAL_FEE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_DIFFERENTIAL_FEE%TYPE default null,                     
                                  in_FLS_WELLNESS_FEE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_WELLNESS_FEE%TYPE default null,                             
                                  in_FLS_SUPP_2 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP%TYPE default null,                                             
                                  in_FLS_SUPP_PAYROLL_AMT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_PAYROLL_AMT%TYPE default null,                     
                                  in_FLS_SUPP_OTHER_FUND_ACCT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_ACCT%TYPE default null,             
                                  in_FLS_SUPP_OTHER_FUND_AMT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_AMT%TYPE default null,               
                                  in_FLS_MED_INSURANCE_2 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE%TYPE default null,                           
                                  in_FLS_MED_AMT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_AMT%TYPE default null,                                       
                                  in_FLS_MED_INSURANCE_COMMENT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE_COMMENT%TYPE default null,           
                                  in_FLS_TOTAL_SPONSOR_STIPEND_2 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_SPONSOR_STIPEND%TYPE default null,           
                                  in_FLS_SUPP_AMOUNT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_AMOUNT%TYPE default null,                               
                                  in_FLS_FRINGE_BENEFIT_AMOUNT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_FRINGE_BENEFIT_AMOUNT%TYPE default null,           
                                  in_FLS_ANNUAL_STIPEND_2 in GRADSCH.TGRDFELLOW_SESS.FLS_ANNUAL_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHS_STIPEND_2 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHS_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHLY_STIPEND_2 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHLY_STIPEND%TYPE default null,                       
                                  in_FLS_BUDGET_YEAR_2 in GRADSCH.TGRDFELLOW_SESS.FLS_BUDGET_YEAR%TYPE default null,                               
                                  in_FLS_PRIN_INVESTIGATOR_2 in GRADSCH.TGRDFELLOW_SESS.FLS_PRIN_INVESTIGATOR%TYPE default null,                   
                                  in_FLS_TOTAL_AWARD_AMOUNT_2 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_AWARD_AMOUNT%TYPE default null,  
                                  in_FLS_CALTERM_2 in GRADSCH.TGRDFELLOW_SESS.FLS_CALTERM%TYPE default null,      
                                  in_FLS_REMARKS_2 in GRADSCH.TGRDFELLOW_SESS.FLS_REMARKS%TYPE default null, 
                                  in_FLS_CALYEAR_3 in GRADSCH.TGRDFELLOW_SESS.FLS_CALYEAR%TYPE default null,                                       
                                  in_FLS_SESSION_3 in GRADSCH.TGRDFELLOW_SESS.FLS_SESSION%TYPE default null,                                       
                                  in_FLS_STATUS_3 in GRADSCH.TGRDFELLOW_SESS.FLS_STATUS%TYPE default null,                                         
                                  in_FLS_TUIT_ONLY_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT_ONLY%TYPE default null,                                   
                                  in_FLS_TUIT_AIDCODE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT_AIDCODE%TYPE default null,                             
                                  in_FLS_TUIT_CHRG_SCH_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT_CHRG_SCH%TYPE default null,                           
                                  in_FLS_TUIT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TUIT%TYPE default null,                                             
                                  in_FLS_ADMIN_ASST_3 in GRADSCH.TGRDFELLOW_SESS.FLS_ADMIN_ASST%TYPE default null,                                 
                                  in_FLS_GRAD_APPT_FEE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_GRAD_APPT_FEE%TYPE default null,                           
                                  in_FLS_TECH_FEE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TECH_FEE%TYPE default null,                                     
                                  in_FLS_R_AND_R_FEE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_R_AND_R_FEE%TYPE default null,                               
                                  in_FLS_INTERNATIONAL_FEE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_INTERNATIONAL_FEE%TYPE default null,                   
                                  in_FLS_DIFFERENTIAL_FEE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_DIFFERENTIAL_FEE%TYPE default null,                     
                                  in_FLS_WELLNESS_FEE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_WELLNESS_FEE%TYPE default null,                             
                                  in_FLS_SUPP_3 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP%TYPE default null,                                             
                                  in_FLS_SUPP_PAYROLL_AMT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_PAYROLL_AMT%TYPE default null,                     
                                  in_FLS_SUPP_OTHER_FUND_ACCT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_ACCT%TYPE default null,             
                                  in_FLS_SUPP_OTHER_FUND_AMT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_OTHER_FUND_AMT%TYPE default null,               
                                  in_FLS_MED_INSURANCE_3 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE%TYPE default null,                           
                                  in_FLS_MED_AMT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_AMT%TYPE default null,                                       
                                  in_FLS_MED_INSURANCE_COMMENT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_MED_INSURANCE_COMMENT%TYPE default null,           
                                  in_FLS_TOTAL_SPONSOR_STIPEND_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_SPONSOR_STIPEND%TYPE default null,           
                                  in_FLS_SUPP_AMOUNT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_SUPP_AMOUNT%TYPE default null,                               
                                  in_FLS_FRINGE_BENEFIT_AMOUNT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_FRINGE_BENEFIT_AMOUNT%TYPE default null,           
                                  in_FLS_ANNUAL_STIPEND_3 in GRADSCH.TGRDFELLOW_SESS.FLS_ANNUAL_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHS_STIPEND_3 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHS_STIPEND%TYPE default null,                         
                                  in_FLS_MONTHLY_STIPEND_3 in GRADSCH.TGRDFELLOW_SESS.FLS_MONTHLY_STIPEND%TYPE default null,                       
                                  in_FLS_BUDGET_YEAR_3 in GRADSCH.TGRDFELLOW_SESS.FLS_BUDGET_YEAR%TYPE default null,                               
                                  in_FLS_PRIN_INVESTIGATOR_3 in GRADSCH.TGRDFELLOW_SESS.FLS_PRIN_INVESTIGATOR%TYPE default null,                   
                                  in_FLS_TOTAL_AWARD_AMOUNT_3 in GRADSCH.TGRDFELLOW_SESS.FLS_TOTAL_AWARD_AMOUNT%TYPE default null,
                                  in_FLS_CALTERM_3 in GRADSCH.TGRDFELLOW_SESS.FLS_CALTERM%TYPE default null,    
                                  in_FLS_REMARKS_3 in GRADSCH.TGRDFELLOW_SESS.FLS_REMARKS%TYPE default null, 
                                  in_new_form in varchar2 default null,
                                  in_form_begin_date in varchar2 default null,
                                  in_form_end_date in varchar2 default null,
                                  in_action in varchar2 default 'Cancel') 
 IS
 
 v_rec_seq number;
 x number;
 email_from varchar2(100);
 email_to varchar2(100);
 email_sub varchar2(500);
 email_body varchar2(5000);
 
 
 BEGIN
 
 
 
 if in_action= 'Submit' then
 v_rec_seq := fs_rec_seq.nextval;
 insert into TGRDFELLOW_STAGE 
 values
(v_rec_seq
,in_seqnum
,in_FLB_CODE
,in_FLB_START_SESSION
,in_FLB_START_CALYEAR
,to_date(to_date(in_FLB_BEGIN_DATE,'MM/DD/RR'),'DD-MON-RR')
,to_date(to_date(in_FLB_END_DATE,'MM/DD/RR'),'DD-MON-RR')
,in_FLB_DURATION
,in_FLB_AWARD_YEAR
,in_FLB_SPONSOR
,in_FLB_COMMENTS
,in_FBG_SEQNUM
,in_FBG_UNIQUE
,in_FBG_BUDGET_YEAR
,in_FBG_SAP_ACCT_FUND
,in_FBG_SAP_ACCT_INTERNAL_ORDER
,in_FBG_SAP_ACCT_RESP_CC
,in_FBG_GRANT_ACCT
,in_FLS_CALYEAR_1
,in_FLS_SESSION_1
,in_FLS_STATUS_1
,in_FLS_TUIT_1
,in_FLS_ADMIN_ASST_1
,in_FLS_GRAD_APPT_FEE_1
,in_FLS_TECH_FEE_1
,in_FLS_R_AND_R_FEE_1
,in_FLS_INTERNATIONAL_FEE_1
,in_FLS_DIFFERENTIAL_FEE_1
,in_FLS_WELLNESS_FEE_1
,in_FLS_SUPP_1
,in_FLS_SUPP_PAYROLL_AMT_1
,in_FLS_SUPP_OTHER_FUND_ACCT_1
,in_FLS_SUPP_OTHER_FUND_AMT_1
,in_FLS_MED_INSURANCE_1
,in_FLS_MED_AMT_1
,in_FLS_MED_INSURANCE_COMMENT_1
,in_FLS_TOTAL_SPONSOR_STIPEND_1
,in_FLS_SUPP_AMOUNT_1
,in_FLS_FRINGE_BENEFIT_AMOUNT_1
,in_FLS_ANNUAL_STIPEND_1
,in_FLS_MONTHS_STIPEND_1
,in_FLS_MONTHLY_STIPEND_1
,in_FLS_BUDGET_YEAR_1
,in_FLS_PRIN_INVESTIGATOR_1
,in_FLS_TOTAL_AWARD_AMOUNT_1
,in_FLS_CALTERM_1
,in_FLS_REMARKS_1
,in_FLS_CALYEAR_2
,in_FLS_SESSION_2
,in_FLS_STATUS_2
,in_FLS_TUIT_2
,in_FLS_ADMIN_ASST_2
,in_FLS_GRAD_APPT_FEE_2
,in_FLS_TECH_FEE_2
,in_FLS_R_AND_R_FEE_2
,in_FLS_INTERNATIONAL_FEE_2
,in_FLS_DIFFERENTIAL_FEE_2
,in_FLS_WELLNESS_FEE_2
,in_FLS_SUPP_2
,in_FLS_SUPP_PAYROLL_AMT_2
,in_FLS_SUPP_OTHER_FUND_ACCT_2
,in_FLS_SUPP_OTHER_FUND_AMT_2
,in_FLS_MED_INSURANCE_2
,in_FLS_MED_AMT_2
,in_FLS_MED_INSURANCE_COMMENT_2
,in_FLS_TOTAL_SPONSOR_STIPEND_2
,in_FLS_SUPP_AMOUNT_2
,in_FLS_FRINGE_BENEFIT_AMOUNT_2
,in_FLS_ANNUAL_STIPEND_2
,in_FLS_MONTHS_STIPEND_2
,in_FLS_MONTHLY_STIPEND_2
,in_FLS_BUDGET_YEAR_2
,in_FLS_PRIN_INVESTIGATOR_2
,in_FLS_TOTAL_AWARD_AMOUNT_2
,in_FLS_CALTERM_2
,in_FLS_REMARKS_2
,in_FLS_CALYEAR_3
,in_FLS_SESSION_3
,in_FLS_STATUS_3
,in_FLS_TUIT_ONLY_3
,in_FLS_TUIT_AIDCODE_3
,in_FLS_TUIT_CHRG_SCH_3
,in_FLS_TUIT_3
,in_FLS_ADMIN_ASST_3
,in_FLS_GRAD_APPT_FEE_3
,in_FLS_TECH_FEE_3
,in_FLS_R_AND_R_FEE_3
,in_FLS_INTERNATIONAL_FEE_3
,in_FLS_DIFFERENTIAL_FEE_3
,in_FLS_WELLNESS_FEE_3
,in_FLS_SUPP_3
,in_FLS_SUPP_PAYROLL_AMT_3
,in_FLS_SUPP_OTHER_FUND_ACCT_3
,in_FLS_SUPP_OTHER_FUND_AMT_3
,in_FLS_MED_INSURANCE_3
,in_FLS_MED_AMT_3
,in_FLS_MED_INSURANCE_COMMENT_3
,in_FLS_TOTAL_SPONSOR_STIPEND_3
,in_FLS_SUPP_AMOUNT_3
,in_FLS_FRINGE_BENEFIT_AMOUNT_3
,in_FLS_ANNUAL_STIPEND_3
,in_FLS_MONTHS_STIPEND_3
,in_FLS_MONTHLY_STIPEND_3
,in_FLS_BUDGET_YEAR_3
,in_FLS_PRIN_INVESTIGATOR_3
,in_FLS_TOTAL_AWARD_AMOUNT_3
,in_FLS_CALTERM_3
,in_FLS_REMARKS_3
,in_new_form
,in_form_begin_date
,in_form_end_date
,systimestamp
,'P'
,30);

 insert into TGRDFELLOW_SIG(FSG_RECSEQNUM,FSG_SIGN_LEVEL,FSG_USERSEQNUM,FSG_SIGN_DATE,FSG_SIGN_STATUS,FSG_NOTF_DATE )   
 values(v_rec_seq,40,in_var1,systimestamp,'S',systimestamp);
 
 insert into TGRDFELLOW_SIG(FSG_RECSEQNUM,FSG_SIGN_LEVEL,FSG_USERSEQNUM,FSG_NOTF_DATE)   
 values(v_rec_seq,30,3176,systimestamp);
 
 email_from := 'shanmukesh@purdue.edu' ;
 email_to   := 'shanmukesh@purdue.edu';
 email_sub  := 'FORM 90';
 email_body :='This is to confirm that your FORM 90 request submission is successful';
 
 
 x := wgb_shared.email_file (email_from,email_to,null,null,email_sub,email_body,null,null,null,null);
 
 insert into TGRDFELLOW_SIG(FSG_RECSEQNUM,FSG_SIGN_LEVEL,FSG_USERSEQNUM)   
 values(v_rec_seq,0,1049);

 
 owa_util.redirect_url('www_rgs.wfl_fellowship.disp_fellow_form?in_var1='||in_var1||'&in_var2='||in_var2);
 end if;
 
 END;
 
 
-- Title: proc_fellow_create_form
-- Author: Shanmukesh Vankayala
-- Date: 02/28/2015
-- Description: Procedure for creating a form

procedure proc_fellow_create_form ( in_var1 in number default 0,
                            in_var2 in number default 0,
                            in_action in varchar2 default null,
                            in_puid in varchar2 default null,
                            in_flb_code in varchar2 default null,
                            in_view in number default 1)
IS
cur_user twwwuser1%rowtype;
cur_base tgrdbase%rowtype;
cur_fel tgrdfellcd%rowtype;
v_puid TGRDBASE.B_PUID%TYPE;
v_name TGRDBASE.B_NAME%TYPE;
v_citz TGRDBASE.B_CITZ%TYPE;
cur_reg TGRDREG%ROWTYPE;

cursor base_data is
select * from tgrdbase
where b_puid=in_puid;

cursor select_fellowships is
select * from tgrdfellcd
where fl_felcode=in_flb_code;

BEGIN
   if in_action= 'Cancel' then
   owa_util.redirect_url('www_rgs.wfl_fellowship.disp_fellow_form?in_var1='||in_var1||'&in_var2='||in_var2);
   return;
   end if;

  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is  null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;
  
  wgb_shared.form_start('Graduate School Database');
  wgb_shared.body_start2('Create New Fellowship',null,null, in_var1,in_var2, cur_user);
  --wgb_shared.print_java_date();
  --wgb_shared.print_java_numeric;
  --print_java_copy_from_previous();
  --print_java_alert();
 
  
  if in_action = 'Search' then
  
  htp.print('<script src="'||wgb_constants.constant_ssl_static_page||'/GradSch/calendar.js"></script>');
  
    open base_data;
    fetch base_data into cur_base;
    close base_data;
  
    open select_fellowships;
    fetch select_fellowships into cur_fel;
    close select_fellowships;
    
    select b_puid,b_name,b_citz into v_puid,v_name, v_citz from tgrdbase
    where b_seqnum=cur_base.b_seqnum;
    
    cur_reg := wps_shared.get_most_recent_registration(cur_base.b_seqnum);
    htp.formopen('www_rgs.wfl_fellowship.proc_create_fellowship_stage','POST');
    htp.formhidden('in_var1',in_var1);
    htp.formhidden('in_var2',in_var2);
    htp.formhidden('in_seqnum',cur_base.b_seqnum);
    --htp.header(3,'Student Information',null,null,null,'style="color:#0000CC;"');
    htp.tableopen(null,null,null,null,'style="width:80%; border-collapse:collapse; border:1px solid black; margin-left:auto; margin-right:auto"');
    htp.tablerowopen(null,null,null,null,'style="border:1px solid black;"');
    htp.tableheader('Student Information',null,null,null,null,4,'style="color:#0000CC; padding:10px"');
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata('Name <br>'|| htf.formtext(null,35,null,v_name,'disabled="disabled"'),null,null,null,null,null,'style="padding:5px"');
    htp.tabledata('PUID <br>' ||htf.formtext(null,35,null,v_puid,'disabled="disabled"'),null,null,null,null,null,'style="padding:5px"');
    htp.tabledata('Department <br>'||htf.formtext(null,35,null,wgb_functions.dept_of(cur_reg.rg_dept, cur_reg.rg_campus),'disabled="disabled"'),null,null,null,null,null,'style="border:padding:5px"');
    If (v_citz is null) then
    htp.tabledata('Citizenship <br>'||htf.formtext(null,35,null,'N/A','disabled="disabled"'),null,null,null,null,null,'style="border:1px solid black"');
    elsif wgb_functions.all_digits_string(trim(v_citz)) Then
    htp.tabledata('Citizenship <br>'||htf.formtext(null,35,null,rtrim(wgb_functions.citizen_of(v_citz)),'disabled="disabled"'),null,null,null,null,null,'style="padding:5px"'); 
    else
    htp.tabledata('Citizenship <br>'||htf.formtext(null,35,null,rtrim(wgb_functions.nation_of(v_citz)),'disabled="disabled"'),null,null,null,null,null,'style="padding:5px"'); 
    End If;
    htp.tablerowclose;
    htp.tablerowopen(null,null,null,null,'style="border:1px solid black;"');
    htp.tableheader('Award Information',null,null,null,null,4,'style="color:#0000CC; padding:10px"');
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata('Name <br>'||htf.formtext(null,35,null,cur_fel.fl_felname,'disabled="disabled"'),null,null,null,null,null);
    htp.tabledata('Administration <br>'||htf.formtext(null,35,null,'Assistantship','disabled="disabled"'));
    htp.tabledata('Duration <br>'||htf.formtext(null,35,null,cur_fel.fl_terms_duration,'disabled="disabled"'));
    htp.tabledata('Sponsor <br>'||htf.formtext(null,35,null,'Test','disabled="disabled"'));
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata('Starting session <br>'||htf.formtext(null,35,null,'Fall 2014','disabled="disabled"'));
    if (in_view =1) then 
    htp.tabledata('Start Date <br>'||htf.formtext('in_startdate',25,null,null,'id="Startdate" onchange="check_date(this,this.value)"')||
    '<a href="javascript:NewCal(''CalenderDiv1'',''Startdate'',''mmddyyyy'')">
     <img src="https://iasdev.itap.purdue.edu/gradsch/GradSch/calendar_icon.jpg" width="30" height="25" border="0" style="vertical-align:bottom"    alt="Pick a date" /></a>
     <div id="CalenderDiv1" style="visibility: hidden; position:fixed ; left:10px; background: white; z-index: 2"></div>');
    
    htp.tabledata('End Date <br>'||htf.formtext('in_enddate',25,null,null,'id="Enddate" onchange="check_date(this,this.value)"')||
                  '<a href="javascript:NewCal(''CalenderDiv2'',''Enddate'',''mmddyyyy'')">
                   <img src="https://iasdev.itap.purdue.edu/gradsch/GradSch/calendar_icon.jpg" width="30" height="25" border="0" style="vertical-align:bottom"    alt="Pick a date" /></a>
                   <div id="CalenderDiv2" style="visibility: hidden; position:fixed ; left:220px; background: white; z-index: 2"></div>');
   
    htp.tabledata('PI <br>'||htf.formtext('in_pi',35,null,null),null,null,null,null,null);
    else
    htp.tabledata('Start Date <br>'||htf.formtext('in_startdate',35,null,'08-21-2015','id="Startdate" disabled="disabled"'));
    htp.tabledata('End Date <br>'||htf.formtext('in_enddate',35,null,'09-21-2016','id="Enddate" disabled="disabled"'));
    htp.tabledata('PI <br>'||htf.formtext('in_pi',35,null,'Professor','disabled="disabled"'),null,null,null,null,null);
    end if;
    htp.tablerowclose;
    htp.tablerowopen;
    if (in_view =1) then 
    htp.tabledata('Special Instructions <br>'||htf.formtextarea('in_si',2,160),null,null,null,null,4);
    else
    htp.tabledata('Special Instructions <br>'||htf.formtextarea('in_si',2,160,null,'disabled="disabled"'),null,null,null,null,4);
    end if;
    htp.tablerowclose;
    htp.tablerowopen(null,null,null,null,'style="border:1px solid black;"');
    htp.tableheader('Tution & Fees',null,null,null,null,4,'style="color:#0000CC; padding:10px"');
    htp.tablerowclose;
    htp.tablerowopen;
    htp.print('<td colspan=4>');
    htp.tableopen(null,null,null,null,'style="width:100%; table-layout:fixed"');
    htp.tablerowopen;
    htp.tabledata('Term','center',null,null,null,null,'style="width:5%"');
    htp.tabledata('Academic Year','center');
    htp.tabledata('Status','center',null,null,null,null,'style="width:13%"');
    htp.tabledata('Tution','center');
    htp.tabledata('Grad Appt','center');
    htp.tabledata('Technology','center');
    htp.tabledata('R & R','center');
    htp.tabledata('Wellness','center');
    htp.tabledata('International','center');
    htp.tabledata('Differential','center');
    htp.tabledata('Activity','center');
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata('Fall','center');
    if (in_view =1) then
    htp.tabledata(get_years_selectlist('in_acadyear1',null,15,to_char(sysdate,'YYYY')-5),'center');
    htp.tabledata(selectlist_tgrdrefer('in_FLS_status1',null,'fellowship_status'),'center');
    htp.tabledata(selectlist_tgrdrefer('in_tution1',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer1('in_GRAD_APPT_FEE1',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer1('in_TECH_FEE1',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer('in_RR_FEE1',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer('in_WELL_FEE1',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer('in_INT_FEE1',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer('in_DIFF_FEE1',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer('in_ACT_FEE1',null,'fellowship_tuit_code'),'center');
    else
    htp.tabledata(htf.formtext('in_acadyear1',10,null,'2015','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_FLS_status1',10,null,'Active','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_tution1',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_GRAD_APPT_FEE1',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_TECH_FEE1',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_RR_FEE1',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_WELL_FEE1',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_INT_FEE1',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_DIFF_FEE1',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_ACT_FEE1',10,null,'Fee Remit','disabled="disabled"'),'center');
    end if;
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata('Spring','center');
    if (in_view =1) then
    htp.tabledata(get_years_selectlist('in_acadyear2',null,15,to_char(sysdate,'YYYY')-5),'center');
    htp.tabledata(selectlist_tgrdrefer('in_FLS_status2',null,'fellowship_status'),'center');
    htp.tabledata(selectlist_tgrdrefer('in_tution2',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer1('in_GRAD_APPT_FEE2',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer1('in_TECH_FEE2',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer('in_RR_FEE2',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer('in_WELL_FEE2',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer('in_INT_FEE2',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer('in_DIFF_FEE2',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer('in_ACT_FEE2',null,'fellowship_tuit_code'),'center');
    else
    htp.tabledata(htf.formtext('in_acadyear2',10,null,'2016','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_FLS_status2',10,null,'Active','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_tution2',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_GRAD_APPT_FEE2',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_TECH_FEE2',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_RR_FEE2',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_WELL_FEE2',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_INT_FEE2',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_DIFF_FEE2',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_ACT_FEE2',10,null,'Fee Remit','disabled="disabled"'),'center');
    end if;
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata('Summer','center');
    if (in_view =1) then
    htp.tabledata(get_years_selectlist('in_acadyear3',null,15,to_char(sysdate,'YYYY')-5),'center');
    htp.tabledata(selectlist_tgrdrefer('in_FLS_status3',null,'fellowship_status'),'center');
    htp.tabledata(selectlist_tgrdrefer('in_tution3',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer1('in_GRAD_APPT_FEE3',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer1('in_TECH_FEE3',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer('in_RR_FEE3',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer('in_WELL_FEE3',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer('in_INT_FEE3',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer('in_DIFF_FEE3',null,'fellowship_tuit_code'),'center');
    htp.tabledata(selectlist_tgrdrefer('in_ACT_FEE3',null,'fellowship_tuit_code'),'center');
    else
    htp.tabledata(htf.formtext('in_acadyear3',10,null,'2016','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_FLS_status1',10,null,'Active','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_tution3',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_GRAD_APPT_FEE3',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_TECH_FEE3',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_RR_FEE3',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_WELL_FEE3',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_INT_FEE3',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_DIFF_FEE3',10,null,'Fee Remit','disabled="disabled"'),'center');
    htp.tabledata(htf.formtext('in_ACT_FEE3',10,null,'Fee Remit','disabled="disabled"'),'center');
    end if;
    htp.tablerowclose;
    htp.tablerowopen;
    htp.print('<td colspan=11>');
    htp.tableopen(null,null,null,null,'style="width:100%; border-collapse:collapse; border:1px solid black;"');
    htp.tablerowopen;
    htp.tabledata('If fees charged to an account, use Account 1 and Account 2 below:',null,null,null,null,8);
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata('');
    htp.tabledata('Fund');
    htp.tabledata('Cost Center');
    htp.tabledata('Internal Order');
    htp.tabledata('');
    htp.tabledata('Fund');
    htp.tabledata('Cost Center');
    htp.tabledata('Internal Order');   
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata('Account 1','center');
    if (in_view =1) then
    htp.tabledata(htf.formtext('in_act1_fund',10,null));
    htp.tabledata(htf.formtext('in_act1_cc',10,null));
    htp.tabledata(htf.formtext('in_act1_io',10,null));
    else
    htp.tabledata(htf.formtext('in_act1_fund',10,null,null,'disabled="disabled"'));
    htp.tabledata(htf.formtext('in_act1_cc',10,null,null,'disabled="disabled"'));
    htp.tabledata(htf.formtext('in_act1_io',10,null,null,'disabled="disabled"'));
    end if;
    htp.tabledata('Account 2','center');
    if (in_view =1) then
    htp.tabledata(htf.formtext('in_act2_fund',10,null));
    htp.tabledata(htf.formtext('in_act2_cc',10,null));
    htp.tabledata(htf.formtext('in_act2_io',10,null));
    else
    htp.tabledata(htf.formtext('in_act2_fund',10,null,null,'disabled="disabled"'));
    htp.tabledata(htf.formtext('in_act2_cc',10,null,null,'disabled="disabled"'));
    htp.tabledata(htf.formtext('in_act2_io',10,null,null,'disabled="disabled"'));
    end if;
    htp.tablerowclose;
    htp.tableclose;
    htp.print('</td>');
    htp.tablerowclose;
    htp.tableclose;
    htp.print('</td>');
    htp.tablerowclose;
    htp.tablerowopen(null,null,null,null,'style="border:1px solid black;"');
    htp.tableheader('Stipend & Supplemental Funding Information',null,null,null,null,4,'style="color:#0000CC; padding:10px"');
    htp.tablerowclose;
    htp.tablerowopen;
    htp.print('<td colspan=4>');
    htp.tableopen(null,null,null,null,'style="width:60%; border-collapse:collapse; border:1px solid black;"');
    htp.tablerowopen;
    htp.tabledata('Will this award be supplemented? '|| htf.formradio('in_supp_op','Y')||'Yes '||
                  htf.formradio('in_supp_op','N')|| 'No',null,null,null,null,6);
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata('');
    htp.tabledata('Amount');
    htp.tabledata('Fund');
    htp.tabledata('Cost Center');
    htp.tabledata('Grant');
    htp.tabledata('Internal Order');
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata('Supp Account 1','center');
    if (in_view=1) then
    htp.tabledata(htf.formtext('in_supp_act1_amt',10,null));
    htp.tabledata(htf.formtext('in_supp_act1_fund',10,null));
    htp.tabledata(htf.formtext('in__supp_act1_cc',10,null));
    htp.tabledata(htf.formtext('in__supp_act1_gr',10,null));
    htp.tabledata(htf.formtext('in_supp_act1_io',10,null));
    else
    htp.tabledata(htf.formtext('in_supp_act1_amt',10,null,null,'disabled="disabled"'));
    htp.tabledata(htf.formtext('in_supp_act1_fund',10,null,null,'disabled="disabled"'));
    htp.tabledata(htf.formtext('in__supp_act1_cc',10,null,null,'disabled="disabled"'));
    htp.tabledata(htf.formtext('in__supp_act1_gr',10,null,null,'disabled="disabled"'));
    htp.tabledata(htf.formtext('in_supp_act1_io',10,null,null,'disabled="disabled"'));
    end if;
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata('Supp Account 2','center');
    if (in_view =1) then
    htp.tabledata(htf.formtext('in_supp_act2_amt',10,null));
    htp.tabledata(htf.formtext('in_supp_act2_fund',10,null));
    htp.tabledata(htf.formtext('in_supp_act2_cc',10,null));
    htp.tabledata(htf.formtext('in__supp_act2_gr',10,null));
    htp.tabledata(htf.formtext('in_supp_act2_io',10,null));
    else
    htp.tabledata(htf.formtext('in_supp_act2_amt',10,null,null,'disabled="disabled"'));
    htp.tabledata(htf.formtext('in_supp_act2_fund',10,null,null,'disabled="disabled"'));
    htp.tabledata(htf.formtext('in_supp_act2_cc',10,null,null,'disabled="disabled"'));
    htp.tabledata(htf.formtext('in__supp_act2_gr',10,null,null,'disabled="disabled"'));
    htp.tabledata(htf.formtext('in_supp_act2_io',10,null,null,'disabled="disabled"'));
    end if;
    htp.tablerowclose;
    htp.tableclose;
    htp.print('</td>');
    htp.tablerowclose;
    htp.tablerowopen;
    if (in_view =1) then
    htp.tabledata('Sponsor Stipend <br>'|| htf.formtext('in_SPONSOR_STIPEND',35,20,null));
    htp.tabledata('Supp Amt <br>'||htf.formtext('in_SUPP_AMOUNT',35,20,null,'id="in_SUPP_AMOUNT"' ));
    htp.tabledata('Insurance <br>'||htf.formtext('in_insurance',35,20,null,'id="in_insurance"' ));
    htp.tabledata('Total Annual Stipend <br>'||htf.formtext('in_TOTAL_AWARD_AMOUNT',35,20,13000,'id="in_TOTAL_AWARD_AMOUNT" disabled="disabled"' ));
    else
    htp.tabledata('Sponsor Stipend <br>'|| htf.formtext('in_SPONSOR_STIPEND',35,20,'1000','disabled="disabled"'));
    htp.tabledata('Supp Amt <br>'||htf.formtext('in_SUPP_AMOUNT',35,20,'0','disabled="disabled"'));
    htp.tabledata('Insurance <br>'||htf.formtext('in_insurance',35,20,'1000','disabled="disabled"' ));
    htp.tabledata('Total Annual Stipend <br>'||htf.formtext('in_TOTAL_AWARD_AMOUNT',35,20,'12000','disabled="disabled"' ));
    end if;
    htp.tablerowclose;
    htp.tablerowopen;
    if (in_view =1) then
    htp.tabledata('Total Months Paid <br>'||htf.formtext('in_MONTHS_STIPEND',35,20,null,'id="in_MONTHS_STIPEND"'));
    htp.tabledata('Total Monthly Stipend <br>'||htf.formtext('in_MONTHLY_STIPEND',35,20,1000,'id="in_MONTHLY_STIPEND" disabled="disabled"' ));
    htp.tabledata('Total Award Amount <br>'||htf.formtext('in_TOTAL_AWARD_AMOUNT',35,20,13000,'id="in_TOTAL_AWARD_AMOUNT" disabled="disabled"'),null,null,null,null,2);
    else
    htp.tabledata('Total Months Paid <br>'||htf.formtext('in_MONTHS_STIPEND',35,20,'12','disabled="disabled"'));
    htp.tabledata('Total Monthly Stipend <br>'||htf.formtext('in_MONTHLY_STIPEND',35,20,'1000','disabled="disabled"' ));
    htp.tabledata('Total Award Amount <br>'||htf.formtext('in_TOTAL_AWARD_AMOUNT',35,20,'13000','disabled="disabled"'),null,null,null,null,2);
    end if;
    htp.tablerowclose;
    htp.tablerowopen(null,null,null,null,'style="border:1px solid black;"');
    htp.tableheader('Account Information',null,null,null,null,4,'style="color:#0000CC; padding:10px"');
    htp.tablerowclose;
    htp.tablerowopen;
    if (in_view=2) then
    htp.tabledata('Budget Year <br>'|| htf.formtext('in_budget_year',35,20,null));
    htp.tabledata('Fund <br>'||htf.formtext('in_budget_fund',35,20,null));
    htp.tabledata('Cost Center <br>'||htf.formtext('in_budget_cost_center',35,20,null));
    htp.tabledata('Grant <br>'||htf.formtext('in_budget_grant',35,20,null));
    else 
    htp.tabledata('Budget Year <br>'|| htf.formtext('in_budget_year',35,20,null));
    htp.tabledata('Fund <br>'||htf.formtext('in_budget_fund',35,20,null));
    htp.tabledata('Cost Center <br>'||htf.formtext('in_budget_cost_center',35,20,null));
    htp.tabledata('Grant <br>'||htf.formtext('in_budget_grant',35,20,null));
    /*htp.tabledata('Budget Year <br>'|| htf.formtext('in_budget_year',35,20,2015,'disabled="disabled"'));
    htp.tabledata('Fund <br>'||htf.formtext('in_budget_fund',35,20,4501000,'disabled="disabled"'));
    htp.tabledata('Cost Center <br>'||htf.formtext('in_budget_cost_center',35,20,4012457896,'disabled="disabled"'));
    htp.tabledata('Grant <br>'||htf.formtext('in_budget_grant',35,20,401375,'disabled="disabled"'));*/
    end if;
    htp.tablerowclose;
    htp.tablerowopen;
    if (in_view=2) then
    htp.tabledata('Internal Order <br>'||htf.formtext('in_budget_io',35,20,null));
    htp.tabledata('COPA <br>'||htf.formtext('in_budget_copa',35,20,null));
    htp.tabledata('Fee Remit Budget<br>'||htf.formtext('in_budget_frb',35,20,null));
    htp.tabledata('Supplement Account<br>'||htf.formtext('in_budget_sa',35,20,null));
    else
    htp.tabledata('Internal Order <br>'||htf.formtext('in_budget_io',35,20,null));
    htp.tabledata('COPA <br>'||htf.formtext('in_budget_copa',35,20,null));
    htp.tabledata('Fee Remit Budget<br>'||htf.formtext('in_budget_frb',35,20,null));
    htp.tabledata('Supplement Account<br>'||htf.formtext('in_budget_sa',35,20,null));
    /*htp.tabledata('Internal Order <br>'||htf.formtext('in_budget_io',35,20,800062456,'disabled="disabled"'));
    htp.tabledata('COPA <br>'||htf.formtext('in_budget_copa',35,20,123456,'disabled="disabled"'));
    htp.tabledata('Fee Remit Budget<br>'||htf.formtext('in_budget_frb',35,20,123456,'disabled="disabled"'));
    htp.tabledata('Supplement Account<br>'||htf.formtext('in_budget_sa',35,20,123456,'disabled="disabled"'));*/
    end if;
    htp.tablerowclose;
    htp.tableclose;
    htp.nl;
    htp.tableopen(null,null,null,null,'style="width:91%; margin-left:auto; margin-right:auto"');
    htp.tablerowopen;
    htp.print('<td>');
    htp.formsubmit('in_action','Submit');
    htp.print('&nbsp;&nbsp;');
    htp.formsubmit('in_action','Cancel');
    htp.print('</td>');
    htp.tablerowclose;
    htp.tableclose;
  
  htp.formclose;
  end if;
  htp.bodyClose;
  htp.htmlClose;
END; 

-- Title: proc_award_create_form
-- Author: Shanmukesh Vankayala
-- Date: 02/28/2015
-- Description: Procedure for creating a form

procedure proc_award_create_form ( in_var1 in number default 0,
                            in_var2 in number default 0,
                            in_action in varchar2 default null,
                            in_puid in varchar2 default null,
                            in_flb_code in varchar2 default null)
IS
cur_user twwwuser1%rowtype;
cur_base tgrdbase%rowtype;
cur_fel tgrdfellcd%rowtype;
v_puid TGRDBASE.B_PUID%TYPE;
v_name TGRDBASE.B_NAME%TYPE;
cur_reg TGRDREG%ROWTYPE;


cursor base_data is
select * from tgrdbase
where b_puid=in_puid;

cursor select_fellowships is
select * from tgrdfellcd
where fl_felcode=in_flb_code;

BEGIN
   if in_action= 'Cancel' then
   owa_util.redirect_url('www_rgs.wfl_fellowship.disp_award_form?in_var1='||in_var1||'&in_var2='||in_var2);
   return;
   end if;

  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is  null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;
  
  wgb_shared.form_start('Graduate School Database');
  wgb_shared.body_start2('Create New Fellowship',null,null, in_var1,in_var2, cur_user);
  
  
  if in_action = 'Search' then
  
    htp.print('<script>
    function update_award_amt()
    {
    var sponsor_stipend=document.getElementById("in_FLS_TOTAL_SPONSOR_STIPEND").value;
    sponsor_stipend = sponsor_stipend.replace(/^\s+|\s+$/g,'''');
    if(sponsor_stipend==''''){sponsor_stipend="0";}
    var award=parseFloat(sponsor_stipend);
    award=award.toFixed(2).toString();
    document.getElementById("in_FLS_TOTAL_AWARD_AMOUNT").value=award;
    }
    
    function update_mon_stp()
    {
    var sponsor_stipend=document.getElementById("in_FLS_TOTAL_SPONSOR_STIPEND").value;
    var months_paid =document.getElementById("in_FLS_MONTHS_STIPEND").value;
    sponsor_stipend = sponsor_stipend.replace(/^\s+|\s+$/g,'''');
    months_paid = months_paid.replace(/^\s+|\s+$/g,'''');
    if(sponsor_stipend=='''')
    {
    sponsor_stipend="0";
    document.getElementById("in_FLS_MONTHLY_STIPEND").value=parseFloat(sponsor_stipend);
    }
    else
    {
    if(months_paid==''''){months_paid="1";}
    var stp=parseFloat(sponsor_stipend/months_paid);
    stp=stp.toFixed(2).toString();
    document.getElementById("in_FLS_MONTHLY_STIPEND").value=stp;
    }
    }
    
   </script>');
    
  
  
  
    open base_data;
    fetch base_data into cur_base;
    close base_data;
  
    open select_fellowships;
    fetch select_fellowships into cur_fel;
    close select_fellowships; 
  
    select b_puid,b_name into v_puid,v_name from tgrdbase
    where b_seqnum=cur_base.b_seqnum;
  
    cur_reg := wps_shared.get_most_recent_registration(cur_base.b_seqnum);  
  
    htp.formopen('www_rgs.wfl_fellowship.proc_create_award_stage','POST');
    htp.formhidden('in_var1',in_var1);
    htp.formhidden('in_var2',in_var2);
    htp.formhidden('in_seqnum',cur_base.b_seqnum);
    
    htp.header(3,'Student Details',null,null,null,'style="color:#0000CC;"');
    htp.tableopen(null,null,null,null,'style="width=50%"');
    htp.tablerowopen;
    htp.tabledata('Name');
    htp.tabledata(v_name);
    htp.tablerowclose;  
    htp.tablerowopen;  
    htp.tabledata('PUID');
    htp.tabledata(v_puid);
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata('Department');
    htp.tabledata(wgb_functions.dept_of(cur_reg.rg_dept, cur_reg.rg_campus)||'('||cur_reg.rg_dept||')');
    htp.tablerowclose;
    htp.tableclose;
    
    htp.nl;
    
    htp.header(3,'Fellowship Details',null,null,null,'style="color:#0000CC;"');
    htp.tableopen(null,null,null,null,'style="width=100%"');
    htp.tablerowopen;
    htp.tabledata('Name');
    htp.tabledata(cur_fel.fl_felname);
    htp.tablerowclose;
    htp.tabledata('Administration');
    htp.tabledata(wgb_shared.fel_admin_list('in_fl_adm','Y'));
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata('Starting session');
    htp.tabledata(selectlist_tgrdrefer('in_flb_start_session',null,'term')||get_years_selectlist('in_flb_start_calyear',null,15,to_char(sysdate,'YYYY')-5));
    htp.tablerowclose;
    htp.tableclose;  
    
    htp.nl;
    
    htp.header(3,'Session Details',null,null,null,'style="color:#0000CC;"');
    htp.tableopen;
    htp.tablerowopen;
    htp.tabledata('Status');
    htp.tabledata(selectlist_tgrdrefer('in_FLS_status',null,'fellowship_status'));
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata('Sponsor Stipend');
    htp.tabledata(htf.formtext('in_FLS_TOTAL_SPONSOR_STIPEND',10,20,null,'id="in_FLS_TOTAL_SPONSOR_STIPEND" onchange ="update_award_amt(); update_mon_stp()"' ));
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata('Supp Amt');
    htp.tabledata(htf.formtext('in_FLS_SUPP_AMOUNT',10,20,null,'id="in_FLS_SUPP_AMOUNT"' ));
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata('Total Months Paid');
    htp.tabledata(htf.formtext('in_FLS_MONTHS_STIPEND',10,20,null,'id="in_FLS_MONTHS_STIPEND" onchange="update_mon_stp()"' ));
    htp.tablerowclose;
    htp.tablerowopen;  
    htp.tabledata('Total Monthly Stipend');
    htp.tabledata(htf.formtext('in_FLS_MONTHLY_STIPEND',10,20,0,'id="in_FLS_MONTHLY_STIPEND" disabled="disabled"' ));
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata('Total Award Amount');
    htp.tabledata(htf.formtext('in_FLS_TOTAL_AWARD_AMOUNT',10,20,0,'id="in_FLS_TOTAL_AWARD_AMOUNT" disabled="disabled"' ));
    htp.tablerowclose;
    htp.tableclose;  

       
  htp.nl;
  htp.formsubmit('in_action','Submit');
  htp.print('&nbsp;&nbsp;');
  htp.formsubmit('in_action','Cancel');
  htp.formclose;
  end if;
  htp.bodyClose;
  htp.htmlClose;
END;

-- Title: proc_fellow_form
-- Author: Shanmukesh Vankayala
-- Date: 02/28/2015
-- Description: Procedure for creating a form

procedure proc_fellow_form ( in_var1 in number default 0,
                            in_var2 in number default 0,
                            in_action in varchar2 default null)
IS
cur_user twwwuser1%rowtype;


cursor approved_list is
select FS_RECSEQNUM, B_NAME, B_PUID from TGRDFELLOW_STAGE, TGRDFELLOW_SIG, TGRDBASE
where FS_RECSEQNUM =  FSG_RECSEQNUM
and FS_SEQNUM = B_SEQNUM
and FSG_USERSEQNUM = in_var1
and FSG_SIGN_STATUS in ('P','A');

cursor rejected_list is
select FS_RECSEQNUM, B_NAME, B_PUID from TGRDFELLOW_STAGE, TGRDFELLOW_SIG, TGRDBASE
where FS_RECSEQNUM =  FSG_RECSEQNUM
and FS_SEQNUM = B_SEQNUM
and FSG_USERSEQNUM = in_var1
and FSG_SIGN_STATUS ='R';

cursor submitted_list is
select FS_RECSEQNUM, B_NAME, B_PUID from TGRDFELLOW_STAGE, TGRDFELLOW_SIG, TGRDBASE
where FS_RECSEQNUM =  FSG_RECSEQNUM
and FS_SEQNUM = B_SEQNUM
and FSG_USERSEQNUM = in_var1
and FSG_SIGN_STATUS ='S';

cursor outstanding_list is
select FS_RECSEQNUM, B_NAME, B_PUID from TGRDFELLOW_STAGE, TGRDFELLOW_SIG, TGRDBASE
where FS_RECSEQNUM =  FSG_RECSEQNUM
and FS_MAX_NOT_SIGNED = FSG_SIGN_LEVEL
and FS_SEQNUM = B_SEQNUM
and FSG_USERSEQNUM = in_var1
and FSG_SIGN_STATUS is null;


BEGIN
   if in_action= 'Exit' then
   owa_util.redirect_url('www_rgs.wfl_fellowship.disp_fellow_form?in_var1='||in_var1||'&in_var2='||in_var2);
   return;
   end if;

  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is  null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;
  
  wgb_shared.form_start('Graduate School Database');
  
  if in_action = 'Initiate Form' then
  wgb_shared.body_start2('Create New Fellowship',null,null, in_var1,in_var2, cur_user);
  else
  wgb_shared.body_start2('Fellowship Form 90',null,null, in_var1,in_var2, cur_user);
  htp.formOpen('www_rgs.wfl_fellowship.proc_fellow_form','POST');                             
  htp.formhidden('in_var1',in_var1);
  htp.formhidden('in_var2',in_var2);
  htp.formSubmit('in_action','Exit');
  htp.formSubmit('in_action','Outstanding Forms');
  htp.formSubmit('in_action','Approved Forms');
  htp.formSubmit('in_action','Rejected Forms');
  htp.formSubmit('in_action','Submitted Forms');
  htp.formSubmit('in_action','Initiate Form');
  end if;
  
  
  --wgb_shared.print_java_date();
  --wgb_shared.print_java_numeric;
  --print_java_copy_from_previous();
  --print_java_alert();
  
  if in_action = 'Initiate Form' then
    htp.formopen('www_rgs.wfl_fellowship.proc_fellow_create_form','POST');
    htp.formhidden('in_var1',in_var1);
    htp.formhidden('in_var2',in_var2);
    
    
    htp.header(3,'Student Details',null,null,null,'style="color:#0000CC;"');
    htp.tableopen(null,null,null,null,'style="width=50%"');
    htp.tablerowopen;
    htp.tabledata('PUID');
    htp.tabledata(htf.formtext('in_puid',null,10,null,null));
    htp.tablerowclose;
    htp.tablerowopen;
    htp.tabledata('Fellowship Name');
    htp.tabledata(wgb_shared.fellowship_list('in_flb_code',null,'N','Y'),null,null,null,null,3);
    htp.tablerowclose;
    htp.tableclose;
    
  htp.nl;
  htp.formsubmit('in_action','Search');
  htp.print('&nbsp;&nbsp;');
  htp.formsubmit('in_action','Cancel');
  htp.formclose;
  
  elsif in_action = 'Approved Forms' then
  
  htp.header(3,'Approved Forms',null,null,null,'style="color:#0000CC;"');
  htp.tableopen(null,null,null,null,'style="width=90%"');
  htp.tablerowopen;
  htp.tableheader('PUID');
  htp.tableheader('Name');
  htp.tablerowclose;
  for a in approved_list
  LOOP
  htp.tablerowopen;
  htp.tabledata(htf.anchor('www_rgs.wfl_fellowship.disp_fellow_submit_form?in_var1='|| in_var1 || CHR(38) ||
               'in_var2=' || in_var2 ||CHR(38) || 'in_recseqnum=' || a.FS_RECSEQNUM, a.B_NAME));
  htp.tabledata(a.B_PUID);
  htp.tablerowclose;
  END LOOP;
  htp.tableclose;
  
  
  elsif in_action = 'Submitted Forms' then
  
  htp.header(3,'Submitted Forms',null,null,null,'style="color:#0000CC;"');
  htp.tableopen(null,null,null,null,'style="width=90%"');
  htp.tablerowopen;
  htp.tableheader('PUID');
  htp.tableheader('Name');
  htp.tablerowclose;
  for a in submitted_list
  LOOP
  htp.tablerowopen;
  htp.tabledata(htf.anchor('www_rgs.wfl_fellowship.disp_fellow_submit_form?in_var1='|| in_var1 || CHR(38) ||
               'in_var2=' || in_var2 ||CHR(38) || 'in_recseqnum=' || a.FS_RECSEQNUM, a.B_NAME));
  htp.tabledata(a.B_PUID);
  htp.tablerowclose;
  END LOOP;
  htp.tableclose;

  
  elsif in_action = 'Outstanding Forms' then
  
  htp.header(3,'Outstanding Forms',null,null,null,'style="color:#0000CC;"');
  htp.tableopen(null,null,null,null,'style="width=90%"');
  htp.tablerowopen;
  htp.tableheader('PUID');
  htp.tableheader('Name');
  htp.tablerowclose;
  for a in outstanding_list
  LOOP
  htp.tablerowopen;
  htp.tabledata(htf.anchor('www_rgs.wfl_fellowship.disp_fellow_submit_form?in_var1='|| in_var1 || CHR(38) ||
               'in_var2=' || in_var2 ||CHR(38) || 'in_recseqnum=' || a.FS_RECSEQNUM, a.B_NAME));
  htp.tabledata(a.B_PUID);
  htp.tablerowclose;
  END LOOP;
  htp.tableclose;
    
  elsif in_action = 'Rejected Forms' then
  
  htp.header(3,'Rejected Forms',null,null,null,'style="color:#0000CC;"');
  htp.tableopen(null,null,null,null,'style="width=90%"');
  htp.tablerowopen;
  htp.tableheader('PUID');
  htp.tableheader('Name');
  htp.tablerowclose;
  for a in rejected_list
  LOOP
  htp.tablerowopen;
  htp.tabledata(htf.anchor('www_rgs.wfl_fellowship.disp_fellow_submit_form?in_var1='|| in_var1 || CHR(38) ||
               'in_var2=' || in_var2 ||CHR(38) || 'in_recseqnum=' || a.FS_RECSEQNUM, a.B_NAME));
  htp.tabledata(a.B_PUID);
  htp.tablerowclose;
  END LOOP;
  htp.tableclose;
  

  end if;
  
  if in_action <> 'Initiate Form' then
  htp.formclose;
  end if;
  
  htp.bodyClose;
  htp.htmlClose;
END;

-- Title: proc_award_form
-- Author: Shanmukesh Vankayala
-- Date: 02/28/2015
-- Description: Procedure for creating a form

procedure proc_award_form ( in_var1 in number default 0,
                            in_var2 in number default 0,
                            in_action in varchar2 default null)
IS
cur_user twwwuser1%rowtype;

BEGIN
   if in_action= 'Exit' then
   owa_util.redirect_url('www_rgs.wfl_fellowship.disp_main_fellow_form?in_var1='||in_var1||'&in_var2='||in_var2);
   return;
   end if;

  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is  null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;
  
  wgb_shared.form_start('Graduate School Database');
  
  if in_action = 'Initiate Form' then
  wgb_shared.body_start2('Create New Award Form',null,null, in_var1,in_var2, cur_user);
  else
  wgb_shared.body_start2('Fellowship Award Form',null,null, in_var1,in_var2, cur_user);
  htp.formOpen('www_rgs.wfl_fellowship.proc_award_form','POST');                             
  htp.formhidden('in_var1',in_var1);
  htp.formhidden('in_var2',in_var2);
  htp.formSubmit('in_action','Exit');
  htp.formSubmit('in_action','Outstanding Forms');
  htp.formSubmit('in_action','Approved Forms');
  htp.formSubmit('in_action','Rejected Forms');
  htp.formSubmit('in_action','Submitted Forms');
  htp.formSubmit('in_action','Initiate Form');
  end if;
  
  if in_action = 'Initiate Form' then
    
  htp.formopen('www_rgs.wfl_fellowship.proc_award_create_form','POST');
  htp.formhidden('in_var1',in_var1);
  htp.formhidden('in_var2',in_var2);
  
  htp.header(3,'Award Form Details',null,null,null,'style="color:#0000CC;"');
  htp.tableopen(null,null,null,null,'style="width=50%"');
  htp.tablerowopen;
  htp.tabledata('PUID');
  htp.tabledata(htf.formtext('in_puid',null,10,null,null));
  htp.tablerowclose;
  htp.tablerowopen;
  htp.tabledata('Fellowship Name');
  htp.tabledata(wgb_shared.fellowship_list('in_flb_code',null,'N','Y'),null,null,null,null,3);
  htp.tablerowclose;
  htp.tableclose;
    
  htp.nl;
  htp.formsubmit('in_action','Search');
  htp.print('&nbsp;&nbsp;');
  htp.formsubmit('in_action','Cancel');
  htp.formclose;
  end if;
  
  htp.bodyClose;
  htp.htmlClose;
END;

-- Title: proc_alloc_process
-- Author: Shanmukesh Vankayala
-- Date: 01/5/2016
-- Description: Procedure for processing the routing process

procedure proc_alloc_process ( in_var1 in number default 0,
                               in_var2 in number default 0,
                               in_recseqnum in number default 0,
                               in_action in varchar2 default null,
                               in_signlevel in number,
                               in_comment in varchar2,
                               in_funds_string in varchar2 default null,
                               in_felcode_string in varchar2 default null)
IS
 x number;
 email_from varchar2(100);
 email_to varchar2(100);
 email_sub varchar2(500);
 email_body varchar2(5000);
 
 cursor stage_data is
 select * from TGRDFELLOW_STAGE
 where FS_RECSEQNUM = in_recseqnum;
 
 CURSOR string_cur
 IS
 select regexp_substr(in_felcode_string,'[^,]+', 1, level) as fel_code,
 regexp_substr(in_funds_string,'[^,]+', 1, level) as funds
 from dual
 connect by regexp_substr(in_felcode_string, '[^,]+', 1, level) is not null;
 
BEGIN
   /*if in_action= 'Cancel' then
   owa_util.redirect_url('www_rgs.wfl_fellowship.disp_fellow_form?in_var1='||in_var1||'&in_var2='||in_var2);
   return;
   end if;*/
   if in_felcode_string is not null then
   if in_signlevel =40 then
   for i in string_cur
   LOOP
   UPDATE TGRDFELLOW_ALLOC_RECORDS
   SET far_requested_amt  =  i.funds
   where far_alloc_seqnum = in_recseqnum
   and far_fel_code       = i.fel_code;
   END LOOP; 
   else
   for i in string_cur
   LOOP
   UPDATE TGRDFELLOW_ALLOC_RECORDS
   SET far_alloc_amt      =  i.funds
   where far_alloc_seqnum = in_recseqnum
   and far_fel_code       = i.fel_code;
   END LOOP; 
   end if;
   end if;

  if in_action = 'Approve' then
    
  UPDATE TGRDFELLOW_ALLOC_SIG
  SET fas_sign_status  = 'A',
  fas_sign_date        = systimestamp,
  fas_sign_userseqnum  = in_var1
  where fas_alloc_seqnum = in_recseqnum
  and fas_sign_level     = in_signlevel;
  
  if in_signlevel > 0 then
  
  UPDATE TGRDFELLOW_ALLOC_SIG
  SET  fas_notf_date   = systimestamp
  where fas_alloc_seqnum = in_recseqnum
  and fas_sign_level     = in_signlevel-10;
  
  UPDATE TGRDFELLOW_ALLOC_BASE
  SET fa_max_not_signed  = in_signlevel-10,
  fa_update_date         = systimestamp  
  where fa_alloc_seqnum  = in_recseqnum;
  end if;
  
  if in_signlevel =30 then
  
  UPDATE TGRDFELLOW_ALLOC_BASE
  SET fa_form_status      = 'A',
  fa_update_date         = systimestamp  
  where fa_alloc_seqnum  = in_recseqnum;
  
  elsif in_signlevel =0 then
  
  UPDATE TGRDFELLOW_ALLOC_BASE
  SET fa_form_status      = 'A1',
  fa_update_date         = systimestamp  
  where fa_alloc_seqnum  = in_recseqnum;
  end if;
   
  
  select us_email into email_to from twwwuser1
  where us_userseqnum = in_var1;
  
  email_from := 'shanmukesh@purdue.edu' ;
  email_sub  := 'Allocation Form';
  
  -- Notification to the user submitting signature
  email_body :='This is to confirm that your Allocation Form signature is successful';
  x := wgb_shared.email_file (email_from,email_to,null,null,email_sub,email_body,null,null,null,null);
  
  
  -- Notification to the next level user
  if in_signlevel > 30 then
  select us_email into email_to from twwwuser1
  where us_userseqnum = (select fas_userseqnum from TGRDFELLOW_ALLOC_SIG 
                         where fas_alloc_seqnum = in_recseqnum  
                         and   fas_sign_level   = in_signlevel-10)   ;
   
  
  email_body :='An Allocation Form is awaiting for your Signature';
  x := wgb_shared.email_file (email_from,email_to,null,null,email_sub,email_body,null,null,null,null);                      
  end if;                       
  
  
  elsif in_action = 'Reject' then
  
  UPDATE TGRDFELLOW_ALLOC_SIG
  SET fas_sign_status  = 'R',
  fas_sign_date        = systimestamp,
  fas_sign_userseqnum  = in_var1
  where fas_alloc_seqnum = in_recseqnum
  and fas_sign_level     = in_signlevel;
  
  if in_signlevel >= 30 then
  
  UPDATE TGRDFELLOW_ALLOC_BASE
  SET fa_form_status     = 'R',
  fa_update_date         = systimestamp  
  where fa_alloc_seqnum  = in_recseqnum;
  
  else
  
  UPDATE TGRDFELLOW_ALLOC_BASE
  SET fa_form_status     = 'R1',
  fa_update_date         = systimestamp  
  where fa_alloc_seqnum  = in_recseqnum;
  end if;
  
  select us_email into email_to from twwwuser1
  where us_userseqnum = in_var1;
  
  email_from := 'shanmukesh@purdue.edu' ;
  email_sub  := 'Allocation Form';
  
  -- Notification to the user submitting signature
  email_body :='This is to confirm that your Allocation Form signature is successful';
  x := wgb_shared.email_file (email_from,email_to,null,null,email_sub,email_body,null,null,null,null);
  
  
  -- Notification to the user submitting the form
  if in_signlevel >= 30 then
  select us_email into email_to from twwwuser1
  where us_userseqnum = (select fas_userseqnum from TGRDFELLOW_ALLOC_SIG 
                         where fas_alloc_seqnum = in_recseqnum  
                         and   fas_sign_level   = 60)   ;
   else
   
   select us_email into email_to from twwwuser1
   where us_userseqnum = (select fas_userseqnum from TGRDFELLOW_ALLOC_SIG 
                         where fas_alloc_seqnum = in_recseqnum  
                         and   fas_sign_level   = 20)   ;
   end if;
   
  
  email_body :='An Allocation Form was Rejected';
  x := wgb_shared.email_file (email_from,email_to,null,null,email_sub,email_body,null,null,null,null);                      
                         
  
  elsif in_action = 'Add' then
  
  insert into TGRDFELLOW_ALLOC_COM
  (fac_alloc_seqnum,fac_userseqnum,fac_date,fac_comment)
  values
  (in_recseqnum,in_var1,sysdate,in_comment);
  end if;
  
  
  if in_signlevel >= 30 then
  owa_util.redirect_url('www_rgs.wfl_fellowship.disp_alloc_submit_form?in_var1='|| in_var1 || CHR(38) ||
               'in_var2=' || in_var2 ||CHR(38) || 'in_recseqnum=' || in_recseqnum);
  else
  owa_util.redirect_url('www_rgs.wfl_fellowship.disp_alloc_2_submit_form?in_var1='|| in_var1 || CHR(38) ||
               'in_var2=' || in_var2 ||CHR(38) || 'in_recseqnum=' || in_recseqnum);
  end if;
  
END;


-- Title: proc_alloc_student_submit
-- Author: Shanmukesh Vankayala
-- Date: 1/5/2016
-- Description: Procedure for handling the second stage of the allocation form
PROCEDURE proc_alloc_student_submit(
    in_var1         IN NUMBER DEFAULT 0,
    in_var2         IN NUMBER DEFAULT 0,
    in_recseqnum    IN NUMBER DEFAULT 0,
    in_puid         IN VARCHAR2 DEFAULT NULL,
    in_fel          IN VARCHAR2 DEFAULT NULL,
    in_amt          IN NUMBER DEFAULT NULL,
    in_action       IN VARCHAR2 DEFAULT NULL,
    in_radio_delete IN VARCHAR2 DEFAULT NULL)
IS
  v_temp1    NUMBER;
  v_temp2    NUMBER;
  v_temp3    NUMBER;
  v_email    VARCHAR2(50);
  x          NUMBER;
  email_from VARCHAR2(100);
  email_to   VARCHAR2(100);
  email_sub  VARCHAR2(500);
  email_body VARCHAR2(5000);
BEGIN
  IF in_action= 'Cancel' THEN
    owa_util.redirect_url('www_rgs.wfl_fellowship.disp_alloc_form?in_var1='||in_var1||'&in_var2='||in_var2);
    RETURN;
  elsif in_action ='Add' THEN
    INSERT
    INTO TGRDFELLOW_ALLOC_STUD_REC
      (
        faf_alloc_seqnum,
        faf_puid,
        faf_fel_code,
        faf_fund_amt
      )
      VALUES
      (
        in_recseqnum,
        in_puid,
        in_fel,
        in_amt
      );
      
      owa_util.redirect_url('www_rgs.wfl_fellowship.disp_alloc_2_form?in_var1='||in_var1||'&in_var2='||in_var2||'&in_recseqnum='||in_recseqnum);
      
  elsif in_action = 'Delete' THEN
    DELETE
    FROM TGRDFELLOW_ALLOC_STUD_REC
    WHERE faf_alloc_seqnum = in_recseqnum
    AND faf_puid           = in_radio_delete;
    
    owa_util.redirect_url('www_rgs.wfl_fellowship.disp_alloc_2_form?in_var1='||in_var1||'&in_var2='||in_var2||'&in_recseqnum='||in_recseqnum);
    
  ELSIF in_action          = 'Submit' THEN
    UPDATE TGRDFELLOW_ALLOC_BASE
    SET fa_form_status    = 'P1',
        fa_max_not_signed   = 10,
        fa_update_date      = systimestamp
    WHERE fa_alloc_seqnum = in_recseqnum;
    --for GEA Dean/Designee
    SELECT frmwho_userseqnum
    INTO v_temp1
    FROM tfrmroutewho
    WHERE FRMWHO_JOB ='fl_geadean'
    AND FRMWHO_DEPT  = (select fa_col_code from TGRDFELLOW_ALLOC_BASE where fa_alloc_seqnum = in_recseqnum) ;
    INSERT
    INTO TGRDFELLOW_ALLOC_SIG
      (
        fas_alloc_seqnum,
        fas_sign_level,
        fas_userseqnum,
        fas_proxy_userseqnum,
        fas_notf_date,
        fas_sign_userseqnum,
        fas_sign_date,
        fas_sign_status
      )
      VALUES
      (
        in_recseqnum,
        20,
        v_temp1,
        NULL,
        NULL,
        NULL,
        sysdate,
        'S'
      );
      
    --for Fellowship Assistant
      SELECT frmwho_userseqnum
      INTO v_temp2
      FROM tfrmroutewho
      WHERE FRMWHO_JOB ='fl_asst';
      INSERT
    INTO TGRDFELLOW_ALLOC_SIG
      (
        fas_alloc_seqnum,
        fas_sign_level,
        fas_userseqnum,
        fas_proxy_userseqnum,
        fas_notf_date,
        fas_sign_userseqnum,
        fas_sign_date,
        fas_sign_status
      )
      VALUES
      (
        in_recseqnum,
        10,
        v_temp2,
        NULL,
        sysdate,
        NULL,
        NULL,
        NULL
      );
      
    
    
    --for Fellowship Director
    SELECT frmwho_userseqnum
    INTO v_temp3
    FROM tfrmroutewho
    WHERE FRMWHO_JOB ='fl_dir';
    INSERT
    INTO TGRDFELLOW_ALLOC_SIG
      (
        fas_alloc_seqnum,
        fas_sign_level,
        fas_userseqnum,
        fas_proxy_userseqnum,
        fas_notf_date,
        fas_sign_userseqnum,
        fas_sign_date,
        fas_sign_status
      )
      VALUES
      (
        in_recseqnum,
        0,
        v_temp3,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL
      );
    ---Notification email sent to GEA DEAN for successful form submission
    SELECT us_email
    INTO v_email
    FROM twwwuser1
    WHERE us_userseqnum = v_temp1;
    email_from         := 'shanmukesh@purdue.edu' ;
    email_to           := v_email;
    email_sub          := 'FORM 90';
    email_body         :='This is to confirm that your Allocation Form consisting of student data submission is successful';
    x                  := wgb_shared.email_file (email_from,email_to,NULL,NULL,email_sub,email_body,NULL,NULL,NULL,NULL);
    
    ---Notification email sent to Fellowship Assistant that a form is awaiting for review
    SELECT us_email
    INTO v_email
    FROM twwwuser1
    WHERE us_userseqnum = v_temp2;
    email_from         := 'shanmukesh@purdue.edu' ;
    email_to           := v_email;
    email_sub          := 'FORM 90';
    email_body         :='An allocation form is waiting for your review';
    x                  := wgb_shared.email_file (email_from,email_to,NULL,NULL,email_sub,email_body,NULL,NULL,NULL,NULL);
  owa_util.redirect_url('www_rgs.wfl_fellowship.disp_alloc_form?in_var1='||in_var1||'&in_var2='||in_var2);
  END IF;
  END;

-- Title: disp_alloc_2_form
-- Author: Shanmukesh Vankayala
-- Date: 01/05/2016
-- Description: Procedure for displaying second part of the allocation form to submit student list by
--              the GEA Dean/Designee

PROCEDURE disp_alloc_2_form(
    in_var1      IN NUMBER DEFAULT 0,
    in_var2      IN NUMBER DEFAULT 0,
    in_recseqnum IN NUMBER DEFAULT 0)
IS
  cur_user twwwuser1%rowtype;
  cur_base TGRDFELLOW_ALLOC_BASE%rowtype;
  v_temp    VARCHAR2(100);
  v_temp1   VARCHAR2(100);
  temp_list VARCHAR2(32767);
  v_name TGRDBASE.B_NAME%TYPE;
  v_seqnum TGRDBASE.B_SEQNUM%TYPE;
  cur_reg TGRDREG%ROWTYPE;
  CURSOR base_data
  IS
    SELECT * FROM TGRDFELLOW_ALLOC_BASE WHERE fa_alloc_seqnum = in_recseqnum;
  CURSOR records_data
  IS
    SELECT * FROM TGRDFELLOW_ALLOC_RECORDS WHERE far_alloc_seqnum = in_recseqnum;
  CURSOR stu_data
  IS
    SELECT * FROM TGRDFELLOW_ALLOC_STUD_REC WHERE faf_alloc_seqnum = in_recseqnum;
BEGIN
  cur_user                  := (wgb_shared.validate_state(in_var1, in_var2));
  IF cur_user.us_userseqnum IS NULL THEN
    wpu_intra.pu_dispauth(1000);
    RETURN;
  END IF;
  wgb_shared.form_start('Graduate School Database');
  wgb_shared.body_start2('Allocation Form ', NULL,NULL,in_var1,in_var2,cur_user);
  OPEN base_data;
  FETCH base_data INTO cur_base;
  CLOSE base_data;
  SELECT ref_literal
  INTO v_temp
  FROM tgrdrefer
  WHERE ref_name   = 'academic_school_name'
  AND ref_category = 'PWL'
  AND ref_code     = cur_base.fa_col_code;
  htp.formopen('www_rgs.wfl_fellowship.proc_alloc_student_submit','POST');
  htp.formhidden('in_var1',in_var1);
  htp.formhidden('in_var2',in_var2);
  htp.formhidden('in_recseqnum',in_recseqnum);
  htp.tableopen(NULL,NULL,NULL,NULL,'style="width:80%; border-collapse:collapse; border:1px solid black; margin-left:auto; margin-right:auto"');
  htp.tablerowopen;
  htp.tabledata(htf.bold('Academic Year'));
  htp.tabledata(cur_base.fa_ac_year);
  htp.tablerowclose;
  htp.tablerowopen;
  htp.tabledata(htf.bold('College Name'));
  htp.tabledata(v_temp);
  htp.tablerowclose;
  htp.tableclose;
  htp.tableopen(NULL,NULL,NULL,NULL,'style="width:80%; border-collapse:collapse; border:1px solid black; margin-left:auto; margin-right:auto"');
  htp.tablerowopen(NULL,NULL,NULL,NULL,'style="border:1px solid black;"');
  htp.tableheader('Fellowship Name','left',NULL,NULL,NULL,NULL,'style="color:#0000CC;"');
  htp.tableheader('Funds Approved','left',NULL,NULL,NULL,NULL,'style="color:#0000CC;"');
  htp.tablerowclose;
  FOR j IN records_data
  LOOP
    SELECT fl_felname
    INTO v_temp1
    FROM TGRDFELLCD
    WHERE fl_felcode = j.far_fel_code;
    htp.tablerowopen(NULL,NULL,NULL,NULL,'style="border-top:1px solid black;"');
    htp.tabledata(v_temp1||chr(32)||'('||j.far_fel_code||')');
    htp.tabledata(j.far_alloc_amt);
    htp.tablerowclose;
  END LOOP;
  htp.tableclose;
  htp.nl;
  htp.tableopen(NULL,NULL,NULL,NULL,'style="width:80%; border-collapse:collapse; border:1px solid black; margin-left:auto; margin-right:auto"');
  htp.tablerowopen(NULL,NULL,NULL,NULL,'style="border:1px solid black;"');
  htp.tableheader('Student List',NULL,NULL,NULL,NULL,6,'style="color:#0000CC;"');
  htp.tablerowclose;
  htp.tablerowopen(NULL,NULL,NULL,NULL,'style="border:1px solid black;"');
  htp.tableheader('PUID','left',NULL,NULL,NULL,NULL,'style="color:#0000CC;"');
  htp.tableheader('Name','left',NULL,NULL,NULL,NULL,'style="color:#0000CC;"');
  htp.tableheader('Department','left',NULL,NULL,NULL,NULL,'style="color:#0000CC;"');
  htp.tableheader('Fellowship','left',NULL,NULL,NULL,NULL,'style="color:#0000CC;"');
  htp.tableheader('Funding Amount','left',NULL,NULL,NULL,NULL,'style="color:#0000CC;"');
  htp.tableheader(htf.formsubmit('in_action','Delete'));
  htp.tablerowclose;
  FOR j IN stu_data
  LOOP
    SELECT b_seqnum,
      b_name
    INTO v_seqnum,
      v_name
    FROM tgrdbase
    WHERE b_puid=j.faf_puid;
    SELECT fl_felname
    INTO v_temp1
    FROM TGRDFELLCD
    WHERE fl_felcode = j.faf_fel_code;
    cur_reg         := wps_shared.get_most_recent_registration(v_seqnum);
    htp.tablerowopen(NULL,NULL,NULL,NULL,'style="border:1px solid black;"');
    htp.tabledata(j.faf_puid);
    htp.tabledata(v_name);
    htp.tabledata(wgb_functions.dept_of(cur_reg.rg_dept, cur_reg.rg_campus));
    htp.tabledata(v_temp1);
    htp.tabledata(j.faf_fund_amt);
    htp.tabledata(htf.formradio('in_radio_delete',j.faf_puid));
    htp.tablerowclose;
  END LOOP;
  htp.tableclose;
  --Code for creating select list of the fellowships contained in the allocation form
  temp_list := htf.formSelectOpen('in_fel',NULL);
  temp_list := temp_list || htf.formSelectOption(' ');
  FOR each_fel IN records_data
  LOOP
    temp_list := temp_list || htf.formSelectOption(each_fel.far_fel_code, NULL,'VALUE="' || each_fel.far_fel_code || '"');
  END LOOP;
  temp_list := temp_list || htf.formSelectClose;
  htp.nl;
  htp.tableopen(NULL,NULL,NULL,NULL,'style="width:80%; border-collapse:collapse; border:1px solid black; margin-left:auto; margin-right:auto"');
  htp.tablerowopen(NULL,NULL,NULL,NULL,'style="border:1px solid black;"');
  htp.tableheader('Add a Student to the list',NULL,NULL,NULL,NULL,3,'style="color:#0000CC;"');
  htp.tablerowclose;
  htp.tablerowopen;
  htp.tableheader('PUID','left',NULL,NULL,NULL,NULL,'style="color:#0000CC;"');
  htp.tableheader('Fellowship','left',NULL,NULL,NULL,NULL,'style="color:#0000CC;"');
  htp.tableheader('Funding Amount','left',NULL,NULL,NULL,NULL,'style="color:#0000CC;"');
  htp.tablerowclose;
  htp.tablerowopen;
  htp.tabledata(htf.formtext('in_puid',10,10,NULL));
  htp.tabledata(temp_list);
  htp.tabledata(htf.formtext('in_amt',10,10,NULL)|| chr(32) ||htf.formsubmit('in_action','Add'));
  htp.tablerowclose;
  htp.tableclose;
  htp.tableopen(NULL,NULL,NULL,NULL,'style="width:81%; margin-left:auto; margin-right:auto"');
  htp.tablerowopen;
  htp.print('<td>');
  htp.formsubmit('in_action','Submit');
  htp.print('&nbsp;&nbsp;');
  htp.formsubmit('in_action','Cancel');
  htp.print('</td>');
  htp.tablerowclose;
  htp.tableclose;
  htp.formclose;
  htp.bodyClose;
  htp.htmlClose;
END;

-- Title: disp_alloc_submit_form
-- Author: Shanmukesh Vankayala
-- Date: 1/5/2016
-- Description: Displays the Allocation forms that are created 

procedure disp_alloc_submit_form (in_header in number default 0,
                          in_var1 in number default 0,
                          in_var2 in number default 0,
                          in_recseqnum in number default 0) AS
                          
  cur_user twwwuser1%rowtype;
  cur_base TGRDFELLOW_ALLOC_BASE%rowtype;
  v_temp varchar2(100);
  v_temp1 varchar2(100);
  v_user number;
  v_username varchar2(100);
  in_funds_string varchar2(1000);
  in_felcode_string varchar2(1000);
  in_funds_total number;
 

   cursor base_data is
   select * from TGRDFELLOW_ALLOC_BASE
   where fa_alloc_seqnum  = in_recseqnum;
   
   cursor records_data is
   select * from TGRDFELLOW_ALLOC_RECORDS
   where far_alloc_seqnum  = in_recseqnum;
   
   cursor sig_data is
   select * from TGRDFELLOW_ALLOC_SIG
   where FAS_ALLOC_SEQNUM = in_recseqnum
   and fas_sign_level >=30
   order by FAS_SIGN_LEVEL desc;
   
   cursor com_data is
   select * from TGRDFELLOW_ALLOC_COM
   where FAC_ALLOC_SEQNUM = in_recseqnum;
   
      
BEGIN

  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;

  wgb_shared.form_start('Graduate School Database');
  
  wgb_shared.body_start2('Allocation Form ', NULL,NULL,in_var1,in_var2,cur_user); 
  
  if (in_header <> 0) then
    wgb_shared.disp_header(in_header);
  end if;
  
  open base_data;
  fetch base_data into cur_base;
  close base_data; 
  
  select ref_literal into v_temp from tgrdrefer
  where ref_name = 'academic_school_name'
  and ref_category = 'PWL'
  and ref_code = cur_base.fa_col_code;
  
  if cur_base.fa_max_not_signed = 40 or cur_base.fa_max_not_signed =30 then
  select fas_userseqnum into v_user from TGRDFELLOW_ALLOC_SIG
  where fas_alloc_seqnum     = in_recseqnum
  and   fas_sign_level       = cur_base.fa_max_not_signed;
  end if;
  
  
  if (cur_base.fa_max_not_signed = 40 or cur_base.fa_max_not_signed = 30) and in_var1=v_user then
   htp.print('<script language="javascript" type="text/javascript">
               function funds_string()
               {
              var x = document.getElementsByClassName("in_funds");
              var y = 0;
              document.getElementsByName("in_funds_string")[0].value = "";
              document.getElementsByName("in_felcode_string")[0].value = "";
              for (i=0; i < x.length; i++){
              document.getElementsByName("in_funds_string")[0].value = document.getElementsByName("in_funds_string")[0].value + x[i].value+",";
              document.getElementsByName("in_felcode_string")[0].value = document.getElementsByName("in_felcode_string")[0].value + x[i].id+",";
              y= y +  Number(x[i].value)
              }
              document.getElementById("funds_total").innerHTML = "Funds Requested (" + y + ")"
              }
              </script>');
    end if;         
  
  htp.tableopen(null,null,null,null,'style="width:80%; border-collapse:collapse; border:1px solid black; margin-left:auto; margin-right:auto"');
  htp.tablerowopen;
  htp.tabledata(htf.bold('Academic Year &nbsp; &nbsp; : &nbsp;')||cur_base.fa_ac_year);
  --htp.tabledata(cur_base.fa_ac_year);
  htp.tablerowclose;
  htp.tablerowopen;
  htp.tabledata(htf.bold('College Name &nbsp; &nbsp; &nbsp; : &nbsp;')||v_temp);
  --htp.tabledata(v_temp);
  htp.tablerowclose;
  htp.tableclose;
  htp.nl;
  htp.tableopen(null,null,null,null,'style="width:80%; border-collapse:collapse; border:1px solid black; margin-left:auto; margin-right:auto"');
  htp.tablerowopen(null,null,null,null,'style="border:1px solid black;"');
  htp.tableheader('Fellowship Name','left',null,null,null,null,'style="color:#0000CC;"');

  SELECT SUM(far_fund_amt) into in_funds_total
  FROM TGRDFELLOW_ALLOC_RECORDS
  WHERE FAR_ALLOC_SEQNUM = in_recseqnum
  GROUP BY far_alloc_seqnum; 
  htp.tableheader('Funds Allocated ('||in_funds_total||')','left',null,null,null,null,'style="color:#0000CC;"');
  
  -- for adding requested funds by the GEA Dean
  if cur_base.fa_max_not_signed < 50 and cur_base.fa_max_not_signed = 40 then
  htp.tableheader('<p id=funds_total>Funds Requested ('||in_funds_total||')</p>','left',null,null,null,null,'style="color:#0000CC;"');
  
  elsif cur_base.fa_max_not_signed < 50 then
  
  SELECT SUM(far_requested_amt ) into in_funds_total
  FROM TGRDFELLOW_ALLOC_RECORDS
  WHERE FAR_ALLOC_SEQNUM = in_recseqnum
  GROUP BY far_alloc_seqnum; 
  
  htp.tableheader('Funds Requested('||in_funds_total||')','left',null,null,null,null,'style="color:#0000CC;"');
  
  end if;
  
  -- for adding approved funds by Fellowship Director
  if cur_base.fa_max_not_signed < 40 then
  SELECT SUM(far_requested_amt) into in_funds_total
  FROM TGRDFELLOW_ALLOC_RECORDS
  WHERE FAR_ALLOC_SEQNUM = in_recseqnum
  GROUP BY far_alloc_seqnum; 
  
  htp.tableheader('<p id=funds_appr_total>Funds Approved ('||in_funds_total||')</p>','left',null,null,null,null,'style="color:#0000CC;"');
  
  end if;
  
  htp.tablerowclose;

  for j in records_data
  loop
  in_felcode_string := in_felcode_string || j.far_fel_code || ',';
  
  select fl_felname into v_temp1 from TGRDFELLCD
  where fl_felcode = j.far_fel_code;
  
  htp.tablerowopen;
  htp.tabledata(v_temp1);
  htp.tabledata(to_char(j.far_fund_amt, '$999,999,999'));
  
  if cur_base.fa_max_not_signed = 40 and in_var1=v_user then
  htp.tabledata(htf.formtext(null,10,10,j.far_fund_amt,'onchange="funds_string()" class="in_funds" id='||j.far_fel_code));
  in_funds_string:=in_funds_string||j.far_fund_amt||',';
  elsif cur_base.fa_max_not_signed < 50 then
  htp.tabledata(to_char(j.far_requested_amt, '$999,999,999'));
  end if;
    
  if cur_base.fa_max_not_signed = 30 and in_var1=v_user then
  htp.tabledata(htf.formtext(null,10,10,j.far_requested_amt,'onchange="funds_string()" class="in_funds" id='||j.far_fel_code));
  in_funds_string:=in_funds_string||j.far_requested_amt||',';
  elsif cur_base.fa_max_not_signed < 40 then
  htp.tabledata(to_char(j.far_alloc_amt, '$999,999,999'));
  end if;
  
  htp.tablerowclose;
  end loop;
  htp.tableclose;
  htp.nl;
  
  --Comments Section
  htp.tableopen(null,null,null,null,'style="width:80%; border-collapse:collapse; border:1px solid black; margin-left:auto; margin-right:auto"');
  htp.tablerowopen(null,null,null,null,'style="border:1px solid black;"');
  htp.tableheader('Comments','left',null,null,null,3,'style="color:#0000CC;"');
  htp.tablerowclose;
  htp.tablerowopen(null,null,null,null,'style="border:1px solid black;"');
  htp.tabledata('Date',null,null,null,null,null,'style="width: 10%;"');
  htp.tabledata('User',null,null,null,null,null,'style="width: 20%;"');
  htp.tabledata('Comment',null,null,null,null,null,'style="width: 70%;"');
  --htp.tabledata('Date');
  --htp.tabledata('User');
  --htp.tabledata('Comment');
  htp.tablerowclose;
  for j in com_data
  LOOP
  htp.tablerowopen;
  htp.tabledata(j.fac_date);  
  
  select US_FIRSTNAME||', '||US_LASTNAME into v_username from TWWWUSER1 where US_USERSEQNUM=j.FAC_USERSEQNUM;
  htp.tabledata(v_username); 
  
  htp.tabledata(j.fac_comment);  
  htp.tablerowclose;
  END LOOP;
  htp.tableclose;
  htp.nl;
  
  
  htp.formOpen('www_rgs.wfl_fellowship.proc_alloc_process','POST');
  htp.formhidden('in_var1',in_var1);
  htp.formhidden('in_var2',in_var2);
  htp.formhidden('in_recseqnum',in_recseqnum);
  htp.formhidden('in_signlevel',cur_base.fa_max_not_signed);
  htp.formhidden('in_funds_string',in_funds_string);
  htp.formhidden('in_felcode_string',in_felcode_string);
  
  htp.tableopen(null,null,null,null,'style="width:80%; border-collapse:collapse; margin-left:auto; margin-right:auto"');
  htp.tablerowopen;
  htp.tableheader('Add Comments','left',null,null,null,null,'style="color:#0000CC;"');
  htp.tablerowclose;
  htp.tablerowopen;
  htp.tabledata(htf.formtextarea('in_comment',3,100));
  htp.tablerowclose;
  htp.tablerowopen;
  htp.tabledata(htf.formsubmit('in_action','Add'),'left',null,null,null,null);
  htp.tablerowclose;
  htp.tableclose;
  htp.nl;
  
  htp.tableopen(null,null,null,null,'style="width:80%; background-color:#ffff80; border-collapse:collapse; border:1px solid black; margin-left:auto; margin-right:auto"');
  htp.tablerowopen(null,null,null,null,'style="border:1px solid black;"');
  htp.tableheader('Approval Status','left',null,null,null,4,'style="color:#0000CC;"');
  htp.tablerowclose;

  htp.tablerowopen(null,null,null,null,'style="border:1px solid black;"');
  htp.tableheader('Level', 'left');
  htp.tableheader('Authorization', 'left');
  htp.tableheader('Required Signature', 'left');
  htp.tableheader('Status', 'left');
  htp.tablerowclose;
  
  FOR a in sig_data
  LOOP
  --htp.tablerowopen(null,null,null,null,'style="border:1px solid black;"');
  htp.tablerowopen;
  htp.tabledata(a.FAS_SIGN_LEVEL);
  
  if a.FAS_SIGN_LEVEL = 60 then
  htp.tabledata('Fellowship Assistant');
  elsif (a.FAS_SIGN_LEVEL = 50 or a.FAS_SIGN_LEVEL=30 or  a.FAS_SIGN_LEVEL=10)  then  
  htp.tabledata('Fellowship Director');
  else
  htp.tabledata('GEA Dean');
  end if;
  
  select US_FIRSTNAME||', '||US_LASTNAME into v_username from TWWWUSER1 where US_USERSEQNUM=a.FAS_USERSEQNUM;
  htp.tabledata(v_username);
  
  if a.FAS_SIGN_LEVEL = 60 then
    htp.tabledata('Submitted on '||to_char(a.FAS_SIGN_DATE, 'mm/dd/yyyy hh24:mi:ss'));
  else
   if a.FAS_SIGN_STATUS = 'A' then
        htp.tabledata('Approved on '||to_char(a.FAS_SIGN_DATE, 'mm/dd/yyyy hh24:mi:ss'));
        elsif a.FAS_SIGN_STATUS = 'R' then
        htp.tabledata('Rejected on '||to_char(a.FAS_SIGN_DATE, 'mm/dd/yyyy hh24:mi:ss'));
        else
        if  a.FAS_SIGN_LEVEL = cur_base.fa_max_not_signed  then
        if a.FAS_USERSEQNUM = in_var1  then
        if cur_base.fa_max_not_signed = 40 then
        htp.tabledata(htf.formSubmit('in_action','Approve')||'    '|| htf.formSubmit('in_action','Reject'));
        else
        htp.tabledata(htf.formSubmit('in_action','Approve')||'    '|| htf.formSubmit('in_action','Reject'));
        end if;
        else
        htp.tabledata('Waiting for Signature');
        end if;
        else
        htp.tabledata('Waiting for higher level signatures');
        end if;
        end if;
   end if;     
  
  htp.tablerowclose;      
  END LOOP;
  htp.tableclose;
  
  
  
  htp.formClose;

  htp.bodyClose;
  htp.htmlClose;
 
END disp_alloc_submit_form;

-- Title: disp_alloc_2_submit_form
-- Author: Shanmukesh Vankayala
-- Date: 1/5/2016
-- Description: Displays the second part of the allocation form that are submitted 

procedure disp_alloc_2_submit_form (in_header in number default 0,
                          in_var1 in number default 0,
                          in_var2 in number default 0,
                          in_recseqnum in number default 0) AS
                          
  
  cur_user twwwuser1%rowtype;
  cur_base TGRDFELLOW_ALLOC_BASE%rowtype;
  cur_reg TGRDREG%ROWTYPE;
  v_temp varchar2(100);
  v_temp1 varchar2(100);
  v_user number;
  v_username varchar2(100);
 

   cursor base_data is
   select * from TGRDFELLOW_ALLOC_BASE
   where fa_alloc_seqnum  = in_recseqnum;
   
   cursor records_data is
   select * from TGRDFELLOW_ALLOC_RECORDS
   where far_alloc_seqnum  = in_recseqnum;
   
   
   cursor sig_data is
   select * from TGRDFELLOW_ALLOC_SIG
   where FAS_ALLOC_SEQNUM = in_recseqnum
   and fas_sign_level <=20
   order by FAS_SIGN_LEVEL desc;
   
   cursor stu_data is
   select * from TGRDFELLOW_ALLOC_STUD_REC,tgrdbase, TGRDFELLCD
   where faf_puid = B_PUID
   and faf_fel_code = FL_FELCODE        
   and faf_alloc_seqnum = in_recseqnum  
   order by faf_fel_code,B_NAME;
   
BEGIN

  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;

  wgb_shared.form_start('Graduate School Database');
  
  wgb_shared.body_start2('Allocation Form 2', NULL,NULL,in_var1,in_var2,cur_user); 
  
  if (in_header <> 0) then
    wgb_shared.disp_header(in_header);
  end if;
  
  open base_data;
  fetch base_data into cur_base;
  close base_data; 
  
  select ref_literal into v_temp from tgrdrefer
  where ref_name = 'academic_school_name'
  and ref_category = 'PWL'
  and ref_code = cur_base.fa_col_code;
  
  if cur_base.fa_max_not_signed <= 40 and cur_base.fa_max_not_signed <> 0 then
  select fas_userseqnum into v_user from TGRDFELLOW_ALLOC_SIG
  where fas_alloc_seqnum     = in_recseqnum
  and   fas_sign_level       = cur_base.fa_max_not_signed;
  end if;
  
  htp.tableopen(null,null,null,null,'style="width:80%; border-collapse:collapse; border:1px solid black; margin-left:auto; margin-right:auto"');
  htp.tablerowopen;
  htp.tabledata(htf.bold('Academic Year'));
  htp.tabledata(cur_base.fa_ac_year);
  htp.tablerowclose;
  htp.tablerowopen;
  htp.tabledata(htf.bold('College Name'));
  htp.tabledata(v_temp);
  htp.tablerowclose;
  htp.tableclose;
  htp.tableopen(null,null,null,null,'style="width:80%; border-collapse:collapse; border:1px solid black; margin-left:auto; margin-right:auto"');
  htp.tablerowopen(null,null,null,null,'style="border:1px solid black;"');
  htp.tableheader('Fellowship Name','left',null,null,null,null,'style="color:#0000CC;"');
  htp.tableheader('Funds Allocated','left',null,null,null,null,'style="color:#0000CC;"');
  htp.tablerowclose;

  for j in records_data
  loop
  
  select fl_felname into v_temp1 from TGRDFELLCD
  where fl_felcode = j.far_fel_code;
  
  htp.tablerowopen;
  htp.tabledata(v_temp1);
  htp.tabledata(j.far_alloc_amt);
  htp.tablerowclose;
  end loop;
  htp.tableclose;
  
  htp.tableopen(NULL,NULL,NULL,NULL,'style="width:80%; border-collapse:collapse; border:1px solid black; margin-left:auto; margin-right:auto"');
  htp.tablerowopen(NULL,NULL,NULL,NULL,'style="border:1px solid black;"');
  htp.tableheader('Student List',NULL,NULL,NULL,NULL,5,'style="color:#0000CC;"');
  htp.tablerowclose;
  htp.tablerowopen(NULL,NULL,NULL,NULL,'style="border:1px solid black;"');
  htp.tableheader('PUID','left',NULL,NULL,NULL,NULL,'style="color:#0000CC;"');
  htp.tableheader('Name','left',NULL,NULL,NULL,NULL,'style="color:#0000CC;"');
  htp.tableheader('Department','left',NULL,NULL,NULL,NULL,'style="color:#0000CC;"');
  htp.tableheader('Fellowship','left',NULL,NULL,NULL,NULL,'style="color:#0000CC;"');
  htp.tableheader('Funding Amount','left',NULL,NULL,NULL,NULL,'style="color:#0000CC;"');
  htp.tablerowclose;
  FOR j IN stu_data
  LOOP
    cur_reg         := wps_shared.get_most_recent_registration(j.b_seqnum);
    htp.tablerowopen(NULL,NULL,NULL,NULL,'style="border:1px solid black;"');
    htp.tabledata(j.faf_puid);
    htp.tabledata(j.b_name);
    htp.tabledata(wgb_functions.dept_of(cur_reg.rg_dept, cur_reg.rg_campus));
    htp.tabledata(j.fl_felname);
    htp.tabledata(j.faf_fund_amt);
    htp.tablerowclose;
  END LOOP;
  htp.tableclose;
  
  htp.formOpen('www_rgs.wfl_fellowship.proc_alloc_process','POST');                             
  htp.formhidden('in_var1',in_var1);
  htp.formhidden('in_var2',in_var2);
  htp.formhidden('in_recseqnum',in_recseqnum);
  htp.formhidden('in_signlevel',cur_base.fa_max_not_signed);
  
  htp.tableopen(null,null,null,null,'style="width:80%; background-color:#ffff80; border-collapse:collapse; border:1px solid black; margin-left:auto; margin-right:auto"');
  htp.tablerowopen(null,null,null,null,'style="border:1px solid black;"');
  htp.tableheader('Approval Status','left',null,null,null,4,'style="color:#0000CC;"');
  htp.tablerowclose;
  htp.tablerowopen(null,null,null,null,'style="border:1px solid black;"');
  htp.tableheader('Level', 'left');
  htp.tableheader('Authorization', 'left');
  htp.tableheader('Required Signature', 'left');
  htp.tableheader('Status', 'left');
  htp.tablerowclose;
  
  FOR a in sig_data
  LOOP
  --htp.tablerowopen(null,null,null,null,'style="border:1px solid black;"');
  htp.tablerowopen;
  htp.tabledata(a.FAS_SIGN_LEVEL);
  
  if a.FAS_SIGN_LEVEL = 20 then
  htp.tabledata('GEA Dean');
  elsif a.FAS_SIGN_LEVEL = 10  then  
  htp.tabledata('Fellowship Assistant');
  else
  htp.tabledata('Fellowship Director');
  end if;
  
  select US_FIRSTNAME||', '||US_LASTNAME into v_username from TWWWUSER1 where US_USERSEQNUM=a.FAS_USERSEQNUM;
  htp.tabledata(v_username);
  
IF a.FAS_SIGN_LEVEL = 20 THEN
  htp.tabledata('Submitted on '||TO_CHAR(a.FAS_SIGN_DATE, 'mm/dd/yyyy hh24:mi:ss'));
ELSE
  IF a.FAS_SIGN_STATUS = 'A' THEN
    htp.tabledata('Approved on '||TO_CHAR(a.FAS_SIGN_DATE, 'mm/dd/yyyy hh24:mi:ss'));
  elsif a.FAS_SIGN_STATUS = 'R' THEN
    htp.tabledata('Rejected on '||TO_CHAR(a.FAS_SIGN_DATE, 'mm/dd/yyyy hh24:mi:ss'));
  ELSE
    IF a.FAS_SIGN_LEVEL               = cur_base.fa_max_not_signed THEN
      IF a.FAS_USERSEQNUM             = in_var1 THEN
       
      htp.tabledata(htf.formSubmit('in_action','Approve')||'    '|| htf.formSubmit('in_action','Reject'));
        
      ELSE
        htp.tabledata('Waiting for Signature');
      END IF;
    ELSE
      htp.tabledata('Waiting for higher level signatures');
    END IF;
  END IF;
END IF; 

  htp.tablerowclose;      
  END LOOP;
  htp.tableclose;
  
  
  
  htp.formClose;

  htp.bodyClose;
  htp.htmlClose;
 
END disp_alloc_2_submit_form;

-- Title: proc_alloc_submit_form
-- Author: Shanmukesh Vankayala
-- Date: 1/5/2016
-- Description: Procedure for processing the allocation form data
procedure proc_alloc_submit_form ( in_var1 in number default 0,
                            in_var2 in number default 0,
                            in_acyear in varchar2 default null,
                            in_col_code in varchar2 default null,
                            in_funds_string in varchar2 default null,
                            in_felcode_string in varchar2 default null,
                            in_action in varchar2 default null)
 IS
 
 v_rec_seq number;
 v_temp number;
 v_temp1 number;
 v_temp2 number;
 v_email varchar2(50); 
 x number;
 email_from varchar2(100);
 email_to varchar2(100);
 email_sub varchar2(500);
 email_body varchar2(5000);
 
 CURSOR string_cur
 IS
 select regexp_substr(in_felcode_string,'[^,]+', 1, level) as fel_code,
 regexp_substr(in_funds_string,'[^,]+', 1, level) as funds
 from dual
 connect by regexp_substr(in_felcode_string, '[^,]+', 1, level) is not null;
 
 
 
 BEGIN
 
   if in_action= 'Cancel' then
   owa_util.redirect_url('www_rgs.wfl_fellowship.disp_alloc_form?in_var1='||in_var1||'&in_var2='||in_var2);
   return;
   else
   v_rec_seq := fs_alloc_rec_seq .nextval;
   INSERT INTO TGRDFELLOW_ALLOC_BASE
   (fa_alloc_seqnum,fa_col_code,fa_ac_year,fa_form_status,fa_max_not_signed,fa_create_date,fa_update_date)
   values
   (v_rec_seq,in_col_code,in_acyear,'P',50,systimestamp,null);
   
   for i in string_cur
   LOOP
   INSERT INTO TGRDFELLOW_ALLOC_RECORDS
   (far_alloc_seqnum,far_fel_code,far_fund_amt,far_requested_amt,far_alloc_amt)
   values
   (v_rec_seq,i.fel_code,i.funds,null,null);
   END LOOP;
   
   --Inserting different signature levels into TGRDFELLOW_ALLOC_SIG
   
   --for Fellowship Assistant
   select frmwho_userseqnum into v_temp 
   from tfrmroutewho
   where FRMWHO_JOB ='fl_asst';
   
    INSERT INTO TGRDFELLOW_ALLOC_SIG
   (fas_alloc_seqnum,fas_sign_level,fas_userseqnum,fas_proxy_userseqnum,fas_notf_date,fas_sign_userseqnum,fas_sign_date,fas_sign_status)
   values
   (v_rec_seq,60,v_temp,null,null,null,sysdate,'S');
   
   --for Fellowship Director
   select frmwho_userseqnum into v_temp1 
   from tfrmroutewho
   where FRMWHO_JOB ='fl_dir';
   
   INSERT INTO TGRDFELLOW_ALLOC_SIG
   (fas_alloc_seqnum,fas_sign_level,fas_userseqnum,fas_proxy_userseqnum,fas_notf_date,fas_sign_userseqnum,fas_sign_date,fas_sign_status)
   values
   (v_rec_seq,50,v_temp1,null,null,null,null,null);
   
    INSERT INTO TGRDFELLOW_ALLOC_SIG
   (fas_alloc_seqnum,fas_sign_level,fas_userseqnum,fas_proxy_userseqnum,fas_notf_date,fas_sign_userseqnum,fas_sign_date,fas_sign_status)
   values
   (v_rec_seq,30,v_temp1,null,null,null,null,null);
   
  -- INSERT INTO TGRDFELLOW_ALLOC_SIG
  -- (fas_alloc_seqnum,fas_sign_level,fas_userseqnum,fas_proxy_userseqnum,fas_notf_date,fas_sign_userseqnum,fas_sign_date,fas_sign_status)
  -- values
  -- (v_rec_seq,10,v_temp1,null,null,null,null,null);
   
   --for GEA Dean/Designee
   select frmwho_userseqnum into v_temp2 
   from tfrmroutewho
   where FRMWHO_JOB ='fl_geadean'
   and FRMWHO_DEPT= in_col_code;
   
   INSERT INTO TGRDFELLOW_ALLOC_SIG
   (fas_alloc_seqnum,fas_sign_level,fas_userseqnum,fas_proxy_userseqnum,fas_notf_date,fas_sign_userseqnum,fas_sign_date,fas_sign_status)
   values
   (v_rec_seq,40,v_temp2,null,null,null,null,null);
   
  --INSERT INTO TGRDFELLOW_ALLOC_SIG
  --(fas_alloc_seqnum,fas_sign_level,fas_userseqnum,fas_proxy_userseqnum,fas_notf_date,fas_sign_userseqnum,fas_sign_date,fas_sign_status)
  -- values
  --(v_rec_seq,20,v_temp2,null,null,null,null,null);
   
   
   
   owa_util.redirect_url('www_rgs.wfl_fellowship.disp_alloc_form?in_var1='||in_var1||'&in_var2='||in_var2);
   
    ---Notification email sent to Fellowship Assistant for successful form submission
    select us_email into v_email from twwwuser1
    where us_userseqnum = v_temp;
   
    email_from := 'shanmukesh@purdue.edu' ;
    email_to   := v_email;
    email_sub  := 'FORM 90';
    email_body :='This is to confirm that your Allocation Form submission is successful';
    x := wgb_shared.email_file (email_from,email_to,null,null,email_sub,email_body,null,null,null,null);
    
    
   ---Notification email sent to Fellowship Director that a form is awaiting for review
    select us_email into v_email from twwwuser1
    where us_userseqnum = v_temp1;
    
    email_from := 'shanmukesh@purdue.edu' ;
    email_to   :=  v_email;
    email_sub  := 'FORM 90';
    email_body :='An allocation form is waiting for your review';
    x := wgb_shared.email_file (email_from,email_to,null,null,email_sub,email_body,null,null,null,null);
   end if;

END;


-- Title: proc_award_form_submit
-- Author: Shanmukesh Vankayala
-- Date: 01/05/2016
-- Description: Procedure for processing a submitted form

procedure proc_alloc_form ( in_var1 in number default 0,
                            in_var2 in number default 0,
                            in_action in varchar2 default null)
IS
cur_user twwwuser1%rowtype;
v_temp varchar(100);
v_temp1 number;

--cursor col_names is
--select * from tgrdrefer
--where ref_name = 'academic_school_name'
--and ref_category = 'PWL'
--and ref_code <>'U';

cursor fel_names is
select * from tgrdfellcd
where fl_alloc ='Y'
order by fl_felname;

cursor outstanding_list is
select fa_alloc_seqnum ,fa_ac_year,fa_col_code from TGRDFELLOW_ALLOC_BASE  
where fa_form_status ='P';

BEGIN
   if in_action= 'Exit' then
   owa_util.redirect_url('www_rgs.wfl_fellowship.disp_main_fellow_form?in_var1='||in_var1||'&in_var2='||in_var2);
   return;
   end if;

  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is  null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;
  
  wgb_shared.form_start('Graduate School Database');
  
  if in_action = 'Initiate Form' then
  wgb_shared.body_start2('Create New Allocation Form',null,null, in_var1,in_var2, cur_user);
  else
  wgb_shared.body_start2('Fellowship Award Form',null,null, in_var1,in_var2, cur_user);
  htp.formOpen('www_rgs.wfl_fellowship.proc_award_form_submit','POST');                             
  htp.formhidden('in_var1',in_var1);
  htp.formhidden('in_var2',in_var2);
  htp.formSubmit('in_action','Exit');
  htp.formSubmit('in_action','Outstanding Forms');
  htp.formSubmit('in_action','Approved Forms');
  htp.formSubmit('in_action','Rejected Forms');
  htp.formSubmit('in_action','Submitted Forms');
  htp.formSubmit('in_action','Initiate Form');
  end if;
  
  if in_action = 'Initiate Form' then
    htp.print('<script language="javascript" type="text/javascript">
               function funds_string()
               {
              var x = document.getElementsByClassName("in_funds");
              var y = 0
              document.getElementsByName("in_funds_string")[0].value = "";
              document.getElementsByName("in_felcode_string")[0].value = "";
              for (i=0; i < x.length; i++){
              document.getElementsByName("in_funds_string")[0].value = document.getElementsByName("in_funds_string")[0].value + x[i].value+",";
              document.getElementsByName("in_felcode_string")[0].value = document.getElementsByName("in_felcode_string")[0].value + x[i].id+",";
              y= y +  Number(x[i].value)
              }
              document.getElementById("funds_alloc_total").innerHTML = "Funds Allocated (" + y + ")"
              }
              </script>');
    
  htp.formopen('www_rgs.wfl_fellowship.proc_alloc_submit_form','POST');
  htp.formhidden('in_var1',in_var1);
  htp.formhidden('in_var2',in_var2);
  htp.formhidden('in_funds_string');
  htp.formhidden('in_felcode_string');
    
  htp.tableopen(null,null,null,null,'style="width:80%; border-collapse:collapse; border:1px solid black; margin-left:auto; margin-right:auto"');
  htp.tablerowopen;
  htp.tabledata(htf.bold('Academic Year'));
  htp.tabledata(wps_shared.get_academic_years_selectlist('in_acyear',null,15,to_char(sysdate,'YYYY')-9));
  htp.tablerowclose;
  htp.tablerowopen;
  htp.tabledata(htf.bold('College Name'));
  htp.tabledata(wgb_shared.school_selectlist('in_col_code','PWL','Y'));
  htp.tablerowclose;
  htp.tablerowopen(null,null,null,null,'style="border:1px solid black;"');
  htp.tableheader('Fellowship Name','left',null,null,null,null,'style="color:#0000CC;"');
  htp.tableheader('<p id=funds_alloc_total>Funds Allocated (0)</p>','left',null,null,null,null,'style="color:#0000CC;"');
  htp.tablerowclose;

  
  for j in fel_names
  loop
  htp.tablerowopen;
  htp.tabledata(j.fl_felname);
  htp.tabledata(htf.formtext(null,35,20,null,'onchange="funds_string()" class="in_funds" id='||j.fl_felcode));
  htp.tablerowclose;
  end loop;

  htp.tablerowclose;
  htp.tableclose;
  
  htp.nl;
  htp.tableopen(null,null,null,null,'style="width:81%; margin-left:auto; margin-right:auto"');
  htp.tablerowopen;
  htp.print('<td>');
  htp.formsubmit('in_action','Submit');
  htp.print('&nbsp;&nbsp;');
  htp.formsubmit('in_action','Cancel');
  htp.print('</td>');
  htp.tablerowclose;
  htp.tableclose;  
  htp.formclose;
  
  elsif in_action = 'Outstanding Forms' then
  
  htp.header(3,'Outstanding Forms',null,null,null,'style="color:#0000CC;"');
  htp.tableopen(null,null,null,null,'style="width=90%"');
  htp.tablerowopen;
  htp.tableheader('Form Number');
  htp.tableheader('Academic Year');
  htp.tableheader('College Name');
  htp.tableheader('Total Funds Allocated');
  htp.tableheader('Status');

  htp.tablerowclose;
  for a in outstanding_list
  LOOP
  
  select ref_literal into v_temp from tgrdrefer
  where ref_name = 'academic_school_name'
  and ref_category = 'PWL'
  and ref_code = a.fa_col_code;
  
  select coalesce((select sum(far_fund_amt) from TGRDFELLOW_ALLOC_RECORDS
  where FAR_ALLOC_SEQNUM = a.fa_alloc_seqnum
  group by far_alloc_seqnum),0) into v_temp1 from dual;
  
  htp.tablerowopen;
  htp.tabledata(htf.anchor('www_rgs.wfl_fellowship.disp_alloc_submit_form?in_var1='|| in_var1 || CHR(38) ||
               'in_var2=' || in_var2 ||CHR(38) || 'in_recseqnum=' || a.fa_alloc_seqnum,a.fa_alloc_seqnum));
  htp.tabledata(a.fa_ac_year);
  htp.tabledata(v_temp);
  htp.tabledata(v_temp1); 
  htp.tabledata('Outstanding');
  htp.tablerowclose;
  END LOOP;
  htp.tableclose;
  
  
  end if;
  
  
  
  
  htp.bodyClose;
  htp.htmlClose;
END;

-- Title: proc_add_fellow_form
-- Author: Shanmukesh Vankayala
-- Date: 02/28/2015
-- Description: Procedure for adding a new fellowship

procedure proc_add_fellow_form ( in_var1 in number default 0,
                            in_var2 in number default 0,
                            in_action in varchar2 default null)
IS
cur_user twwwuser1%rowtype;


BEGIN
   if in_action= 'Exit' then
   owa_util.redirect_url('www_rgs.wfl_fellowship.disp_main_fellow_form?in_var1='||in_var1||'&in_var2='||in_var2);
   return;
   end if;

  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is  null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;
  
  wgb_shared.form_start('Graduate School Database');
  
  if in_action = 'Initiate Request' then
  wgb_shared.body_start2('Add new Fellowship',null,null, in_var1,in_var2, cur_user);
  else
  wgb_shared.body_start2('Add new Fellowship',null,null, in_var1,in_var2, cur_user);
  htp.formOpen('www_rgs.wfl_fellowship.proc_award_form','POST');                             
  htp.formhidden('in_var1',in_var1);
  htp.formhidden('in_var2',in_var2);
  htp.formSubmit('in_action','Exit');
  htp.formSubmit('in_action','Outstanding Requests');
  htp.formSubmit('in_action','Approved Requests');
  htp.formSubmit('in_action','Rejected Requests');
  htp.formSubmit('in_action','Submitted Requests');
  htp.formSubmit('in_action','Initiate Request');
  end if;
  
  if in_action = 'Initiate Request' then
    
  htp.formopen('www_rgs.wfl_fellowship.proc_award_create_form','POST');
  htp.formhidden('in_var1',in_var1);
  htp.formhidden('in_var2',in_var2);
  
  htp.tableopen;
  --htp.tablerowopen;
  --htp.tabledata('Code');
  --htp.tabledata(htf.formtext('in_code',10,20,null));
  --htp.tablerowclose;
  htp.tablerowopen;
  htp.tabledata('Name');
  htp.tabledata(htf.formtext('in_name',20,100,null));
  htp.tablerowclose;
  --htp.tablerowopen;
  --htp.tabledata('Current');
  --htp.tabledata(wgb_shared.yesno_list('in_current'));
  --htp.tablerowclose;
  htp.tablerowopen;
  htp.tabledata('Type');
  htp.tabledata(wgb_shared.refer_list('in_feltype',null, 'fellowship_type', 'Y'));
  htp.tablerowclose;
  --htp.tablerowopen;  
  --htp.tabledata('Hold');
  --htp.tabledata(wgb_shared.yesno_list('in_felhold'));
  --htp.tablerowclose;
  htp.tablerowopen;
  htp.tabledata('Duration');
  htp.tabledata(htf.formtext('in_dur',10,20,null));
  htp.tablerowclose;
  htp.tableclose; 
    
  htp.nl;
  htp.formsubmit('in_action','Submit');
  htp.print('&nbsp;&nbsp;');
  htp.formsubmit('in_action','Cancel');
  htp.formclose;
  end if;
  
  htp.bodyClose;
  htp.htmlClose;
END;

-- Title: proc_fellow_process
-- Author: Shanmukesh Vankayala
-- Date: 02/28/2015
-- Description: Procedure for creating a form

procedure proc_fellow_process ( in_var1 in number default 0,
                                in_var2 in number default 0,
                                in_recseqnum in number default 0,
                                in_action in varchar2 default null,
                                in_approve_reject in varchar2 default null)
IS
 cur_user twwwuser1%rowtype;
 cur_stage TGRDFELLOW_STAGE%rowtype;
 x number;
 email_from varchar2(100);
 email_to varchar2(100);
 email_sub varchar2(500);
 email_body varchar2(5000);
 
 cursor stage_data is
 select * from TGRDFELLOW_STAGE
 where FS_RECSEQNUM = in_recseqnum;
 
BEGIN
   if in_action= 'Cancel' then
   owa_util.redirect_url('www_rgs.wfl_fellowship.disp_fellow_form?in_var1='||in_var1||'&in_var2='||in_var2);
   return;
   end if;

  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is  null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;
  
  if in_action = 'Submit Signature' then
  if in_approve_reject = 'P' then
  
  UPDATE TGRDFELLOW_SIG
  SET FSG_SIGN_STATUS = in_approve_reject,
  FSG_SIGN_DATE = systimestamp
  where FSG_RECSEQNUM = in_recseqnum
  and FSG_USERSEQNUM = in_var1
  and FSG_SIGN_LEVEL = 30;
  
  UPDATE TGRDFELLOW_STAGE
  SET FS_MAX_NOT_SIGNED = 0
  where FS_RECSEQNUM = in_recseqnum;
  
  UPDATE TGRDFELLOW_SIG
  SET FSG_NOTF_DATE = systimestamp
  where FSG_RECSEQNUM = in_recseqnum
  and FSG_SIGN_LEVEL = 0;
  
  email_from := 'shanmukesh@purdue.edu' ;
  email_to   := 'shanmukesh@purdue.edu';
  email_sub  := 'FORM 90';
  email_body :='This is to confirm that your FORM 90 signature is successful';
 
 
  x := wgb_shared.email_file (email_from,email_to,null,null,email_sub,email_body,null,null,null,null);
  owa_util.redirect_url('www_rgs.wfl_fellowship.disp_fellow_form?in_var1='||in_var1||'&in_var2='||in_var2);
  
  elsif in_approve_reject = 'A' then
  
  UPDATE TGRDFELLOW_SIG
  SET FSG_SIGN_STATUS = in_approve_reject,
  FSG_SIGN_DATE = systimestamp
  where FSG_RECSEQNUM = in_recseqnum
  and FSG_USERSEQNUM = in_var1
  and FSG_SIGN_LEVEL = 0;
  
  UPDATE TGRDFELLOW_STAGE
  SET FS_MAX_NOT_SIGNED = null,
  FS_FORM_STATUS = 'A'
  where FS_RECSEQNUM = in_recseqnum;
  
  open stage_data;
  fetch stage_data into cur_stage;
  close stage_data;
  
  proc_create_fellowship(in_var1
,in_var2
,cur_stage.FS_SEQNUM
,cur_stage.FS_CODE
,cur_stage.FS_START_SESSION
,cur_stage.FS_START_CALYEAR
,to_char(cur_stage.FS_BEGIN_DATE, 'MM/DD/RR')
,to_char(cur_stage.FS_END_DATE, 'MM/DD/RR')
,cur_stage.FS_DURATION
,cur_stage.FS_AWARD_YEAR
,cur_stage.FS_SPONSOR
,cur_stage.FS_COMMENTS
,cur_stage.FS_BUDGET_SEQNUM
,cur_stage.FS_BUDGET_UNIQUE
,cur_stage.FS_BUDGET_YEAR
,cur_stage.FS_SAP_ACCT_FUND
,cur_stage.FS_SAP_ACCT_INTERNAL_ORDER
,cur_stage.FS_SAP_ACCT_RESP_CC
,cur_stage.FS_GRANT_ACCT
,cur_stage.FS_CALYEAR_1
,cur_stage.FS_SESSION_1
,cur_stage.FS_STATUS_1
,cur_stage.FS_TUIT_1
,cur_stage.FS_ADMIN_ASST_1
,cur_stage.FS_GRAD_APPT_FEE_1
,cur_stage.FS_TECH_FEE_1
,cur_stage.FS_R_AND_R_FEE_1
,cur_stage.FS_INTERNATIONAL_FEE_1
,cur_stage.FS_DIFFERENTIAL_FEE_1
,cur_stage.FS_WELLNESS_FEE_1
,cur_stage.FS_SUPP_1
,cur_stage.FS_SUPP_PAYROLL_AMT_1
,cur_stage.FS_SUPP_OTHER_FUND_ACCT_1
,cur_stage.FS_SUPP_OTHER_FUND_AMT_1
,cur_stage.FS_MED_INSURANCE_1
,cur_stage.FS_MED_AMT_1
,cur_stage.FS_MED_INSURANCE_COMMENT_1
,cur_stage.FS_TOTAL_SPONSOR_STIPEND_1
,cur_stage.FS_SUPP_AMOUNT_1
,cur_stage.FS_FRINGE_BENEFIT_AMOUNT_1
,cur_stage.FS_ANNUAL_STIPEND_1
,cur_stage.FS_MONTHS_STIPEND_1
,cur_stage.FS_MONTHLY_STIPEND_1
,cur_stage.FS_BUDGET_YEAR_1
,cur_stage.FS_PRIN_INVESTIGATOR_1
,cur_stage.FS_TOTAL_AWARD_AMOUNT_1
,cur_stage.FS_CALTERM_1
,cur_stage.FS_REMARKS_1
,cur_stage.FS_CALYEAR_2
,cur_stage.FS_SESSION_2
,cur_stage.FS_STATUS_2
,cur_stage.FS_TUIT_2
,cur_stage.FS_ADMIN_ASST_2
,cur_stage.FS_GRAD_APPT_FEE_2
,cur_stage.FS_TECH_FEE_2
,cur_stage.FS_R_AND_R_FEE_2
,cur_stage.FS_INTERNATIONAL_FEE_2
,cur_stage.FS_DIFFERENTIAL_FEE_2
,cur_stage.FS_WELLNESS_FEE_2
,cur_stage.FS_SUPP_2
,cur_stage.FS_SUPP_PAYROLL_AMT_2
,cur_stage.FS_SUPP_OTHER_FUND_ACCT_2
,cur_stage.FS_SUPP_OTHER_FUND_AMT_2
,cur_stage.FS_MED_INSURANCE_2
,cur_stage.FS_MED_AMT_2
,cur_stage.FS_MED_INSURANCE_COMMENT_2
,cur_stage.FS_TOTAL_SPONSOR_STIPEND_2
,cur_stage.FS_SUPP_AMOUNT_2
,cur_stage.FS_FRINGE_BENEFIT_AMOUNT_2
,cur_stage.FS_ANNUAL_STIPEND_2
,cur_stage.FS_MONTHS_STIPEND_2
,cur_stage.FS_MONTHLY_STIPEND_2
,cur_stage.FS_BUDGET_YEAR_2
,cur_stage.FS_PRIN_INVESTIGATOR_2
,cur_stage.FS_TOTAL_AWARD_AMOUNT_2
,cur_stage.FS_CALTERM_2
,cur_stage.FS_REMARKS_2
,cur_stage.FS_CALYEAR_3
,cur_stage.FS_SESSION_3
,cur_stage.FS_STATUS_3
,cur_stage.FS_TUIT_ONLY_3
,cur_stage.FS_TUIT_AIDCODE_3
,cur_stage.FS_TUIT_CHRG_SCH_3
,cur_stage.FS_TUIT_3
,cur_stage.FS_ADMIN_ASST_3
,cur_stage.FS_GRAD_APPT_FEE_3
,cur_stage.FS_TECH_FEE_3
,cur_stage.FS_R_AND_R_FEE_3
,cur_stage.FS_INTERNATIONAL_FEE_3
,cur_stage.FS_DIFFERENTIAL_FEE_3
,cur_stage.FS_WELLNESS_FEE_3
,cur_stage.FS_SUPP_3
,cur_stage.FS_SUPP_PAYROLL_AMT_3
,cur_stage.FS_SUPP_OTHER_FUND_ACCT_3
,cur_stage.FS_SUPP_OTHER_FUND_AMT_3
,cur_stage.FS_MED_INSURANCE_3
,cur_stage.FS_MED_AMT_3
,cur_stage.FS_MED_INSURANCE_COMMENT_3
,cur_stage.FS_TOTAL_SPONSOR_STIPEND_3
,cur_stage.FS_SUPP_AMOUNT_3
,cur_stage.FS_FRINGE_BENEFIT_AMOUNT_3
,cur_stage.FS_ANNUAL_STIPEND_3
,cur_stage.FS_MONTHS_STIPEND_3
,cur_stage.FS_MONTHLY_STIPEND_3
,cur_stage.FS_BUDGET_YEAR_3
,cur_stage.FS_PRIN_INVESTIGATOR_3
,cur_stage.FS_TOTAL_AWARD_AMOUNT_3
,cur_stage.FS_CALTERM_3
,cur_stage.FS_REMARKS_3
,cur_stage.FS_NEW_FORM
,cur_stage.FS_FORM_BEGIN_DATE
,cur_stage.FS_FORM_END_DATE
,'Create');
  
  end if; 
  end if;
  
  
END; 


-- Title: disp_fellow_form
-- Author: Shanmukesh Vankayala
-- Date: 02/28/2015
-- Description: Displays the initial screen for electronic form 90

procedure disp_fellow_submit_form (in_header in number default 0,
                          in_var1 in number default 0,
                          in_var2 in number default 0,
                          in_recseqnum in number default 0) AS
                          
  --v_init number default 0;
  cur_user twwwuser1%rowtype;
  cur_stage TGRDFELLOW_STAGE%rowtype;
  cur_fel_name TGRDFELLCD.FL_FELNAME%TYPE default null;
  --i number default 1;
  v_username varchar2(100);
 

   cursor stage_data is
   select * from TGRDFELLOW_STAGE
   where FS_RECSEQNUM = in_recseqnum;
   
   cursor sig_data is
   select * from tgrdfellow_sig
   where FSG_RECSEQNUM = in_recseqnum
   order by FSG_SIGN_LEVEL desc;
   
BEGIN

  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;

  wgb_shared.form_start('Graduate School Database');
  
  wgb_shared.body_start2('Form 90: Fellowship ', NULL,NULL,in_var1,in_var2,cur_user); 
  
  /*htp.print('<script>
         function decision_upd()
               {
              var x = document.getElementsByName("in_approve_reject");
              for (i=0; i < x.length; i++){
              if (x[i].checked == true) 
              document.getElementsByName("in_decision_string")[0].value = x[i].value;
               }
               //alert(document.getElementsByName("in_decision_string")[0].value);
                 }
          </script>' );*/       
  
  if (in_header <> 0) then
    wgb_shared.disp_header(in_header);
  end if;
  
  open stage_data;
  fetch stage_data into cur_stage;
  close stage_data; 
  
  select fl_felname into cur_fel_name from TGRDFELLCD
  where fl_felcode=cur_stage.FS_CODE;
  
     --v_init := wef_shared.is_initiator(cur_user.us_userseqnum, '30');
  
      print_student_details(cur_stage.fs_seqnum);
    
      htp.header(3,'Fellowship Details',null,null,null,'style="color:#0000CC;"');
      
      
     
      
      htp.tableopen(null,null,null,null,'style="width=100%"');
      htp.tablerowopen;
      htp.tabledata('Name');
      htp.tabledata(cur_fel_name,null,null,null,null,3);
      htp.tablerowclose;
      htp.tablerowopen;
      htp.tabledata('Award Year');
      htp.tabledata(cur_stage.fs_award_year);
      htp.tabledata('Duration');
      htp.tabledata(cur_stage.fs_duration);
      htp.tablerowclose;
      htp.tablerowopen;
      htp.tabledata('Starting session');
      htp.tabledata(case cur_stage.fs_start_session when 10 then 'Fall' when 20 then 'Spring' when 30 then 'Summer' else 'N/A' end ||'-'||cur_stage.fs_start_calyear);
      htp.tabledata('Sponsor');
      htp.tabledata(cur_stage.fs_sponsor);
      htp.tablerowclose;
      htp.tablerowopen;
      htp.tabledata('Begin Date');
      htp.tabledata(cur_stage.fs_begin_date);
      htp.tabledata('End Date');
      htp.tabledata(cur_stage.fs_end_date);
      htp.tablerowclose;
      htp.tablerowopen;
      htp.tabledata('Comments');
      htp.tabledata(cur_stage.fs_comments,null,null,null,null,3);
      htp.tablerowclose;
      htp.tableclose;
      
      htp.header(3,'Budget Year Account Details',null,null,null,'style="color:#0000CC;"');
      htp.tableopen(null,null,null,null,'width="100%"  border="1"');
      htp.tablerowopen;
      htp.tableheader('Budget Year');
      htp.tableheader('SAP Acct Fund');
      htp.tableheader('SAP Acct Resp Cost Center');       
      htp.tableheader('SAP Acct Internal Order');        
      htp.tableheader('Grant Account');
      htp.tablerowclose;
      htp.tablerowopen(null,null,null,null,'style="background-color:#FF85C2;"');
      htp.tabledata(cur_stage.fs_budget_year);
      htp.tabledata(cur_stage.fs_SAP_ACCT_FUND);
      htp.tabledata(cur_stage.fs_SAP_ACCT_INTERNAL_ORDER);
      htp.tabledata(cur_stage.fs_SAP_ACCT_RESP_CC);
      htp.tabledata(cur_stage.fs_GRANT_ACCT);
      htp.tablerowclose;
      htp.tableclose;
      
      print_sess_details (in_var1,in_var2,cur_stage.FS_CALYEAR_1,cur_stage.FS_SESSION_1,cur_stage.FS_STATUS_1,cur_stage.FS_TUIT_1,
                          cur_stage.FS_ADMIN_ASST_1, cur_stage.FS_GRAD_APPT_FEE_1, cur_stage.FS_TECH_FEE_1, cur_stage.FS_R_AND_R_FEE_1,
                          cur_stage.FS_INTERNATIONAL_FEE_1, cur_stage.FS_DIFFERENTIAL_FEE_1, cur_stage.FS_WELLNESS_FEE_1, cur_stage.FS_SUPP_1, 
                          cur_stage.FS_SUPP_PAYROLL_AMT_1, cur_stage.FS_SUPP_OTHER_FUND_ACCT_1, cur_stage.FS_SUPP_OTHER_FUND_AMT_1, cur_stage.FS_MED_INSURANCE_1, 
                          cur_stage.FS_MED_AMT_1, cur_stage.FS_MED_INSURANCE_COMMENT_1, cur_stage.FS_TOTAL_SPONSOR_STIPEND_1, cur_stage.FS_SUPP_AMOUNT_1, 
                          cur_stage.FS_FRINGE_BENEFIT_AMOUNT_1, cur_stage.FS_ANNUAL_STIPEND_1, cur_stage.FS_MONTHS_STIPEND_1, cur_stage.FS_MONTHLY_STIPEND_1, 
                          cur_stage.FS_BUDGET_YEAR_1, cur_stage.FS_PRIN_INVESTIGATOR_1, cur_stage.FS_TOTAL_AWARD_AMOUNT_1, cur_stage.FS_CALTERM_1, cur_stage.FS_REMARKS_1); 

      print_sess_details (in_var1,in_var2,cur_stage.FS_CALYEAR_2,cur_stage.FS_SESSION_2,cur_stage.FS_STATUS_2,cur_stage.FS_TUIT_2,
                          cur_stage.FS_ADMIN_ASST_2, cur_stage.FS_GRAD_APPT_FEE_2, cur_stage.FS_TECH_FEE_2, cur_stage.FS_R_AND_R_FEE_2,
                          cur_stage.FS_INTERNATIONAL_FEE_2, cur_stage.FS_DIFFERENTIAL_FEE_2, cur_stage.FS_WELLNESS_FEE_2, cur_stage.FS_SUPP_2, 
                          cur_stage.FS_SUPP_PAYROLL_AMT_2, cur_stage.FS_SUPP_OTHER_FUND_ACCT_2, cur_stage.FS_SUPP_OTHER_FUND_AMT_2, cur_stage.FS_MED_INSURANCE_2, 
                          cur_stage.FS_MED_AMT_2, cur_stage.FS_MED_INSURANCE_COMMENT_2, cur_stage.FS_TOTAL_SPONSOR_STIPEND_2, cur_stage.FS_SUPP_AMOUNT_2, 
                          cur_stage.FS_FRINGE_BENEFIT_AMOUNT_2, cur_stage.FS_ANNUAL_STIPEND_2, cur_stage.FS_MONTHS_STIPEND_2, cur_stage.FS_MONTHLY_STIPEND_2, 
                          cur_stage.FS_BUDGET_YEAR_2, cur_stage.FS_PRIN_INVESTIGATOR_2, cur_stage.FS_TOTAL_AWARD_AMOUNT_2, cur_stage.FS_CALTERM_2, cur_stage.FS_REMARKS_2); 
  
     print_sess_details (in_var1,in_var2,cur_stage.FS_CALYEAR_3,cur_stage.FS_SESSION_3,cur_stage.FS_STATUS_3,cur_stage.FS_TUIT_3,
                          cur_stage.FS_ADMIN_ASST_3, cur_stage.FS_GRAD_APPT_FEE_3, cur_stage.FS_TECH_FEE_3, cur_stage.FS_R_AND_R_FEE_3,
                          cur_stage.FS_INTERNATIONAL_FEE_3, cur_stage.FS_DIFFERENTIAL_FEE_3, cur_stage.FS_WELLNESS_FEE_3, cur_stage.FS_SUPP_3, 
                          cur_stage.FS_SUPP_PAYROLL_AMT_3, cur_stage.FS_SUPP_OTHER_FUND_ACCT_3, cur_stage.FS_SUPP_OTHER_FUND_AMT_3, cur_stage.FS_MED_INSURANCE_3, 
                          cur_stage.FS_MED_AMT_3, cur_stage.FS_MED_INSURANCE_COMMENT_3, cur_stage.FS_TOTAL_SPONSOR_STIPEND_3, cur_stage.FS_SUPP_AMOUNT_3, 
                          cur_stage.FS_FRINGE_BENEFIT_AMOUNT_3, cur_stage.FS_ANNUAL_STIPEND_3, cur_stage.FS_MONTHS_STIPEND_3, cur_stage.FS_MONTHLY_STIPEND_3, 
                          cur_stage.FS_BUDGET_YEAR_3, cur_stage.FS_PRIN_INVESTIGATOR_3, cur_stage.FS_TOTAL_AWARD_AMOUNT_3, cur_stage.FS_CALTERM_3, cur_stage.FS_REMARKS_3); 
  
  
  htp.header(3,'Book-keeping',null,null,null,'style="color:#0000CC;"');
  htp.tableopen;
  htp.tablerowopen;
  htp.tabledata('Is this a new form90?&nbsp;&nbsp;&nbsp;&nbsp;'||cur_stage.fs_new_form);
  if cur_stage.fs_new_form ='YES' then
  htp.tabledata('Form Begin Date');
  htp.tabledata(cur_stage.fs_form_begin_date);
  htp.tabledata('Form End Date');
  htp.tabledata(cur_stage.fs_form_end_date);
  end if;
  htp.tablerowclose;
  htp.tableclose;
  
  htp.header(3,'Approval Status',null,null,null,'style="color:#0000CC;"');
  
  htp.formOpen('www_rgs.wfl_fellowship.proc_fellow_process','POST');                             
  htp.formhidden('in_var1',in_var1);
  htp.formhidden('in_var2',in_var2);
  htp.formhidden('in_recseqnum',in_recseqnum);
  --htp.formhidden('in_decision_string');
  
  htp.tableopen(null,null,null,null,'BGCOLOR="#ffff80" cellpadding="2" cellspacing="6" width="100%"' );
  htp.tablerowopen;
  htp.tableheader('Level', 'left');
  htp.tableheader('Authorization', 'left');
  htp.tableheader('Required Signature', 'left');
  htp.tableheader('Status', 'left');
  htp.tablerowclose;
  
  FOR a in sig_data
  LOOP
  htp.tablerowopen;
  htp.tabledata(a.FSG_SIGN_LEVEL);
  
  if a.FSG_SIGN_LEVEL = 40 then
  htp.tabledata('Business Office');
  elsif a.FSG_SIGN_LEVEL = 30 then  
  htp.tabledata('Cost Center');
  else
  htp.tabledata('Graduate School Authorization');
  end if;
  
  select US_FIRSTNAME||', '||US_LASTNAME into v_username from TWWWUSER1 where US_USERSEQNUM=a.FSG_USERSEQNUM;
  htp.tabledata(v_username);
  
  if a.FSG_SIGN_LEVEL = 40 then
    htp.tabledata('Submitted on '||to_char(a.FSG_SIGN_DATE, 'mm/dd/yyyy hh24:mi:ss'));
  elsif a.FSG_SIGN_LEVEL = 30 then 
       if a.FSG_SIGN_STATUS = 'P' then
        htp.tabledata('Processed on '||to_char(a.FSG_SIGN_DATE, 'mm/dd/yyyy hh24:mi:ss'));
        elsif a.FSG_SIGN_STATUS = 'R2' then
        htp.tabledata('Rejected on '||to_char(a.FSG_SIGN_DATE, 'mm/dd/yyyy hh24:mi:ss'));
        else
        if a.FSG_USERSEQNUM = in_var1 then
        htp.tabledata(htf.formradio('in_approve_reject','P','checked','onclick="decision_upd()"')
                      || 'Process  ' ||
                      htf.formradio('in_approve_reject','R2',null,'onclick="decision_upd()"')
                      || 'Reject  '  ||
                      htf.formSubmit('in_action','Submit Signature'));
        else
        htp.tabledata('Waiting for Processing');
        end if;
        end if;
   else
   if a.FSG_SIGN_STATUS = 'A' then
        htp.tabledata('Approved on '||to_char(a.FSG_SIGN_DATE, 'mm/dd/yyyy hh24:mi:ss'));
        elsif a.FSG_SIGN_STATUS = 'R3' then
        htp.tabledata('Rejected on '||to_char(a.FSG_SIGN_DATE, 'mm/dd/yyyy hh24:mi:ss'));
        else
        if  a.FSG_SIGN_LEVEL = cur_stage.FS_max_not_signed  then
        if a.FSG_USERSEQNUM = in_var1  then
        htp.tabledata(htf.formradio('in_approve_reject','A','CHECKED','onclick="decision_upd()"')
                      || 'Approve  ' ||
                      htf.formradio('in_approve_reject','R3',null,'onclick="decision_upd()"')
                      || 'Reject  '  ||
                      htf.formSubmit('in_action','Submit Signature'));
        else
        htp.tabledata('Waiting for Approval');
        end if;
        else
        htp.tabledata('Waiting for higher level signatures');
        end if;
        end if;
   end if;     
  
   
   
  htp.tablerowclose;      
  END LOOP;
  htp.tableclose;
  
  
  
  htp.formClose;  
  htp.bodyClose;
  htp.htmlClose;
 
END disp_fellow_submit_form;


-- Title: disp_main_fellow_form
-- Author: Shanmukesh Vankayala
-- Date: 02/28/2015
-- Description: Displays the initial screen for electronic form 90

procedure disp_main_fellow_form (in_header in number default 0,
                          in_var1 in number default 0,
                          in_var2 in number default 0) AS
                          
  v_init number default 0;
  cur_user twwwuser1%rowtype;
  
            
BEGIN

  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;

  wgb_shared.form_start('Graduate School Database');
  
  wgb_shared.body_start2('Fellowship Forms ', NULL,NULL,in_var1,in_var2,cur_user);                       
                            
  
  if (in_header <> 0) then
    wgb_shared.disp_header(in_header);
  end if;
  
  v_init := wef_shared.is_initiator(cur_user.us_userseqnum, '30');
  
 if (v_init = 1 or cur_user.us_role1 < 15) then
 htp.ulistOpen;
 
 htp.listItem(htf.anchor('wgb_lists.disp_transactions?in_header='|| 0 || CHR(38) ||'in_var1='|| in_var1 || 
                            CHR(38) || 'in_var2=' || in_var2 ,
                            htf.bold('Exit')));
 
 htp.nl;
 htp.nl;
 
 htp.listItem(htf.anchor('www_rgs.wfl_fellowship.disp_alloc_form?in_var1='|| in_var1 || 
                            CHR(38) || 'in_var2=' || in_var2,
                            htf.bold('Allocation Form')));
 
 htp.nl; 
 htp.nl;
 
 htp.listItem(htf.anchor('www_rgs.wfl_fellowship.disp_award_form?in_var1='|| in_var1 || 
                            CHR(38) || 'in_var2=' || in_var2 ,
                            htf.bold('Award Form')));
 
 htp.nl; 
 htp.nl;

 htp.listItem(htf.anchor('www_rgs.wfl_fellowship.disp_fellow_form?in_var1='|| in_var1 || 
                            CHR(38) || 'in_var2=' || in_var2 ,
                            htf.bold('E-form 90'))); 
                            
 htp.nl; 
 htp.nl;

 htp.listItem(htf.anchor('www_rgs.wfl_fellowship.disp_add_fellow_form?in_var1='|| in_var1 || 
                            CHR(38) || 'in_var2=' || in_var2 ,
                            htf.bold('Add a new Fellowship')));                           
                            
htp.ulistClose;     
end if;

  
  htp.bodyClose;
  htp.htmlClose;
 
END disp_main_fellow_form;

-- Title: disp_add_fellow_form
-- Author: Shanmukesh Vankayala
-- Date: 02/28/2015
-- Description: Displays the initial screen for electronic form 90

procedure disp_add_fellow_form (in_header in number default 0,
                          in_var1 in number default 0,
                          in_var2 in number default 0) AS
                          
  v_init number default 0;
  cur_user twwwuser1%rowtype;
  
            
BEGIN

  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;

  wgb_shared.form_start('Graduate School Database');
  
  wgb_shared.body_start2('Add a new Fellowship', NULL,NULL,in_var1,in_var2,cur_user);                       
                            
  htp.formOpen('www_rgs.wfl_fellowship.proc_add_fellow_form','POST');                             
  htp.formhidden('in_var1',in_var1);
  htp.formhidden('in_var2',in_var2);
 
  
  if (in_header <> 0) then
    wgb_shared.disp_header(in_header);
  end if;
  
  v_init := wef_shared.is_initiator(cur_user.us_userseqnum, '30');
  
 if (v_init = 1 or cur_user.us_role1 < 15) then
     htp.formSubmit('in_action','Exit');
     htp.formSubmit('in_action','Outstanding Requests');
     htp.formSubmit('in_action','Approved Requests');
     htp.formSubmit('in_action','Rejected Requests');
     htp.formSubmit('in_action','Submitted Requests');
     htp.formSubmit('in_action','Initiate Request');
end if;

  htp.formClose;  
  htp.bodyClose;
  htp.htmlClose;
 
END disp_add_fellow_form;

-- Title: disp_award_form
-- Author: Shanmukesh Vankayala
-- Date: 02/28/2015
-- Description: Displays the initial screen for electronic form 90

procedure disp_award_form (in_header in number default 0,
                          in_var1 in number default 0,
                          in_var2 in number default 0) AS
                          
  v_init number default 0;
  cur_user twwwuser1%rowtype;
  
            
BEGIN

  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;

  wgb_shared.form_start('Graduate School Database');
  
  wgb_shared.body_start2('Award Form', NULL,NULL,in_var1,in_var2,cur_user);                       
                            
  htp.formOpen('www_rgs.wfl_fellowship.proc_award_form','POST');                             
  htp.formhidden('in_var1',in_var1);
  htp.formhidden('in_var2',in_var2);
 
  
  if (in_header <> 0) then
    wgb_shared.disp_header(in_header);
  end if;
  
  v_init := wef_shared.is_initiator(cur_user.us_userseqnum, '30');
  
 if (v_init = 1 or cur_user.us_role1 < 15) then
     htp.formSubmit('in_action','Exit');
     htp.formSubmit('in_action','Outstanding Forms');
     htp.formSubmit('in_action','Approved Forms');
     htp.formSubmit('in_action','Rejected Forms');
     htp.formSubmit('in_action','Submitted Forms');
     htp.formSubmit('in_action','Initiate Form');
end if;

  htp.formClose;  
  htp.bodyClose;
  htp.htmlClose;
 
END disp_award_form;


-- Title: disp_alloc_form
-- Author: Shanmukesh Vankayala
-- Date: 02/28/2015
-- Description: Displays the initial screen for allocation form

procedure disp_alloc_form (in_header in number default 0,
                          in_var1 in number default 0,
                          in_var2 in number default 0) AS
                          
  v_init number default 0;
  cur_user twwwuser1%rowtype;
  v_temp varchar(100);
  v_temp1 number;
  user_role tfrmroutewho%rowtype;
  cur_alloc_list sys_refcursor;
  v_alloc_list TGRDFELLOW_ALLOC_BASE%rowtype;
  
 
BEGIN

  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;
  
  select * into user_role 
  from tfrmroutewho 
  where FRMWHO_USERSEQNUM = in_var1
  and FRMWHO_JOB in ('fl_dir','fl_asst','fl_geadean');

  wgb_shared.form_start('Graduate School Database');
  
  wgb_shared.body_start2('Allocation Form', NULL,NULL,in_var1,in_var2,cur_user);                       
                            
  htp.formOpen('www_rgs.wfl_fellowship.proc_alloc_form','POST');                             
  htp.formhidden('in_var1',in_var1);
  htp.formhidden('in_var2',in_var2);
 
  
  if (in_header <> 0) then
    wgb_shared.disp_header(in_header);
  end if;
  
  --v_init := wef_shared.is_initiator(cur_user.us_userseqnum, '30');
  
 --if (v_init = 1 or cur_user.us_role1 < 15) then

  htp.tableopen(null,null,null,null,'style="width:81%; margin-left:auto; margin-right:auto"');
  htp.tablerowopen;
  htp.print('<td>');
  htp.formSubmit('in_action','Exit');
  if (user_role.FRMWHO_JOB = 'fl_asst' or user_role.FRMWHO_JOB = 'fl_dir') then 
  htp.print('&nbsp;&nbsp;');
  htp.formSubmit('in_action','Initiate Form');
  end if;
  htp.print('</td>');
  htp.tablerowclose;
  htp.tableclose;  

-- end if;
htp.nl;
htp.nl;

htp.print('<style>
.main_head {
    padding: 8px;
    text-align: left;
    border-bottom: 1px solid #ddd;
    background-color: #0000ff;
    color: white;
}

.main_row {
    padding: 8px;
    text-align: left;
    border-bottom: 1px solid #ddd;
}
.main:hover{background-color:#e6e6e6}

</style>');
    
  
  
  --htp.header(3,'Outstanding Forms',null,null,null,'style="color:#0000CC;"');
  --htp.tableopen(null,null,null,null,'style="width=90%"');
  htp.tableopen(null,null,null,null,'style="width:80%; border-collapse:collapse; border:1px solid #ddd; margin-left:auto; margin-right:auto"');
  htp.tablerowopen(null,null,null,null,'class="main"');
  --htp.tablerowopen(null,null,null,null,'style="border:1px solid black;"');
  htp.tableheader('Form Number','left',null,null,null,null,'class="main_head"');
  htp.tableheader('Academic Year','left',null,null,null,null,'class="main_head"');
  htp.tableheader('College Name','left',null,null,null,null,'class="main_head"');
  htp.tableheader('Total Funds Allocated','left',null,null,null,null,'class="main_head"');
  htp.tableheader('Status','left',null,null,null,null,'class="main_head"');
  htp.tablerowclose;
  
  if (user_role.FRMWHO_JOB = 'fl_geadean') then 
  
  open cur_alloc_list FOR 
  select * from TGRDFELLOW_ALLOC_BASE
  where fa_col_code = user_role.FRMWHO_DEPT
  order by FA_AC_YEAR desc,fa_col_code;
  
  else
  
  open cur_alloc_list FOR
  select * from TGRDFELLOW_ALLOC_BASE
  order by FA_AC_YEAR desc;
  end if;
  
  LOOP
  
  fetch cur_alloc_list into v_alloc_list;
  exit when cur_alloc_list%notfound;
 
  select ref_literal into v_temp from tgrdrefer
  where ref_name = 'academic_school_name'
  and ref_category = 'PWL'
  and ref_code = v_alloc_list.fa_col_code;
  
  select coalesce((select sum(far_fund_amt) from TGRDFELLOW_ALLOC_RECORDS
  where FAR_ALLOC_SEQNUM = v_alloc_list.fa_alloc_seqnum
  group by far_alloc_seqnum),0) into v_temp1 from dual;
 -- v_temp1:=0;
  
  htp.tablerowopen(null,null,null,null,'class="main"');
  htp.tabledata(htf.anchor('www_rgs.wfl_fellowship.disp_alloc_submit_form?in_var1='|| in_var1 || CHR(38) ||
               'in_var2=' || in_var2 ||CHR(38) || 'in_recseqnum=' || v_alloc_list.fa_alloc_seqnum,v_alloc_list.fa_alloc_seqnum),'left',null,null,null,null,'class="main_row"');
  htp.tabledata(v_alloc_list.fa_ac_year,'left',null,null,null,null,'class="main_row"');
  htp.tabledata(substr(v_temp,12),'left',null,null,null,null,'class="main_row"');
  htp.tabledata(to_char(v_temp1,'$999,999,999'),'left',null,null,null,null,'class="main_row"'); 
  htp.tabledata(case when v_alloc_list.fa_form_status='P' then 'Outstanding Allocation Form'
                     when v_alloc_list.fa_form_status='R' then 'Rejected Allocation Form'
                     when v_alloc_list.fa_form_status='A' then 'Approved Allocation Form' || CHR(32) || 
                     htf.anchor('www_rgs.wfl_fellowship.disp_alloc_2_form?in_var1='|| in_var1 || CHR(38) ||
                     'in_var2=' || in_var2 ||CHR(38) || 'in_recseqnum=' || v_alloc_list.fa_alloc_seqnum, 'Add Recipients')
                     when v_alloc_list.fa_form_status='P1' then 'Outstanding Recipients Form' || CHR(32) || 
                     htf.anchor('www_rgs.wfl_fellowship.disp_alloc_2_submit_form?in_var1='|| in_var1 || CHR(38) ||
                     'in_var2=' || in_var2 ||CHR(38) || 'in_recseqnum=' || v_alloc_list.fa_alloc_seqnum, 'View Recipients Form')
                     when v_alloc_list.fa_form_status='R1' then 'Rejected Recipients Form' || CHR(32) || 
                     htf.anchor('www_rgs.wfl_fellowship.disp_alloc_2_submit_form?in_var1='|| in_var1 || CHR(38) ||
                     'in_var2=' || in_var2 ||CHR(38) || 'in_recseqnum=' || v_alloc_list.fa_alloc_seqnum, 'View Recipients Form')
                     when v_alloc_list.fa_form_status='A1' then 'Approved Recipients Form' || CHR(32) || 
                     htf.anchor('www_rgs.wfl_fellowship.disp_alloc_2_submit_form?in_var1='|| in_var1 || CHR(38) ||
                     'in_var2=' || in_var2 ||CHR(38) || 'in_recseqnum=' || v_alloc_list.fa_alloc_seqnum, 'View Recipients Form')
                END,'left',null,null,null,null,'class="main_row"' );
  htp.tablerowclose;
  END LOOP;
  close cur_alloc_list;
  htp.tableclose;
  
  
  htp.formClose;  
  htp.bodyClose;
  htp.htmlClose;
 
END disp_alloc_form;




 
-- Title: disp_fellow_form
-- Author: Shanmukesh Vankayala
-- Date: 02/28/2015
-- Description: Displays the initial screen for electronic form 90

procedure disp_fellow_form (in_header in number default 0,
                          in_var1 in number default 0,
                          in_var2 in number default 0) AS
                          
  v_init number default 0;
  cur_user twwwuser1%rowtype;
  
            
BEGIN

  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;

  wgb_shared.form_start('Graduate School Database');
  
  wgb_shared.body_start2('Fellowship Form 90 ', NULL,NULL,in_var1,in_var2,cur_user);                       
                            
  htp.formOpen('www_rgs.wfl_fellowship.proc_fellow_form','POST');                             
  htp.formhidden('in_var1',in_var1);
  htp.formhidden('in_var2',in_var2);
 
  
  if (in_header <> 0) then
    wgb_shared.disp_header(in_header);
  end if;
  
  v_init := wef_shared.is_initiator(cur_user.us_userseqnum, '30');
  
 if (v_init = 1 or cur_user.us_role1 < 15) then
     htp.formSubmit('in_action','Exit');
     htp.formSubmit('in_action','Outstanding Forms');
     htp.formSubmit('in_action','Approved Forms');
     htp.formSubmit('in_action','Rejected Forms');
     htp.formSubmit('in_action','Submitted Forms');
     htp.formSubmit('in_action','Initiate Form');
end if;

  htp.formClose;  
  htp.bodyClose;
  htp.htmlClose;
 
END disp_fellow_form;


/* 
--Commented out 05/05/2013 : Migrating to production. This procedure will not be used.
procedure disp_new_view(in_var1 number default 0,
                        in_var2 number default 0,
                        in_seqnum number default 0)
as
cur_user twwwuser1%rowtype;
cur_base tgrdbase%rowtype;
v_update_base_authority boolean default false;
v_update_appl_authority boolean default false;

cursor base_data is
select * from tgrdbase
where b_seqnum=in_seqnum;

begin
  --insert into cand_audit_log values (in_var1||','||in_var2||','||in_seqnum, systimestamp);
  cur_user := (wgb_shared.validate_state(in_var1, in_var2));
  if cur_user.us_userseqnum is  null then
    wpu_intra.pu_dispauth(1000);
    return;
  end if;
  open base_data;
  fetch base_data into cur_base;
  if (base_data%notfound) then
    close base_data;
    wgb_lists.disp_qry_appl(1015 , in_var1, in_var2, cur_base.b_puid, cur_base.b_sid,
                          null, null, null, null,
                          null, null, null, null,
                          null);
    return;
  end if;
  close base_data;
  v_update_base_authority := FALSE;
  if cur_user.us_role1 < 15 then
    v_update_base_authority := TRUE;
    -- IF GS STAFF PERSON HAS UPDATE APPL AUTHORITY MEANS CAN VIEW APPLICANT USER ID AND PASSWORD
    -- AND CAN UPDATE APPLICATION
    IF wgb_functions.mask_and(cur_user.us_updflags,wgb_constants.constant_updflag_appl,8)=wgb_constants.constant_updflag_appl  THEN
      v_update_appl_authority := TRUE;
    END IF;
  end if;
  wgb_shared.form_start('Graduate School Intranet Database');
  -- insert body tags and toolbar
  wgb_shared.body_start2('Individual Information Folder',null,null, in_var1,in_var2, cur_user);
  
  --Add javascript calls
  wgb_shared.print_java_date();
  print_java_areyousure();
  IF cur_user.us_role1< 15 THEN
    -- will only need these java scripts if update is possible
    wgb_shared.print_java_numeric;
    wgb_shared.print_java_date;
  END IF;
  htp.tableopen('border=0 cellpadding=0 cellspacing=4  bgColor="#FFFFCC" width="100%"');
  wgb_dispstd.print_tabs(in_var1,in_var2,in_seqnum);
  htp.tablerowopen;
  htp.print('<TD COLSPAN="9" NOWRAP>');
    print_grad_general(in_var1,in_var2,in_seqnum,6,null);
  htp.print('</TD>');
  htp.tablerowclose;
  htp.tableclose;
  
  htp.div(null,'style="background-color:#FFFFCC"');
    print_funding(in_var1,in_var2,in_seqnum);
    htp.nl;
    htp.nl;
    print_funding_summary(in_var1,in_var2,in_seqnum);
  htp.print('</div>');
  htp.bodyClose;
  htp.htmlClose;

end;
*/

end;

/
