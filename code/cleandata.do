clear all
capture log close
log using "..\logs\cleandata.txt", text replace

use "..\data\fipscodes.dta"

merge 1:m fips using "..\data\covidtracking.dta", keep(2 3)
drop _merge

merge 1:1 state date using "..\data\cdc_deaths.dta"
drop _merge

drop fips
merge m:1 state using "..\data\fipscodes.dta", keep(1 3)
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
collapse (firstnm) state report_date (sum) positive-datagrade death-pneumon_influ_and_covid *_mis, by(end_week fips)
foreach var of varlist positive-datagrade {
	replace `var' = . if `var'_mis > 0
}
foreach var of varlist death-pneumon_influ_and_covid {
	replace `var' = . if `var'_mis > 6 | report_date == .
}
drop *_mis

xtset fips end_week, delta(7)

gen new_pos = d.positive
gen new_neg = d.negative
gen p_pos = new_pos/(new_pos+new_neg)*100
order new_pos-p_pos, after(negative)

// adjust expected deaths for reporting lag: https://www.cdc.gov/nchs/data/vsrr/report001.pdf
// maybe also somehow adjust for how the individual state was doing relative to expectations pre-covid
gen days_to_report = report_date - end_week
gen adj_expected_deaths = .
replace adj_expected_deaths = expected_deaths * 4.8 / 100 if days_to_report <= 1*7 & days_to_report != .
replace adj_expected_deaths = expected_deaths * 27.2 / 100 if days_to_report > 1*7 & days_to_report <= 2*7
replace adj_expected_deaths = expected_deaths * 43.8 / 100 if days_to_report > 2*7 & days_to_report <= 3*7
replace adj_expected_deaths = expected_deaths * 54.1 / 100 if days_to_report > 3*7 & days_to_report <= 4*7
replace adj_expected_deaths = expected_deaths * 61.9 / 100 if days_to_report > 4*7 & days_to_report <= 5*7
replace adj_expected_deaths = expected_deaths * 67.0 / 100 if days_to_report > 5*7 & days_to_report <= 6*7
replace adj_expected_deaths = expected_deaths * 71.0 / 100 if days_to_report > 6*7 & days_to_report <= 7*7
replace adj_expected_deaths = expected_deaths * 74.5 / 100 if days_to_report > 7*7 & days_to_report <= 8*7
replace adj_expected_deaths = expected_deaths * 77.4 / 100 if days_to_report > 8*7 & days_to_report <= 9*7
replace adj_expected_deaths = expected_deaths * 79.7 / 100 if days_to_report > 9*7 & days_to_report <= 10*7
replace adj_expected_deaths = expected_deaths * 81.4 / 100 if days_to_report > 10*7 & days_to_report <= 11*7
replace adj_expected_deaths = expected_deaths * 82.8 / 100 if days_to_report > 11*7 & days_to_report <= 12*7
replace adj_expected_deaths = expected_deaths * 83.9 / 100 if days_to_report > 12*7 & days_to_report <= 13*7
replace adj_expected_deaths = expected_deaths * 84.9 / 100 if days_to_report > 13*7 & days_to_report <= 14*7
replace adj_expected_deaths = expected_deaths * 86.0 / 100 if days_to_report > 14*7 & days_to_report <= 15*7
replace adj_expected_deaths = expected_deaths * 86.9 / 100 if days_to_report > 15*7 & days_to_report <= 16*7

gen log_covdeath = log(covid_deaths)
gen log_allcause = log(total_deaths)
gen log_expected = log(adj_expected_deaths)
gen excess_deaths = log_allcause-log_expected


reg excess_deaths c.log_covdeath c.p_pos if days_to_report > 14 & excess_deaths > 0
reg excess_deaths c.log_covdeath##c.p_pos if days_to_report > 14 & excess_deaths > 0

reg excess_deaths c.log_covdeath c.p_pos [aweight=adj_expected_deaths] if days_to_report > 14 // weights should really be based on population
reg excess_deaths c.log_covdeath##c.p_pos [aweight=adj_expected_deaths] if days_to_report > 14

log close