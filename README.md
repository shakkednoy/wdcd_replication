# wdcd_replication
This repository contains the data and code necessary to replicate the results in "What Does Codetermination Do?" (Jäger, Noy, and Schoefer, 2021, ILR Review), with the exception of the European Company Survey data (which are not publicly available, but can be downloaded with a license).

INSTRUCTIONS:
- Download the raw data files in the folder "Raw Data", and save them in a folder named "Raw Data"
- Download the .do files in the folder "State Code", and save them in a folder named "Stata Code"
- Download "Master File.do", and update the working directory and paths at the top of the document to match your computer
- Run "Master File.do"

EXPLANATION:

The Raw Data folder contains the following files:
- "World_Countries.shp" and "World_Countries.dbf" (standard shape files for Stata's
	'spmap' command)
- "World Bank - annual population.csv" and "World Bank - pct of population who are working age.csv",
	which are datasets at the country-year level from the World Bank that enable us
	to calculate the number of working-age people in each country-year in our data 
	(information which we use to normalize certain outcome variables). The datasets are
	downloaded from the following URL: https://data.oecd.org/pop/population.htm#indicator-chart
- "cbr_data.xlsx", which is the dataset from the CBR Labor Regulation Index
	compiled by Adams, Bishop, and Deakin (2016). This dataset is downloaded from
	the following URL: https://www.repository.cam.ac.uk/handle/1810/256566
- Several Excel files named "ILO_COUNTRYNAME.xlsx", which contain data on strike
	intensity at the country-year level (and population, which we use to fill in years
	prior to 1960, which is when the World Bank population data start). These data
	are sourced from International Labour Organization Yearbooks; they are compiled
	by Sjaak van der Velden, whom we thank, and the full source dataset is available for download
	at the following URL: https://datasets.iisg.amsterdam/dataverse/Global
- Several .txt files named "AMECOnum.txt", which contain data on aggregate 
	economic outcomes from the European Commission's AMECO database. They are
	available for download at the following URL: https://ec.europa.eu/info/business-economy-euro/indicators-statistics/economic-databases/macro-economic-database-ameco/download-annual-data-set-macro-economic-database-ameco_en
- "WEF labor relations.xlsx" presents average responses at the country-year level 
	to a question in the World Economic Forum's Executive Opinion Survey, about
	the cooperativeness of labor relations. The data are available since 2007.
	The source file, "WEF labor relations source file.xlsx", can be downloaded
	from the following URL: http://reports.weforum.org/global-competitiveness-report-2015-2016/competitiveness-dataset-xls/
- "OECD Institutions Data.xlsx", which contains historical data at the country-year
	level on works council powers, union density, and centralization in collective bargaining.
	The data are drawn from the OECD/IAIS ICTWSS dataset, accessible at the following
	URL: https://www.oecd.org/employment/ictwss-database.htm

NOTES:
Running the code requires installation of the following (possibly non-exhaustive) list of Stata packages:
