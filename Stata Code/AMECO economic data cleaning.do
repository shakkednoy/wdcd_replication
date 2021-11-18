/* This file cleans the AMECO datasets and prepares a dataset at the country-year
level with information on wage growth, the labor share, TFP growth, net capital formation,
and GDP per capita growth.

Input files: AMECOnum.txt, reforms_new_ameco.dta
Intermediate Stata Data files created: ameco_variables.dta
Output files created: none */


#delimit;
set more off;
clear all;

local graphopts "graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))";

* reading in the datasets;
forvalues n = 1/18 {;
	import delimited "${rawfolder}/AMECO`n'.txt", clear delimiters(";");
	* delimiters(";");
	
	save ameco`n'_raw, replace;
};


************************* cleaning the relevant datasets ***********************;

*** population;
use ameco1_raw, clear;

* keeping the relevant variable;
keep if (v3=="01 Population" & v4=="Total population (National accounts) ") | _n==1;

* renaming variables;
rename v2 country;

forvalues n = 6/67 {;
	local name = v`n'[1];
	rename v`n' v`name';
};

drop v1 v3 v4 v5 v68;
drop if _n==1;

* reshaping to a country-year data structure;
reshape long v, i(country) j(year);

rename v population;

destring population, replace force;

* converting the 'population in thousands' variable to total population;
replace population = population*1000;

* keeping the relevant countries;
keep if inlist(country,"Austria","Belgium","Denmark","Finland","France",
	"Ireland") | inlist(country,"Iceland","Italy","Netherlands","Norway",
	"Sweden","Switzerland","United Kingdom","West Germany")
	| inlist(country,"United States","Canada","Australia","New Zealand");
replace country = "Germany" if country=="West Germany";

* merging on list of reforms;
merge m:1 country using reforms_new_ameco, keep(master match) nogen;

* duplicating the countries that have two reform-years;
expand 2;
sort country year;
capture drop dup;
quietly by country year: gen dup = cond(_N==1,0,_n);
drop if dup>1 & reformyear2==.;

gen reformyear = reformyear1;
foreach country in Finland Norway {;
	replace reformyear = reformyear2 if country=="`country'" & dup==2;
	replace country = "`country'1" if country=="`country'" & dup==1;
	replace country = "`country'2" if country=="`country'" & dup==2;
};

* generating treated dummy;
gen treated = reformyear!=.;
egen countrygroup = group(country);

save ameco_pop_wid, replace;

drop if inlist(country,"United States","Canada","Australia","New Zealand");

save ameco_pop, replace;


*** unemployment;

use ameco1_raw, clear;

* keeping the relevant variable;
keep if (v3=="03 Unemployment" & v4=="Unemployment rate: total :- Member States: definition EUROSTAT ") | _n==1;

* renaming variables;
rename v2 country;

forvalues n = 6/67 {;
	local name = v`n'[1];
	rename v`n' v`name';
};

drop v1 v3 v4 v5 v68;
drop if _n==1;

* reshaping to a country-year data structure;
reshape long v, i(country) j(year);

rename v unemp_rate;

destring unemp_rate, replace force;


* keeping the relevant countries;
keep if inlist(country,"Austria","Belgium","Denmark","Finland","France",
	"Ireland") | inlist(country,"Iceland","Italy","Netherlands","Norway",
	"Sweden","Switzerland","United Kingdom","West Germany")
	| inlist(country,"United States","Canada","Australia","New Zealand");
replace country = "Germany" if country=="West Germany";

save science_unemp, replace;


*** GDP;
use ameco6_raw, clear;

keep if (v3=="01 Gross domestic product" & v4=="Gross domestic product at 2015 reference levels ") | _n==1;

rename v2 country;

forvalues n = 6/67 {;
	local name = v`n'[1];
	rename v`n' v`name';
};

drop v1 v3 v4 v5 v68;
drop if _n==1;

