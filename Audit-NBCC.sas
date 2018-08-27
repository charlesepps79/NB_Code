data _null_;
	*** BranchNumber, Checknumber, SS7 as string, amt_id as # ---- ***;
	call symput("lastcamp",
		"WORK.'114538A_RMC_NB_7.1_Final_Mailfil'n");
	*** BranchNumber, Checknumber, SS7 as string, amt_id as # ---- ***;
	call symput("auditnbcc",
		"WORK.'114539A_RMC_NB_7.2_Final_Mailfil'n");
	call symput("auditfile",
		"\\mktg-app01\E\Production\Audits\NBCC AUDIT - 7.2 - Final Mail File.xlsx");
run;

/*
data lastcamp;
set &lastcamp;
filecode_priorcampaign=filecode;
ownbr=branchnumber;
ss7ownbr=cats(ss7,ownbr);
name_priorcampaign=name;
street_priorcampaign=street;
hhseqnumber_priorcampaign=hhseqnumber;
checknumber_priorcampaign=checknumber;
drop filecode name ss7 street HHSeqNumber checknumber BranchNumber ownbr ;
run;
*/

data auditnbcc;
set &auditnbcc;
run;

/*
data check;
set auditnbcc;
ss7ownbr=cats(ss7,branchnumber);
run;
proc sort data=check;
by ss7ownbr;
run;
proc sort data=lastcamp;
by ss7ownbr;
run;
data dups;
merge check(in=x) lastcamp(in=y);
by ss7ownbr;
if x and y;
keep checknumber checknumber_priorcampaign name name_priorcampaign street street_priorcampaign hhseqnumber hhseqnumber_priorcampaign filecode filecode_priorcampaign;
run;
*/

data short1;
set rmcath.mailfile_short_2015 (keep=CheckNumber);
where CheckNumber not in("",".");
run;
data short2;
set rmcath.mailfile_short_2016 (keep=CheckNumber);
where CheckNumber not in("",".");
run;
data short3;
set rmcath.mailfile_short_2017 (keep=CheckNumber);
where CheckNumber not in("",".");
run;

data short;
set short1 short2 short3;
run;
proc sort data=short;
by checknumber;
run;
proc sort data=auditnbcc;
by checknumber;
run;

data dupchecknum;
merge short(in=x) auditnbcc(in=y);
by checknumber;
if x and y;
keep checknumber;
run;



data snip;
set auditnbcc (obs=4);
run;

data checkinfo1;
infile datalines delimiter=",";
input  check_routing_number_x state $ acctnum_x;
datalines;
53101561, AL, 8018011620,
53101561, GA, 8018012941,
53101561, NC, 2079900553369,
53101561, NM, 8018011588,
53101561, OK, 8018011604,
53101561, SC, 2079900585175,
53101561, TN, 2079900552962,
53101561, TX, 2079900585188,
53101561, VA, 8018017353,
;
run;
proc sort data=checkinfo1;
by state;
run;
proc sort data=auditnbcc;
by state;
run;

data auditnbcc;
merge auditnbcc checkinfo1;
by state;
run;

data auditnbcc;
set auditnbcc;
if acctnum_x=acctnum then AcctNum_Error=0;
else acctnum_error=1;
if check_routing_number_x=check_routing_number then RoutingNum_Error=0;
else RoutingNum_Error=1;
if equ_dob = "" then EQDOB=0;
else EQDOB=1;
if tu_birth_date="" then TUDOB=0;
else TUDOB=1;
run;

data po;
set auditnbcc;
if adr1 =: "PO";
run;

data name;
set auditnbcc;
if length(fname) = 1;
run;

proc import datafile="\\mktg-app01\E\Production\Master Files and Instructions\AMTID Master.xlsx" dbms=excel out=amtids replace;
run;
proc print data=amtids;
run;
data amtids2;
set amtids;
keep state Amtid offer_amount 'fico range'n MinFICO MaxFICO 'Payment Amount'n Term;
MinFICO=input(substr('fico range'n,1,3),3.);
MaxFICO=input(substr('fico range'n,5,3),3.);
run;
data amtids3;
set amtids2;
if amtid ne .;
rename amtid=amt_id;
run;
proc sort data=amtids3;
by state amt_id;
run;
proc sort data=auditnbcc;
by state amt_id;
run;
data auditnbcc;
merge auditnbcc(in=x) amtids3;
by state amt_id;
if x;
run;

data auditnbcc;
set auditnbcc;
if offer_amount ne checkamount then amt_id_error=1;
if 'Payment Amount'n ne pmt_amt_1 then amt_id_error=1;
if term ne num_pmt_1 then amt_id_error = 1;
else amt_id_error=0;
run;


*Check Branch Info;
data audit2nbcc;
set auditnbcc;
keep BranchNumber BranchStreetAddress BranchCity BranchState BranchZip BranchPhone;
run;
proc sort data=audit2nbcc nodupkey;
by BranchNumber BranchStreetAddress BranchCity BranchState BranchZip BranchPhone;
run;
data branchinfo;
set rmcath.branchinfo;
branchnumber=branchnumber_txt;
run;
proc sort data=branchinfo;
by branchnumber;
run;
data branchInfo_Check;
merge branchinfo audit2nbcc(in=x);
by branchnumber;
if x;
run;
data branchinfo_check2;
set branchinfo_check;
if Branchstreetaddress ne StreetAddress then Br_Info_Mismatch=1;
if Branchcity ne city then Br_Info_Mismatch=1;
if branchstate ne state then br_info_mismath=1;
if branchzip ne zip_full then br_info_mismatch=1;
if branchphone ne phone then br_info_mismatch=1;
if br_info_mismatch=1;
drop BranchNumber_txt;
rename BranchNumber_number=Branch;
run;

