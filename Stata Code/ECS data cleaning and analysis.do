/* This file creates descriptive statistics on worker involvement in firms with
and without formal codetermination, drawing on the 2013 and 2019 European Company Survey.

Input files: ecs13_management.dta, ecs19_management_dta, cbr_data.xlsx
Intermediate Stata Data files created: none relevant to other files
Output files created: ecs_involved13.pdf, ecs_influence_comparison19_num.pdf,
	ecs_involved13_stacked.pdf, ecs_binscatter_laws_voice.pdf


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

* Mac cd;
local workingfolder "/Users/shakkednoy/Dropbox/Codetermination_EPI/Stata";
local rawfolder "`workingfolder'/Raw Data";
local outfolder "`workingfolder'/Output";
cd "`workingfolder'/Intermediate Stata Data";
local graphopts "graphregion(fcolor(white) lcolor(white) ifcolor(white) ilcolor(white))";

********************* Cleaning the ECS management survey ***********************;

*** 2013;
use "${rawfolder}/ecs13_management", clear;

* country variable for merging on to mapping files;
decode country, gen(COUNTRY_temp);
replace COUNTRY_temp = "Macedonia" if country==31;
gen COUNTRY = ltrim(COUNTRY_temp);
drop COUNTRY_temp;

* private or public;
rename APRIVATE private_public_status;
recode private_public_status (8 9 = .);

* multi-site;
gen multi_site = ASINGLE==2;
replace multi_site = . if ASINGLE==9;

* number of hierarchical levels, top-coded at 10;
rename EHIERA num_hierarchy;
replace num_hierarchy = . if num_hierarchy>100;
replace num_hierarchy = 10 if num_hierarchy==10;
	
* member of an employers' organisation participating in collective bargaining;
rename AEMPORG org_cb;
recode org_cb (2 = 0) (8 9 = .);
label var org_cb "Member of an employers' organisation that participates in CB";

* types of CB agreements;
rename ICAEST cb_company;
rename ICASECT cb_sectoral;
rename ICAOCC cb_occupational;
rename ICANAT cb_national;

foreach var of varlist cb_* {;
	recode `var' (2 = 0) (8 9  = .);
};

gen covered_cb = cb_company==1 | cb_sectoral==1 | cb_occupational==1 | cb_national==1;
replace covered_cb = . if cb_company==. | cb_sectoral==. | cb_occupational==. | cb_national==.;

* establishment size (categorical variable with 3 categories);
rename est_size3 num_employees;

* industry code;
rename NACE6_R1_1 industry;
	
* change in number of employees in past 3 years;
gen change_emp_increased = BCHEMP==1;
gen change_emp_decreased = BCHEMP==2;
gen change_emp_constant = BCHEMP==3;
gen change_emp_msg = BCHEMP==8 | BCHEMP==9;
		
* presence of employee representation;
label var er_present "Company or establishment has employee representation";
	
* types of employee representation;
foreach sfx in A B C D E F G {;
	recode ERTYPE_`sfx' (2 = 0) (9 = .);
	/* As far as I can tell, companies are assigned missing values when
	this type of employee representation is not asked about in their country -
	i.e. it does not exist as an institution in their country */
};
rename ERTYPE_A rep_union;
rename ERTYPE_B rep_workscouncil;
gen rep_other = .;
foreach sfx in C D E F G {;
	replace rep_other = 1 if ERTYPE_`sfx'==1;
	replace rep_other = 0 if ERTYPE_`sfx'==0 & rep_other==.;
};
* rep_other = 1 if the company has some other type of employee representation;
* and it is missing if none of the alternative forms are applicable to the country;

* views on employee representation;
rename IINIMWPP view_er_constructive;
rename IINDELAY view_er_delay;
rename IINDIR view_er_prefdirect;
rename IINIMPEA view_er_buyin;
rename IERTRUS view_er_trustworthy;

label define agree
	1 "Strongly disagree"
	2 "Disagree"
	3 "Agree"
	4 "Strongly agree";

