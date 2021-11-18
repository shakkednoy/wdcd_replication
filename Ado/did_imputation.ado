*! did_imputation: Treatment effect estimation and pre-trend testing in staggered adoption diff-in-diff designs with an imputation approach of Borusyak, Jaravel, and Spiess (2021)
*! Version: April 27, 2021
*! Author: Kirill Borusyak
*! Please check the latest version at https://www.dropbox.com/sh/r7wy4wjpwxy5uyy/AADxVrOHP653damnqpy_OhN1a?dl=0
*! Updates: general types of FE allowed now (e.g. with no unit FE or for repeated cross-sections)
*! Citation: Borusyak, Jaravel, and Spiess, "Revisiting Event Study Designs: Robust and Efficient Estimation" (2021)

/*
Syntax: did_imputation Y i t Ei [if] [in] [aw iw fw], [optional parameters]

Requires: recent version of reghdfe. If you are getting error messages (e.g. "verbose must be between 0 and 5" or r(123)) please first reinstall reghdfe to make sure you have the most recent version.

Main parameters (before the comma):
Y = outcome variable
i = varible for unique unit id
t = varible for calendar period
Ei = varible for unit-specific date of treatment (missing is interpreted as never-treated)
These main parameters imply the treatment indicator D=(t>=Ei) and the number of periods since treatment K=(t-Ei)/delta (possibly modified by the `shift' option below)

Weights:  aw/iw/fw are allowed and produce identical results. Weights should always be non-negative. The weights play two roles. 
- First, imputation is done by a weighted regression. This is most efficient when the variance of the error term is inversely proportionate to the weights
- Second, the average that defines the estimand is weighted by these weights. If wtr is specified explicitly, the weights are applied on top(!) of them.

Optional parameters:
- wtr(varlist): variables which define the estimand by storing the weights on the treated observations (values for controls are ignored, except as initial values in the iterative procedure for computing SE). If nothing is specified, the default is a simple average of all treated observations (within the if clause), so wtr=1/# of those. OK for wtr to not add up to one but wtr<0 is allowed only if option "sum" is also specified. Typically only one variable is specified but multiple are allowed for faster estimation and getting the joint variance-covariance matrix.
- sum: if specified, the weighted sum of treatment effects is computed (overall and by horizons), instead of a weighted average. With sum specified, it's OK to have some wtr<0 or even adding up to zero; this is useful, for example, to estimate the difference between two weighted averages of treatment effects
- Horizons(numlist): an optional list of non-negative integers. If specified, weighted averages/sums of treatment effects will be reported for each of these horizons (i.e. in the treatment date for h=0, one period after for h=1, etc.), besides the overall sum.
- ALLHorizons: picks all non-negative horizons available in the sample
- HBALance: if specified together with a list of horizons, estimands for each of the horizons will be based only on the subset of units for which observations for all chosen horizons are available (note that by contruction this means that the estimands will be based on different periods). If wtr or aw/iw/fw weights are provided, the researcher needs to make sure that such weights are constant over time for the relevant units---otherwise proper balancing is impossible and an error will be thrown. Note that excluded units will still be used in the imputation step (e.g. to recover the time fixed effect) and pre-trend tests.
- minn: the minimum effective number (i.e. inverse Herfindahl index) of treated observations, below which a coefficient is suppressed and a warning is issued.
- AUTOSample: if specified, the observations for which FE cannot be imputed will be automatically dropped from the sample, with a warning issued. Otherwise an error will be thrown if any such observations are found. Autosample cannot be combined with options sum or hbalance; please specify the sample explicitly if using one of those options.
- SAVEestimates(newvarname): if specified, a new variable where estimates of treatment effects for each observation are stored. These estimates are not consistent of course but weighted sums of many of them typically are. The researcher can then construct weighted averages of their interest manually (without SE)
- SAVEWeights: if specified, new variables where weights corresponding to (each) estimator are saved in variables called __w_*. The DiD imputation estimator is a linear estimator that can be represented as a weighted sum of the outcomes (with weights that add up to zero for every unit and time period). For treated observations this equals to the corresponding wtr. [what about fw here?]
- LOADWeights(varlist): use this to speed up the analysis of different outcome variables with an identical specification on an identical sample. To do so, provide the set of the weight variables (__w* but can be renamed of course), saved using the saveweights option when running the analysis for the first outcome. [Warning: the validity of the weights is assumed and not double-checked!]
- shift(integer): specify to allow for anticipation effects (or, if no ancitipation effects are expected, for a placebo test). The command will pretend that treatment happened `shift' periods earlier. Note that output is measured relative to the pseudo treated date Ei-shift (e.g. _b[tau0] is the anticipation effect `shift' periods before treatment).
- PREtrends(integer): if some value P>0 is specified, also performs a test for parallel trends, by a separate(!) regression with nontreated observations only, of the outcome on the dummies for 1,...,P periods before treatment, in addition to all the FE and controls. The coefficients are reported as pre1, ..., preP. The Wald statistic, pvalue, and degrees-of-freedom as reported in e(pre_chi2), e(pre_p), and e(pre_df) resp. Note 1: with too many pre-trend coefficients the power of the joint test will be lower. Note 2: the entire sample of nontreated observations is always used (regardless of `hbalance' and other options that restrict the sample for post-treatment effect estimation). Note 3: the test does not affect the post-treatment effect estimates, which are always computed under the assumption that there are parallel trends.
- AVGEFFectsby(varlist): the SE computation requires averaging the treatment effects within some large group of treated observations, as defined by this parameters. The SE are only asymptotically exact if there is no treatment effect heterogeneity within these group, and conversative otherwise. However, they are downward biased if the groups are too small, because of overfitting. The default is cohort-years (`Ei' `t'), which is appropriate for large cohorts. For small cohorts specify coarser groupings; a version that is always conservative is avgeffectsby(D), i.e. it is conversative under any heterogeneity of treatment effects within D==1.
- fe(list of FE): which FE to include in the model of Y(0). Default is "`i' `t'" but you can include fewer (e.g. just `t') or more, e.g. "`i' `t'#state" (for state-by-year FE with county-level data) or "`i'#dow `t'" (for unit by day-of-week FE). Each member of the list has to look like v1#v2#...#vk. If you want no FE at all, specify "fe(.)".
- Controls(varlist): list of time-varying controls
- TIMEControls(varlist): list of continuous controls (often time-invariant) to be included interacted by time dummies. E.g. with timecontrols(population) the regression includes i.year#c.popultion. Use with caution: the command may not recognize that imputation is not possible for some observations.
- UNITControls(varlist): list of continuous controls (often unit-invariant) to be included interacted by unit dummies. E.g. with unitcontrols(year) the regression includes unit-specific trends. Use with caution: the command may not recognize that imputation is not possible for some observations.
- CLUSter(varname): cluster SE within groups defined by this variable. Default is `i'.
- delta(integer): one period correponds to `delta' steps of `t' or `Ei'. Default is 1, except when the time dimension of the data is set (via tsset or xtset); in that case the default is the corresponding delta.
- tol and maxit: tolerance and the maximum number of iterations for convergence in searching for the estimator weights (increase if convergence is not achieved otherwise). Defaults are 10^-6 and 100, resp.
- verbose: specify for debugging mode
- nose: do not produce standard errors (much faster!)

Notes:
- The command will throw an error if there are treated observations with wtr not equal to zero/missing for which the treatment effect cannot be imputed. The dummy for those observations will be saved in the variable cannot_impute---e.g. for periods when all units are already treated. Modify the wtr or the if clause such that this does not happen, and rerun.
- The command will throw a warning if there are coefficients for which the effective sample size is insufficient: the inverse Herfindahl index for treated coefficients is below 30; those coefs will be suppressed. The threshold can be changed by setting the minn parameter but it is not recommended.

Output:
- e(b): a row-vector of the estimates. If `horizons' is specified, the program returns tau`h' for each `h' in the list of horizons. If multiple wtr are specified, the program returns tau_`v' for each `v' in the list of wtr variables. Otherwise simply r(tau) is returned. In addition, if `pretrends' is specified, the command returns pre`h' for each pre-trend coefficient h=1..`pretrends'.
- e(V): corresponding variance-covariance matrix
- e(Nt): a row-vector for the number of treated observations used to compute each estimator
- e(Nc): the number of control observations used in imputation (scalar)
- e(droplist): the set of coefficients suppressed to zero because of insufficient effective sample size
- e(autosample_drop): the set of coefficients suppressed to zero because treatment effects could not be imputed for any observation (if autosample is specified)
- e(autosample_trim): the set of coefficients where the sample was partially reduced because treatment effects could not be imputed for some observations (if autosample is specified)
- e(pre_chi2), e(pre_p), e(pre_df): if `pretrends' is specified, the Wald statistic, pvalue, and dof for the joint test for no pre-trends
- e(Niter): the # of iterations to compute SE

To-do:
- Report coefs on continuous controls; report Y(0)
- Explain the interpretation of saveweights() in presence of regression weights
- hbalance to work with autosample
- Further clustering
- Check if imputation is not possible with timei() or uniti()

Usage examples:

1) Estimate the single ATE for all treated observations, assuming that FE can be imputed for all treated observations (which is rarely the case)
did_imputation Y i t Ei

2) Same but dropping the observations for which it cannot be imputed. (After running, investigate that the sample is what you think it is!)
did_imputation Y i t Ei, autosample

3) Estimate the ATE by horizon
did_imputation Y i t Ei, allhorizons autosample

4) Estimate the ATE at horizons 0..+6 only
did_imputation Y i t Ei, horizons(0/6)

5) Estimate the ATE at horizons 0..+6 for the subset of units available for all of these horizons (such that the dynamics are not driven by compositional effects)
did_imputation Y i t Ei, horizons(0/6) hbalance

6) Include simple controls:
did_imputation Y i t Ei, controls(w_first w_other*)

7) Include state-by-year FE
did_imputation Y county year Ei, fe(county state#year)

8) Drop unit FE
did_imputation Y i t Ei, fe(t)

9) Estimate pre-trend coefficients for leads 1,...,5
did_imputation Y i t Ei, horizons(0/6) pretrends(5)

10) Estimate the difference between ATE at horizons +2 vs +1 [this can equivalently be done via lincom after estimating ATE by horizon]
count if K==1
gen wtr1 = (K==1)/r(N)
count if K==2
gen wtr2 = (K==2)/r(N)
gen wtr_diff = wtr2-wtr1
did_imputation Y i t Ei, wtr(wtr_diff) sum

11) Save estimation time by using loadweights if analyzing several outcomes with identical specifications on identical samples:
did_imputation Y1 i t Ei, horizons(0/10) saveweights
rename __* myweights* // optional, just to understand that __* are weight variables
did_imputation Y2 i t Ei, horizons(0/10) loadweights(myweights*)
did_imputation Y3 i t Ei, horizons(0/10) loadweights(myweights*)

*/