proc tabulate data=auditnbcc;
class amt_id amt_id_error state;
tables amt_id,state;
where amt_id_error=1;
run;



ods excel file="&auditfile" options(sheet_name="Data Snippet" sheet_interval="none");
proc summary data=auditnbcc print;run;
proc print data=snip;
run;


ods excel options(sheet_interval='table');                         
ods select none; data _null_; dcl odsout obj(); run; ods select all;
ods excel options(sheet_name="Credit Score Info" sheet_interval="none" );
proc means data=auditnbcc n min max maxdec=0;
var fico Vantage;
run;
proc tabulate data=auditnbcc;
class filecode;
var equ_BNI_SCORE tu_score_Attribute;
tables filecode all, n equ_BNI_SCORE*min*f=5.0 equ_BNI_SCORE*max*f=5.0 tu_score_Attribute*min*f=5.0 tu_score_Attribute*max*f=5.0;
run;

ods excel options(sheet_interval='table');                         
ods select none; data _null_; dcl odsout obj(); run; ods select all;
ods excel options(sheet_name="StateAndCompany Checks" sheet_interval="NONE");
proc tabulate data=auditnbcc;
class state branchstate;
tables state, branchstate;
run;
proc tabulate data=auditnbcc;
class state BranchCompany;
tables state,branchcompany;
run;
proc freq data=auditnbcc;
table state/nocum nopercent;
run;
proc tabulate data=auditnbcc;
class state county BranchNumber;
tables state*county*branchnumber,n;
run;

ods excel options(sheet_interval='table');                         
ods select none; data _null_; dcl odsout obj(); run; ods select all;
ods excel options(sheet_name="Offer Amount by CreditSc" sheet_interval="none");
proc tabulate data=auditnbcc;
class lettercd state CheckAmount;
var fico tu_variable7 equ_attribute_9 equ_NumOpenMortAccts tu_scrfi01 tu_mtn001;
tables lettercd*state*checkamount,n fico*min*f=5.0 fico*max*f=5.0 tu_variable7*min*f=5.0 tu_variable7*max*f=5.0 equ_attribute_9*min*f=5.0 equ_ATTRIBUTE_9*max*f=5.0 equ_NumOpenMortAccts*min*f=5.0 equ_NumOpenMortAccts*max*f=5.0 tu_scrfi01*min*f=5.0 tu_scrfi01*max*f=5.0 tu_mtn001*min*f=5.0 tu_mtn001*max*f=5.0;
run;

ods excel options(sheet_interval='table');                         
ods select none; data _null_; dcl odsout obj(); run; ods select all;
ods excel options(sheet_name="Campaign Info" sheet_interval="none");
proc freq data=auditnbcc;
tables Drop_Date Closed_Date/nocum nopercent;
run;
proc tabulate data=auditnbcc;
class state amt_id CheckAmount offer_amount;
var fico MinFICO MaxFICO;
tables state*amt_id*CheckAmount*offer_amount, MinFICO*min*f=5.0 fico*Min*f=5.0 MaxFICO*max*f=5.0 fico*Max*f=5.0;
run;
proc tabulate data=auditnbcc;
class CheckAmount_SpelledOut;
var CheckAmount;
tables CheckAmount_SpelledOut,CheckAmount*mean*f=dollar10.2;
run;
proc tabulate data=auditnbcc;
class AcctNum_Error RoutingNum_Error amt_id_error;
tables AcctNum_Error RoutingNum_Error amt_id_error;
run;
proc tabulate data=auditnbcc;
class node_code;
var fico equ_attribute_7 tu_variable10 equ_ATTRIBUTE_9 tu_variable7;
tables node_code, n fico*Min*f=5.0 fico*max*f=5.0 equ_ATTRIBUTE_7*min*f=5.0 equ_attribute_7*max*f=5.0 tu_Variable10*min*f=5.0 tu_variable10*max*f=5.0 equ_ATTRIBUTE_9*min*f=5.0 equ_attribute_9*max*f=5.0 tu_variable7*min*f=5.0 tu_variable7*max*f=5.0;
label equ_attribute_7=CollEQX tu_variable10=CollTU equ_attribute_9=OpenEQX tu_variable7=OpenTU;
run;
proc tabulate data=auditnbcc;
class filecode;
var tudob eqdob;
tables filecode, tudob eqdob;
run;

proc tabulate data=auditnbcc;
class lettercd;
tables lettercd all, n;
run;

proc tabulate data=auditnbcc;
class amt_id;
tables amt_id, n;
run;
/*
proc tabulate data=auditnbcc;
class state control_test_flag;
tables state,control_test_flag;
run;
*/

proc tabulate data=auditnbcc;
class state batch;
tables state,batch;
run;

proc tabulate data=auditnbcc;
class state lco;
tables state,lco;
run;
ods excel options(sheet_interval='table');                         
ods select none; data _null_; dcl odsout obj(); run; ods select all;
ods excel options(sheet_name="FNAME and MNAME check" sheet_interval="none");
proc print data=name;
run;
ods excel options(sheet_interval='table');                         
ods select none; data _null_; dcl odsout obj(); run; ods select all;
ods excel options(sheet_name="Dupe Check" sheet_interval="none");
/*
proc print data=dups;
run;
*/
proc print data=po;
run;


ods excel options(sheet_interval='table');                         
ods select none; data _null_; dcl odsout obj(); run; ods select all;
ods excel options(sheet_name="Branch Info Check" sheet_interval="none");
proc print data=branchinfo_check2 noobs;
run;
ods excel close;

/*
proc sort data=auditnbcc;
by state;
run;
proc tabulate data=auditnbcc;
class amt_id state;
tables amt_id, state;
by state;
run;
*/