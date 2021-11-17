/* [Introduction]

Our results draw on the following raw data files, all of which (except for the
European Company Survey files) are contained in the "Raw Data" folder:

1. "World_Countries.shp" and "World_Countries.dbf" (standard shape files for Stata's
	'spmap' command)
2. "World Bank - annual population.csv" and "World Bank - pct of population who are working age.csv",
	which are datasets at the country-year level from the World Bank that enable us
	to calculate the number of working-age people in each country-year in our data 
	(information which we use to normalize our strikes variable). The datasets are
	downloaded from the following URL: https://data.oecd.org/pop/population.htm#indicator-chart
3. "cbr_data.xlsx", which is the dataset from the CBR Labor Regulation Index
	compiled by Adams, Bishop, and Deakin (2016). This dataset is downloaded from
	the following URL: https://www.repository.cam.ac.uk/handle/1810/256566
4. Several Excel files named "ILO_COUNTRYNAME.xlsx", which contain data on strike
	intensity at the country-year level (and population, which we use to fill in years
	prior to 1960, which is when the World Bank population data start). These data
	are sourced from International Labour Organization Yearbooks; they are compiled
	by Sjaak van der Velden, whom we thank, and the full source dataset is available for download
	at the following URL: https://datasets.iisg.amsterdam/dataverse/Global
5. Several .txt files named "AMECOnum.txt", which contain data on aggregate 
	economic outcomes from the European Commission's AMECO database. They are
	available for download at the following URL: 
	https://ec.europa.eu/info/business-economy-euro/indicators-statistics/economic-databases/macro-economic-database-ameco/download-annual-data-set-macro-economic-database-ameco_en
6. "ecs13_management.dta" and "ecs19_management.dta". These are responses to the 
	management questionnaires in the 2013 and 2019 waves of the European Company
	Survey. They are available for download via the UK Data Service
7. "WEF labor relations.xlsx" presents average responses at the country-year level 
	to a question in the World Economic Forum's Executive Opinion Survey, about
	the cooperativeness of labor relations. The data are available since 2007.
	The source file, "WEF labor relations source file.xlsx", can be downloaded
	from the following URL: 
	http://reports.weforum.org/global-competitiveness-report-2015-2016/competitiveness-dataset-xls/
8. "OECD Institutions Data.xlsx", which contains historical data at the country-year
	level on works council powers, union density, and centralization in collective bargaining.
	The data are drawn from the OECD/IAIS ICTWSS dataset, accessible at the following
	URL: https://www.oecd.org/employment/ictwss-database.htm

This file also requires the installation of several commands from ssc, including 'xls2dta',
'reghdfe', [others?]


 */

* defining paths
if "`c(username)'"=="shakkednoy" {
		
	global workingfolder "/Users/shakkednoy/Dropbox/Codetermination_EPI/Replication File"
	
	global rawfolder "${workingfolder}/Raw Data"
	global intermediate "${workingfolder}/Intermediate Stata Data"
	global outfolder "${workingfolder}/Output"
	global adopath "${workingfolder}/Ado"
	
	cd "${intermediate}"
	
}
if "`c(username)'"=="predoc" {
		
	global workingfolder "/Users/predoc/Dropbox/Codetermination_EPI/Replication File"
	
	global rawfolder "${workingfolder}/Raw Data"
	global intermediate "${workingfolder}/Intermediate Stata Data"
	global outfolder "${workingfolder}/Output"
	global adopath "${workingfolder}/Ado"
	
	cd "${intermediate}"
	
}

********************* data cleaning and preparation ****************************

* creating list of codetermination reforms (and Fig A.13)
do "${workingfolder}/Stata Code/List of codetermination reforms.do"
/*
This file manually creates a dataset containing the list of country-reforms
that we use in our event-study analyses, as well as a graph visualizing
the list of reforms (this graph is Appendix Figure A.13). 

Input files: none
Intermediate Stata Data files created: reforms_new_ameco.dta, reforms_new_ilo.dta
Output files created: reforms_timeline.pdf
*/

* creating country-year population dataset
do "${workingfolder}/Stata Code/World Bank population data.do"
/* 
This file cleans and reshapes the World Bank data to create a dataset
containing the size of a country's working-age population at the country-year level.

Input files: "World Bank - pct of population who are working age.csv" and 
	"World Bank - annual population.csv"
Intermediate Stata Data files created: worldbank_population.dta
Output files: none
*/


