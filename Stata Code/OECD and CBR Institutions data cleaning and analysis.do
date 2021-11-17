/* This file compares the non-codetermination labor market institutions of countries with 
and without codetermination laws, drawing on the OECD/IAIS ICTWSS dataset and CBR
Labor Regulation Index data. It also creates the event-study results for the 
union density growth outcome variable. 

Input files: "OECD Institutions Data.xslx", mapdata.dta, pop_world.dta, coords_world.dta, 
	cbr_regulationrankings.dta, analysis_full.dta, reforms_new_ameco.dta
Intermediate Stata Data files created: none relevant to other files
Output files created: oecd_cbgraph.pdf, oecd_udgraph.pdf, oecd_reggraph.pdf,
	oecd_uniondensity_tsline.pdf, synthplot_union_density_growth_COUNTRYNAME.pdf,
	testplot_union_density_growth.pdf, rawplot_union_density_growth.pdf, 
	eventstudy_union_density_growth.pdf
	
*/


# delimit;
clear all;
set more off;
set seed 6000;
local graphopts "graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))";

local graphopts "graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))";
adopath ++ "${adopath}"; 


********************************** cleaning data *******************************;

* importing OECD/IAIS ICTWSS data;
import excel "${rawfolder}/OECD Institutions Data.xlsx", sheet("OECD-AIAS Database") firstrow clear;
export excel "${intermediate}/OECD sheet.xlsx", replace;

import excel "${intermediate}/OECD sheet.xlsx", firstrow clear;



*** quick variable cleaning;
drop iso3c;

destring year, replace;
rename Country country;

* works council power variables;
foreach var of varlist WC* {;
	destring `var', replace;
	recode `var' (-88 -99 = .);
};

rename WC wc_existence;
recode wc_existence (2 = 1) (1 = 0.5);

rename WC_rights wc_powers;
replace wc_powers = 0 if wc_powers==.;
label define wc_powers
	0 "No works councils"
	1 "Information and Consultation, No JR"
	2 "Information and Consultation, JR"
	3 "Codermination";
	

* union density variables;
foreach var in UD UM_female UD_female {;
	destring `var', replace;
	recode `var' (-88 = .);
};

rename UD union_density;
rename UM_female union_pct_female;
rename UD_female union_density_female;

* collective bargaining variables;
foreach var in Level WSSA Ext UnadjCov UnadjCov_s {;
	destring `var', replace;
	recode `var' (-88 -99 = .);
};

rename Level cb_bargaininglevel;
rename WSSA cb_howdetermines;
recode cb_howdetermines (0 = 2) (2 = 0);
rename Ext cb_extensions;


gen cb_coverage = UnadjCov;
replace cb_coverage = UnadjCov_s if cb_coverage==.;

gen dummy = year>2010 & cb_coverage!=.;
egen maxdummy = max(dummy), by(country);


* trimming down to the relevant variables;
keep country year wc_* union_* cb_*;

rename country COUNTRY;

* disambiguating country names;
replace COUNTRY = "Czech Republic" if COUNTRY=="Czechoslovakia";
replace COUNTRY = "Macedonia" if COUNTRY=="North Macedonia";
replace COUNTRY = "Slovakia" if COUNTRY=="Slovak Republic";

* merging on CBR Labor Regulation data on the strength of board-level/shop-floor codetermination laws;
merge m:1 COUNTRY using mapdata, keep(match) keepusing(_ID codetermination works_councils);

drop if year==2020;

save oecd_institutions_clean, replace;


*** creating "CB coverage" bar graph;
use oecd_institutions_clean, clear;

sort COUNTRY year;

* keeping relevant countries;
keep if inlist(COUNTRY,"Australia","Austria","Belgium","Canada","Denmark","Finland",
	"France","Germany") | inlist(COUNTRY,"Ireland","Italy","New Zealand","Netherlands",
	"Sweden","Switzerland","United Kingdom","United States","Norway");