keep if inlist(country,"Austria","Belgium","Denmark","Finland","France",
	"Ireland") | inlist(country,"Iceland","Italy","Netherlands","Norway",
	"Sweden","Switzerland","United Kingdom","West Germany") | 
	inlist(country,"United States","Canada","Australia","New Zealand"); 

reshape long v, i(country) j(year);

rename v gdp;

destring gdp, replace force;

replace country = "Germany" if country=="West Germany";

merge m:1 country using reforms_new_ameco, keep(master match) nogen;

expand 2;
sort country year;
capture drop dup;
quietly by country year: gen dup = cond(_N==1,0,_n);
drop if dup>1 & reformyear2==.;

gen reformyear = reformyear1;
foreach country in Finland Norway {;
	replace reformyear = reformyear2 if country=="`country'" & dup==2;
	replace country = "`country'1" if country=="`country'" & dup==1;
	replace country = "`country'2" if country=="`country'" & dup==2;
};


gen treated = reformyear!=.;
egen countrygroup = group(country);



save ameco_gdp_raw, replace;

* converting to 'growth in GDP per capita';

* merging on population;
merge 1:1 country year using ameco_pop_wid, keepusing(population) keep(master match) nogen;


* GDP per working population (i.e. productivity);
foreach country in Austria Belgium Denmark Finland1 Finland2 France Germany
	Iceland Ireland Italy Netherlands Norway1 Norway2 Sweden Switzerland UK {;
	
	merge m:1 country year using `country'_workingpop, update keep(master match match_update) nogen;
		
	
};
	
* filling in missing values of working population;
gen ratio = pop/population;
foreach country in "Austria" "Belgium" "Denmark" "Finland1" "Finland2" "France" "Germany"
	"Iceland" "Ireland" "Italy" "Netherlands" "Norway1" "Norway2" "Sweden" "Switzerland" "United Kingdom" {;
		
	quietly su `ratio' if country=="`country'";
	replace pop = population*r(mean) if pop==. & country=="`country'";
		
};
		
		
gen productivity = gdp/pop;
gen ln_productivity = ln(productivity);
drop pop ratio;


* calculating GDP per capita;
replace gdp = gdp/population;

* calculating GDP per capita growth;
sort country year;
gen growth = 100*((gdp-gdp[_n-1])/gdp[_n-1]);
replace growth = . if country!=country[_n-1];
rename growth gdp_growth;

save ameco_gdp_wid, replace;
drop if inlist(country,"United States","Canada","Australia","New Zealand");

save ameco_gdp, replace;

*** labor share;
use ameco7_raw, clear;

keep if (v3=="06 Adjusted wage share" & v4=="Adjusted wage share: total economy: as percentage of GDP at current prices (Compensation per employee as percentage of GDP at market prices per person employed.)") 
	| _n==1;

rename v2 country;

forvalues n = 6/67 {;
	local name = v`n'[1];
	rename v`n' v`name';
};

drop v1 v3 v4 v5 v68;
drop if _n==1;

reshape long v, i(country) j(year);

rename v laborshare;

replace laborshare = "." if laborshare=="NA" | laborshare=="NA                                                   "
	| laborshare=="NA                                                      "
	| laborshare=="NA                                                                                                                                                                                                                                                                  "
	| laborshare=="NA                                                                                                                                       "
	| laborshare=="NA                                                                                                                                                                                                                                                                                                                                              "
	| laborshare=="NA                                                                                                                                                                                                                                                                 "
	| laborshare=="NA                                                                                                                                                                                                                                                                                        "
	;
destring laborshare, replace force;

* keeping the relevant countries;
keep if inlist(country,"Austria","Belgium","Denmark","Finland","France",
	"Ireland") | inlist(country,"Iceland","Italy","Netherlands","Norway",
	"Sweden","Switzerland","United Kingdom","West Germany") |
	inlist(country,"United States","Canada","Australia","New Zealand");