* cleaning ILO strikes data
do "${workingfolder}/Stata Code/ILO strikes data cleaning.do"
/* This file cleans each country's ILO dataset, merges them together,
and prepares a dataset containing strike intensity rank at the country-year level
for our event-study analyses.

Input files: ILO_COUNTRYNAME.xlsx, worldbank_population.dta, reforms_new_ilo.dta
Intermediate Stata Data files created: ilo_variables.dta, 'country'_workingpop.dta
Output files created: none
*/

* cleaning AMECO economic data
do "${workingfolder}/Stata Code/AMECO economic data cleaning.do"
/* This file cleans the AMECO datasets and prepares a dataset at the country-year
level with information on wage growth, the labor share, TFP growth, net capital formation,
and GDP per capita growth.

Input files: AMECOnum.txt, reforms_new_ameco.dta, 'country'_workingpop.dta'
Intermediate Stata Data files created: ameco_variables.dta
Output files created: none */

* merging ILO and AMECO datasets
do "${workingfolder}/Stata Code/Merging ILO and AMECO data.do"
/* This file merges together the ILO and AMECO datasets created by the previous
two .do files, to create a single file used in our event-study analyses

Input files: ilo_variables.dta, ameco_variables.dta
Intermediate Stata Data files created: analysis_full.dta
Output files created: none
*/

* maps of board-level and shop-floor representation laws (Figures 1 and 2)
do "${workingfolder}/Stata Code/CBR Maps.do"
/* This file creates the maps of board-level and shop-floor representation laws
worldwide, drawing on CBR Labor Regulation Index data. 

Input files: World_Countries.shp, World_Countries.dbf, cbr_data.xlsx
Intermediate Stata Data files created: pop_world.dta, coords_world.dta, mapdata.dta, cbr_regulationrankings.dta
Output files created: map_codetermination.pdf, map_works_councils.pdf
*/

* map of shop-floor representative powers, comparison of institutions, and union density DiD (Figures 3 and 4, and 6b)
do "${workingfolder}/Stata Code/OECD and CBR Institutions data cleaning and analysis.do"
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

* main DiD analyses (economic outcomes and strikes) (Fig 5)
do "${workingfolder}/Stata Code/Event-study analyses.do"
/* This file produces our main event-study results for our economic and strikes
outcome variables.

Input files: analysis_full.dta
Intermediate Stata Data files created: none relevant to other files
Output files created: synthplot_VARNAME_COUNTRYNAME.pdf, testplot_VARNAME.pdf,
	rawplot_VARNAME.pdf, eventstudy_VARNAME.pdf
*/

* cross-sectional relationship between industrial relations cooperativeness and codetermination laws (Fig 6c)
do "${workingfolder}/Stata Code/WEF labor relations cross-sectional analysis.do"
/* This file analyzes the cross-sectional relationship between the presence of codetermination
laws in a country and the cooperativeness of that country's labor relations, drawing on
the World Economic Forum's Executive Opinion Survey and the CBR Labor Regulation Index dataset.


Input files: "WEF labor relations.xlsx", mapdata.dta, 
Intermediate Stata Data files created: none relevant to other files
Output files created: binscatter_labor_relations.pdf

*/

* ECS influence descriptives (Fig 7)
do "${workingfolder}/Stata Code/ECS data cleaning and analysis.do"

/* This file creates descriptive statistics on worker involvement in firms with
and without formal codetermination, drawing on the 2013 and 2019 European Company Survey.

Input files: ecs13_management.dta, ecs19_management_dta, cbr_data.xlsx
Intermediate Stata Data files created: none relevant to other files
Output files created: ecs_involved13.pdf, ecs_influence_comparison19_num.pdf,
	ecs_involved13_stacked.pdf, ecs_binscatter_laws_voice.pdf


*/

do "${workingfolder}/Stata Code/WID data cleaning and analysis.do"

/* This file cleans income inequality data from the World Inequality Database
and generates event-study results for the income inequality outcome variable.

Input files: wid_rawdata.dta, ameco_variables_wid.dta, analysis_full.dta
Intermediate Stata Data files created: none relevant to other files
Output files created: synthplot_VARNAME_COUNTRYNAME.pdf, testplot_VARNAME.pdf,
	rawplot_VARNAME.pdf, eventstudy_VARNAME.pdf, where VARNAME = share_bottom90
	
*/



