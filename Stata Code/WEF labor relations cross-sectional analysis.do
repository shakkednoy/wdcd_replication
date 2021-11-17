#delimit;
set more off;
clear all;


local graphopts "graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))";

****************************** cleaning the data *******************************;

import excel "${rawfolder}/WEF labor relations.xlsx", clear;

*** reshaping the raw data;
local n = 0;
foreach var of varlist _all {;
	local n = `n'+1;
	rename `var' var`n';
};

gen ivar = _n;

reshape long var, i(ivar) j(jvar);

rename ivar year;
replace year = 2019-year;

drop if jvar==1;

quietly su jvar if year==2018;
local maxval = r(max);

gen vartemp = var;
destring vartemp, force replace;

forvalues n = 2007/2017 {;
	gen val`n' = .;
	forvalues m = 1/`maxval' {;
		quietly su vartemp if year==`n' & jvar==`m';
		replace val`n' = r(mean) if jvar==`m';
	};
};

drop if _n>`maxval'-1;

rename var country;
drop year jvar vartemp;

reshape long val, i(country) j(year);

rename val labor_relations;
label var labor_relations "Labor relations score (1-7)";

* recoding country names to be consistent with mapdata.dta;
replace country = "Brunei" if country=="Brunei Darussalam";
replace country = "Democratic Republic of the Congo" if country=="Congo, Democratic Rep.";
replace country = "Ivory Coast" if country=="Côte d'Ivoire";
replace country = "Gambia" if country=="Gambia, The";
replace country = "Iran" if country=="Iran, Islamic Rep.";
replace country = "South Korea" if country=="Korea, Rep.";
replace country = "Kyrgyzstan" if country=="Kyrgyz Republic";
replace country = "Laos" if country=="Lao PDR";
replace country = "Macedonia" if country=="Macedonia, FYR";
replace country = "Puerto Rico (US)" if country=="Puerto Rico";
replace country = "Russia" if country=="Russian Federation";
replace country = "Slovakia" if country=="Slovak Republic";
replace country = "Taiwan" if country=="Taiwan, China";
replace country = "Vietnam" if country=="Viet Nam";
drop if country=="Hong Kong SAR" | country=="Timor-Leste";

save wef_labor_relations, replace;

************************ cross-sectional analysis ******************************;

*** map of labor relations;

use wef_labor_relations, clear;

* latest year in the CBR data;
keep if year==2015;

* merging on CBR data;
rename country COUNTRY;
merge 1:1 COUNTRY using mapdata, keep(master match using) nogen;

* creating codetermination variable;
gen cod_sum = codetermination+works_councils;

* maps;
foreach var in labor_relations {;

	format `var' %12.2f;

	spmap `var' using coords_world, id(_ID) fc(Reds) clm(quantile)
		 legend(pos(8) size(large)) `graphopts' ndfcolor(gray);
	graph export "${outfolder}/map_`var'.pdf", replace;
	graph export "${outfolder}/map_`var'.png", replace;
};


*** binned scatterplot;
reg labor_relations cod_sum, robust;
local coef: display %5.3f _b[cod_sum];
local se: display %5.3f _se[cod_sum];
	
pwcorr labor_relations cod_sum, sig;
local corrtemp = r(C)[2,1];	
local corr: display %5.3f `corrtemp';
local se_corrtemp = r(sig)[2,1];
local se_corr: display %5.3f `se_corrtemp';

	
binscatter labor_relations cod_sum, 
	reportreg replace yscale(range(1 7)) ylabel(1(1)7, angle(horizontal)) `graphopts'
	text(1.65 0.1 "Slope = `coef' (SE `se')" 1.3 0.1 "Corr = `corr' (p-value `se_corr')", size(large)
	placement(e)) 
	ytitle("Labor-Management Cooperation", size(large))
	xtitle("Strength of Codetermination Laws", size(large));
graph export "${outfolder}/binscatter_labor_relations.pdf", replace;
graph export "${outfolder}/binscatter_labor_relations.png", replace;

	