replace country = "Germany" if country=="West Germany";

merge m:1 country using reforms_new_ameco, keep(master match) nogen;

expand 2;
sort country year;
capture drop dup;
quietly by country year: gen dup = cond(_N==1,0,_n);
drop if dup>1 & reformyear2==.;

gen reformyear = reformyear1;
foreach country in Finland Norway {;
	replace reformyear = reformyear2 if country=="`country'" & dup==2;
	replace country = "`country'1" if country=="`country'" & dup==1;
	replace country = "`country'2" if country=="`country'" & dup==2;
};


gen treated = reformyear!=.;
egen countrygroup = group(country);

save ameco_laborshare_wid, replace;

drop if inlist(country,"United States","Canada","Australia","New Zealand");

save ameco_laborshare, replace;

*** real wage growth;
use ameco7_raw, clear;

keep if (v3=="05 Real compensation per employee, total economy" & v4=="Real compensation per employee, deflator GDP: total economy ") 
	| _n==1;

rename v2 country;

forvalues n = 6/67 {;
	local name = v`n'[1];
	rename v`n' v`name';
};

drop v1 v3 v4 v5 v68;
drop if _n==1;

* removing quotation marks from some countries;
replace country = subinstr(country, `"""',  "", .);

* keeping the relevant countries;
keep if inlist(country,"Austria","Belgium","Denmark","Finland","France",
	"Ireland") | inlist(country,"Iceland","Italy","Netherlands","Norway",
	"Sweden","Switzerland","United Kingdom","Germany (linked)")
	| inlist(country,"United States","Canada","Australia","New Zealand");
	
replace country = "Germany" if country=="Germany (linked)";

reshape long v, i(country) j(year);

rename v wages;

destring wages, force replace;


* calculating wage growth;
gen wagegrowth = 100*((wages-wages[_n-1])/wages[_n-1]);
replace wagegrowth = . if country!=country[_n-1];




merge m:1 country using reforms_new_ameco, keep(master match) nogen;

expand 2;
sort country year;
capture drop dup;
quietly by country year: gen dup = cond(_N==1,0,_n);
drop if dup>1 & reformyear2==.;

gen reformyear = reformyear1;
foreach country in Finland Norway {;
	replace reformyear = reformyear2 if country=="`country'" & dup==2;
	replace country = "`country'1" if country=="`country'" & dup==1;
	replace country = "`country'2" if country=="`country'" & dup==2;
};


gen treated = reformyear!=.;
egen countrygroup = group(country);

save ameco_wagegrowth_wid, replace;

drop if inlist(country,"United States","Canada","Australia","New Zealand");

save ameco_wagegrowth, replace;

*** capital formation;
use ameco3_raw, clear;

keep if (v3=="03 Net fixed capital formation, total economy" & v4=="Net fixed capital formation at current prices: total economy "
	& v5=="(Mrd PPS) ") | _n==1;
	
rename v2 country;

forvalues n = 6/67 {;
	local name = v`n'[1];
	rename v`n' v`name';
};

drop v1 v3 v4 v5 v68;
drop if _n==1;

reshape long v, i(country) j(year);

rename v netcapital;

replace netcapital = "." if netcapital=="NA"
	| netcapital=="NA                                                                                                                                                                                                                                                                                                    "
	| netcapital=="NA                                                                                                                                                                                                                                                                                                                                                                                "
	| netcapital=="NA                                                                                                                                                                                                                                                                                                                                                               "
	| netcapital=="NA                                                                                                                                                                                                                                                                                                                                     "
	| netcapital=="NA                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    "
	| netcapital=="NA                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            "
	| netcapital=="NA                                                                                                                                                                                                                                                                                                                                                                                                                                                                          "
	;

destring netcapital, replace force;
	
keep if inlist(country,"Austria","Belgium","Denmark","Finland","France",
	"Ireland") | inlist(country,"Iceland","Italy","Netherlands","Norway",
	"Sweden","Switzerland","United Kingdom","West Germany") |
	inlist(country,"United States","Canada","Australia","New Zealand");
	
