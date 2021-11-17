/* This file produces our main event-study results for our economic and strikes
outcome variables.

Input files: analysis_full.dta
Intermediate Stata Data files created: none relevant to other files
Output files created: synthplot_VARNAME_COUNTRYNAME.pdf, testplot_VARNAME.pdf,
	rawplot_VARNAME.pdf, eventstudy_VARNAME.pdf
*/

if "`c(username)'"=="shakkednoy" {
		
	global workingfolder "/Users/shakkednoy/Dropbox/Codetermination_EPI/Replication File"
	
	global rawfolder "${workingfolder}/Raw Data"
	global intermediate "${workingfolder}/Intermediate Stata Data"
	global outfolder "${workingfolder}/Output"
	global adopath "${workingfolder}/Ado"
	
	cd "${intermediate}"
	
}

#delimit;
set more off;
clear all;

adopath ++ "${adopath}"; 
local graphopts "graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))";


****************************** analyses ****************************************;

* this is the list of variables the synthetic control matches on;
local varlist "wagegrowth laborshare netcapital tfpgrowth gdp_growth";


* looping over outcome variables;
foreach var in wagegrowth laborshare netcapital tfpgrowth gdp_growth rank_strikes capital_intensity gdp_growth {;
	
	local synthpredictors "`varlist'";
	
	* setting locals for axis labels, axis length, and annotation position;
	
	if "`var'"=="wagegrowth" {;
		local ytitle1 "Wage Growth (%)";
		local ytitle2 "Effect on Wage Growth (ppt)";
		local yscale "-2 7";
		local y1 = 6.5;
		local y2 = 6;
		local y3 = 5.5;
	};
	if "`var'"=="laborshare" {;
		local ytitle1 "Labor Share (%)";
		local ytitle2 "Effect on Labor Share (ppt)";
		local yscale "-2 7";
		local y1 = 6.5;
		local y2 = 6;
		local y3 = 5.5;
	};
	if "`var'"=="netcapital" {;
		local ytitle1 "Net Capital Formation (% of GDP)";
		local ytitle2 "Effect on Net Capital Formation (ppt of GDP)";
		local yscale "-6 5.5";
		local y1 = 5;
		local y2 = 4.5;
		local y3 = 4;
	};
	if "`var'"=="tfpgrowth" {;
		local ytitle1 "TFP Growth (%)";
		local ytitle2 "Effect on TFP Growth (ppt)";
		local yscale "-2 5";
		local y1 = 4.8;
		local y2 = 4.4;
		local y3 = 4.0;
	};
	if "`var'"=="gdp_growth" {;
		local ytitle1 "GDP Growth (%)";
		local ytitle2 "Effect on GDP Growth (ppt)";
		local yscale "-4 5";
		local y1 = 4.9;
		local y2 = 4.5;
		local y3 = 4.1;
	};
	if "`var'"=="rank_strikes" {;
		local ytitle1 "Strike Intensity Rank (0-1)";
		local ytitle2 "Effect on Strike Intensity Rank (0-1)";
		local yscale = "-0.5 0.7";
		local y1 = 0.65;
		local y2 = 0.6;
		local y3 = 0.55;
	};
	if "`var'"=="capital_intensity" {;
		local ytitle1 "Log Capital/Labor Ratio";
		local ytitle2 "Effect on Log Capital/Labor Ratio";
		local yscale = "0 0";
		local y1 = 0.2;
		local y2 = 0.18;
		local y3 = 0.16;
	};
	
	* lists of treated countries with nonmissing values for this variable in the treatment window;
	if "`var'"!="rank_strikes" 
		local treatedlist "Austria Denmark Finland1 Finland2 France Germany Netherlands Norway1 Norway2 Sweden";
	if "`var'"=="rank_strikes" 
		local treatedlist "Austria Denmark Finland1 Finland2 Germany Netherlands Norway1 Norway2 Sweden";
		
	* looping over treated countries and constructing a synthetic control group for each;
	foreach country in `treatedlist' {;
	
		di "`country'";
	
		* setting local for legend label;
		local countrylabel "`country'";
		if "`country'"=="Finland1" | "`country'"=="Finland2" local countrylabel "Finland";
		if "`country'"=="Norway1" | "`country'!"=="Norway2" local countrylabel "Norway";
	
		use analysis_full, clear;
				
		quietly su reformyear if country=="`country'";
		local reformyear = r(mean);
		
		* if the dependent variable is strikes, interpolating to fix a few missing values;
		if "`var'"=="rank_strikes" {;
			rename rank_strikes raw_rank_strikes;
			ipolate raw_rank_strikes year, gen(rank_strikes) by(country);
		};
		
		* narrowing to the relevant 21-year window;
		quietly su reformyear if country=="`country'";
		gen year_rel = year-r(mean);
		keep if inrange(year_rel,-10,10);
		
		* keeping countries with nonmissing values for treatment and predictor variables throughout the window;
		foreach varcheck in `var' `synthpredictors' {;
			gen dummy = `varcheck'!=.;
			egen sumdummy = sum(dummy), by(country);
			egen maxsumdummy = max(sumdummy);
			keep if sumdummy==maxsumdummy;
			drop dummy sumdummy maxsumdummy;
		};
		
		* dropping countries whose treatment status changes during this time window;
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
				
				* dropping 1960 because the first time period is missing for our 'growth' variabkles;
				if "`var'"=="wagegrowth" | "`var'"=="tfpgrowth" | "`var'"=="gdp_growth" drop if year==1960;
						
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
				
				* this is a quirk because of France's truncated post-reform period;
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
		if "`var'"=="wagegrowth" | "`var'"=="tfpgrowth" | "`var'"=="gdp_growth" drop if year==1960;
				
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
		if "`var'"=="wagegrowth" | "`var'"=="netcapital" | "`var'"=="tfpgrowth" | "`var'"=="gdp_growth"
			| "`var'"=="rank_strikes" local legendpos = 1;
		if "`var'"=="wage_level" | "`var'"=="tfp_level" | "`var'"=="gdp_level" | "`var'"=="ln_stock_price"
			| "`country'"=="Norway1" | "`country'"=="Norway2" | "`var'"=="laborshare" local legendpos = 11;
			
		if "`var'"=="laborshare" & ("`country'"=="Finland2" | "`country'"=="France"
			| "`country'"=="Netherlands") local legendpos = 8;
		if "`var'"=="laborshare" & "`country'"=="Norway" local legendpos = 9;
		
		if "`var'"=="tfpgrowth" & "`country'"=="Finland2" local legendpos = 11;
		if "`var'"=="tfpgrowth" & "`country'"=="Sweden" local legendpos = 8;
		
		if "`var'"=="netcapital" & "`country'"=="Denmark" local legendpos = 8;
		if "`var'"=="gdp_growth" & "`country'"=="Denmark" local legendpos = 11;
		
		if "`var'"=="laborshare" & "`country'"=="Finland1" local legendpos = 1;
		if ("`var'"=="tfpgrowth" | "`var'"=="gdp_growth") & "`country'"=="France" local legendpos = 11;
		if "`var'"=="gdp_growth" & "`country'"=="Germany" local legendpos = 5;
		
		if "`var'"=="tfpgrowth" & "`country'"=="Norway2" local legendpos = 1;
		
		
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
		
	if "`var'"=="wagegrowth" | "`var'"=="laborshare" | "`var'"=="netcapital" | "`var'"=="tfpgrowth" | "`var'"=="gdp_growth"
			| "`var'"=="rank_strikes" local legendpos = 1;
		if "`var'"=="wage_level" | "`var'"=="tfp_level" | "`var'"=="gdp_level" 
			 local legendpos = 11;
		if "`var'"=="ln_stock_price" local legendpos = 4;
				 
	collapse (mean) `var', by(year_rel treated);
		
	gen ceil = 0;
	local loc = 0;
		
	if "`var'"=="wagegrowth" {;
		replace ceil = 6;
		local loc = 5.5;
	};
	if "`var'"=="laborshare" {;
		replace ceil = 64;
		local loc = 63.5;
	};
	if "`var'"=="tfpgrowth" {;
		replace ceil = 4;
		local loc = 3.8;
	};
	if "`var'"=="gdp_growth" {;
		replace ceil = 6;
		local loc = 5;
	};
	if "`var'"=="netcapital" {;
		replace ceil = 15	;
		local loc = 14;
	};
	if "`var'"=="rank_strikes" {;
		replace ceil = 0.8;
		local loc = 0.78;
	};
		
	* this is just to make the background grey bars (that 'shade' the plot area) work properly;
	expand 2;
	sort year_rel treated;
	quietly by year_rel treated: gen dup = cond(_N==1,0,_n);
	replace year_rel = year_rel+0.5 if dup==2;
	replace `var' = . if dup==2;
		
	* creating evaluation plot;
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
	
	if "`var'"=="wagegrowth" | "`var'"=="laborshare" | "`var'"=="netcapital" | "`var'"=="tfpgrowth" | "`var'"=="gdp_growth"
			| "`var'"=="rank_strikes" local legendpos = 1;
		if "`var'"=="wage_level" | "`var'"=="tfp_level" | "`var'"=="gdp_level" | "`var'"=="ln_stock_price"
			 local legendpos = 11;
	
	
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
	
	* making coefficient plot;
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
