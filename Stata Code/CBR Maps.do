/* This file creates the maps of board-level and shop-floor representation laws
worldwide, drawing on CBR Labor Regulation Index data. 

Input files: World_Countries.shp, World_Countries.dbf, cbr_data.xlsx
Intermediate Stata Data files created: pop_world.dta, coords_world.dta, mapdata.dta, cbr_regulationrankings.dta
Output files created: map_codetermination.pdf, map_works_councils.pdf
*/


#delimit;
set more off;
clear all;

local graphopts "graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))";

********************** Section 1: manipulating raw data ************************;
cd "${rawfolder}";

* creating Stata mapping files from raw downloaded files;
shp2dta using "World_countries", 
	data("${intermediate}/pop_world") 
	coord("${intermediate}/coords_world") replace;
	
* loading and reshaping the CBR dataset;
forvalues n = 1/118 {;
	capture erase "${intermediate}/cbr_data_`n'.dta";
};
xls2dta, allsheets save("${intermediate}") 
	: import excel "cbr_data.xlsx";
	

**************** Section 2: cleaning the manipulated data **********************;

* changing working directory for convenience;
cd "${intermediate}";

* cleaning each sheet of the CBR data;
forvalues n = 2/118 {;
	use cbr_data_`n', clear;
	
	* renaming and dropping variables;
	rename A COUNTRY;
	rename C year;
	rename AG codetermination;
	rename AH works_councils;
	rename AB unions1;
	rename AC unions2;
	rename AD unions3;
	rename AE unions4;
	
	local maxval = _N;
	forvalues m = 1/`maxval' {;
		replace COUNTRY = COUNTRY[1];
	};
	
	* destringing;
	foreach var in B D E F G H I J K L M N O P Q R S T U V W X Y Z AA AF 
		AI AJ AK AL AM AN AO AP AQ {;
		destring `var', replace;
	};
	
	* correcting an error in the raw data;
	replace unions1 = 1 if COUNTRY=="Montenegro";
	
	* measure of union strength;
	gen union_strength = unions1+unions2+unions3+unions4;
	
	save cbr_temp_`n', replace;
	
	* keeping only the most recent observation of these regulations;
	quietly su year;
	keep if year==r(max);
	
	save cbr_clean_`n', replace;
};

***** temporarily saving a longitudinal CBR dataset at the country-year level;
clear;
forvalues n = 2/118 {;
	append using cbr_temp_`n', force;
	capture erase cbr_temp_`n';
};

* disambiguation of country names in advance of merging onto the shape files;
replace COUNTRY = "Algeria" if COUNTRY=="algeria";
replace COUNTRY = "Australia" if COUNTRY=="australia";
replace COUNTRY = "Austria" if COUNTRY=="austria";
replace COUNTRY = "United States" if COUNTRY=="USA ";
replace COUNTRY = "Morocco" if COUNTRY=="Morocco ";
replace COUNTRY = "Kazakhstan" if COUNTRY=="Kazakhstan ";
replace COUNTRY = "South Korea" if COUNTRY=="Korea";
replace COUNTRY = "Democratic Republic of the Congo" if COUNTRY=="Democratic Republic of Congo";
replace COUNTRY = "United Kingdom" if COUNTRY=="UK";

drop if year==.;

save cbr_data_temp, replace;
*****;

* combining all of the sheets into one dataset;
clear;
forvalues n = 2/118 {;
	append using cbr_clean_`n', force;
	capture erase cbr_clean_`n';
};

* disambiguation of country names in advance of merging onto the shape files;
replace COUNTRY = "Algeria" if COUNTRY=="algeria";
replace COUNTRY = "Australia" if COUNTRY=="australia";
replace COUNTRY = "Austria" if COUNTRY=="austria";
replace COUNTRY = "United States" if COUNTRY=="USA ";
replace COUNTRY = "Morocco" if COUNTRY=="Morocco ";
replace COUNTRY = "Kazakhstan" if COUNTRY=="Kazakhstan ";
replace COUNTRY = "South Korea" if COUNTRY=="Korea";
replace COUNTRY = "Democratic Republic of the Congo" if COUNTRY=="Democratic Republic of Congo";
replace COUNTRY = "United Kingdom" if COUNTRY=="UK";

save cbr_data_final, replace;

* confirming that no country names need to be disambiguated;
merge 1:1 COUNTRY using pop_world, keep(master match);

* setting up mapping dataset, with countries absent from the CBR data receiving missing values; 
use pop_world, clear;
merge 1:1 COUNTRY using cbr_data_final, keep(master match using);

* dropping Antarctica to make the legend more readable;
drop if COUNTRY=="Antarctica";

save mapdata, replace;

*** creating dataset containing aggregate intensity labor market regulations;
use cbr_data_temp, clear;

keep if year==2013 | year==1970;

gen regulation = 0;

foreach var in D E F G H I J K L M N O P R Q S T U V W X Y Z AA AF AI AJ AK AL AM AN AO AP AQ {;
	replace regulation = regulation+`var';
};

keep COUNTRY year regulation;

* keeping only countries present in both years, to keep the rank calculation consistent;
sort COUNTRY;
quietly by COUNTRY: gen dup = cond(_N==1,0,_n);
egen maxdup = max(dup), by(COUNTRY);
drop if maxdup==0;

egen regulation_rank = rank(regulation), track by(year);
quietly su regulation_rank;
replace regulation_rank = 100*(regulation_rank/100);

replace year = 60 if year==1970;
replace year = 18 if year==2013;

egen countrygroup = group(COUNTRY);

keep COUNTRY year countrygroup regulation_rank;

reshape wide regulation_rank, i(countrygroup) j(year);

drop countrygroup;

save cbr_regulationrankings, replace;


********************** Section 3: generating the maps **************************;
cd "${intermediate}";

use mapdata, clear;

foreach var in codetermination works_councils {;

	spmap `var' using coords_world, id(_ID) fc(Reds) clm(unique)
		 legend(pos(8) size(large)) `graphopts' ndfcolor(gray);
	 
	graph export "${outfolder}/map_`var'.pdf", replace;
	graph export "${outfolder}/map_`var'.png", replace width(1500) height(650);
	 
};
	 


