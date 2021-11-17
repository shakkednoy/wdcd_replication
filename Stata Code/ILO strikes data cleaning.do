/* This file cleans each country's ILO dataset, merges them together,
and prepares a dataset containing strike intensity rank at the country-year level
for our event-study analyses.

Input files: ILO_COUNTRYNAME.xlsx, worldbank_population.dta, reforms_new_ilo.dta
Intermediate Stata Data files created: ilo_variables.dta
Output files created: none
*/


#delimit;
set more off;
clear all;

local graphopts "graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))";

******************** Changes in board-level representation laws ****************;

* cleaning datasets;
foreach country in Austria Belgium Denmark Finland France Germany
	Iceland Ireland Italy Netherlands Norway Sweden Switzerland UK {;

	* loading the country's dataset;
	import excel "${rawfolder}/ILO_`country'.xlsx", clear;
			
	* reshaping the data;
	local n = 0;
	foreach var of varlist _all {;
		local n = `n'+1;
		rename `var' var`n';
		destring var`n', replace;
	};
			
			
	gen ivar = _n;

	reshape long var, i(ivar) j(jvar);

	gen year = var;
	gen pop = .;
	gen num_days = .;
			
	quietly su jvar;
	local maxval = r(max);
	forvalues n = 1/`maxval' {;
		quietly su var if ivar==2 & jvar==`n';
		replace pop = r(mean) if ivar==1 & jvar==`n';
				
		quietly su var if ivar==3 & jvar==`n';
		replace num_days = r(mean) if ivar==1 & jvar==`n';
	};
			
	drop if _n>`maxval';
			
	* creating a 'working-age population' variable;
	rename pop ilopop;
	replace ilopop = ilopop/1000000;
	gen country = "`country'";
	
	* using World Bank data first---these extend back to 1960;
	merge m:1 country year using worldbank_population, keep(master match);
	
	/* prior to 1960, filling in 'working-age population' values using linearly interpolated values from the
	ILO 'total population variable' multiplied by the percent of the population who are working age in 1960, 
	from the World Bank data */
	quietly su pop_pct if year==1960;
	replace ilopop = ilopop*(r(mean)/100);
	replace pop = ilopop if pop==.;
	drop ilopop;
	ipolate pop year, gen (n_pop);
	replace pop = n_pop;
	drop n_pop pop_pct;
	
	preserve;
	
		keep country year pop;
		replace country = "United Kingdom" if "`country'"=="UK";
		save `country'_workingpop, replace;
		
		if "`country'"=="Finland" | "`country'"=="Norway" {;
			replace country = "`country'1";
			save `country'1_workingpop, replace;
			replace country = "`country'2";
			save `country'2_workingpop, replace;
		};
	
	restore;
	
			
	* number of days lost to strikes, normalized by working-age population;
	gen days_per_pop = num_days/pop;
			
	keep country year days_per_pop;
			
	keep if days_per_pop!=.;
					
	* creating the ordinal rank variable;
	egen rank_strikes = rank(days_per_pop), track by(country);
	egen denom = max(rank_strikes), by(country);
	replace rank_strikes = rank_strikes/denom;
	
	* plotting the cardinal and ordinal strike intensity variables for Germany (for Appendix Figure A.15);
	if "`country'"=="Germany" {;
	
		preserve;
				
			twoway (line days_per_pop year, color(navy)), `graphopts' ytitle("Days Lost Per Million People")
				xtitle("Year");
			graph export "${outfolder}/germany_rawstrikes.pdf", replace;
			graph export "${outfolder}/germany_rawstrikes.png", replace;
			
			twoway (line rank_strikes year, color(navy)), `graphopts' ytitle("Strike Intensity Rank")
				xtitle("Year");
			graph export "${outfolder}/germany_rankstrikes.pdf", replace;
			graph export "${outfolder}/germany_rankstrikes.png", replace;
			
		restore;
	
	};
	
	* merging on list of codetermination reforms;
	merge m:1 country using reforms_new_ilo, keep(master match) nogen;
	
	* keeping years post-1960;
	keep if year>=1960;
	
	* keeping relevant variable list;
	keep country year days_per_pop rank_strikes reformyear1 reformyear2;
			
	* saving each country's dataset, and duplicating the countries with two reforms and saving as separate datasets;
	if reformyear2[1]==. {;
		save ILO_`country', replace;
	};
				
	else {;
			
		forvalues n = 1/2 {;
				
			preserve;
				
				replace country = "`country'`n'";
					
				if `n'==1 drop reformyear2;
				if `n'==2 drop reformyear1;
					
				rename reformyear`n' reformyear;
					
				save ILO_`country'`n', replace;
										
			restore;
				
		};
			
	};				
			
};

* combining all country-reforms into one dataset;
clear;
foreach country in Austria Belgium Denmark Finland1 Finland2 France Germany
	Iceland Ireland Italy Netherlands Norway1 Norway2 Sweden Switzerland UK {;
	
	append using ILO_`country';
	
};

save ilo_variables, replace;
