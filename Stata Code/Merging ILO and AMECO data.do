/* This file merges together the ILO and AMECO datasets created by the previous
two .do files, to create a single file used in our event-study analyses

Input files: ilo_variables.dta, ameco_variables.dta
Intermediate Stata Data files created: analysis_full.dta
Output files created: none
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

use ameco_variables, clear;

merge 1:1 country year using ilo_variables, keep(master match) nogen
	keepusing(rank_strikes);
	
***;
merge 1:1 country year using penndata_clean, keep(master match) keepusing(capital_intensity);
***;

egen countrygroup = group(country);

drop treated;

save analysis_full, replace;