foreach var of varlist view_er* {;
	recode `var' (8 9 = .) (4 = 1) (1 = 4) (2 = 3) (3 = 2);
	label val `var' agree;
};

* more views questions - note these are asked of _everyone_, as hypotheticals about the effect employee involvement would have;
rename JEIDELAY allview_delay;
rename JEIRETEN allview_retention;
rename JEICOMP allview_competitive;

foreach var of varlist allview* {;
	recode `var' (8 9 = .) (4 = 1) (1 = 4) (2 = 3) (3 = 2);
	label val `var' agree;
};

* major changes in the establishment questions;
rename JCHREMU major_remuneration;
rename JCHTECH major_tech;
rename JCHALLOC major_allocation;
rename JCHRECRU major_recruitment;
rename JCHTIME major_time;

foreach var of varlist major* {;
	recode `var' (2 = 0) (8 9 = .);
};

rename JMOIMPCH which_one_major;
recode which_one_major (8 9 = .);
* note this is only asked of managers who reported more than one major change!;


* were employee representatives involved?;
rename JERINF er_informed;
rename JERCONS er_consulted;
rename JERDEC er_involved;
rename JERCOPR commonpractice_er;

* were employees directly involved?;
rename JEMPINF dir_informed;
rename JEMPCONS dir_consulted;
rename JEMPEC dir_involved;
rename JEMCOPR commonpractice_dir;

foreach var of varlist er_informed er_consulted er_involved dir* {;
	recode `var' (2 = 0) (8 9 = .);
};
foreach var in commonpractice_er commonpractice_dir {;
	recode `var' (8 9 = .) (1 = 4) (4 = 1) (3 = 2) (2 = 3);
	label val `var' agree;
};


keep org_cb num_employees change* er_present view_er* rep* cb_* covered_cb country COUNTRY allview*
	major* which_one_major er* dir* commonpractice* private_public_status num_hierarchy industry multi_site;

save ecs13_management_clean, replace;

*** 2019;
use "${rawfolder}/ecs19_management", clear;

* country variable for merging on to map data;
decode country, gen(COUNTRY);
replace COUNTRY = "Czech Republic" if COUNTRY=="Czechia";

* establishment size (categorical variable - small, medium, and large establishments);
rename est_size num_employees;
* note this is still 3-categories but defined slightly differently than the 2013 survey;

* number of hierarchical levels, top-coded at 10;
rename hiera num_hierarchy;
recode num_hierarchy (-9 -3 = .);

* industry;
rename scr_NACE industry;

* whether employees must act autonomously;
rename compprobs_d autonomous_solutions;
recode autonomous_solutions (-3 = .);
rename comorg_d autonomous_time;
recode autonomous_time (-3 = .);

* collective bargaining coverage;
foreach var in canat casec careg cacom caocc caoth {;
	recode `var' (2 = 0) (-3 = .);
};
rename canat cb_national;
rename casec cb_sectoral;
rename careg cb_regional;
rename cacom cb_company;
rename caocc cb_occupation;
rename caoth cb_other;

gen covered_cb = 0;
foreach var of varlist cb_* {;
	replace covered_cb = 1 if `var'==1;
};
label var covered_cb "Covered by some form of collective bargaining";

* types of employee representation;

gen rep_union = mmerconfirm_v3_1==1 | mmerconfirm_v4_1==1;
gen rep_steward = mmerconfirm_v3_2==1 | mmerconfirm_v4_2==1;
gen rep_workscouncil = mmerconfirm_v3_3==1 | mmerconfirm_v3_4==1 | mmerconfirm_v4_3==1
	| mmerconfirm_v4_4==1;
gen rep_other = 0;
forvalues x = 5/8 {;
	replace rep_other = 1 if mmerconfirm_v3_`x'==1 | mmerconfirm_v4_`x'==1;
};

* no employee representation;
gen rep_none = mmerconfirm_v4_9==1;

* correcting things for Sweden, Malta, and Cyprus;
replace rep_steward = 1 if mmerconfirm_v1==1 & (COUNTRY=="Sweden" | COUNTRY=="Malta");
replace rep_union = 1 if mmerconfirm_v1==1 & COUNTRY=="Cyprus";
recode mmerconfirm_v1 (2 -3 = 0);
replace rep_none = 1-mmerconfirm_v1 if (COUNTRY=="Sweden" | COUNTRY=="Malta" | COUNTRY=="Cyprus");

