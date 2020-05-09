clear all
capture log close
log using "..\logs\cleandata.txt", text replace

use "..\data\population.dta" // start from this file because it has both fips codes and state names

merge 1:m fips using "..\data\covidtracking.dta", keep(2 3)
drop _merge population // merge population back in later because want it merged to all observations, even those missing from the current dataset

merge 1:1 state date using "..\data\cdc_deaths.dta"
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

foreach var of varlist positive-datagrade death-pneumon_influ_and_covid {
	gen `var'_mis = (`var'==.)
}
collapse (firstnm) state report_date (lastnm) positive-datagrade (sum) death-pneumon_influ_and_covid population *_mis, by(end_week fips)
foreach var of varlist positive-datagrade {
	replace `var' = . if `var'_mis > 0
}
foreach var of varlist death-pneumon_influ_and_covid {
	replace `var' = . if `var'_mis > 6 | report_date == .
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

gen feb_adj_expected_deaths = .
replace feb_adj_expected_deaths = expected_deaths * 79.7 / 100 if days_to_report > 9*7+3 & days_to_report <= 10*7+3 & month(end_week)==2
replace feb_adj_expected_deaths = expected_deaths * 81.4 / 100 if days_to_report > 10*7+3 & days_to_report <= 11*7+3 & month(end_week)==2
replace feb_adj_expected_deaths = expected_deaths * 82.8 / 100 if days_to_report > 11*7+3 & days_to_report <= 12*7+3 & month(end_week)==2
replace feb_adj_expected_deaths = expected_deaths * 83.9 / 100 if days_to_report > 12*7+3 & days_to_report <= 13*7+3 & month(end_week)==2
replace feb_adj_expected_deaths = expected_deaths * 84.9 / 100 if days_to_report > 13*7+3 & days_to_report <= 14*7+3 & month(end_week)==2
replace feb_adj_expected_deaths = expected_deaths * 86.0 / 100 if days_to_report > 14*7+3 & days_to_report <= 15*7+3 & month(end_week)==2
replace feb_adj_expected_deaths = expected_deaths * 86.9 / 100 if days_to_report > 15*7+3 & days_to_report <= 16*7+3 & month(end_week)==2
replace feb_adj_expected_deaths = expected_deaths * 88.0 / 100 if days_to_report > 16*7+3 & days_to_report <= 17*7+3 & month(end_week)==2
replace feb_adj_expected_deaths = expected_deaths * 89.3 / 100 if days_to_report > 17*7+3 & days_to_report <= 18*7+3 & month(end_week)==2
replace feb_adj_expected_deaths = expected_deaths * 90.3 / 100 if days_to_report > 18*7+3 & days_to_report <= 19*7+3 & month(end_week)==2
replace feb_adj_expected_deaths = expected_deaths * 91.3 / 100 if days_to_report > 19*7+3 & days_to_report <= 20*7+3 & month(end_week)==2
replace feb_adj_expected_deaths = expected_deaths * 92.2 / 100 if days_to_report > 20*7+3 & days_to_report <= 21*7+3 & month(end_week)==2
replace feb_adj_expected_deaths = expected_deaths * 93.1 / 100 if days_to_report > 21*7+3 & days_to_report <= 22*7+3 & month(end_week)==2
replace feb_adj_expected_deaths = expected_deaths * 93.8 / 100 if days_to_report > 22*7+3 & days_to_report <= 23*7+3 & month(end_week)==2

gen relative_st_deaths = total_deaths / feb_adj_expected_deaths if month(end_week)==2
egen st_expected_death_adj = mean(relative_st_deaths), by(fips)

gen adj_expected_deaths = .
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 4.8 / 100 if days_to_report <= 1*7+3 & days_to_report != .
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 27.2 / 100 if days_to_report > 1*7+3 & days_to_report <= 2*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 43.8 / 100 if days_to_report > 2*7+3 & days_to_report <= 3*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 54.1 / 100 if days_to_report > 3*7+3 & days_to_report <= 4*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 61.9 / 100 if days_to_report > 4*7+3 & days_to_report <= 5*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 67.0 / 100 if days_to_report > 5*7+3 & days_to_report <= 6*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 71.0 / 100 if days_to_report > 6*7+3 & days_to_report <= 7*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 74.5 / 100 if days_to_report > 7*7+3 & days_to_report <= 8*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 77.4 / 100 if days_to_report > 8*7+3 & days_to_report <= 9*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 79.7 / 100 if days_to_report > 9*7+3 & days_to_report <= 10*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 81.4 / 100 if days_to_report > 10*7+3 & days_to_report <= 11*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 82.8 / 100 if days_to_report > 11*7+3 & days_to_report <= 12*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 83.9 / 100 if days_to_report > 12*7+3 & days_to_report <= 13*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 84.9 / 100 if days_to_report > 13*7+3 & days_to_report <= 14*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 86.0 / 100 if days_to_report > 14*7+3 & days_to_report <= 15*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 86.9 / 100 if days_to_report > 15*7+3 & days_to_report <= 16*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 88.0 / 100 if days_to_report > 16*7+3 & days_to_report <= 17*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 89.3 / 100 if days_to_report > 17*7+3 & days_to_report <= 18*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 90.3 / 100 if days_to_report > 18*7+3 & days_to_report <= 19*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 91.3 / 100 if days_to_report > 19*7+3 & days_to_report <= 20*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 92.2 / 100 if days_to_report > 20*7+3 & days_to_report <= 21*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 93.1 / 100 if days_to_report > 21*7+3 & days_to_report <= 22*7+3
replace adj_expected_deaths = expected_deaths * st_expected_death_adj * 93.8 / 100 if days_to_report > 22*7+3 & days_to_report <= 23*7+3

egen cumulative_covdeath = sum(covid_deaths), by(fips)

gen covdeath_pc = covid_deaths*1000000/population
gen excess_deaths_pc = (total_deaths-adj_expected_deaths)*1000000/population
gen new_pos_pc = new_pos*1000000/population
gen new_neg_pc = new_neg*1000000/population
gen new_tests_pc = new_pos_pc + new_neg_pc

gen log_covdeath = log(covid_deaths)
	//replace log_covdeath = 2 if covid_deaths==0
gen log_allcause = log(total_deaths)
gen log_expected = log(adj_expected_deaths)
gen excess_deaths = log_allcause-log_expected


reg excess_deaths c.log_covdeath c.p_pos if days_to_report > 14, cluster(fips)
reg excess_deaths c.log_covdeath##c.p_pos if days_to_report > 14, cluster(fips)

reg excess_deaths c.log_covdeath c.p_pos if days_to_report > 14 & excess_deaths > 0, cluster(fips)
reg excess_deaths c.log_covdeath##c.p_pos if days_to_report > 14 & excess_deaths > 0, cluster(fips)

reg excess_deaths c.log_covdeath c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths c.log_covdeath##c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)

reg excess_deaths_pc c.covdeath_pc c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.covdeath_pc##c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.covdeath_pc c.new_pos_pc c.new_neg_pc [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.covdeath_pc##c.new_pos_pc c.covdeath_pc##c.new_neg_pc [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.covdeath_pc c.new_tests_pc c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.covdeath_pc##c.new_tests_pc [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.covdeath_pc##c.new_tests_pc c.covdeath_pc##c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)
reg excess_deaths_pc c.covdeath_pc##c.new_tests_pc##c.p_pos [aweight=population] if days_to_report > 14, cluster(fips)

reghv excess_deaths_pc covdeath_pc if days_to_report > 14, var(new_tests_pc p_pos population) twostage cluster(fips)
reghv excess_deaths_pc covdeath_pc if days_to_report > 14, var(new_tests_pc p_pos population) cluster(fips)

log close