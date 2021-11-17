

# delimit;
clear all;
set more off;
set seed 6000;
local graphopts "graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))";

local graphopts "graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))";
adopath ++ "${adopath}"; 


* Downloading data if not done yet;
/*
ssc install wid;

wid, indicators(sptinc) areas(_all) perc(p90p100);
 
save "${rawfolder}/wid_rawdata", replace;
*/

* cleaning data;
use "${rawfolder}/wid_rawdata", clear;


* keeping relevant countries;
keep if inlist(country,"DK","FR","DE","NL","NO","SE","CH","GB") | inlist(country,"US","CA","NZ","AU","AT");

* keeping relevant populations;
keep if pop=="j";

* keeping relevant variables;
keep country year value;

* linear interpolation of values;
keep if year>1920;
egen countrygroup = group(country);
tsset countrygroup year;
tsfill;
replace country = country[_n-1] if country=="" & countrygroup==countrygroup[_n-1];
ipolate value year, by(countrygroup) gen(i_value);

drop value;
rename i_value share_top10;
gen share_bottom90 = 1-share_top10;

foreach var of varlist share_* {;
	replace `var' = `var'*100;
};

* keeping relevant years;
keep if inrange(year,1960,2019);

* recoding countries;
replace country = "Australia" if country=="AU";
replace country = "Canada" if country=="CA";
replace country = "Switzerland" if country=="CH";
replace country = "Denmark" if country=="DK";
replace country = "France" if country=="FR";
replace country = "Germany" if country=="DE";
replace country = "United Kingdom" if country=="GB";
replace country = "Netherlands" if country=="NL";
replace country = "Norway" if country=="NO";
replace country = "New Zealand" if country=="NZ";
replace country = "Sweden" if country=="SE";
replace country = "United States" if country=="US";
replace country = "Austria" if country=="AT";

* duplicating Finland and Norway;
expand 2;
sort country year;
quietly by country year: gen dup = cond(_N==1,0,_n);
drop if dup>1 & !(country=="Norway");

replace country = "Norway1" if country=="Norway" & dup==1;
replace country = "Norway2" if country=="Norway" & dup==2;

drop countrygroup;
egen countrygroup = group(country);

* merging on codetermination reform and macroeconomic data;
merge m:1 country year using ameco_variables_wid, keep(master match)  nogen
	keepusing(wagegrowth tfpgrowth gdp_growth laborshare netcapital reformyear);
	
save science_wid, replace;

drop if country=="Austria";
	
save wid_clean, replace;


* raw plots from main results;
/*
use ameco_variables_wid, clear;
keep if inlist(country,"United States","Australia","Canada");
drop treated;
save tempcomparison, replace;
*/

use analysis_full, clear;

*append using tempcomparison;

gen treated = reformyear!=.;
drop if country=="Norway2" | country=="Finland2";

replace treated = 0 if country=="France";

collapse (mean) wagegrowth laborshare netcapital tfpgrowth gdp_growth,
	by(treated year);
	
foreach var in wagegrowth laborshare netcapital tfpgrowth gdp_growth {;

	if "`var'"=="wagegrowth" local ytitle "Wage Growth (%)";
	if "`var'"=="laborshare" local ytitle "Labor Share (%)";
	if "`var'"=="netcapital" local ytitle "Net Capital Formation (% of GDP)";
	if "`var'"=="tfpgrowth" local ytitle "TFP Growth (%)";
	if "`var'"=="gdp_growth" local ytitle "GDP Growth (%)";

	twoway (line `var' year if treated==1, color(navy))
	(line `var' year if treated==0, color(maroon) lpattern(dash)),
	`graphopts' ytitle(`ytitle') xtitle("Year") legend(order(1 "Codetermined Countries"
	2 "Non-Codetermined Countries"));
graph export "${outfolder}/rawseries_`var'.pdf", replace;
graph export "${outfolder}/rawseries_`var'.png", replace;

};



* raw plot;
use wid_clean, clear;

gen treated = reformyear!=.;
drop if country=="Norway2";

* MAYBE TEMPORARY;
*replace treated = 0 if country=="France";

collapse (mean) share_bottom90, by(treated year);

