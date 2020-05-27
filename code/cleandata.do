clear all
capture log close
log using "..\logs\cleandata.txt", text replace

use "..\data\population.dta" // start from this file because it has both fips codes and state names

merge 1:m fips using "..\data\covidtracking.dta", keep(2 3)
drop _merge population // merge population back in later because want it merged to all observations, even those missing from the current dataset

merge 1:1 state date using "..\data\cdc_deaths.dta"
drop _merge

merge 1:1 state date using "..\data\cdc_historical_deaths.dta"
drop _merge

drop fips
merge m:1 state using "..\data\population.dta", keep(1 3)
drop _merge
order date fips
sort fips state date

drop if fips > 56

encode dataqualitygrade, gen(datagrade)
order datagrade, after(dataqualitygrade)
drop dataqualitygrade

gen end_week = date + mod(6 - dow(date), 7)
format end_week %tdCCYYNNDD
order end_week, after(date)

foreach var of varlist positive-datagrade death-pneumon_influ_or_covid numinfluenzadeaths-percentcomplete {
	gen `var'_mis = (`var'==.)
}
gen dayscollapsed = 1
collapse (firstnm) state report_date epi_week (lastnm) positive-datagrade population death-posneg (sum) deathincrease-pneumon_influ_or_covid numinfluenzadeaths-percentcomplete *_mis dayscollapsed, by(end_week fips)
foreach var of varlist positive-datagrade {
	replace `var' = . if `var'_mis > 0
}
foreach var of varlist death-pneumon_influ_or_covid numinfluenzadeaths-percentcomplete {
	replace `var' = . if `var'_mis == dayscollapsed
}
drop *_mis

xtset fips end_week, delta(7)

gen new_pos = d.positive if d.positive>=0
gen new_neg = d.negative if d.negative>=0
gen p_pos = new_pos/(new_pos+new_neg)*100
order new_pos-p_pos, after(negative)

// adjust expected deaths for reporting lag: https://www.cdc.gov/nchs/data/vsrr/report001.pdf
// maybe also somehow adjust for how the individual state was doing relative to expectations pre-covid
gen days_to_report = report_date - end_week

drop if fips == 9 | fips == 37 // Connecticut and North Carolina's data look highly problematic, so dropping them

/*
gen allcause_minus_posscovid = total_deaths - pneumon_influ_or_covid
gen allcause_minus_posscovid_pc  = allcause_minus_posscovid*100000/population
bys days_to_report: sum allcause_minus_posscovid_pc
gen adj_allcause_minus_posscovid_pc = allcause_minus_posscovid_pc
replace adj_allcause_minus_posscovid_pc = allcause_minus_posscovid_pc * 212 / 93 if days_to_report <= 7 & days_to_report != .
replace adj_allcause_minus_posscovid_pc = allcause_minus_posscovid_pc * 212 / 159 if days_to_report > 7 & days_to_report <= 14
replace adj_allcause_minus_posscovid_pc = allcause_minus_posscovid_pc * 212 / 192 if days_to_report > 14 & days_to_report <= 21
*/

//gen adj_expected_deaths = expected_deaths
//replace adj_expected_deaths = expected_deaths * 93 / 212 if days_to_report <= 7 & days_to_report != .
//replace adj_expected_deaths = expected_deaths * 159 / 212 if days_to_report > 7 & days_to_report <= 14
//replace adj_expected_deaths = expected_deaths * 192 / 212 if days_to_report > 14 & days_to_report <= 21
gen adj_expected_deaths = expected_deaths * (1-exp(-.09246997*days_to_report))
order adj_expected_deaths, after(expected_deaths)

gen pneumon_or_influ_fluview = numinfluenzadeaths + numpneumoniadeaths if end_week < date("20200201","YMD")
gen mmwrweek = substr(epi_week,-2,2)

//egen old_expected_influ_pneu_deaths = mean(pneumon_or_influ_fluview), by(fips mmwrweek)

// generate expected influenza/pneumonia deaths based on historical patterns
	gen epi_year = substr(epi_week,1,4)
	destring epi_year mmwrweek, replace
	replace epi_year = epi_year + 1 if mmwrweek >= 40

	gen mmwrweek2 = mmwrweek - 39 if mmwrweek >= 40
	replace mmwrweek2 = l.mmwrweek2 + 1 if mmwrweek < 40
	replace mmwrweek2 = mmwrweek + 13 if mmwrweek2 == .
	//gen pi_time = 2*_pi*mmwrweek2/52.1775
	//gen sin_time = sin(pi_time)
	//gen cos_time = cos(pi_time)
	//gen halfsin_time = sin(pi_time/2)
	//gen halfcos_time = cos(pi_time/2)

	gen pneumon_or_influ_fluview_pc = pneumon_or_influ_fluview * 100000 / population
	
	// most year-to-year variation in influenza severity seems to be from weeks 50 to 8; thus, create a sin spike for this period with a year-varying coefficient
	gen fluseason = 0 if mmwrweek != .
	replace fluseason = 1 if (mmwrweek >= 50 | mmwrweek <= 8) & mmwrweek != .
	gen fluseason_sin_time = sin(fluseason*_pi*(mmwrweek2-10)/12)
	
	reg pneumon_or_influ_fluview_pc i.fips i.epi_year i.mmwrweek i.epi_year#c.fluseason_sin_time [aweight=population]
	predict expected_influ_pneu_deaths_pc
	gen expected_influ_pneu_deaths = expected_influ_pneu_deaths_pc * population / 100000

