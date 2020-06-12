clear all
capture log close
log using "..\logs\cleandata.txt", text replace

use "..\data\population.dta" // start from this file because it has both fips codes and state names

merge 1:m fips using "..\data\covidtracking.dta", keep(2 3)
drop _merge population risk_standardized_population // merge population back in later because want it merged to all observations, even those missing from the current dataset

merge 1:1 state date using "..\data\past_reports\ 6 Jun 2020 cdc_deaths.dta"
drop _merge

merge 1:1 state date using "..\data\cdc_historical_deaths.dta"
drop _merge

drop fips
merge m:1 state using "..\data\population.dta", keep(1 3)
drop _merge
order date fips
sort fips state date

// bring in delay multipliers, which adjust expected deaths for reporting lag: https://www.cdc.gov/nchs/data/vsrr/report001.pdf
// note: excess deaths do not adjust for how the individual state was doing relative to expectations pre-covid this year
gen end_week = date + mod(6 - dow(date), 7)
format end_week %tdCCYYNNDD
order end_week, after(date)
gen days_to_report = report_date - end_week
merge m:1 state days_to_report using "..\data\delay_multipliers.dta", keep(1 3)
drop _merge
replace delay_multiplier = 1 if days_to_report >= 118 & delay_multiplier == . & days_to_report != .

drop if fips > 56

//drop if fips == 9 | fips == 37 // Connecticut and North Carolina's provisional death data look highly problematic, so they are not included in analyses using death counts; however, they are kept in the dataset for analysis of hospitalizations

encode dataqualitygrade, gen(datagrade)
order datagrade, after(dataqualitygrade)
drop dataqualitygrade

drop hash datechecked // new variables added to more recent versions of covidtracking's data that interfere with following code:
foreach var of varlist positive-datagrade death-pneumon_influ_or_covid numinfluenzadeaths-percentcomplete {
	gen `var'_mis = (`var'==.)
}
gen dayscollapsed = 1
sort fips state date
collapse (firstnm) state report_date epi_week (lastnm) positive-datagrade population risk_standardized_population delay_multiplier days_to_report death-posneg (sum) deathincrease-pneumon_influ_or_covid numinfluenzadeaths-percentcomplete *_mis dayscollapsed, by(end_week fips)
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

// dropping CDC expected death data because it appears to have errors
drop expected_deaths


// generate expected influenza/pneumonia deaths based on historical patterns
	gen pneumon_or_influ_fluview = numinfluenzadeaths + numpneumoniadeaths if end_week < date("20200201","YMD")
	gen mmwrweek = substr(epi_week,-2,2)
	gen year = year(end_week)
	destring mmwrweek, replace
	replace mmwrweek = l.mmwrweek + 1 if mmwrweek == . & year == 2020
	
	// use 2017-2019 data to calculate for each state the weekly average number of all-cause deaths and influenza/pneumonia deaths
	replace pneumon_or_influ_fluview = .  if year == 2020 | year < 2016
	rename totaldeaths allcause_fluview
	replace allcause_fluview = .  if year == 2020 | year < 2016
	
	egen expected_influ_pneu_deaths = mean(pneumon_or_influ_fluview), by(state mmwrweek)
	egen expected_deaths = mean(allcause_fluview), by(state mmwrweek)
	
	// Not currently using this method: most year-to-year variation in influenza severity seems to be from weeks 50 to 8; thus, create a sin spike for this period with a year-varying coefficient
	/*
	gen flu_year = year + 1 if mmwrweek >= 40
	gen mmwrweek2 = mmwrweek - 39 if mmwrweek >= 40
	replace mmwrweek2 = l.mmwrweek2 + 1 if mmwrweek < 40
	replace mmwrweek2 = mmwrweek + 13 if mmwrweek2 == .
	gen fluseason = 0 if mmwrweek != .
	replace fluseason = 1 if (mmwrweek >= 50 | mmwrweek <= 8) & mmwrweek != .
	gen fluseason_sin_time = sin(fluseason*_pi*(mmwrweek2-10)/12)
	
	gen pneumon_or_influ_fluview_pc = pneumon_or_influ_fluview * 100000 / population if end_week < date("20200201","YMD")
	gen allcause_fluview_pc = totaldeaths * 100000 / population if end_week < date("20200201","YMD")

	reg pneumon_or_influ_fluview_pc i.fips i.flu_year i.mmwrweek i.flu_year#c.fluseason_sin_time [aweight=population]
	predict expected_influ_pneu_deaths_pc
	gen expected_influ_pneu_deaths = expected_influ_pneu_deaths_pc * population / 100000
	
	reg allcause_fluview_pc i.fips i.flu_year i.mmwrweek i.flu_year#c.fluseason_sin_time [aweight=population]
	predict expected_allcause_deaths_pc
	gen expected_allcause_deaths = expected_allcause_deaths_pc * population / 100000
	*/

