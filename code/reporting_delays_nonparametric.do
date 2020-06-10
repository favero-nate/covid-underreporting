clear all
capture log close
log using "..\logs\reporting_delays_preparing_data_for_r.txt", text replace

use "..\data\past_reports\16 May 2020 cdc_deaths.dta"
append using "..\data\past_reports\23 May 2020 cdc_deaths.dta"
append using "..\data\past_reports\30 May 2020 cdc_deaths.dta"
append using "..\data\past_reports\ 6 Jun 2020 cdc_deaths.dta"

rename date end_week
drop if state == "Connecticut" | state == "North Carolina" | state == "Puerto Rico"
keep end_week state covid_deaths total_deaths pneumon_influ_or_covid report_date
egen state_id = group(state)

egen state_end_week = group(state end_week)
xtset state_end_week report_date, delta(7)
gen days_to_report = report_date - end_week

foreach var of varlist covid_deaths total_deaths pneumon_influ_or_covid {
	replace `var' = 5 if `var' == .
	gen newreport_`var' = d.`var'
	gen increase_`var' = f.`var'/`var'
	egen avg_inc_`var' = mean(increase_`var'), by(state days_to_report)
	replace avg_inc_`var' = 1 if avg_inc_`var' < 1
}

bys state days_to_report: sum newreport_* increase_* avg_inc_*

keep if days_to_report > 6 & days_to_report < 118
keep state state_id days_to_report avg_inc_*
duplicates drop
xtset state_id days_to_report, delta(7)
gen delay_multiplier = avg_inc_total_deaths
forvalues i = 1/20 {
	replace delay_multiplier = delay_multiplier * f`i'.delay_multiplier if f`i'.delay_multiplier != .
}

keep state days_to_report delay_multiplier

save "..\data\delay_multipliers.dta", replace

log close