* flagging all remaining establishments;
gen rep_msg = 1;
replace rep_msg = 0 if (rep_union==1 | rep_steward==1 | rep_workscouncil==1 |
	rep_other==1 | rep_none==1);
* this encompasses establishments who gave a weird contradictory pattern of responses;

* this seems to make sense but I'm still suspicious of these data!;

* views of employee representation;
rename eratt view_er_constructive;
rename indir view_er_prefdirect;
rename ertrus view_er_trust;
rename eidelay view_er_delay;
rename eicomp view_er_competitive;

foreach var of varlist view_er* {;
	recode `var' (-3 = .) (1 = 4) (4 = 1) (2 = 3) (3 = 2);
};

label define constructive
	1 "Not at all constructive"
	2 "Not very constructive"
	3 "Fairly constructive"
	4 "Very constructive";
label val view_er_constructive constructive;

label define prefdirect
	1 "Pref not to consult with either"
	2 "Pref to consult with both"
	3 "Pref consult directly"
	4 "Pref consult representatives";
label val view_er_prefdirect prefdirect;

label define extent
	1 "Not at all"
	2 "To a small extent"
	3 "To a moderate extent"
	4 "To a great extent";
label val view_er_trust extent;
label val view_er_delay extent;
label val view_er_competitive extent;

rename mmepinorg involve_dir_organisation;
rename mmepindism involve_dir_dismissals;
rename mmepintrain involve_dir_training;
rename mmepintime involve_dir_workingtime;
rename mmepinpay involve_dir_payschemes;

rename mmerinorg involve_er_organisation;
rename mmerindism involve_er_dismissals;
rename mmerintrain involve_er_training;
rename mmerintime involve_er_workingtime;
rename mmerinpay involve_er_payschemes;

foreach var of varlist involve_* {;
	recode `var' (-7 -4 -3 = .) (1 = 4) (4 = 1) (2 = 3) (3 = 2);
	label val `var' extent;
};

* types of informal involvement;
gen regular_meetings = regmee==1;
gen regular_staffmeet = staffme==1;
gen regular_dissemination = dissinf==1;
gen regular_online = somedi==1;


keep num_employees cb_* rep* country COUNTRY covered_cb view* involve_* industry num_hierarchy autonomous*
	regular*;

save ecs19_management_clean, replace;


********************************* Panel (a) ************************************;

* descriptives on which major decisions occur;
use ecs13_management_clean, clear;

* are employee representatives consulted? are workers directly consulted?;
* again, a triple bar graph;

keep if dir_consulted!=.;
		
* # of observations in each category (for error bars);
gen not_er_present = er_present==0;
quietly su not_er_present;
local N1 = r(sum);
quietly su er_present;
local N2 = r(sum);
		
gen id = _n;
expand 3;

sort id;
quietly by id: gen dup = cond(_N==1,0,_n);

foreach suffix in informed consulted involved {;
	gen `suffix' = .;
	replace `suffix' = dir_`suffix' if dup==1 & er_present==0;
	replace `suffix' = dir_`suffix' if dup==2 & er_present==1;
	replace `suffix' = er_`suffix' if dup==3 & er_present==1;
};