twoway (line share_bottom90 year if treated==1, color(navy))
	(line share_bottom90 year if treated==0, color(maroon) lpattern(dash)),
	`graphopts' ytitle("Bottom 90% share of income") xtitle("Year") legend(order(1 "Codetermined Countries"
	2 "Non-Codetermined Countries"));
graph export "${outfolder}/rawseries_bottom90.pdf", replace;


* analysis;

local synthpredictors "wagegrowth tfpgrowth gdp_growth laborshare netcapital";

local treatedlist "Denmark France Germany Netherlands Norway1 Norway2 Sweden";

foreach var in share_bottom90 {;
	
	if "`var'"=="share_bottom90" {;
	
		local ytitle1 "Bottom 90% Share of Income (pct)";
		local ytitle2 "Effect on Bottom 90%'s Share of Income (ppt)";
		local yscale "0 5";
		local y1 = 4.8;
		local y2 = 4.4;
		local y3 = 4;
		
	};
	
	* looping over treated countries and constructing a synthetic control group for each;
	foreach country in `treatedlist' {;
		
		di "`country'";
		
		* setting local for legend label;
		local countrylabel "`country'";
		if "`country'"=="Finland1" | "`country'"=="Finland2" local countrylabel "Finland";
		if "`country'"=="Norway1" | "`country'!"=="Norway2" local countrylabel "Norway";
		
		use wid_clean, clear;
					
		quietly su reformyear if country=="`country'";
		local reformyear = r(mean);
			
		* narrowing to the relevant 21-year window;
		quietly su reformyear if country=="`country'";
		gen year_rel = year-r(mean);
		keep if inrange(year_rel,-10,10);
		
		* keeping countries with nonmissing values for treatment and predictor variables throughout the window;
		capture drop dummy sumdummy;
		foreach varcheck in `var' `synthpredictors' {;
			gen dummy = `varcheck'!=.;
			egen sumdummy = sum(dummy), by(country);
			egen maxsumdummy = max(sumdummy);
			keep if sumdummy==maxsumdummy;
			drop dummy sumdummy maxsumdummy;
		};
				
		* dropping countries whose treatment status changes during this time window;
		capture drop dummy;
		gen dummy = year==reformyear;
		egen maxdummy = max(dummy), by(country);
		drop if maxdummy==1 & country!="`country'";
			
		* for countries with multiple reforms, dropping the other reform;
		if "`country'"=="Finland1" drop if country=="Finland2";
		if "`country'"=="Finland2" drop if country=="Finland1";
		if "`country'"=="Norway1" drop if country=="Norway2";
		if "`country'"=="Norway2" drop if country=="Norway1";
			
		* dropping Finland entirely if either Finnish reform is in the outcome range;
		* same with Norway;
		if "`country'"!="Finland1" & "`country'"!="Finland2" {;
			quietly su reformyear if country=="`country'";
			local valtemp = r(mean);
			if inrange(`valtemp',1968,2000) drop if country=="Finland1" | country=="Finland2";
		};
		if "`country'"!="Norway1" & "`country'"!="Norway2" {;
			quietly su reformyear if country=="`country'";
			local valtemp = r(mean);
			if inrange(`valtemp',1960,1983) drop if country=="Norway1" | country=="Norway2";
		};

		*** synthetic control group training/validation period;
			
		if "`country'"!="Norway1" {;
			preserve;
				
				* setting up panel;
				tsset countrygroup year_rel;
				
				gen treated = country=="`country'";
				quietly su countrygroup if treated==1;
				local trunit = r(mean);
					
				* DROPPING POST-REFORM PERIOD;
				drop if year_rel>0;
					
				* the time variable has to be nonzero;
				replace year_rel = year_rel+10;
				
				* dropping 1960 because the first time period is missing for our 'growth' variables;
				if "`var'"=="union_density_growth" drop if year==1960;
					
				* using 'synth' to calculate synthetic control outcome series;
				di `trunit';
				synth `var' `synthpredictors', trunit(`trunit') trperiod(5) figure
					keep(`country'_`var'_test, replace) `mspeperiod';
					
					
					
				* saving correspondence between year_rel and actual year;
				collapse (mean) `var', by(year_rel year);
				keep year_rel year;
				save `country'_`var'_year_test, replace;
					
				* loading the saved dataset from the synth command;
				use `country'_`var'_test, clear;
				
				if "`country'"=="France" drop if _time==.;

				keep _Y_treated _Y_synthetic _time;
					
				* reshaping into one treated outcome series and one control outcome series;
				rename _Y_treated `var'1;
				rename _Y_synthetic `var'2;
				reshape long `var', i(_time) j(jvar);
					
				* fixing the country and time variables;
				gen country = ".";
				replace country = "`country'" if jvar==1;
				replace country = "`country'_synth" if jvar==2;
					
				rename _time year_rel;
				merge m:1 year_rel using `country'_`var'_year_test, keep(master match) nogen
					keepusing(year);
					
				replace year_rel = year_rel-10;
					
				gen treated = jvar==1;
				drop jvar;
				
				save `country'_`var'_test, replace;
				
			restore;
		};
			
			
			
		*** constructing synthetic control group;
				
		* setting up panel;
		tsset countrygroup year_rel;
			
		gen treated = country=="`country'";
		quietly su countrygroup if treated==1;
		local trunit = r(mean);
			
		* the time variable has to be nonzero;
		replace year_rel = year_rel+10;
		
		* dropping 1960 because the first time period is missing for our 'growth' variables;
		if "`var'"=="union_density_growth" drop if year==1960;
							
		* using 'synth' to calculate synthetic control outcome series;
		di `trunit';
		synth `var' `synthpredictors', trunit(`trunit') trperiod(10) figure
			keep(`country'_`var', replace) `mspeperiod';
			
		* saving correspondence between year_rel and actual year;
		collapse (mean) `var', by(year_rel year);
		keep year_rel year;
		save `country'_`var'_year, replace;
			
		* loading the saved dataset from the synth command;
		use `country'_`var', clear;
		
			
		keep _Y_treated _Y_synthetic _time;
			
		* reshaping into one treated outcome series and one control outcome series;
		rename _Y_treated `var'1;
		rename _Y_synthetic `var'2;
		reshape long `var', i(_time) j(jvar);
			
		* fixing the country and time variables;
		gen country = ".";
		replace country = "`country'" if jvar==1;
		replace country = "`country'_synth" if jvar==2;
			
		rename _time year_rel;
		merge m:1 year_rel using `country'_`var'_year, keep(master match) nogen
			keepusing(year);
			
		replace year_rel = year_rel-10;
			
		gen treated = jvar==1;
		drop jvar;
			
		local extra = "";
		if "`country'"=="Norway1" local extra "xline(1973, lpattern(dash_dot) lcolor(black))";
		if "`country'"=="Norway2" local extra "xline(1966, lpattern(dash_dot) lcolor(black))";
			
		* coding legend location;
		local legendpos = 1;
		
		* Denmark, Germany, Netherlands, second Norway reform;
		
		if "`country'"=="Denmark" | "`country'"=="Norway1" | "`country'"=="Norway2"
			| "`country'"=="France" | "`country'"=="Sweden" | "`country'"=="Germany" local legendpos = 11;
			
		merge m:1 year_rel using `country'_`var'_year, keep(master match) nogen;
			
		* tsline of treated vs control;
		twoway (connected `var' year if treated==1, color(navy))
			(connected `var' year if treated==0, color(maroon) msymbol(triangle_hollow) lpattern(dash)),
			`graphopts' xline(`reformyear', lpattern(dash_dot) lcolor(black)) ytitle(`ytitle1') xtitle("Year")
			legend(order(1 "`countrylabel'" 2 "Synthetic `countrylabel'") ring(0) position(`legendpos') region(lwidth(none))
			cols(1)) `extra' ylabel(,angle(horizontal)) ylabel(,angle(horizontal))
		;
		graph export "${outfolder}/synthplot_`var'_`country'.pdf", replace;
		graph export "${outfolder}/synthplot_`var'_`country'.png", replace;
		* saving dataset;
		save `country'_`var'_clean, replace;
			
	};
		
	*** pooling all country-reform synth test datasets and creating evaluation plots;
		
	clear;
	foreach country in `treatedlist' {;
		if "`country'"!="Norway1" append using `country'_`var'_test;
	};
			
		
	local legendpos = 1;
					 
	collapse (mean) `var', by(year_rel treated);
			
	gen ceil = 0;
	local loc = 0;
			
	if "`var'"=="share_bottom90" {;
		replace ceil = 76;
		local loc = 71;
	};

	expand 2;
	sort year_rel treated;
	quietly by year_rel treated: gen dup = cond(_N==1,0,_n);
	replace year_rel = year_rel+0.5 if dup==2;
	replace `var' = . if dup==2;
				
	twoway (bar ceil year_rel if year_rel<-5, bcolor(gs14))
	(connected `var' year_rel if treated==1, color(navy))
		(connected `var' year_rel if treated==0, color(maroon) msymbol(triangle_hollow) lpattern(dash)),
		`graphopts' xline(-5, lpattern(dash_dot) lcolor(black)) ytitle(`ytitle1') xtitle("Year Relative to Reform")
		legend(order(2 "Treated Countries" 3 "Synthetic Controls") ring(0) position(`legendpos') region(lwidth(none))
		cols(1)) text(`loc' -10 "Training Period", placement(e) size(large)) ylabel(,angle(horizontal));
	graph export "${outfolder}/testplot_`var'.pdf", replace;
	graph export "${outfolder}/testplot_`var'.png", replace;
		
	*** pooling all country-reforms and their synthetic controls together;
	
	clear;
	foreach country in `treatedlist' {;
		append using `country'_`var'_clean;
	};
		
	
	local legendpos = 11;
	if "`var'"=="union_density" | "`var'"=="union_density_norm" local legendpos = 11;
		
		
	* raw plot;
	preserve;
		
		collapse (mean) `var', by(year_rel treated);
			
		twoway (connected `var' year_rel if treated==1, color(navy))
			(connected `var' year_rel if treated==0, color(maroon) msymbol(triangle_hollow) lpattern(dash)),
			`graphopts' xline(0, lpattern(dash_dot) lcolor(black)) ytitle(`ytitle1') xtitle("Year Relative to Reform")
			legend(order(1 "Treated Countries" 2 "Synthetic Controls") ring(0) position(`legendpos') region(lwidth(none))
				cols(1)) ylabel(,angle(horizontal));
		graph export "${outfolder}/rawplot_`var'.pdf", replace;
		graph export "${outfolder}/rawplot_`var'.png", replace;
		
	restore;
		
		
		
	* generating dummies for event-study regression;
	forvalues n = 0/20 {;
		gen dummy`n' = treated==1 & year_rel==`n'-10;
	};
		
	gen predummy = treated==1 & year_rel<-1;
	gen postdummy = treated==1 & year_rel>=0;
		
	* dropping the first lag because it's our omitted category;	
	drop dummy9;

	egen countrygroup = group(country);
	gen year_rel_pos = year_rel+10;
		
	* event-study regression;
	reg `var' dummy* i.year_rel_pos i.countrygroup i.year, vce(cluster countrygroup);
		
	* storing coefficients and standard errors;
	forvalues n = 0/20 {;
		if `n'!=9 {;
			local coef`n' = _b[dummy`n'];
			local se`n' = _se[dummy`n'];
		};
	};
		
	* calculating average pre-period and average post-period effects;
	reg `var' predummy postdummy i.year_rel_pos i.countrygroup i.year, vce(cluster countrygroup);
		
	* storing coefficients and standard errors;
	local precoef: display %5.3f _b[predummy];
	local prese: display %5.3f _se[predummy];
		
	local postcoef: display %5.3f _b[postdummy];
	local postse: display %5.3f _se[postdummy];
		
	* wild bootstrap of each standard error;
	foreach prefix in pre post {;
		boottest `prefix'dummy, boottype(wild) statistic(c);
		local ptemp = r(p);
		local wild_`prefix': display %5.3f `ptemp';
	};
		
	* BJS coefficient;
	gen treattime = 0;
	replace treattime = . if treated==0;
	tsset countrygroup year_rel;
		
	* this is different to the ones printed on the BJS plots because I don't explicitly relativize to the t = -1 coef;	
	* (by adding the t = -1 coefficient. Using year_rel_new doesn't change the results);
	did_imputation `var' countrygroup year_rel treattime, autosample minn(0) controls();	
	local bjscoef: display %5.3f _b[tau];
	local bjsse: display %5.3f _se[tau];
		
		
	* making dataset for coefficient plot;
	clear;
	set obs 21;
	gen t = _n-1;
	gen coef = .;
	gen se = .;
		
	replace coef = 0 if t==9;
	replace se = 0 if t==9;
		
	forvalues n = 0/20 {;
		if `n'!=9 {;
			replace coef = `coef`n'' if t==`n';
			replace se = `se`n'' if t==`n';
		};
	};
		
	gen high = coef+(1.96*se);
	gen low = coef-(1.96*se);
		
	replace t = t-10;
		
	twoway (scatter coef t, color(navy)) (rcap high low t, color(navy)),
		`graphopts' xline(0, lpattern(dash_dot) lcolor(black)) yline(0, lpattern(dash_dot) lcolor(black))
		yscale(range(`yscale'))
		ylabel(,angle(horizontal))
		ytitle(`ytitle2') xtitle("Year Relative to Reform") legend(off)
		text(`y1' -10.1 "Pre-Reform Coef = `precoef' (SE `prese')"
			 `y2' -10 "Bootstrapped p-value = `wild_pre'"
			 `y1' -0.1 "Post-Reform Coef = `postcoef' (SE `postse')"
			 `y2' 0 "Bootstrapped p-value = `wild_post'"
			 `y3' 0 "BJS Coef = `bjscoef' (SE `bjsse')", placement(e));
				 
		
	graph export "${outfolder}/eventstudy_`var'.pdf", replace;
	graph export "${outfolder}/eventstudy_`var'.png", replace;
	
};
