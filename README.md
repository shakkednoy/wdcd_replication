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

