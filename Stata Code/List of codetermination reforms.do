/*
This file manually creates a dataset containing the list of country-reforms
that we use in our event-study analyses, as well as a graph visualizing
the list of reforms (this graph is Appendix Figure A.13). 

Input files: none
Intermediate Stata Data files created: reforms_new_ameco.dta, reforms_new_ilo.dta
Output files created: reforms_timeline.pdf
*/

#delimit;
set more off;
clear all;

local graphopts "graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))";

* creating a list containing the country, its year(s) of reform(s), and the type(s) of the reform(s);
set obs 8;
gen country = ".";
gen reformyear1 = .;
gen reformyear2 = .;
gen boardlevel1 = 0;
gen boardlevel2 = 0;

replace country = "Austria" if _n==1;
replace reformyear1 = 1975 if _n==1;
replace boardlevel1 = 1 if _n==1;

replace country = "Denmark" if _n==2;
replace reformyear1 = 1973 if _n==2;
replace boardlevel1 = 1 if _n==2;

replace country = "Sweden" if _n==3;
replace reformyear1 = 1976 if _n==3;
replace boardlevel1 = 0 if _n==3;

replace country = "Norway" if _n==4;
replace reformyear1 = 1966 if _n==4;
replace boardlevel1 = 0 if _n==4;
replace reformyear2 = 1973 if _n==4;
replace boardlevel2 = 1 if _n==4;

replace country = "Finland" if _n==5;
replace reformyear1 = 1978 if _n==5;
replace reformyear2 = 1990 if _n==5;
replace boardlevel1 = 0 if _n==5;
replace boardlevel2 = 1 if _n==5;

replace country = "France" if _n==6;
replace reformyear1 = 2013 if _n==6;
replace boardlevel1 = 1 if _n==6;

replace country = "Netherlands" if _n==7;
replace reformyear1 = 1979 if _n==7;
replace boardlevel1 = 0 if _n==7;

replace country = "Germany" if _n==8;
replace reformyear1 = 1976 if _n==8;
replace boardlevel1 = 1 if _n==8;

* saving dataset;
save reforms_new_ameco, replace;

drop if country=="France";
save reforms_new_ilo, replace;


* graph of reform timelines;
use reforms_new_ameco, clear;

expand 2;
sort country;
quietly by country: gen dup = cond(_N==1,0,_n);
drop if dup==2 & reformyear2==.;

replace reformyear1 = reformyear2 if dup==2;
replace boardlevel1 = boardlevel2 if dup==2;

egen countrygroup = group(country);
quietly su countrygroup;
replace countrygroup = (r(max)-countrygroup)+1;
labmask countrygroup, values(country);

twoway (scatter countrygroup reformyear1 if boardlevel1==1, color(green) msymbol(triangle_hollow) msize(large))
	(scatter countrygroup reformyear1 if boardlevel1==0, color(grey) msymbol(square) msize(large)), `graphopts'
	ylabel(1 "Sweden" 2 "Norway" 3 "Netherlands" 4 "Germany"
	5 "France" 6 "Finland" 7 "Denmark" 8 "Austria", angle(0)) ytitle("") xtitle("Year")
	legend(order(1 "Board-Level Reform" 2 "Shop-Floor Reform"));
graph export "${outfolder}/reforms_timeline.pdf", replace;
graph export "${outfolder}/reforms_timeline.png", replace;