drop codetermination;
gen codetermination = inlist(COUNTRY,"Austria","Belgium","Denmark","Finland","France","Germany","Netherlands",
	"Sweden","Norway");
	
gen cb18 = cb_coverage if year==2018;

forvalues n = 1/10 {;
	local m = 2018-`n';
	gen cb`m' = cb_coverage if year==`m';
	egen maxcb`m' = max(cb`m'), by(COUNTRY);
	replace cb18 = maxcb`m' if cb18==. & year==2018;
	drop cb`m';
}; // actually this procedure is unnecessary for all countries


keep if year==2018;
keep COUNTRY cb18 codetermination;
drop if cb18==.;

gen COUNTRY3 = COUNTRY;
replace COUNTRY3 = "AUS" if COUNTRY=="Australia";
replace COUNTRY3 = "AUT" if COUNTRY=="Austria";
replace COUNTRY3 = "BEL" if COUNTRY=="Belgium";
replace COUNTRY3 = "CAN" if COUNTRY=="Canada";
replace COUNTRY3 = "DNK" if COUNTRY=="Denmark";
replace COUNTRY3 = "FRA" if COUNTRY=="France";
replace COUNTRY3 = "FIN" if COUNTRY=="Finland";
replace COUNTRY3 = "DEU" if COUNTRY=="Germany";
replace COUNTRY3 = "IRL" if COUNTRY=="Ireland";
replace COUNTRY3 = "ITA" if COUNTRY=="Italy";
replace COUNTRY3 = "NLD" if COUNTRY=="Netherlands";
replace COUNTRY3 = "NZL" if COUNTRY=="New Zealand";
replace COUNTRY3 = "NOR" if COUNTRY=="Norway";
replace COUNTRY3 = "SWE" if COUNTRY=="Sweden";
replace COUNTRY3 = "CHE" if COUNTRY=="Switzerland";
replace COUNTRY3 = "GBR" if COUNTRY=="United Kingdom";
replace COUNTRY3 = "USA" if COUNTRY=="United States";


* making bar graph;
sort cb18;
gen x = _n;

labmask x, values(COUNTRY3);

twoway (bar cb18 x if codetermination==0, bcolor(maroon) fcolor(maroon%0) barwidth(0.5) lwidth(thick)) 
	(bar cb18 x if codetermination==1, color(navy) barwidth(0.5)),
	`graphopts' xlabel(1(1)15,val angle(90)) ytitle("Collective Bargaining Coverage (2018, %)") xtitle("") 
	legend(order(2 "Codetermined Countries" 1 "Non-Codetermined Countries"));
graph display, ysize(4) xsize(11);
graph export "${outfolder}/oecd_coveragebar.pdf", replace;
	


*** creating map of works council rights;
use oecd_institutions_clean, clear;

keep if year==2019;

* keeping European countries;
drop if inlist(COUNTRY,"Argentina","Australia","Brazil","Canada","Chile","China","Colombia",
	"Costa Rica") | inlist(COUNTRY,"India","Indonesia","Israel","Japan","Mexico","New Zealand","Portugal",
	"Russian Federation") | inlist(COUNTRY,"South Africa","United States");


spmap wc_powers using coords_world, id(_ID) fc(Reds) clm(unique)
		 legend(pos(8) size(large)) `graphopts' ndfcolor(gray) legend(order(2 "No Rights" 3 "Info & Consultation (no Judicial Redress)"
			4 "Info & Consultation (with Judicial Redress)" 5 "Co-decision-making"));
graph export "${outfolder}/map_wc_powers.pdf", replace;
graph export "${outfolder}/map_wc_powers.png", replace height(750) width(1400);
	 

* institutions vs codetermination graphs;
use oecd_institutions_clean, clear;

