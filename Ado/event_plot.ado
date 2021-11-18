*! event_plot: Plot coefficients from a staggered adoption event study analysis
*! Version: March 4, 2021
*! Author: Kirill Borusyak
*! Please check the latest version at https://www.dropbox.com/sh/r7wy4wjpwxy5uyy/AADxVrOHP653damnqpy_OhN1a?dl=0
*! Citation: Borusyak, Jaravel, and Spiess, "Revisiting Event Study Designs: Robust and Efficient Estimation" (2021)

/*
Plot the staggered-adoption diff-in-diff ("event study") estimates: coefficients post treatment ("lags") and, if available, pre-trend coefficients ("leads") along with confidence intervals (CIs). This command is used once estimates are produced by our did_imputation command or by conventional event study (other methods will be supported later). 

Syntax: event_plot [list of models] [, optional parameters]

List of models: 
- if not specified, the current estimates (stored in the e() output) are used. 
- to show previously constructed estimates or combine several sets of estimates, specify a list of their names which were previously saved by "estimates store". In this list a dot (.) indicates the current estimates. A maximum of 5 plots is currently supported.

Optional parameters are described below.

WHICH COEFFICIENTS TO SHOW:
- stub_lag(prefix#postfix): a template for how the relevant coefficients are called in the estimation output. It is mandatory except after did_imputation. The template must include the symbol # indicating where the number is located (running from 0). Examples: stub_lag(tau#) means that the relevant coefficients are called tau0, tau1, ... (note that the postfix is optional); L#xyz means they are called L0xyz, L1xyz, ...
- stub_lead(prefix#postfix): same for the leads. Here the number runs from 1. Examples: pre# or F#xyz.
- trimlag(integer): lags 0..`trimlag' will be shown. To show none (i.e. pre-trends only), select -1. The default is show all available lags.
- trimlead(integer): leads 1..`trimlead' will be shown. To show none (i.e no pre-trends), select 0. The default is show all available lags.

HOW TO SHOW THEM:
- plottype(string): the twoway plot type used to show coefficient estimates. Supported options: connected (default), line, scatter
- ciplottype(string): the twoway plot type used to show CI estimates. Supported options: rarea (default for plottype=connected/line), rcap (default for plottype=scatter), connected, scatter, none (i.e. don't show CIs at all; default if SE are not available)
- together: by default the leads and lags are shown as two separate lines (as recommended by Borusyak, Jaravel, and Spiess 2021). If `together' is specified, they are shown as one line, and the options for the lags are used for this line (while the options for the leads are ignored).
- shift(integer): Shift all coefficients to the left (when positive) to right (when negative). Specify if tau0 actually corresponds to period -`shift' (as in the case of anticipation effects, similar to the `shift' option in did_imputation). Default is zero.

GRAPH OPTIONS:
- default_look: sets default graph parameters. Other graph options can still be specified and will be combined with these, but options cannot be repeated.
- graph_opt(string): additional twoway options (e.g. title, xlabel). See details in the Default Look section below.
- lag_opt(string): additional options for the lag coefficient graph (e.g. msymbol, lpattern, color)
- lag_ci_opt(string): additional options for the lag CI graph (e.g. color)
- lead_opt(string), lead_ci_opt(string): same for lead coefficients and CIs
- noautolegend: suppresses the automatic legend. A manual legend (or the legend(off) parameter) should be added to graph_opt(). Notes:
	-- if ciplottype=connected/scatter, each CI is two lines instead of one. 
	-- if `together' is specified, the legend is not shown (unless noautolegend is specified)
- legend_opt(string): additional options for the automatic legend. Note the order of graphs for the legend: lead coefs, lead CIs, lag coefs, lag CIs (excluding those not applicable, e.g. CIs when ciplottype=none)

MISC OPTIONS
- savecoef: save the data underlying the plot in the current dataset (e.g. to later use in more elaborate manual plots). Variables __event_H*, __event_pos*, __event_coef*, __event_lo*, and __event_hi* will be created (where *=1,... corresponds to each set of estimates), where H is the number of periods relative to treatment, pos is the horizontal position (typically H but modified by `perturb' and `shift'), coef is the coef, and [lo,hi] is the CI.
- reportcommand: report the command for the plot. Use it together with savecoef to then create more elaborate manual plots.
- noplot: do not plot (useful together with savecoef)
- verbose: debugging mode

COMBINING PLOTS: With several plots, additional options are available.
- perturb(numlist): shifts the plots horizontally relative to each other, so that the estimates are easier to read. The perturb option is a list of x-shifts, the default is an equally spaced sequence from 0 to 0.2 (but negative numbers are allowed). To prevent the shifts, specify perturb(0).
- lag_optX(string), lag_ci_optX(string), lead_optX(string), lead_ci_optX() for X=1,...,5: extra parameters for individual graphs (e.g. colors). Note that the options without a number, e.g. lag_opt(), are passed to all relevant graphs.
- Options stub_lag, stub_lead, shift can be specified either as a sequence of different values one for each plot, or as just one value used for all plots
- Options trim_lag, trim_lead, together are currently required to be the same for all graphs. Please email me if that's not enough for your goals.

DEFAULT LOOK:
- With one plot, specifying default_look is equivalent to including these options:
	graph_opt(xline(0, lcolor(gs8) lpattern(dash)) yline(0, lcolor(gs8)) graphregion(color(white)) bgcolor(white) ylabel(, angle(horizontal))) ///
	lag_opt(color(navy)) lead_opt(color(maroon) msymbol(S)) ///
	lag_ci_opt(color(navy%45 navy%45)) lead_ci_opt(color(maroon%45 maroon%45)) ///
	legend_opt(region(lstyle(none)))
- With more than one plot, the only difference is in colors. Both lags and leads use the same color: navy for the first plot, maroon for the second, etc.
	
USAGE EXAMPLES:
1) Estimation + plottting via did_imputation:
did_imputation Y i t Ei, autosample hor(0/20) pretrend(14)
estimates store bjs // this is only for combined plots later
event_plot, default_look graph_opt(xtitle("Days since the event") ytitle("Coefficients") xlabel(-14(7)14 20)) 

2) Estimation + plotting via conventional OLS-based event study estimation
forvalues l = 0/19 { // creating dummies for the lags 0..19, based on K = number of periods since treatment (or missing if there is a never-treated group)
	gen L`l'event = K==`l'
}
gen L20event = K>=20 // binning K=20 and above
forvalues l = 0/13 { // creating dummies for the leads 1..14
	gen F`l'event = K==-`l'
}
gen F14event = K<=-14 // binning K=-14 and below
reghdfe outcome o.F1event o.F2event F3event-F14event L*event, a(i t) cluster(i) // Drop leads 1 and 2 to avoid underidentification when there is no never-treated group (could instead drop any others)
event_plot, default_look stub_lag(L#event) stub_lead(F#event) together plottype(scatter) graph_opt(xtitle("Days since the event") ytitle("OLS coefficients") xlabel(-14(7)14 20)) 

3) Combining did_imputation and OLS estimates:
event_plot bjs ., stub_lag(tau# L#) stub_lead(pre# F#) together plottype(scatter) default_look ///
	 graph_opt(xtitle("Days since the event") ytitle("OLS coefficients") xlabel(-14(7)14 20))  

TO-DO:
- More flexibility than stub_lag and stub_lead for reading the coefficients of conventional event studies
- Automatic compatibility with the did_multiplegt command (once it returns e(b) and e(V))
- Read data from vectors or matrices, so that it works with the Sun-Abraham command
- Don't require stub_lead if there are no leads

*/