save involved13_temp`sfx', replace;

collapse (mean) informed consulted involved (sd) sd_informed=informed
	sd_consulted=consulted sd_involved=involved, by(dup);

rename informed var1;
rename consulted var2;
rename involved var3;
		
rename sd_informed sd1;
rename sd_consulted sd2;
rename sd_involved sd3;

reshape long var sd, i(dup) j(jvar);

* converting to percent;
replace var = var*100;
replace sd = sd*100;
		
* top and bottom of error bars;
gen high = .;
replace high = var+((1.96*sd)/sqrt(`N1')) if dup==1;
replace high = var+((1.96*sd)/sqrt(`N2')) if dup==2 | dup==3;
gen low = .;
replace low = var-((1.96*sd)/sqrt(`N1')) if dup==1;
replace low = var-((1.96*sd)/sqrt(`N2')) if dup==2 | dup==3;
	
capture label drop dup;
label define dup
	1 "Workers directly (no ER)"
	2 "Workers directly (ER present)"
	3 "Emp reps (ER present)";
label val dup dup;
			
capture label drop jvar;
label define jvar
	1 "Informed"
	2 "Asked to Give View"
	3 "Involved in Decision";
label val jvar jvar;
		
		
gen xvar = .;
replace xvar = 100 if dup==1 & jvar==1;
replace xvar = 200 if dup==2 & jvar==1;
replace xvar = 300 if dup==3 & jvar==1;

replace xvar = 475 if dup==1 & jvar==2;
replace xvar = 575 if dup==2 & jvar==2;
replace xvar = 675 if dup==3 & jvar==2;

replace xvar = 850 if dup==1 & jvar==3;
replace xvar = 950 if dup==2 & jvar==3;
replace xvar = 1050 if dup==3 & jvar==3;
		
label define xvar 
	200 "Informed"
	575 "Asked to Give view"
	950 "Involved in Decision";
label val xvar xvar;
splitvallabels xvar, length(30);
			

twoway (bar var xvar if dup==1, bcolor(maroon) fcolor(maroon%0) barwidth(0.5) lwidth(thick) barwidth(100))
   (bar var xvar if dup==2, bcolor(maroon) fcolor(maroon%50) barwidth(0.5) lwidth(thick) barwidth(100))
   (bar var xvar if dup==3, color(navy) barwidth(100))
   (rcap high low xvar), ytitle("% of Firms", size(large)) `graphopts'
		yscale(range(0 100)) ylabel(0(20)100, angle(horizontal)) legend(order(1 "Workers Directly (Firms without Worker Representation)"
		2 "Workers Directly (Firms with Worker Representation)" 3 "Worker Representatives (Firms with Worker Representation)") cols(1))
		xlabel(200 "Informed" 575 "Asked to Give View" 950 "Involved in Decision", noticks)
		xtitle("") title("", color(black));
graph export "${outfolder}/ecs_involved13.pdf", replace;
graph export "${outfolder}/ecs_involved13.png", replace;


********************************** Panel (b) ***********************************;



use ecs19_management_clean, clear;
	
keep involve* rep_none country;

quietly su rep_none;
local N1 = r(sum);
gen er_present = rep_none==0;
quietly su er_present;
local N2 = r(sum);

gen id = _n;

expand 3;

sort id;
quietly by id: gen dup = cond(_N==1,0,_n);

foreach suffix in organisation dismissals training workingtime payschemes {;

	gen involve_`suffix' = .;
		
	* direct involvement in workplaces _without_ employee representation;
	replace involve_`suffix' = involve_dir_`suffix' if dup==1;
	replace involve_`suffix' = . if dup==1 & rep_none!=1;
		
	* direct involvement in workplaces _with_ employee representation;
	replace involve_`suffix' = involve_dir_`suffix' if dup==2;
	replace involve_`suffix' = . if dup==2 & rep_none==1;
		
	* ER involvement in workplaces _with_ employee representation;
	replace involve_`suffix' = involve_er_`suffix' if dup==3;
	replace involve_`suffix' = . if dup==3 & rep_none==1;
		
	forvalues m = 1/4 {;
		gen involve_`suffix'_n`m' = involve_`suffix'==`m';
		replace involve_`suffix'_n`m' = . if involve_`suffix'==.;
	};		
};


local sdlist "";
foreach suffix in organisation dismissals training workingtime payschemes {;
	forvalues m = 1/4 {;
		local sdlist "`sdlist' sd_involve_`suffix'_n`m'=involve_`suffix'_n`m'";
	};
};

collapse (mean) *_n1 *_n2 *_n3 *_n4 (sd) `sdlist', by(dup);
		
reshape long involve_organisation_n sd_involve_organisation_n involve_dismissals_n sd_involve_dismissals_n
	involve_training_n sd_involve_training_n involve_workingtime_n sd_involve_workingtime_n
	involve_payschemes_n sd_involve_payschemes_n, i(dup) j(jvar);
		
capture label drop dup;
label define dup
	1 "Direct involve. (no ER)"
	2 "Direct involve. (ER present)"
	3 "ER involvement (ER present)";
label val dup dup;

capture label define extent
	1 "Not at all"
	2 "To a small extent"
	3 "To a moderate extent"
	4 "To a great extent";
label val jvar extent;

forvalues n = 1/5 {;
	capture erase graph`n'.gph;
	capture erase pitchgraph`n'.gph;
};	

gen xvar = .;
replace xvar = 1 if dup==1 & jvar==1;
replace xvar = 2 if dup==2 & jvar==1;
replace xvar = 3 if dup==3 & jvar==1;

replace xvar = 4.75 if dup==1 & jvar==2;
replace xvar = 5.75 if dup==2 & jvar==2;
replace xvar = 6.75 if dup==3 & jvar==2;

replace xvar = 8.5 if dup==1 & jvar==3;
replace xvar = 9.5 if dup==2 & jvar==3;
replace xvar = 10.5 if dup==3 & jvar==3;

replace xvar = 12.25 if dup==1 & jvar==4;
replace xvar = 13.25 if dup==2 & jvar==4;
replace xvar = 14.25 if dup==3 & jvar==4;

local n = 0;

foreach suffix in organisation dismissals training workingtime payschemes {;

	local n = `n'+1;
		
	if "`suffix'"=="organisation" local title "Organisation of work";
	if "`suffix'"=="dismissals" local title "Dismissals";
	if "`suffix'"=="training" local title "Training";
	if "`suffix'"=="workingtime" local title "Working time arrangements";
	if "`suffix'"=="payschemes" local title "Payment schemes";

	* converting to percent;
	replace involve_`suffix'_n = involve_`suffix'_n*100;
	replace sd_involve_`suffix'_n = sd_involve_`suffix'_n*100;
		
	* top and bottom error bars;
	gen high_`suffix'_n = .;
	replace high_`suffix'_n = involve_`suffix'_n+((1.96*sd_involve_`suffix'_n)/sqrt(`N1')) if dup==1;
	replace high_`suffix'_n = involve_`suffix'_n+((1.96*sd_involve_`suffix'_n)/sqrt(`N2')) if dup==2 | dup==3;
	gen low_`suffix'_n = .;
	replace low_`suffix'_n = involve_`suffix'_n-((1.96*sd_involve_`suffix'_n)/sqrt(`N1')) if dup==1;
	replace low_`suffix'_n = involve_`suffix'_n-((1.96*sd_involve_`suffix'_n)/sqrt(`N2')) if dup==2 | dup==3;

	twoway (bar involve_`suffix'_n xvar if dup==1, bcolor(maroon) fcolor(maroon%0) lwidth(thick))
	   (bar involve_`suffix'_n xvar if dup==2, bcolor(maroon) fcolor(maroon%50) lwidth(thick))
	   (bar involve_`suffix'_n xvar if dup==3, color(navy))
	   (rcap high_`suffix'_n low_`suffix'_n xvar), ytitle("% of Firms", size(large)) `graphopts'
	   yscale(range(0 50)) ylabel(0(10)50, angle(horizontal)) legend(order(1 "Workers Directly (Firms without Worker Representation)"
		2 "Workers Directly (Firms with Worker Representation)" 3 "Worker Representatives (Firms with Worker Representation)") cols(1))
		xlabel(2 "Not at All" 5.75 "Small Extent" 9.5 "Moderate Extent" 13.25 "Great Extent", noticks)
		xtitle("");
	graph export "${outfolder}/ecs_influence_comparison19_`n'.pdf", replace;
	graph export "${outfolder}/ecs_influence_comparison19_`n'.png", replace;
	
};

		
*********************************** Panel (c) **********************************;
use ecs13_management_clean, clear;

forvalues n = 1/2 {;
	capture erase graph`n'.gph;
};

keep if dir_informed!=.;

label define num_employees
	1 "Small"
	2 "Medium" 
	3 "Large", replace;
label val num_employees num_employees;

local n = 0;
foreach suffix in consulted involved {;

	local n = `n'+1;
	
	if "`suffix'"=="consulted" local title "Consulted";
	if "`suffix'"=="involved" local title "Involved";

	gen dir_only_`suffix' = dir_`suffix'==1 & er_`suffix'!=1;
	gen er_only_`suffix' = dir_`suffix'!=1 & er_`suffix'==1;
	gen both_`suffix' = dir_`suffix'==1 & er_`suffix'==1;
	gen none_`suffix' = dir_`suffix'!=1 & er_`suffix'!=1;
	
	foreach var in none_`suffix' dir_only_`suffix' er_only_`suffix' both_`suffix' {;
		replace `var' = 100*`var';
	};
	
	graph bar none_`suffix' dir_only_`suffix' er_only_`suffix' both_`suffix', over(num_employees) stack
		`graphopts'  ytitle("% of Firms", size(large)) legend(order(1 "Neither" 2 "Workers Directly" 3 "Worker Representatives " 4 "Both")) 
		b1title("Firm Size") asyvars bar(1, color(gs12*0.5)) bar(2, bcolor(maroon*0.8) fcolor(maroon%0) lwidth(thick)) bar(3, bcolor(navy*0.8)) bar(4, bcolor("111 72 111"*0.8) fcolor("111 72 111"*0.3) lwidth(thick))
			title(`title', color(black)) ylabel(,angle(horizontal));
	graph save graph`n'.gph;
	
};

grc1leg graph1.gph graph2.gph, `graphopts' legendfrom(graph1.gph);
graph export "${outfolder}/ecs_involved13_stacked.pdf", replace;
graph export "${outfolder}/ecs_involved13_stacked.png", replace;


********************************** Panel (d) ***********************************;

* foreach var in workrep_anykind;

local ytitle "% of Firms with Worker Involvement";

local controlvars "";
		
use ecs13_management_clean, clear;
			
keep if dir_involved!=.;
gen workrep_anykind = dir_involved==1 | er_involved==1;

local title "All firms";

local location "35 0.44";
local location2 "32.5 0.49";

collapse (mean) workrep_anykind, by(COUNTRY);

replace workrep_anykind = workrep_anykind*100;


* merging on "codetermination laws" data;
gen year = 2013;
merge 1:1 COUNTRY year using "`rawfolder'/cbr_data", keep(master match);

gen er_strength = codetermination+works_councils;


					
reg workrep_anykind er_strength, robust;

local coef_raw = _b[er_strength];
local se_raw = _se[er_strength];

local coef: display %5.3f `coef_raw';
local se: display %5.3f `se_raw';
			
pwcorr workrep_anykind er_strength, sig;
			local corrtemp = r(C)[2,1];
local corr: display %5.3f `corrtemp';
			local se_corrtemp = r(sig)[2,1];
			local se_corr: display %5.3f `se_corrtemp';
			
gen labpos = 3;
replace labpos = 9 if COUNTRY=="Bulgaria" | COUNTRY=="Netherlands";
replace labpos = 4 if COUNTRY=="Poland";
replace labpos = 2 if COUNTRY=="Spain" | COUNTRY=="Denmark";
replace labpos = 11 if COUNTRY=="France";

			
twoway (scatter workrep_anykind er_strength, mlabel(COUNTRY) mlabvpos(labpos))
	(lfit workrep_anykind er_strength),  `graphopts' xscale(range(0 2.22))
	text(`location' "Slope = `coef' (SE `se')" `location2' "Corr = `corr' (p-value `se_corr')", size(medium))
	 xtitle("Strength of Codetermination Laws", size(large)) ytitle(`ytitle', size(large)) ylabel(,angle(horizontal)) legend(off); 
				
	graph export "${outfolder}/ecs_binscatter_laws_voice.pdf", replace;
	graph export "${outfolder}/ecs_binscatter_laws_voice.png", replace;
			
				
