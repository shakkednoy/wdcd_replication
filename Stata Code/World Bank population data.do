/* 
This file cleans and reshapes the World Bank data to create a dataset
containing the size of a country's working-age population at the country-year level.

Input files: "World Bank - pct of population who are working age.csv" and 
	"World Bank - annual population.csv"
Intermediate Stata Data files created: worldbank_population.dta
Output files: none
*/


#delimit;
set more off;
clear all;

local graphopts "graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))";

* loading data on pct of population who are working age;
import delimited "${rawfolder}/World Bank - pct of population who are working age.csv";

* renaming and dropping variables;
keep ïlocation time value;
* in some computers the first variable loads as just "location";

rename value pop_pct;
rename ïlocation country;
rename time year;

* loading data on population numbers;
save worldbank_pct, replace;

import delimited "${rawfolder}/World Bank - annual population.csv", clear;

* renaming and dropping variables;
keep ïlocation time value;

rename value pop_total;
rename ïlocation country;
rename time year;

* merging with "pct who are working age" dataset;
merge m:1 country year using worldbank_pct, keep(master match);

* calculating size of working-age population;
gen pop = pop_total*(pop_pct/100);
label var pop "Working-age population (millions)";

keep country year pop pop_pct;

* recoding from 3-digit abbreviations to full country names;
replace country = "Australia" if country=="AUS";
replace country = "Austria" if country=="AUT";
replace country = "Belgium" if country=="BEL";
replace country = "Denmark" if country=="DNK";
replace country = "Canada" if country=="CAN";
replace country = "Finland" if country=="FIN";
replace country = "France" if country=="FRA";
replace country = "Germany" if country=="DEU";
replace country = "Greece" if country=="GRC";
replace country = "Iceland" if country=="ISL";
replace country = "Ireland" if country=="IRL";
replace country = "Italy" if country=="ITA";
replace country = "Netherlands" if country=="NLD";
replace country = "Norway" if country=="NOR";
replace country = "Sweden" if country=="SWE";
replace country = "Switzerland" if country=="CHE";
replace country = "UK" if country=="GBR";
replace country = "US" if country=="USA";

save worldbank_population, replace;