cap program drop event_plot
program define event_plot
syntax [anything(name=eqlist)] [, trimlag(integer -2) trimlead(integer -1) default_look stub_lag(string) stub_lead(string) plottype(string) ciplottype(string) together ///
		graph_opt(string asis) noautolegend legend_opt(string) perturb(numlist) shift(numlist integer) ///
		lag_opt(string) lag_ci_opt(string) lead_opt(string) lead_ci_opt(string) ///
		lag_opt1(string) lag_ci_opt1(string) lead_opt1(string) lead_ci_opt1(string) ///
		lag_opt2(string) lag_ci_opt2(string) lead_opt2(string) lead_ci_opt2(string) ///
		lag_opt3(string) lag_ci_opt3(string) lead_opt3(string) lead_ci_opt3(string) ///
		lag_opt4(string) lag_ci_opt4(string) lead_opt4(string) lead_ci_opt4(string) ///
		lag_opt5(string) lag_ci_opt5(string) lead_opt5(string) lead_ci_opt5(string) ///
		savecoef reportcommand noplot verbose]
qui {	
	// to-do: read dcdh or K_95; compatibility with the code from Goodman-Bacon, eventdd(?), did_multiplegt; use eventstudy_siegloch on options for many graphs; Burtch: ib4.rel_period_pos
	// Part 1: Initialize
	local verbose = ("`verbose'"=="verbose")
	if ("`plottype'"=="") local plottype connected
	if ("`ciplottype'"=="" & ("`plottype'"=="connected" | "`plottype'"=="line")) local ciplottype rarea
	if ("`ciplottype'"=="" & "`plottype'"=="scatter") local ciplottype rcap
	if (`verbose') noi di "#1"
	if ("`eqlist'"=="") local eqlist .
	if ("`shift'"=="") local shift 0
	if ("`savecoef'"=="savecoef") cap drop __event*

	tempname dot
	cap estimates store `dot' // in case there are no current estimate (but plotting is done based on previously saved ones)
	local eq_n : word count `eqlist'
	
	if ("`perturb'"=="") {
	    if (`eq_n'==1) local perturb 0
	    if (`eq_n'==2) local perturb 0 0.2
	    if (`eq_n'==3) local perturb 0 0.01 0.2
	    if (`eq_n'==4) local perturb 0 0.067 0.133 0.2
	    if (`eq_n'==5) local perturb 0 0.05 0.1 0.15 0.2
	}
	
	tokenize `eqlist'
	forvalues eq = 1/`eq_n' {
	    if ("``eq''"==".") estimates restore `dot'
			else estimates restore ``eq''
			
		* extract prefix and suffix
		foreach o in lag lead {
		    local stub : word `eq' of `stub_`o''
			if ("`stub'"=="") local stub : word 1 of `stub_`o''
			if ("`stub'"=="" & e(cmd)=="did_imputation" & "`o'"=="lag") local stub tau#
			if ("`stub'"=="" & e(cmd)=="did_imputation" & "`o'"=="lead") local stub pre#
			if (mi("`stub'")) {
				di as error "Both stub_lag and stub_lead have to be specified, except after did_imputation"
				error 198
			}

			local hashpos = strpos("`stub'","#")
			if (`hashpos'==0) {
				di as error "stub_`o' is incorrectly specified"
				error 198
			}
			local prefix_`o' = substr("`stub'",1,`hashpos'-1)
			local postfix_`o' = substr("`stub'",`hashpos'+1,.)
			local lprefix_`o' = length("`prefix_`o''")
			local lpostfix_`o' = length("`postfix_`o''")
		}
	
		// Part 2: Compute the number of available lags&leads
		local maxlag = -1
		local maxlead = 0 // zero leads = nothing since they start from 1, while lags start from 0
		local allvars : colnames e(b) 
		foreach v of local allvars {
			if (substr("`v'",1,`lprefix_lag')=="`prefix_lag'" & substr("`v'",-`lpostfix_lag',.)=="`postfix_lag'") {
				if !mi(real(substr("`v'",`lprefix_lag'+1,length("`v'")-`lprefix_lag'-`lpostfix_lag'))) {
					local maxlag = max(`maxlag',real(substr("`v'",`lprefix_lag'+1,length("`v'")-`lprefix_lag'-`lpostfix_lag')))
				}
			}
			if (substr("`v'",1,`lprefix_lead')=="`prefix_lead'" & substr("`v'",-`lpostfix_lead',.)=="`postfix_lead'") {
				if !mi(real(substr("`v'",`lprefix_lead'+1,length("`v'")-`lprefix_lead'-`lpostfix_lead'))) {
					local maxlead = max(`maxlead',real(substr("`v'",`lprefix_lead'+1,length("`v'")-`lprefix_lead'-`lpostfix_lead')))
				}
			}
		}
		local maxlag = cond(`trimlag'>=-1, min(`maxlag',`trimlag'), `maxlag') 
		local maxlead = cond(`trimlead'>=0, min(`maxlead',`trimlead'), `maxlead')
		if (_N<`maxlag'+`maxlead'+1) {
			di as err "Not enough observations to store `=`maxlag'+`maxlead'+1' coefficient estimates"
			error 198
		}
		if (`verbose') noi di "#2 `maxlag' `maxlead'"

		// Part 3: Fill in coefs & CIs
		if ("`savecoef'"=="") tempvar H`eq' pos`eq' coef`eq' hi`eq' lo`eq'
		else {
			local H`eq' __event_H`eq'
			local pos`eq' __event_pos`eq'
			local coef`eq' __event_coef`eq'
			local hi`eq' __event_hi`eq'
			local lo`eq' __event_lo`eq'
		}
		
		local shift`eq' : word `eq' of `shift'
		if ("`shift`eq''"=="") local shift`eq' 0
		
		gen `H`eq'' = _n-1-`maxlead' if _n<=`maxlag'+`maxlead'+1
		gen `coef`eq'' = .
		gen `hi`eq'' = .
		gen `lo`eq'' = .
		label var `H`eq'' "Periods since treatment"
		if (`maxlag'>=0) forvalues h=0/`maxlag' {
			cap replace `coef`eq'' = _b[`prefix_lag'`h'`postfix_lag'] if `H`eq''==`h'
			if ("`ciplottype'"!="none") {
				cap replace `hi`eq'' = _b[`prefix_lag'`h'`postfix_lag']+1.96*_se[`prefix_lag'`h'`postfix_lag'] if `H`eq''==`h'
				cap replace `lo`eq'' = _b[`prefix_lag'`h'`postfix_lag']-1.96*_se[`prefix_lag'`h'`postfix_lag'] if `H`eq''==`h'
			}
		}
		if (`maxlead'>0) forvalues h=1/`maxlead' {
			cap replace `coef`eq'' = _b[`prefix_lead'`h'`postfix_lead'] if `H`eq''==-`h'
			if ("`ciplottype'"!="none") {
				cap replace `hi`eq'' = _b[`prefix_lead'`h'`postfix_lead']+1.96*_se[`prefix_lead'`h'`postfix_lead'] if `H`eq''==-`h'
				cap replace `lo`eq'' = _b[`prefix_lead'`h'`postfix_lead']-1.96*_se[`prefix_lead'`h'`postfix_lead'] if `H`eq''==-`h'
			}
		}
		if (`verbose') noi di "#3 `perturb'"
		
		local perturb_now : word `eq' of `perturb'
		if ("`perturb_now'"=="") local perturb_now = 0
		if (`verbose') noi di "#3A gen `pos`eq''=`H`eq''+`perturb_now'-`shift`eq''"
		gen `pos`eq''=`H`eq''+`perturb_now'-`shift`eq''
		if (`verbose') noi di "#3B"

	}
	cap estimates restore `dot'
	cap estimates drop `dot'
	
	// Part 4: Prepare graphs
	if ("`default_look'"!="") {
		local graph_opt xline(0, lcolor(gs8) lpattern(dash)) yline(0, lcolor(gs8)) graphregion(color(white)) bgcolor(white) ylabel(, angle(horizontal))`graph_opt'
		if (`eq_n'==1) {
			local lag_opt color(navy) `lag_opt'
			local lead_opt color(maroon) msymbol(S) `lead_opt'
			local lag_ci_opt color(navy%45 navy%45) `lag_ci_opt' // color repeated twice only for connected/scatter, o/w doesn't matter
			local lead_ci_opt color(maroon%45 maroon%45) `lead_ci_opt'
		}
		else {
			local lag_opt1 color(navy) `lag_opt1'
			local lag_opt2 color(maroon) `lag_opt2'
			local lag_opt3 color(forest_green) `lag_opt3'
			local lag_opt4 color(dkorange) `lag_opt4'
			local lag_opt5 color(teal) `lag_opt5'
			local lead_opt1 color(navy) `lead_opt1'
			local lead_opt2 color(maroon) `lead_opt2'
			local lead_opt3 color(forest_green) `lead_opt3'
			local lead_opt4 color(dkorange) `lead_opt4'
			local lead_opt5 color(teal) `lead_opt5'
			local lag_ci_opt1 color(navy%45 navy%45) `lag_ci_opt1'
			local lag_ci_opt2 color(maroon%45 maroon%45) `lag_ci_opt2'
			local lag_ci_opt3 color(forest_green%45 forest_green%45) `lag_ci_opt3'
			local lag_ci_opt4 color(dkorange%45 dkorange%45) `lag_ci_opt4'
			local lag_ci_opt5 color(teal%45 teal%45) `lag_ci_opt5'
			local lead_ci_opt1 color(navy%45 navy%45) `lead_ci_opt1'
			local lead_ci_opt2 color(maroon%45 maroon%45) `lead_ci_opt2'
			local lead_ci_opt3 color(forest_green%45 forest_green%45) `lead_ci_opt3'
			local lead_ci_opt4 color(dkorange%45 dkorange%45) `lead_ci_opt4'
			local lead_ci_opt5 color(teal%45 teal%45) `lead_ci_opt5'
		}
		local legend_opt region(lstyle(none)) `legend_opt'
	}
	
	local plotindex = 0
	local legend_order

	forvalues eq = 1/`eq_n' {
	    local lead_cmd
		local leadci_cmd
		local lag_cmd
		local lagci_cmd
		
		if ("`together'"=="") { // lead graph commands only when they are separate from lags
			count if !mi(`coef`eq'') & `H`eq''<0
			if (r(N)>0) {
				local ++plotindex
				local lead_cmd (`plottype' `coef`eq'' `pos`eq'' if !mi(`coef`eq'') & `H`eq''<0, `lead_opt' `lead_opt`eq'')
				local legend_order = `"`legend_order' `plotindex' "Pre-trend coefficients""'
			}

			count if !mi(`hi`eq'') & `H`eq''<0
			if (r(N)>0) {
				local ++plotindex
				local leadci_cmd (`ciplottype' `hi`eq'' `lo`eq'' `pos`eq'' if !mi(`hi`eq'') & `H`eq''<0, `lead_ci_opt' `lead_ci_opt`eq'')
			}
		}
		
		local lag_filter = cond("`together'"=="", "`H`eq''>=0", "1") 
		count if !mi(`coef') & `lag_filter'
		if (r(N)>0) {
			local ++plotindex
			local lag_cmd (`plottype' `coef`eq'' `pos`eq'' if !mi(`coef`eq'') & `lag_filter', `lag_opt' `lag_opt`eq'')
			if ("`together'"=="") local legend_order = `"`legend_order' `plotindex' "Treatment effects""'
		}

		count if !mi(`hi`eq'') & `lag_filter'
		if (r(N)>0) {
			local ++plotindex
			local lagci_cmd (`ciplottype' `hi`eq'' `lo`eq'' `pos`eq'' if !mi(`hi`eq'') & `lag_filter', `lag_ci_opt' `lag_ci_opt`eq'')
		}
		if ("`autolegend'"=="noautolegend") local legend = "" 
			else if ("`together'"=="together") local legend = "legend(off)" // show auto legend only for separate, o/w just one item
			else local legend legend(order(`legend_order') `legend_opt')
		local maincmd `maincmd' `lead_cmd' `leadci_cmd' `lag_cmd' `lagci_cmd'
		if (`verbose') noi di `"#4a `lead_cmd' `leadci_cmd' `lag_cmd' `lagci_cmd'"'
	}
	if (`verbose' | "`reportcommand'"!="") noi di `"twoway `maincmd' , `legend' `graph_opt'"'
	if ("`plot'"!="noplot") twoway `maincmd', `legend' `graph_opt'
		
}
end