* keeping European countries and non-European liberal market economies;
keep if inlist(COUNTRY,"Australia","Austria","Belgium","Canada","Denmark","Finland",
	"France","Germany","Iceland") | inlist(COUNTRY,"Ireland","Italy","New Zealand","Netherlands",
	"Sweden","Switzerland","United Kingdom","United States","Norway");
	
* merging on CBR data on the overall intensity of labor market regulations;
capture drop _merge;
merge m:1 COUNTRY using cbr_regulationrankings, keep(master match) nogen;
	
* Iceland's time series in the OECD/IAIS data starts too late;
drop if COUNTRY=="Iceland";
	
sort COUNTRY year;

drop codetermination works_councils;

* generating 'has codetermination laws' indicator;
gen codetermination = inlist(COUNTRY,"Austria","Belgium","Denmark","Finland","France","Germany","Netherlands",
	"Sweden","Norway");


local varlist "cb_bargaininglevel union_density";

egen countrygroup = group(COUNTRY);
quietly su countrygroup;
local maxval = r(max);

* for each country, calculating the value of the outcome variable in 1960 and in 2018;
* these values already exist for the 'regulation rank' variable from the cbr_regulationrankings.dta dataset;
foreach var in cb_bargaininglevel union_density {;

	gen `var'60 = .;
	gen `var'18 = .;

	forvalues n = 1/`maxval' {;
		quietly su `var' if countrygroup==`n' & year==1960;
		replace `var'60 = r(mean) if countrygroup==`n';
		
		quietly su `var' if countrygroup==`n' & year==2018;
		replace `var'18 = r(mean) if countrygroup==`n';
	};
};

* a few countries don't have data available until 2018, so we take their latest available year;
su union_density if COUNTRY=="Australia" & year==2015;
replace union_density18 = r(mean) if COUNTRY=="Australia";

su union_density if COUNTRY=="Canada" & year==2015;
replace union_density18 = r(mean) if COUNTRY=="Canada";

su union_density if COUNTRY=="United States" & year==2016;
replace union_density18 = r(mean) if COUNTRY=="United States";

collapse (mean) *60 *18, by(COUNTRY codetermination);

* calculating means in the groups with and without codetermination;
foreach var in `varlist' regulation_rank {;

	foreach yr in 18 60 {;
	
		quietly su `var'`yr' if codetermination==1;
		gen t_`var'`yr' = r(mean);
		quietly su t_`var'`yr';
		local t_`var'`yr' = r(mean);
		if "`var'"=="cb_bargaininglevel" local t2_`var'`yr' = r(mean)+0.1;
		if "`var'"=="union_density" | "`var'"=="regulation_rank" local t2_`var'`yr' = r(mean)+2;
		
		quietly su `var'`yr' if codetermination==0;
		gen c_`var'`yr' = r(mean);
		quietly su c_`var'`yr';
		local c_`var'`yr' = r(mean);
		if "`var'"=="cb_bargaininglevel" local c2_`var'`yr' = r(mean)-0.1;
		if "`var'"=="union_density" | "`var'"=="regulation_rank" local c2_`var'`yr' = r(mean)-2;

	
	};

};

* creating a variable containing 3-letter country codes;
gen COUNTRY3 = COUNTRY;
replace COUNTRY3 = "AUS" if COUNTRY=="Australia";
replace COUNTRY3 = "AUT" if COUNTRY=="Austria";
replace COUNTRY3 = "BEL" if COUNTRY=="Belgium";
replace COUNTRY3 = "CAN" if COUNTRY=="Canada";
replace COUNTRY3 = "DNK" if COUNTRY=="Denmark";
replace COUNTRY3 = "FRA" if COUNTRY=="France";
replace COUNTRY3 = "FIN" if COUNTRY=="Finland";
replace COUNTRY3 = "DEU" if COUNTRY=="Germany";
replace COUNTRY3 = "IRL" if COUNTRY=="Ireland";
replace COUNTRY3 = "ITA" if COUNTRY=="Italy";
replace COUNTRY3 = "NLD" if COUNTRY=="Netherlands";
replace COUNTRY3 = "NZL" if COUNTRY=="New Zealand";
replace COUNTRY3 = "NOR" if COUNTRY=="Norway";
replace COUNTRY3 = "SWE" if COUNTRY=="Sweden";
replace COUNTRY3 = "CHE" if COUNTRY=="Switzerland";
replace COUNTRY3 = "GBR" if COUNTRY=="United Kingdom";
replace COUNTRY3 = "USA" if COUNTRY=="United States";