replace country = "Germany" if country=="West Germany";

merge m:1 country using reforms_new_ameco, keep(master match) nogen;

expand 2;
sort country year;
capture drop dup;
quietly by country year: gen dup = cond(_N==1,0,_n);
drop if dup>1 & reformyear2==.;

gen reformyear = reformyear1;
foreach country in Finland Norway {;
	replace reformyear = reformyear2 if country=="`country'" & dup==2;
	replace country = "`country'1" if country=="`country'" & dup==1;
	replace country = "`country'2" if country=="`country'" & dup==2;
};


gen treated = reformyear!=.;
egen countrygroup = group(country);

* calculating net capital formation as a percent of GDP;
merge 1:1 country year using ameco_gdp_raw, keep(master match) keepusing(gdp) nogen;

replace netcapital = 100*(netcapital/gdp);

save ameco_netcapital_wid, replace;

drop if inlist(country,"United States","Canada","Australia","New Zealand");

save ameco_netcapital, replace;

* TFP growth;
use ameco8_raw, clear;

keep if (v3=="02 Factor productivity, total economy" & v4=="Total factor productivity: total economy ") 
	| _n==1;

rename v2 country;

forvalues n = 6/67 {;
	local name = v`n'[1];
	rename v`n' v`name';
};

drop v1 v3 v4 v5 v68;
drop if _n==1;

* removing quotation marks from some countries;
replace country = subinstr(country, `"""',  "", .);

* keeping the relevant countries;
keep if inlist(country,"Austria","Belgium","Denmark","Finland","France",
	"Ireland") | inlist(country,"Iceland","Italy","Netherlands","Norway",
	"Sweden","Switzerland","United Kingdom","Germany (linked)") |
	inlist(country,"United States","Canada","Australia","New Zealand");
	
replace country = "Germany" if country=="Germany (linked)";

reshape long v, i(country) j(year);

rename v tfp;

destring tfp, force replace;

* calculating TFP growth;
gen tfpgrowth = 100*((tfp-tfp[_n-1])/tfp[_n-1]);
replace tfpgrowth = . if country!=country[_n-1];



merge m:1 country using reforms_new_ameco, keep(master match) nogen;

expand 2;
sort country year;
capture drop dup;
quietly by country year: gen dup = cond(_N==1,0,_n);
drop if dup>1 & reformyear2==.;

gen reformyear = reformyear1;
foreach country in Finland Norway {;
	replace reformyear = reformyear2 if country=="`country'" & dup==2;
	replace country = "`country'1" if country=="`country'" & dup==1;
	replace country = "`country'2" if country=="`country'" & dup==2;
};


gen treated = reformyear!=.;
egen countrygroup = group(country);

save ameco_tfpgrowth_wid, replace;

drop if inlist(country,"United States","Canada","Australia","New Zealand");

save ameco_tfpgrowth, replace;


foreach suffix in "" "_wid" {;

	use ameco_wagegrowth`suffix', clear;
	keep country year reformyear treated wagegrowth;

	* merging all of the AMECO analyses into one dataset;
	merge 1:1 country year using ameco_laborshare`suffix', keep(master match) nogen keepusing(laborshare);
	merge 1:1 country year using ameco_netcapital`suffix', keep(master match) nogen keepusing(netcapital);
	merge 1:1 country year using ameco_tfpgrowth`suffix', keep(master match) nogen keepusing(tfpgrowth);
	merge 1:1 country year using ameco_gdp`suffix', keep(master match) nogen keepusing(gdp_growth ln_productivity);

	* dropping 2020 for the France analyses because of Covid...;
	keep if year<2020;
	
	drop if country=="New Zealand";
	* as it's missing tfpgrowth and labor share variables...;

	save ameco_variables`suffix', replace;

};