gen adj_expected_influ_pneu_deaths = expected_influ_pneu_deaths / delay_multiplier
order adj_expected_influ_pneu_deaths, after(expected_influ_pneu_deaths)
gen adj_expected_deaths = expected_deaths / delay_multiplier
order adj_expected_deaths, after(expected_deaths)

replace covid_deaths = 5 if covid_deaths == . & total_deaths != . //rough imputation for where data is supressed for 1-9 deaths


gen cumulative_covid_death = covid_deaths
replace cumulative_covid_death = cumulative_covid_death + l.cumulative_covid_death if l.cumulative_covid_death != .


gen adj_covid_deaths = covid_deaths * delay_multiplier
gen adj_cumulative_covid_death = adj_covid_deaths
replace adj_cumulative_covid_death = adj_cumulative_covid_death + l.adj_cumulative_covid_death if l.adj_cumulative_covid_death != .

gen adj_total_deaths = total_deaths * delay_multiplier
gen adj_pneumon_influ_or_covid = pneumon_influ_or_covid * delay_multiplier


gen covid_deaths_pc = covid_deaths*100000/risk_standardized_population
gen excess_deaths_pc = (total_deaths-adj_expected_deaths)*100000/population
gen excess_respir_deaths_pc = (pneumon_influ_or_covid-adj_expected_influ_pneu_deaths)*100000/risk_standardized_population
gen adj_covid_deaths_pc = adj_covid_deaths*100000/risk_standardized_population
gen adj_excess_deaths_pc = (adj_total_deaths-expected_deaths)*100000/population
gen adj_excess_respir_deaths_pc = (adj_pneumon_influ_or_covid-expected_influ_pneu_deaths)*100000/risk_standardized_population
gen new_pos_pc = new_pos*100000/population
gen new_neg_pc = new_neg*100000/population
gen new_tests_pc = new_pos_pc + new_neg_pc
gen deathincrease_pc = deathincrease*100000/risk_standardized_population

/*
gen log_covid_death = log(covid_deaths)
	//replace log_covid_death = 2 if covid_deaths==0
gen log_allcause = log(total_deaths)
gen log_expected = log(adj_expected_deaths)
gen excess_deaths = log_allcause-log_expected
*/

save "..\data\weeklydata.dta", replace


reg excess_deaths_pc covid_deaths_pc [aweight=population] if days_to_report > 14, cluster(fips) nocons
margins, dydx(covid_deaths_pc)

twoway (scatter excess_deaths_pc covid_deaths_pc if days_to_report > 14, mcolor(%30) yline(0)) (function y=x, range(0 40))

reg excess_deaths_pc covid_deaths_pc [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.covid_deaths_pc c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.covid_deaths_pc##c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)

reg deathincrease_pc adj_covid_deaths_pc [aweight=population] if days_to_report > 7, cluster(fips)
reg deathincrease_pc adj_covid_deaths_pc l.adj_covid_deaths_pc [aweight=population] if days_to_report > 7, cluster(fips)
reg deathincrease_pc c.adj_covid_deaths_pc##c.p_pos [aweight=population] if days_to_report > 7, cluster(fips)


reg excess_respir_deaths_pc covid_deaths_pc [aweight=population] if days_to_report > 14, cluster(fips)

reg excess_deaths_pc c.covid_deaths_pc##c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.covid_deaths_pc##c.p_pos c.covid_deaths_pc##c.end_week [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_respir_deaths_pc c.covid_deaths_pc##c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_respir_deaths_pc c.covid_deaths_pc##c.p_pos c.covid_deaths_pc##c.end_week [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.excess_respir_deaths_pc##c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.excess_respir_deaths_pc##c.p_pos c.covid_deaths_pc##c.end_week [aweight=population] if days_to_report > 14, cluster(fips)

reg f.adj_excess_deaths_pc c.new_pos_pc##c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)
reg f.adj_excess_respir_deaths_pc c.new_pos_pc##c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)

log close