gen labpos = 3;

* manually manipulating the location of the dots so that labels are readable;
gen x1 = 1;
gen x1coef = 2;

gen x2 = 3.4;
gen x2coef = 2.6;


replace x1 = x1+0.4 if COUNTRY=="Canada";
replace x1 = x1-0.4 if COUNTRY=="United States";

replace cb_bargaininglevel60 = cb_bargaininglevel60-0.1 if COUNTRY=="France";
replace cb_bargaininglevel60 = cb_bargaininglevel60-0.1 if COUNTRY=="Germany";
replace cb_bargaininglevel60 = cb_bargaininglevel60-0.1 if COUNTRY=="United Kingdom";

replace cb_bargaininglevel60 = cb_bargaininglevel60+0.1 if COUNTRY=="Finland";
replace cb_bargaininglevel60 = cb_bargaininglevel60+0.1 if COUNTRY=="New Zealand";
replace cb_bargaininglevel60 = cb_bargaininglevel60+0.1 if COUNTRY=="Switzerland";

replace x1 = x1+0.4 if COUNTRY=="Finland" | COUNTRY=="France";
replace x1 = x1-0.4 if COUNTRY=="Switzerland" | COUNTRY=="United Kingdom";

replace x1 = x1+0.4 if COUNTRY=="Austria";
replace x1 = x1-0.4 if COUNTRY=="Belgium";

replace cb_bargaininglevel60 = cb_bargaininglevel60+0.1 if COUNTRY=="Denmark"
	| COUNTRY=="Netherlands";
	
replace cb_bargaininglevel60 = cb_bargaininglevel60-0.1 if COUNTRY=="Italy"
	| COUNTRY=="Norway";
	
replace x1 = x1-0.4 if COUNTRY=="Denmark" | COUNTRY=="Italy";
replace x1 = x1+0.4 if COUNTRY=="Netherlands" | COUNTRY=="Norway";

replace cb_bargaininglevel18 = cb_bargaininglevel18+0.1 if COUNTRY=="Canada"
	| COUNTRY=="United States";
replace cb_bargaininglevel18 = cb_bargaininglevel18-0.1 if COUNTRY=="United Kingdom"
	| COUNTRY=="Ireland";
	
replace x2 = x2-0.4 if COUNTRY=="Canada" | COUNTRY=="Ireland";
replace x2 = x2+0.4 if COUNTRY=="United States" | COUNTRY=="United Kingdom";

replace cb_bargaininglevel18 = cb_bargaininglevel18-0.2 if inlist(COUNTRY,"Austria",
	"Denmark","Sweden");
replace cb_bargaininglevel18 = cb_bargaininglevel18+0.2 if inlist(COUNTRY,"Finland",
	"France","Italy");
replace cb_bargaininglevel18 = cb_bargaininglevel18+0.4 if COUNTRY=="Norway";
	
replace x2 = x2-0.4 if inlist(COUNTRY,"Austria","Finland","Netherlands");
replace x2 = x2+0.4 if inlist(COUNTRY,"Sweden","Italy","Switzerland");

/*
(scatteri `c_cb_bargaininglevel60' 2  `c_cb_bargaininglevel18' 2.6 , recast(line) color(black) lpattern(dash))
(scatteri `t_cb_bargaininglevel60' 2 `t_cb_bargaininglevel18' 2.6, recast(line) color(black) lpattern(dash))
*/