//gen adj_expected_influ_pneu_deaths = expected_influ_pneu_deaths
//replace adj_expected_influ_pneu_deaths = expected_influ_pneu_deaths * 93 / 212 if days_to_report <= 7 & days_to_report != .
//replace adj_expected_influ_pneu_deaths = expected_influ_pneu_deaths * 159 / 212 if days_to_report > 7 & days_to_report <= 14
//replace adj_expected_influ_pneu_deaths = expected_influ_pneu_deaths * 192 / 212 if days_to_report > 14 & days_to_report <= 21
gen adj_expected_influ_pneu_deaths = expected_influ_pneu_deaths * (1-exp(-.09246997*days_to_report))
order adj_expected_influ_pneu_deaths, after(expected_influ_pneu_deaths)

replace covid_deaths = 5 if covid_deaths == . & total_deaths != . //rough imputation for where data is supressed for 1-9 deaths


gen cumulative_covdeath = covid_deaths
replace cumulative_covdeath = cumulative_covdeath + l.cumulative_covdeath if l.cumulative_covdeath != .

//gen adj_covid_deaths = covid_deaths
//replace adj_covid_deaths = covid_deaths * 212 / 93 if days_to_report <= 7 & days_to_report != .
//replace adj_covid_deaths = covid_deaths * 212 / 159 if days_to_report > 7 & days_to_report <= 14
//replace adj_covid_deaths = covid_deaths * 212 / 192 if days_to_report > 14 & days_to_report <= 21

gen adj_covid_deaths = covid_deaths / (1-exp(-.09246997*days_to_report))
gen adj_cumulative_covdeath = adj_covid_deaths
replace adj_cumulative_covdeath = adj_cumulative_covdeath + l.adj_cumulative_covdeath if l.adj_cumulative_covdeath != .

gen adj_total_deaths = total_deaths / (1-exp(-.09246997*days_to_report))
gen adj_pneumon_influ_or_covid = pneumon_influ_or_covid / (1-exp(-.09246997*days_to_report))


gen covdeath_pc = covid_deaths*100000/population
gen excess_deaths_pc = (total_deaths-adj_expected_deaths)*100000/population
gen excess_respir_deaths_pc = (pneumon_influ_or_covid-adj_expected_influ_pneu_deaths)*100000/population
gen adj_excess_deaths_pc = (adj_total_deaths-expected_deaths)*100000/population
gen adj_excess_respir_deaths_pc = (adj_pneumon_influ_or_covid-expected_influ_pneu_deaths)*100000/population
gen new_pos_pc = new_pos*100000/population
gen new_neg_pc = new_neg*100000/population
gen new_tests_pc = new_pos_pc + new_neg_pc
gen deathincrease_pc = deathincrease*100000/population
gen adj_covid_deaths_pc = adj_covid_deaths*100000/population

/*
gen log_covdeath = log(covid_deaths)
	//replace log_covdeath = 2 if covid_deaths==0
gen log_allcause = log(total_deaths)
gen log_expected = log(adj_expected_deaths)
gen excess_deaths = log_allcause-log_expected
*/

save "..\data\weeklydata.dta", replace


reg excess_deaths_pc covdeath_pc [aweight=population] if days_to_report > 14, cluster(fips) nocons
margins, dydx(covdeath_pc)

twoway (scatter excess_deaths_pc covdeath_pc if days_to_report > 14, mcolor(%30) yline(0)) (function y=x, range(0 40))

reg excess_deaths_pc covdeath_pc [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.covdeath_pc c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.covdeath_pc##c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.covdeath_pc c.new_pos_pc c.new_neg_pc [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.covdeath_pc##c.new_pos_pc c.covdeath_pc##c.new_neg_pc [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.covdeath_pc c.new_tests_pc [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.covdeath_pc##c.new_tests_pc [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.covdeath_pc##c.new_tests_pc c.covdeath_pc##c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.covdeath_pc##c.new_tests_pc##c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)

gen covdeath_pcXp_pos = covdeath_pc * p_pos
reghv excess_deaths_pc covdeath_pc p_pos covdeath_pcXp_pos if days_to_report > 14, var( new_tests_pc covdeath_pc population) twostage cluster(fips)
reghv excess_deaths_pc covdeath_pc p_pos covdeath_pcXp_pos if days_to_report > 14, var( new_tests_pc covdeath_pc population) cluster(fips)
drop covdeath_pcXp_pos



reg deathincrease_pc adj_covid_deaths_pc [aweight=population] if days_to_report > 7, cluster(fips)
reg deathincrease_pc adj_covid_deaths_pc l.adj_covid_deaths_pc [aweight=population] if days_to_report > 7, cluster(fips)
reg deathincrease_pc c.adj_covid_deaths_pc##c.p_pos [aweight=population] if days_to_report > 7, cluster(fips)
reg deathincrease_pc c.adj_covid_deaths_pc##c.new_tests_pc [aweight=population] if days_to_report > 7, cluster(fips)
reg deathincrease_pc c.adj_covid_deaths_pc##c.new_tests_pc c.l.adj_covid_deaths_pc##c.new_tests_pc [aweight=population] if days_to_report > 7, cluster(fips)
reg deathincrease_pc c.excess_deaths_pc##c.new_tests_pc c.l.excess_deaths_pc##c.new_tests_pc [aweight=population] if days_to_report > 7, cluster(fips)


reg excess_deaths_pc covdeath_pc [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_respir_deaths_pc covdeath_pc [aweight=population] if days_to_report > 14, cluster(fips)

reg excess_deaths_pc c.covdeath_pc##c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_respir_deaths_pc c.covdeath_pc##c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)

reg f.adj_excess_deaths_pc c.new_pos_pc##c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)
reg f.adj_excess_respir_deaths_pc c.new_pos_pc##c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)


log close