cap program drop did_imputation
program define did_imputation, eclass sortpreserve
syntax varlist(min=4 max=4) [if] [in] [aw iw fw] [, wtr(varlist) sum Horizons(numlist >=0) ALLHorizons HBALance minn(integer 30) shift(integer 0) ///
	AUTOSample SAVEestimates(name) SAVEWeights LOADWeights(varlist) ///
	AVGEFFectsby(varlist) fe(string) Controls(varlist) UNITControls(varlist) TIMEControls(varlist) ///
	CLUSter(varname) tol(real 0.000001) maxit(integer 100) verbose nose PREtrends(integer 0) delta(integer 0)]
qui {
	if ("`verbose'"!="") noi di "Starting"
	ms_get_version reghdfe, min_version("5.7.3")
	ms_get_version ftools, min_version("2.37.0")
	// Part 1: Initialize
	marksample touse, novarlist
	if ("`controls'"!="") markout `touse' `controls'
	if ("`unitcontrols'"!="") markout `touse' `unitcontrols'
	if ("`timecontrols'"!="") markout `touse' `timecontrols'
//	if ("`timeinteractions'"!="") markout `touse' `timeinteractions'
	if ("`cluster'"!="") markout `touse' `cluster'
	if ("`saveestimates'"!="") confirm new variable `saveestimates'
	if ("`saveweights'"!="") confirm new variable `saveweights'
	if ("`verbose'"!="") noi di "#00"
	tempvar wei
	if ("`weight'"=="") {
	    gen `wei' = 1
		local weiexp ""
	}
	else {
		gen `wei' `exp'
		replace `wei' = . if `wei'==0
		markout `touse' `wei'
		
		if ("`sum'"=="") { // unless want a weighted sum, normalize the weights to have reasonable scale, just in case for better numerical convergence
			sum `wei' if `touse'
			replace `wei' = `wei' * r(N)/r(sum)
		}
		local weiexp "[`weight'=`wei']"
	}
	local debugging = ("`verbose'"=="verbose")
	
	tokenize `varlist'
	local Y `1'
	local i `2'
	local t `3'
	local ei `4'
	markout `touse' `Y' `i' `t' // missing `ei' is fine, indicates the never-treated group
	tempvar D K
	
	// Process FE
	if ("`fe'"=="") local fe `i' `t'
	if ("`fe'"==".") {
	    tempvar constant
		gen `constant' = 1
	    local fe `constant'
	}
	local fecount = 0
	foreach fecurrent of local fe {
	    if (("`fecurrent'"!="`i'" | "`unitcontrols'"=="") & ("`fecurrent'"!="`t'" | "`timecontrols'"=="")) { // skip i and t if there are corresponding interacted controls 
			local ++fecount
			local fecopy `fecopy' `fecurrent'
			local fe`fecount' = subinstr("`fecurrent'","#"," ",.)
			markout `touse' `fe`fecount''
		}
	}
	local fe `fecopy'
	
	// Figure out the delta
	if (`delta'==0) {
		cap tsset, noquery
		if (_rc==0) {
			if (r(timevar)=="`t'") {
				local delta = r(tdelta)
				if (`delta'!=1) noi di "Note: setting delta = `delta'"
			}
		}
		else local delta = 1
	}
	if (`delta'<=0 | mi(`delta')) {
		di as error "A problem has occured with determining delta. Please specify it explicitly."
		error 198
	}
	
	if (`debugging') noi di "#1"
	gen `K' = (`t'-`ei'+`shift')/`delta' if `touse'
	cap assert mi(`K') | mod(`K',1)==0
	if (_rc!=0) {
		di as error "There are non-integer values of the number of periods since treatment. Please check the time dimension of your data."
		error 198
	}
	
	gen `D' = (`K'>=0 & !mi(`K')) if `touse'

	if ("`avgeffectsby'"=="") local avgeffectsby = "`ei' `t'"
	if ("`cluster'"=="") local cluster = "`i'"
	
	if ("`autosample'"!="" & "`sum'"!="") {
		di as error "Autosample cannot be combined with sum. Please specify the sample explicitly"
		error 184
	}
	if ("`autosample'"!="" & "`hbalance'"!="") {
		di as error "Autosample cannot be combined with hbalance. Please specify the sample explicitly"
		error 184
	}
	if (`debugging') noi di "#2 `fe'"
	
	// Part 2: Prepare the variables with weights on the treated units (e.g. by horizon)
	local wtr_count : word count `wtr'
	if (`wtr_count'==0) { // if no wtr, use the simple average
		tempvar wtr
		gen `wtr' = 1 if (`touse') & (`D'==1)
		local wtrnames tau
		local wtr_count = 1
	}
	else { // create copies of the specified variables so that I can modify them later (adjust for weights, normalize)
		if (`wtr_count'==1) local wtrnames tau
			else local wtrnames "" // will fill it in the loop
		
	    local wtr_new_list 
		foreach v of local wtr {
		    tempvar `v'_new
			gen ``v'_new' = `v' if `touse'
			local wtr_new_list `wtr_new_list' ``v'_new'
			if (`wtr_count'>1) local wtrnames `wtrnames' tau_`v'
		}
		local wtr `wtr_new_list'
	}

	* Horizons
	if (("`horizons'"!="" | "`allhorizons'"!="") & `wtr_count'>1) {
		di as error "Options horizons and allhorizons cannot be combined with multiple wtr variables"
		error 184
	}
	
	if ("`allhorizons'"!="") {
		if ("`horizons'"!="") {
			di as error "Options horizons and allhorizons cannot be combined"
			error 184
		}
		if ("`hbalance'"!="") di as error "Warning: combining hbalance with allhorizons may lead to very restricted samples. Consider specifying a smaller subset of horizons."
		
		levelsof `K' if `touse' & `D'==1 & `wtr'!=0 & !mi(`wtr'), local(horizons) 
	}
	
	if ("`horizons'"!="") { // Create a weights var for each horizon
		if ("`hbalance'"=="hbalance") {
		    // Put zero weight on units for which we don't have all horizons
			tempvar in_horizons num_horizons_by_i min_weight_by_i max_weight_by_i
			local n_horizons = 0
			gen `in_horizons'=0 if `touse'
			foreach h of numlist `horizons' {
				replace `in_horizons'=1 if (`K'==`h') & `touse'
				local ++n_horizons
			}
			egen `num_horizons_by_i' = sum(`in_horizons') if `in_horizons'==1, by(`i')
			replace `wtr' = 0 if `touse' & (`in_horizons'==0 | (`num_horizons_by_i'<`n_horizons'))
			
			// Now check whether wtr and wei weights are identical across periods
			egen `min_weight_by_i' = min(`wtr'*`wei') if `touse' & `in_horizons'==1 & (`num_horizons_by_i'==`n_horizons'), by(`i')
			egen `max_weight_by_i' = max(`wtr'*`wei') if `touse' & `in_horizons'==1 & (`num_horizons_by_i'==`n_horizons'), by(`i')
			cap assert `max_weight_by_i'<=1.000001*`min_weight_by_i' if `touse' & `in_horizons'==1 & (`num_horizons_by_i'==`n_horizons')
			if (_rc>0) {
			    di as error "Weights must be identical across periods for units in the balanced sample"
				error 498
			}
			drop `in_horizons' `num_horizons_by_i' `min_weight_by_i' `max_weight_by_i'
		}
		foreach h of numlist `horizons' {
		    tempvar wtr`h'
			gen `wtr`h'' = `wtr' * (`K'==`h')
			local horlist `horlist' `wtr`h''
			local hornameslist `hornameslist' tau`h'
		}
		local wtr `horlist'
		local wtrnames `hornameslist'
	}
	if (`debugging') noi di "List: `wtr'"
	if (`debugging') noi di "Namelist: `wtrnames'"
	
	if ("`sum'"=="") { // If computing the mean, normalize each wtr variable such that sum(wei*wtr*(D==1))==1
		foreach v of local wtr {
			cap assert `v'>=0 if (`touse') & (`D'==1)
			if (_rc!=0) {
				di as error "Negative wtr weights are only allowed if the sum option is specified"
				error 9
			}
			sum `v' `weiexp' if (`touse') & (`D'==1)
			replace `v' = `v'/r(sum) // r(sum)=sum(`v'*`weiexp')
		}
	}
	
	// Part 3: Run the imputation regression and impute the controls for treated obs
	if ("`unitcontrols'"!="") local fe_i `i'##c.(`unitcontrols')
	if ("`timecontrols'"!="") local fe_t `t'##c.(`timecontrols')
	if (`debugging') noi di "#4: reghdfe `Y' `controls' if (`D'==0) & (`touse') `weiexp', a(`fe_i' `fe_t' `fe', savefe) nocon keepsing"
	if (`debugging') noi reghdfe `Y' `controls' if (`D'==0) & (`touse') `weiexp', a(`fe_i' `fe_t' `fe', savefe) nocon keepsing 
		else reghdfe `Y' `controls' if (`D'==0) & (`touse') `weiexp', a(`fe_i' `fe_t' `fe', savefe) nocon keepsing verbose(-1)
		// nocon makes the constant recorded in the first FE
		// keepsing is important for when there are units available in only one period (e.g. treated in period 2) which are fine
		// verbose(-1) suppresses singleton warnings

	* Extrapolate the controls to the treatment group and construct Y0
	if (`debugging') noi di "#5"
	tempvar Y0
	gen `Y0' = 0 if `touse'
	
	local feset = 1 // indexing as in reghdfe
	if ("`unitcontrols'"!="") {
	    recover __hdfe`feset'__*, from(`i')
		replace `Y0' = `Y0' + __hdfe`feset'__ if `touse'
		local j=1
		foreach v of local unitcontrols {
			replace `Y0' = `Y0'+__hdfe`feset'__Slope`j'*`v' if `touse'
			local ++j
		}
		local ++feset
	}
	if ("`timecontrols'"!="") {
	    recover __hdfe`feset'__*, from(`t')
		replace `Y0' = `Y0' + __hdfe`feset'__ if `touse'
		local j=1
		foreach v of local timecontrols {
			replace `Y0' = `Y0'+__hdfe`feset'__Slope`j'*`v' if `touse'
			local ++j
		}
		local ++feset
	}
	forvalues feindex = 1/`fecount' { // indexing as in the fe option
	    recover __hdfe`feset'__, from(`fe`feindex'')
		replace `Y0' = `Y0' + __hdfe`feset'__ if `touse'
	    local ++feset
	}
	foreach v of local controls {
		replace `Y0' = `Y0'+_b[`v']*`v' if `touse'
	}
	if (`debugging') noi di "#7"
	
	if ("`saveestimates'"=="") tempvar effect
	else {
		local effect `saveestimates'
		cap confirm var `effect', exact
		if (_rc==0) drop `effect'
	}
	gen `effect' = `Y' - `Y0' if (`D'==1) & (`touse')

	drop __hdfe*
	if (`debugging') noi di "#8"

	// Check if imputation was successful, and apply autosample
	* For FE can just check they have been imputed everywhere
	tempvar need_imputation
	gen byte `need_imputation' = 0
	foreach v of local wtr {
	    replace `need_imputation'=1 if `touse' & `D'==1 & `v'!=0 & !mi(`v')
	}
	replace `touse' = (`touse') & (`D'==0 | `need_imputation') // View as e(sample) all controls + relevant treatments only
	
	count if mi(`effect') & `need_imputation'
	if r(N)>0 {
		if (`debugging') noi di "#8b `wtr'"
		cap drop cannot_impute
		gen byte cannot_impute = mi(`effect') & `need_imputation'
		count if cannot_impute==1
		if ("`autosample'"=="") {
			noi di as error "Could not impute FE for " r(N) " observations. Those are saved in the cannot_impute variable. Use the autosample option if you would like those observations to be dropped from the sample automatically."
			error 198
		}
		else { // drop the subsample where it didn't work and renormalize all wtr variables
			assert "`sum'"==""
			local j = 1
			qui foreach v of local wtr {
				if (`debugging') noi di "#8d sum `v' `weiexp' if `touse' & `D'==1"
				local outputname : word `j' of `wtrnames'
				sum `v' `weiexp' if `touse' & `D'==1 // just a test that it added up to one first
				if (`debugging') noi di "#8dd " r(sum)
				assert abs(r(sum)-1)<10^-5 | abs(r(sum))<10^-5 // if this variable is always zero/missing, then the sum would be zero
				
				count if `touse' & `D'==1 & cannot_impute==1 & `v'!=0 & !mi(`v') 
				local n_cannot_impute = r(N) // count the dropped units
				if (`n_cannot_impute'>0) {
					sum `v' `weiexp' if `touse' & `D'==1 & cannot_impute!=1 & `v'!=0 & !mi(`v') // those still remaining
					if (r(N)==0) {
						replace `v' = 0 if `touse' & `D'==1 // totally drop the wtr
						local autosample_drop `autosample_drop' `outputname'
					}
					else {
						replace `v' = `v'/r(sum) if `touse' & `D'==1 & cannot_impute!=1
						replace `v' = 0 if cannot_impute==1
						local autosample_trim `autosample_trim' `outputname'
					}
				}
				local ++j
			}
			if (`debugging') noi di "#8e"
			replace `touse' = `touse' & cannot_impute!=1
			if ("`autosample_drop'"!="") noi di "Warning: suppressing the following coefficients because FE could not be imputed for any units: `autosample_drop'." 
			if ("`autosample_trim'"!="") noi di "Warning: part of the sample was dropped for the following coefficients because FE could not be imputed: `autosample_trim'." 
		}		
	}
	* Compare model degrees of freedom [does not work correctly for timecontrols and unitcontrols, need to recompute]
	if (`debugging') noi di "#8c"
	tempvar tnorm
	gen `tnorm' = rnormal() if (`touse') & (`D'==0 | `need_imputation')
	reghdfe `tnorm' `controls' if (`D'==0) & (`touse'), a(`fe_i' `fe_t' `fe') nocon keepsing verbose(-1)
	local df_m_control = e(df_m) // model DoF corresponding to explicitly specified controls
	local df_a_control = e(df_a) // DoF for FE
	reghdfe `tnorm' `controls' , a(`fe_i' `fe_t' `fe') nocon keepsing verbose(-1)
	local df_m_full = e(df_m) 
	local df_a_full = e(df_a) 
	if (`debugging') noi di "#9 `df_m_control' `df_m_full' `df_a_control' `df_a_full'"
	if (`df_m_control'<`df_m_full') {
		di as error "Could not run imputation for some observations because some controls are collinear in the D==0 subsample but not in the full sample"
		if ("`autosample'"!="") di as error "Please note that autosample does not know how to deal with this. Please correct the sample manually"
		error 481
	}
	if (`df_a_control'<`df_a_full') {
		di as error "Could not run imputation for some observations because some absorbed variables/FEs are collinear in the D==0 subsample but not in the full sample"
		if ("`autosample'"!="") di as error "Please note that autosample does not know how to deal with this. Please correct the sample manually"
		error 481
	}
	
	// Part 4: Drop wtr which have an effective sample size (for absolute weights of treated obs) that is too small
	local droplist 
	tempvar abswei
	gen `abswei' = .
	local j = 1
	foreach v of local wtr {
		local outputname : word `j' of `wtrnames'
		replace `abswei' = abs(`v') if (`touse') & (`D'==1)
		sum `v' `weiexp' 
		if (r(sum)!=0) { // o/w dropped earlier
			replace `abswei' = (`v'*`wei'/r(sum))^2 // !! Probably doesn't work with fw, not sure about pw; probably ok for aw
			sum `abswei'
			if (r(sum)>1/`minn') { // HHI is large => effective sample size is too small
				local droplist `droplist' `outputname'
				replace `v' = 0 if `touse'
			}
		}
		else local droplist `droplist' `outputname' // not ideal: should report those with no data at all separately (maybe together with autosample_drop?)
		local ++j
	}
	if ("`droplist'"!="") noi di "WARNING: suppressing the following coefficients from estimation because of insufficient effective sample size: `droplist'. To report them nevertheless, set the minn option to a smaller number or 0, but keep in mind that the estimates may be unreliable and their SE may be downward biased." 
	
	if (`debugging') noi di "#9.5"
	
	// Part 5A: initialize the matrices
	local tau_num : word count `wtr'
	if (`debugging') noi di `tau_num' 
	if (`debugging') noi di `"`wtr' | `wtrnames'"'
	tempname b Nt
	matrix `b' = J(1,`tau_num'+`pretrends',.)
	matrix `Nt' = J(1,`tau_num',.)
	if (`debugging') noi di "#9.6"
	
	// Part 5: pre-tests
	if (`pretrends'>0) {
		tempname pretrendvar
		tempvar preresid
		forvalues h = 1/`pretrends' {
			gen `pretrendvar'`h' = (`K'==-`h') if `touse'
			local pretrendvars `pretrendvars' `pretrendvar'`h'
			local prenames `prenames' pre`h'
		}
		if (`debugging') noi di "#9A reghdfe `Y' `controls' `pretrendvars' `weiexp' if `touse' & `D'==0,  a(`fe_i' `fe_t' `fe') cluster(`cluster') resid(`preresid')"
		reghdfe `Y' `controls' `pretrendvars' `weiexp' if `touse' & `D'==0,  a(`fe_i' `fe_t' `fe') cluster(`cluster') resid(`preresid')
		forvalues h = 1/`pretrends' {
			matrix `b'[1,`tau_num'+`h'] = _b[`pretrendvar'`h']
			local preb`h' = _b[`pretrendvar'`h']
			local prese`h' = _se[`pretrendvar'`h']
		}
		local pre_df = e(df_r)
		if (`debugging') noi di "#9B"
		local list_pre_weps
		if ("`se'"!="nose") { // Construct weights behind pre-trend estimaters. Could speed up by residualizing all relevant vars on FE first
			matrix pre_b = e(b)
			if (`debugging') noi di "#9C1"
			matrix pre_V = e(V)
			if (`debugging') noi di "#9C2"
			local dof_adj = (e(N)-1)/(e(N)-e(df_m)-e(df_a)) * (e(N_clust)/(e(N_clust)-1)) // that's how regdfhe does dof adjustment with clusters, see reghdfe_common.mata line 634
			if (`debugging') noi di "#9C3"
			local pretrendvars "" // drop omitted vars from pretrendvars (so that residualization works correctly when computing SE)
			forvalues h = 1/`pretrends' {
				if (`preb`h''!=0 | `prese`h''!=0) local pretrendvars `pretrendvars' `pretrendvar'`h'
			}
			if (`debugging') noi di "#9C4 `pretrendvars'"
			
			tempvar preweight
			forvalues h = 1/`pretrends' {
				if (`debugging') noi di "#9D `h'"
				tempvar preeps_w`h'
				if (`preb`h''==0 & `prese`h''==0) gen `preeps_w`h'' = 0 // omitted
				else {
					local rhsvars = subinstr("`pretrendvars' ","`pretrendvar'`h' ","",.) // space at the end so that it works for the last var too
					reghdfe `pretrendvar'`h' `controls' `rhsvars' `weiexp' if `touse' & `D'==0,  a(`fe_i' `fe_t' `fe') cluster(`cluster') resid(`preweight')
					replace `preweight' = `preweight' * `wei'
					sum `preweight' if `touse' & `D'==0 & `pretrendvar'`h'==1
					replace `preweight' = `preweight'/r(sum)
					egen `preeps_w`h'' = total(`preweight' * `preresid') if `touse', by(`cluster')
					replace `preeps_w`h'' = `preeps_w`h'' * sqrt(`dof_adj')
					drop `preweight'
				}
				local list_pre_weps `list_pre_weps' `preeps_w`h''
			}		
		}
		if (`debugging') noi di "#9.75"	
	}

	// Part 6: Compute the effects 
	count if `D'==0 & `touse'
	local Nc = r(N)
	
	count if `touse'
	local Nall = r(N)

	tempvar effectsum
	gen `effectsum' = .
	local j = 1
	foreach v of local wtr {
		local outputname : word `j' of `wtrnames'
		if (`debugging') noi di "Reporting `j' `v' `outputname'"

		replace `effectsum' = `effect'*`v'*`wei' if (`D'==1) & (`touse')
		sum `effectsum'
		//ereturn scalar `outputname' = r(sum)
		matrix `b'[1,`j'] = r(sum)
	    
		count if `D'==1 & `touse' & `v'!=0 & !mi(`v')
		matrix `Nt'[1,`j'] = r(N)

		local ++j
	}
	
	if (`debugging') noi di "#10"
	
	// Part 7: Report SE [can add a check that there are no conflicts in the residuals]
	if ("`se'"!="nose") { 
		cap drop __w_*
		tempvar tag_clus resid
		egen `tag_clus' = tag(`cluster') if `touse'
		gen `resid' = `Y' - `Y0' if (`touse') & (`D'==0)
		if ("`loadweights'"=="") {
			local weightvars = ""
			foreach vn of local wtrnames {
				local weightvars `weightvars' __w_`vn'
			}
			if (`debugging') noi di "#11a imputation_weights `i' `t' `D' , touse(`touse') wtr(`wtr') saveweights(`weightvars') wei(`wei') fe(`fe') controls(`controls') unitcontrols(`unitcontrols') timecontrols(`timecontrols') tol(`tol') maxit(`maxit')"
			noi imputation_weights `i' `t' `D', touse(`touse') wtr(`wtr') saveweights(`weightvars') wei(`wei') ///
				fe(`fe') controls(`controls') unitcontrols(`unitcontrols') timecontrols(`timecontrols') ///
				tol(`tol') maxit(`maxit') `verbose'
			local Niter = r(iter)
		}
		else {
		    local weightvars `loadweights'
			// Here can verify the supplied weights
		}
		
		local list_weps = ""
		local j = 1
		foreach v of local wtr { // to do: speed up by sorting for all wtr together
			if (`debugging') noi di "#11b `v'"
			local weightvar : word `j' of `weightvars'
			tempvar sqshares avgtau eps_w`j' // Need to regenerate every time in case the weights on treated are in conflict
			egen `sqshares' = pc(`wei'*`v'^2) if (`touse') & (`D'==1), prop by(`avgeffectsby') // CHECK with Jann whether it's still correct
		//	egen `sqshares' = pc(`wei') if (`touse') & (`D'==1), prop by(`avgeffectsby')
			egen `avgtau' = sum(`effect'*`sqshares') if (`touse') & (`D'==1), by(`avgeffectsby')
			replace `resid' = `effect'-`avgtau' if (`touse') & (`D'==1)
			egen `eps_w`j'' = sum(`wei'*`weightvar'*`resid') if `touse', by(`cluster')
			
			//replace `eps_w' = `eps_w'^2
			//sum `eps_w' if `tag_clus'	
			//ereturn scalar se_`outputname' = sqrt(r(sum))
			local list_weps `list_weps' `eps_w`j''
			drop `sqshares' `avgtau'
			local ++j
		}
		if (`debugging') noi di "11c"
		tempname V
		if (`debugging') noi di "11d `list_weps' `list_pre_weps'"
		matrix accum `V' = `list_weps' `list_pre_weps' if `tag_clus', nocon
		if (`debugging') noi di "11e `wtrnames' `prenames'"
		matrix rownames `V' = `wtrnames' `prenames'
		matrix colnames `V' = `wtrnames' `prenames'
		if ("`saveweights'"=="" & "`loadweights'"=="") drop __w_*
	}
	
	// Part 8: report everything 
	if (`debugging') noi di "#12"
	matrix colnames `b' = `wtrnames' `prenames'
	matrix colnames `Nt' = `wtrnames'
	ereturn post `b' `V', esample(`touse') depname(`Y') obs(`Nall')
	ereturn matrix Nt = `Nt'
	ereturn scalar Nc = `Nc'
	ereturn local depvar `Y'
	ereturn local cmd did_imputation
	ereturn local droplist `droplist'
	ereturn local autosample_drop `autosample_drop'
	ereturn local autosample_trim `autosample_trim'
	if ("`Niter'"!="") ereturn scalar Niter = `Niter'
	if (`pretrends'>0 & "`se'"!="nose") {
		test `prenames', df(`pre_df')
		ereturn scalar pre_F = r(F)
		ereturn scalar pre_p = r(p)
		ereturn scalar pre_df = `pre_df'
	}
}

_coef_table_header
ereturn display

end

// Additional program that computes the weights corresponding to the imputation estimator and saves them in a variable
cap program drop imputation_weights
program define imputation_weights, rclass sortpreserve
syntax varlist(min=3 max=3), touse(varname) wtr(varlist) SAVEWeights(namelist) wei(varname) ///
	[tol(real 0.000001) maxit(integer 1000) fe(string) Controls(varlist) UNITControls(varlist) TIMEControls(varlist) verbose]
	// Weights of the imputation procedure given wtr for controls = - X0 * (X0'X0)^-1 * X1' * wtr but we get them via iterative procedure
	// k<0 | k==. is control
	// Observation weights are in wei; wtr should be specified BEFORE applying the wei, and the output is before applying them too, i.e. estimator = sum(wei*saveweights*Y)
qui {	
	// Part 1: Initialize
	local debugging = ("`verbose'"=="verbose")
	if (`debugging') noi di "#IW1"
	tokenize `varlist'
	local i `1'
	local t `2'
	local D `3'
	
	local wcount : word count `wtr'
	local savecount : word count `saveweights'
	assert `wcount'==`savecount'
	forvalues j = 1/`wcount' {
		local wtr_j : word `j' of `wtr'
		local saveweights_j : word `j' of `saveweights'
		gen `saveweights_j' = `wtr_j'
		replace `saveweights_j' = 0 if mi(`saveweights_j') & `touse'
		tempvar copy`saveweights_j'
		gen `copy`saveweights_j'' = `saveweights_j'
	}
	
	local fecount = 0
	foreach fecurrent of local fe {
		local ++fecount
		local fe`fecount' = subinstr("`fecurrent'","#"," ",.)
	}
	
	if (`debugging') noi di "#IW2"
	
	// Part 2: Demean & construct denom for weight updating
	if ("`unitcontrols'"!="") {
	    tempvar N0i
		egen `N0i' = sum(`wei') if (`touse') & `D'==0, by(`i')
	}
	if ("`timecontrols'"!="") {
		tempvar N0t
		egen `N0t' = sum(`wei') if (`touse') & `D'==0, by(`t')
	}
	forvalues feindex = 1/`fecount' {
	    tempvar N0fe`feindex'
		egen `N0fe`feindex'' = sum(`wei') if (`touse') & `D'==0, by(`fe`feindex'')
	}

	foreach v of local controls {
		tempvar dm_`v' c`v'
		sum `v' [aw=`wei'] if `D'==0 & `touse' // demean such that the mean is zero in the control sample
		gen `dm_`v'' = `v'-r(mean) if `touse'
		egen `c`v'' = sum(`wei' * `dm_`v''^2) if `D'==0 & `touse' 
	}
	
	foreach v of local unitcontrols {
		tempvar u`v' dm_u`v' s_u`v'
		egen `s_u`v'' = pc(`wei') if `D'==0 & `touse', by(`i') prop
		egen `dm_u`v'' = sum(`s_u`v'' * `v') if `touse', by(`i') // this automatically includes it in `D'==1 as well
		replace `dm_u`v'' = `v' - `dm_u`v'' if `touse'
		egen `u`v'' = sum(`wei' * `dm_u`v''^2) if `D'==0 & `touse', by(`i')
		drop `s_u`v''
	}
	foreach v of local timecontrols { 
		tempvar t`v' dm_t`v' s_t`v'
		egen `s_t`v'' = pc(`wei') if `D'==0 & `touse', by(`t') prop
		egen `dm_t`v'' = sum(`s_t`v'' * `v') if `touse', by(`t') // this automatically includes it in `D'==1 as well
		replace `dm_t`v'' = `v' - `dm_t`v'' if `touse'
		egen `t`v'' = sum(`wei' * `dm_t`v''^2) if `D'==0 & `touse', by(`t')
		drop `s_t`v''
	}
	if (`debugging') noi di "#IW3"

	// Part 3: Iterate
	local it = 0
	local keepiterating `saveweights'
	tempvar delta
	gen `delta' = 0
	while (`it'<`maxit' & "`keepiterating'"!="") {
		if (`debugging') noi di "#IW it `it': `keepiterating'"
		// Simple controls 
		foreach v of local controls {
			update_weights `dm_`v'' , w(`keepiterating') wei(`wei') d(`D') touse(`touse') denom(`c`v'') 
		}
		
		// Unit-interacted continuous controls 
		foreach v of local unitcontrols {
			update_weights `dm_u`v'' , w(`keepiterating') wei(`wei') d(`D') touse(`touse') denom(`u`v'') by(`i')
		}
		if ("`unitcontrols'"!="") update_weights , w(`keepiterating') wei(`wei') d(`D') touse(`touse') denom(`N0i') by(`i') // could speed up a bit by skipping this if we have i#something later
		
		// Time-interacted continuous controls
		foreach v of local timecontrols {
			update_weights `dm_t`v'' , w(`keepiterating') wei(`wei') d(`D') touse(`touse') denom(`t`v'') by(`t')
		}
		if ("`timecontrols'"!="") update_weights , w(`keepiterating') wei(`wei') d(`D') touse(`touse') denom(`N0t') by(`t') // could speed up a bit by skipping this if we have t#something later

		// FEs
		forvalues feindex = 1/`fecount' {
		    update_weights , w(`keepiterating') wei(`wei') d(`D') touse(`touse') denom(`N0fe`feindex'') by(`fe`feindex'')
		}
		
		// Check for which coefs the weights have changed, keep iterating for them
		local newkeepit
		foreach w of local keepiterating {
			replace `delta' = abs(`w'-`copy`w'')
			sum `delta' if `D'==0 & `touse'
			if (`debugging') noi di "#IW it `it' `w' " r(sum)
			if (r(sum)>`tol') local newkeepit `newkeepit' `w'
			replace `copy`w'' = `w'
		}
		local keepiterating `newkeepit'
		local ++it
	}
	if ("`keepiterating'"!="") {
	    noi di as error "Convergence of standard errors is not achieved for coefs: `keepiterating'."
		noi di as error "Try increasing the tolerance, the number of iterations, or use the nose option for the point estimates without SE."
	    error 430
	}
	return scalar iter = `it'
}
end

cap program drop update_weights // warning: intentionally destroys sorting
program define update_weights, rclass
	syntax [varname(default=none)] , w(varlist) wei(varname) d(varname) touse(varname) denom(varname) [by(varlist)]
	// varlist = variable on which to residualize (if empty, a constant is assumed, as for any FE) [for now only one is max!]
	// w = variable storing the weights to be updated
	// wei = observation weights
	// touse = variable defining sample
	// denom = variable storing sum(`wei'*`varlist'^2) if `d'==0, by(`by')
qui {	
	tempvar sumw
	tokenize `varlist'
	if ("`1'"=="") local 1 = "1"
	if ("`by'"!="") sort `by'
	foreach w_j of local w {
		noi di "#UW 5 `w_j': `1' by(`by') "
		egen `sumw' = total(`wei' * `w_j' * `1') if `touse', by(`by')
		replace `w_j' = `w_j'-`sumw'*`1'/`denom' if `d'==0 & `denom'!=0 & `touse'
		assert !mi(`w_j') if `touse'
		drop `sumw'
	}
}
end

// When there is a variable that only varies by `from' but is missing for some observations, fill in its missing values wherever possible
cap program drop recover 
program define recover, sortpreserve
	syntax varlist, from(varlist)
	foreach var of local varlist {
		gsort `from' -`var'
		by `from' : replace `var' = `var'[1] if mi(`var')
	}
end