* creating the plot;
twoway (scatter cb_bargaininglevel60 x1 if codetermination==1, mlabel(COUNTRY3) mlabvpos(labpos) color(navy))
	(scatter cb_bargaininglevel60 x1 if codetermination==0, mlabel(COUNTRY3) mlabvpos(labpos) color(maroon)
		msymbol(triangle_hollow))
	
	(scatter t_cb_bargaininglevel60 x1coef , color(navy) msize(large) msymbol(square) )
	(scatter c_cb_bargaininglevel60 x1coef , color(maroon) msize(large) msymbol(square_hollow))
	
	
	(scatter cb_bargaininglevel18 x2 if codetermination==1, mlabel(COUNTRY3) mlabcolor(navy) mlabvpos(labpos) color(navy))
	(scatter cb_bargaininglevel18 x2 if codetermination==0, mlabel(COUNTRY3) mlabcolor(maroon) mlabvpos(labpos) color(maroon)
		msymbol(triangle_hollow))
	
	(scatter t_cb_bargaininglevel18 x2coef , color(navy) msize(large) msymbol(square) )
	(scatter c_cb_bargaininglevel18 x2coef , color(maroon) msize(large) msymbol(square_hollow))
	, `graphopts'  yscale(range(0.9 5.5))  xscale(range(1 4))
	text(`c2_cb_bargaininglevel60' 2  "Mean", placement(s) color(maroon))
	text(`t2_cb_bargaininglevel60' 2  "Mean", placement(n) color(navy))
	text(`c2_cb_bargaininglevel18' 2.6  "Mean", placement(s) color(maroon))
	text(`t2_cb_bargaininglevel18' 2.6  "Mean", placement(n) color(navy))
xlabel(1.45 "1960" 3.15 "2018", nogrid angle(horizontal) noticks) xtitle("") legend(order(1 "Codetermined Countries" 2 "Non-Codetermined Countries")) 
xline(2.3, lcolor(black))
	ylabel(1 "Company" 2 "Company-Industry" 3 "Industry" 4 "Industry-National" 5 "National", angle(horizontal))
	ytitle("");

graph export "${outfolder}/oecd_cbgraph.pdf", replace;
graph export "${outfolder}/oecd_cbgraph.png", replace;

* more manual manipulation of dot locations;
drop x1 x2 x1coef x2coef;

gen x1 = 1;
gen x1coef = 2;

gen x2 = 3.4;
gen x2coef = 2.6;


replace x1 = x1+0.4 if COUNTRY=="Italy";
replace x1 = x1-0.4 if COUNTRY=="Canada";

replace x1 = x1-0.4 if COUNTRY=="Germany";
replace x1 = x1+0.4 if COUNTRY=="Finland";

replace x1 = x1+0.13 if COUNTRY=="Switzerland";
replace x1 = x1-0.13 if COUNTRY=="United States";

replace x1 = x1-0.4 if COUNTRY=="United Kingdom";
replace x1 = x1+0.4 if COUNTRY=="Netherlands";

replace x1 = x1+0.4 if COUNTRY=="Denmark";
replace x1 = x1-0.4 if COUNTRY=="Norway";

replace x2 = x2-0.4 if COUNTRY=="United States";
replace x2 = x2+0.2 if COUNTRY=="Switzerland";

replace x2 = x2+0.4 if COUNTRY=="Germany";
replace x2 = x2-0.4 if COUNTRY=="Australia";

replace x2 = x2-0.4 if COUNTRY=="United Kingdom";
replace x2 = x2+0.4 if COUNTRY=="Ireland";

replace x2 = x2-0.2 if COUNTRY=="Norway";
replace x2 = x2+0.2 if COUNTRY=="Belgium";

replace x2 = x2+0.2 if COUNTRY=="Sweden";
replace x2 = x2-0.2 if COUNTRY=="Finland";

replace x2 = x2-0.1 if COUNTRY=="Netherlands";
replace x2 = x2-0.4 if COUNTRY=="Canada";
	
replace union_density18 = . if COUNTRY=="New Zealand";


di `t_union_density60'-`c_union_density60';
di `t_union_density18'-`c_union_density18';

/*
(scatteri `c_union_density60' 2  `c_union_density18' 2.6 , recast(line) color(black) lpattern(dash))
(scatteri `t_union_density60' 2 `t_union_density18' 2.6, recast(line) color(black) lpattern(dash))
*/

* creating the plot;
twoway (scatter union_density60 x1 if codetermination==1, mlabel(COUNTRY3) mlabvpos(labpos) color(navy))
	(scatter union_density60 x1 if codetermination==0, mlabel(COUNTRY3) mlabvpos(labpos) color(maroon)
		msymbol(triangle_hollow))
	
	(scatter t_union_density60 x1coef , color(navy) msize(large) msymbol(square) )
	(scatter c_union_density60 x1coef , color(maroon) msize(large) msymbol(square_hollow))
	
	
	(scatter union_density18 x2 if codetermination==1, mlabel(COUNTRY3) mlabcolor(navy) mlabvpos(labpos) color(navy))
	(scatter union_density18 x2 if codetermination==0, mlabel(COUNTRY3) mlabcolor(maroon) mlabvpos(labpos) color(maroon)
		msymbol(triangle_hollow))
	
	(scatter t_union_density18 x2coef , color(navy) msize(large) msymbol(square) )
	(scatter c_union_density18 x2coef , color(maroon) msize(large) msymbol(square_hollow))
	, `graphopts'  yscale(range(0.9 5.5))  xscale(range(0.6 4))
	text(`c2_union_density60' 2  "Mean", placement(s) color(maroon))
	text(`t2_union_density60' 2  "Mean", placement(n) color(navy))
	text(`c2_union_density18' 2.6  "Mean", placement(s) color(maroon))
	text(`t2_union_density18' 2.6  "Mean", placement(n) color(navy))
xlabel(1.45 "1960" 3.15 "2018", nogrid angle(horizontal) noticks) xtitle("") legend(order(1 "Codetermined Countries" 2 "Non-Codetermined Countries")) 
xline(2.3, lcolor(black))
	ylabel(0(10)100, angle(horizontal))
	ytitle("Union Membership as % of Workforce");
	
graph export "${outfolder}/oecd_udgraph.pdf", replace;
graph export "${outfolder}/oecd_udgraph.png", replace;



***************************** regulation rankings ******************************;


* more manual manipulation of dot locations;
drop x1 x2 x1coef x2coef;


gen x1 = 1;
gen x1coef = 2;

gen x2 = 3.4;
gen x2coef = 2.6;

replace x1 = x1-0.4 if COUNTRY=="Ireland";
replace x1 = x1+0.4 if COUNTRY=="Denmark";
replace x1 = x1-0.3 if COUNTRY=="United Kingdom";

replace x1 = x1+0.2 if COUNTRY=="Sweden";
replace x1 = x1-0.2 if COUNTRY=="Switzerland";

replace x1 = x1+0.2 if COUNTRY=="Belgium";
replace x1 = x1-0.2 if COUNTRY=="Austria";

replace x1 = x1+0.2 if COUNTRY=="Germany";
replace x1 = x1-0.2 if COUNTRY=="Norway";

replace x1 = x1+0.2 if COUNTRY=="France";
replace x1 = x1-0.2 if COUNTRY=="Netherlands";


replace x2 = x2-0.4 if COUNTRY=="United States";
replace x2 = x2+0.4 if COUNTRY=="New Zealand";

replace x2 = x2+0.2 if COUNTRY=="United Kingdom";
replace x2 = x2-0.2 if COUNTRY=="Switzerland";

replace x2 = x2+0.2 if COUNTRY=="Austria";
replace x2 = x2-0.2 if COUNTRY=="Ireland";

replace x2 = x2+0.2 if COUNTRY=="Norway";
replace x2 = x2-0.2 if COUNTRY=="Sweden";

replace x2 = x2-0.6 if COUNTRY=="Netherlands";
replace x2 = x2-0.4 if COUNTRY=="Italy";

replace x2 = x2+0.3 if COUNTRY=="Belgium";


capture gen labpos = 3;
capture gen labpos2 = 3;
	
	
/*
(scatteri `c_regulation_rank60' 2  `c_regulation_rank18' 2.6 , recast(line) color(black) lpattern(dash))
(scatteri `t_regulation_rank60' 2 `t_regulation_rank18' 2.6, recast(line) color(black) lpattern(dash))
*/


* creating the plot;
twoway (scatter regulation_rank60 x1 if codetermination==1, mlabel(COUNTRY3) mlabvpos(labpos) color(navy))
	(scatter regulation_rank60 x1 if codetermination==0, mlabel(COUNTRY3) mlabvpos(labpos) color(maroon)
		msymbol(triangle_hollow))
	
	(scatter t_regulation_rank60 x1coef , color(navy) msize(large) msymbol(square) )
	(scatter c_regulation_rank60 x1coef , color(maroon) msize(large) msymbol(square_hollow))
	
	
	(scatter regulation_rank18 x2 if codetermination==1, mlabel(COUNTRY3) mlabcolor(navy) mlabvpos(labpos) color(navy))
	(scatter regulation_rank18 x2 if codetermination==0, mlabel(COUNTRY3) mlabcolor(maroon) mlabvpos(labpos) color(maroon)
		msymbol(triangle_hollow))
	
	(scatter t_regulation_rank18 x2coef , color(navy) msize(large) msymbol(square) )
	(scatter c_regulation_rank18 x2coef , color(maroon) msize(large) msymbol(square_hollow))
	, `graphopts'  yscale(range(0.9 5.5))  xscale(range(0.6 4))
	text(`c2_regulation_rank60' 2  "Mean", placement(s) color(maroon))
	text(`t2_regulation_rank60' 2  "Mean", placement(n) color(navy))
	text(`c2_regulation_rank18' 2.6  "Mean", placement(s) color(maroon))
	text(`t2_regulation_rank18' 2.6  "Mean", placement(n) color(navy))
xlabel(1.45 "1960" 3.15 "2018", nogrid angle(horizontal) noticks) xtitle("") legend(order(1 "Codetermined Countries" 2 "Non-Codetermined Countries")) 
xline(2.3, lcolor(black))
	ylabel(0(10)100, angle(horizontal))
	ytitle("Percentile of Labor Regulation Intensity");
	
graph export "${outfolder}/oecd_reggraph.pdf", replace;
graph export "${outfolder}/oecd_reggraph.png", replace;



* timelines of union density;
use oecd_institutions_clean, clear;

keep if inlist(COUNTRY,"Australia","Austria","Belgium","Canada","Denmark","Finland",
	"France","Germany","Iceland") | inlist(COUNTRY,"Ireland","Italy","New Zealand","Netherlands",
	"Sweden","Switzerland","United Kingdom","United States","Norway");
	
drop codetermination works_councils;

gen codetermination = inlist(COUNTRY,"Austria","Belgium","Denmark","Finland","France","Germany","Netherlands",
	"Sweden","Norway");

* keeping countries where at least 50% of the years are nonmissing;
gen dummy = 1;
egen sumdummy = sum(dummy), by(COUNTRY);
gen union_nonm = union_density!=.;
egen sum_union_nonm = sum(union_nonm), by(COUNTRY);

keep if sum_union_nonm/sumdummy>=0.5;
keep if sumdummy==60;

* interpolating union density to fill in missing years;
ipolate union_density year, gen(temp_union_density) by(COUNTRY);
replace union_density = temp_union_density if union_density==.;

egen countrygroup = group(COUNTRY);
labmask countrygroup, values(COUNTRY);

quietly su countrygroup;
local maxval = r(max);

sort countrygroup year;
gen n = _n;

save union_tsline, replace;
	
collapse (mean) union_density, by(year codetermination);

drop if year==2019;


twoway (line union_density year if codetermination==1, color(navy))
	(line union_density year if codetermination==0, color(maroon) lpattern(dash)), `graphopts'
	ytitle("Union Membership as % of Workforce") legend(order(1 "Codetermined Countries" 2 "Non-Codetermined Countries"))
	xtitle(Year) ;
graph export "${outfolder}/oecd_uniondensity_tsline.pdf", replace;
graph export "${outfolder}/oecd_uniondensity_tsline.png", replace;
	
********************* DiD analysis of union density ****************************;



use oecd_institutions_clean, clear;

* keeping our sample countries;
keep if inlist(COUNTRY,"Australia","Austria","Belgium","Canada","Denmark","Finland",
	"France","Germany","Iceland") | inlist(COUNTRY,"Ireland","Italy","New Zealand","Netherlands",
	"Sweden","Switzerland","United Kingdom","United States","Norway");
drop if inlist(COUNTRY,"Australia","Canada","New Zealand","United States");
	
capture drop _merge;
merge m:1 COUNTRY using cbr_regulationrankings, keep(master match) nogen;
	
drop if COUNTRY=="Iceland";
* union density time series starts too late;
	
sort COUNTRY year;

drop codetermination works_councils;
	
* keeping countries where at least 50% of the years are nonmissing;
gen dummy = 1;
egen sumdummy = sum(dummy), by(COUNTRY);
gen union_nonm = union_density!=.;
egen sum_union_nonm = sum(union_nonm), by(COUNTRY);

keep if sum_union_nonm/sumdummy>=0.5;
keep if sumdummy==60;

* interpolating union density;
ipolate union_density year, gen(temp_union_density) by(COUNTRY);
replace union_density = temp_union_density if union_density==.;

* merging on reform-years and conducting the necessary duplications for Finland and Norway;
rename COUNTRY country;
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
	


local treatedlist "Austria Denmark Finland1 Finland2 France Germany Netherlands Norway1 Norway2 Sweden";

drop if year==2019;

egen countrygroup = group(country);

* calculating union density growth;
sort country year;
gen union_density_growth = 100*((union_density-union_density[_n-1])/union_density[_n-1]);
replace union_density_growth = . if country!=country[_n-1];

* merging on macro data for synth matching;
merge m:1 country year using analysis_full, keep(master match) nogen 
	keepusing(wagegrowth tfpgrowth gdp_growth laborshare netcapital);
	

save oecd_did_full, replace;

local synthpredictors "wagegrowth tfpgrowth gdp_growth laborshare netcapital";

foreach var in union_density_growth {;
	
	if "`var'"=="union_density_growth" {;
	
		local ytitle2 "Effect on Union Density Growth (ppt)";
		local yscale "0 9";
		local y1 = 9;
		local y2 = 8.2;
		local y3 = 7.4;
		
	};

	* looping over treated countries and constructing a synthetic control group for each;
	foreach country in `treatedlist' {;
		
		di "`country'";
		
		* setting local for legend label;
		local countrylabel "`country'";
		if "`country'"=="Finland1" | "`country'"=="Finland2" local countrylabel "Finland";
		if "`country'"=="Norway1" | "`country'!"=="Norway2" local countrylabel "Norway";
		
		use oecd_did_full, clear;
					
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
				
				* dropping 1960 because the first time period is missing for our 'growth' variabkles;
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
		
		* dropping 1960 because the first time period is missing for our 'growth' variabkles;
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
			
	if "`var'"=="union_density" {;
		replace ceil = 6;
		local loc = 5.5;
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
		
	
	local legendpos = 1;
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

