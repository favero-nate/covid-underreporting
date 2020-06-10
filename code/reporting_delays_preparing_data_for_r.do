clear all
capture log close
log using "..\logs\reporting_delays_preparing_data_for_r.txt", text replace

use "..\data\past_reports\16 May 2020 cdc_deaths.dta"
append using "..\data\past_reports\23 May 2020 cdc_deaths.dta"
append using "..\data\past_reports\30 May 2020 cdc_deaths.dta"
append using "..\data\past_reports\ 6 Jun 2020 cdc_deaths.dta"

drop if state == "United States" | state == "Connecticut" | state == "North Carolina" | state == "Puerto Rico"
egen state_id = group(state)

replace covid_deaths = 5 if covid_deaths == .
replace total_deaths = 5 if total_deaths == .
replace pneumon_influ_or_covid = 5 if pneumon_influ_or_covid == .

egen state_end_week = group(state date)
xtset state_end_week report_date, delta(7)

gen newly_reported_total_deaths = d.total_deaths
gen newly_reported_covid_deaths = d.covid_deaths
gen newly_reported_pneumon_influ_or_covid = d.pneumon_influ_or_covid

save "..\data\past_reports\weekly_cdc_deaths.dta", replace

forvalues i = 1/49 {
	use "..\data\past_reports\weekly_cdc_deaths.dta"
	keep if state_id==`i'
	drop 
}


save "..\data\past_reports\by_state\ 6 Jun 2020 cdc_deaths.dta"


merge m:1 state using "..\data\population.dta"
drop _merge
replace fips = 0 if state == "United States"
replace fips = 72 if state == "Puerto Rico"

//drop if state == "United States" | state == "Connecticut" | state == "North Carolina" | state == "Puerto Rico" | state == "West Virginia"
//drop if  state == "Connecticut" | state == "North Carolina" | state == "Puerto Rico" | state == "West Virginia"

rename date end_week

gen days_to_report = report_date - end_week
sum days_to_report
gen days_since_first_report = days_to_report - r(min)

order end_week report_date days_to_report
sort end_week report_date

foreach var of varlist covid_deaths- pneumon_influ_or_covid {
    replace `var' = 5 if `var' == .
}

//following code commented out because it only works with weekly data:
/*
xtset end_week report_date, delta(7)
gen growth_total_deaths = f.total_deaths / total_deaths
bys days_to_report: sum growth_total_deaths
gen est_real_total_deaths = 1.005286 * total_deaths if days_to_report==70
replace est_real_total_deaths = 1.005286 * 1.007821 * total_deaths if days_to_report==63
replace est_real_total_deaths = 1.005286 * 1.007821 * 1.014075 * total_deaths if days_to_report==56
replace est_real_total_deaths = 1.005286 * 1.007821 * 1.014075 * 1.015894 * total_deaths if days_to_report==49
replace est_real_total_deaths = 1.005286 * 1.007821 * 1.014075 * 1.015894 * 1.01353 * total_deaths if days_to_report==42
replace est_real_total_deaths = 1.005286 * 1.007821 * 1.014075 * 1.015894 * 1.01353 * 1.014131 * total_deaths if days_to_report==35
replace est_real_total_deaths = 1.005286 * 1.007821 * 1.014075 * 1.015894 * 1.01353 * 1.014131 * 1.024915 * total_deaths if days_to_report==28
replace est_real_total_deaths = 1.005286 * 1.007821 * 1.014075 * 1.015894 * 1.01353 * 1.014131 * 1.024915 * 1.055341 * total_deaths if days_to_report==21
replace est_real_total_deaths = 1.005286 * 1.007821 * 1.014075 * 1.015894 * 1.01353 * 1.014131 * 1.024915 * 1.055341 * 1.163302 * total_deaths if days_to_report==14
replace est_real_total_deaths = 1.005286 * 1.007821 * 1.014075 * 1.015894 * 1.01353 * 1.014131 * 1.024915 * 1.055341 * 1.163302 * 1.733615 * total_deaths if days_to_report==7
*/

// create week marker, with new weeks starting on Fridays (since there's always a Friday report available)
gen weeks_to_report = .
forvalues i=0/20 {
    replace weeks_to_report = `i' if days_to_report + 1 >= 7*`i' & days_to_report + 1 < 7*(`i'+1)
}
egen state_end_week = group(state end_week)
sort state_end_week report_date
egen ts = fill(0 1)
xtset state_end_week ts
gen growth_per_day = (log(f.total_deaths) - log(total_deaths))/(f.days_to_report - days_to_report)
bys weeks_to_report: sum growth_per_day

gen loglog_days_to_report = log(log(days_to_report))

reg growth_per_day c.loglog_days_to_report##b0.fips

/*
gen state_delay = 0 if state_id==1
forvalues i = 2/48 {
    replace state_delay = _b[`i'.state_id] if state_id == `i'
}
*/


/*
// need to merge in population data, make per capita, include population in lnsigma
// or instead, make alpha a function of population & week & state? prolly not
capture program drop reporting_delays
program reporting_delays
	args lnf detected time alpha lnsigma
	quietly replace `lnf' = ///
		ln(normalden( $ML_y1,  `alpha' - `alpha'*exp(-(exp(`time') * $ML_y2 )), exp(`lnsigma'+`detected'*$ML_y2 )))
end

ml model lf reporting_delays ///
	(detected: total_deaths = ) ///
	(time: days_to_report = state_delay) ///
	(alpha: i.state_end_week) ///
	(lnsigma: )
ml maximize

display "k="exp(_b[#2:_cons])

gen delay_adj_total_deaths = total_deaths / (1-exp(-exp(_b[#2:_cons])*days_to_report))




egen min_realdeaths = max(total_deaths), by(state_end_week)


capture program drop reporting_delays
program reporting_delays
	args lnf detected time missed_realdeaths lnsigma delta
	quietly replace `lnf' = ///
		ln(normalden( $ML_y1,  ($ML_y3 + exp(`missed_realdeaths')) - (1-1/exp(`delta'))*($ML_y3 + exp(`missed_realdeaths'))*exp(-(exp(`time') * $ML_y2 )), exp(`lnsigma'+`detected'*$ML_y2 )))
end

ml model lf reporting_delays ///
	(detected: total_deaths = ) ///
	(time: days_to_report = ) ///
	(missed_realdeaths: min_realdeaths = i.end_week) ///
	(lnsigma: ) ///
	(delta: ) if end_week < date("20200510","YMD")
ml maximize

display "k="exp(_b[#2:_cons])
display "beta=limit*"1/exp(_b[#5:_cons])
display "alpha="(1-1/exp(_b[#5:_cons]))

gen delay_adj_total_deaths2 = total_deaths / (1-(1-1/exp(_b[#5:_cons]))*exp(-exp(_b[#2:_cons])*days_to_report))


capture program drop reporting_delays
program reporting_delays
	args lnf time detected0 missed_realdeaths lnsigma
	quietly replace `lnf' = ///
		ln(normalden( $ML_y1,  -(1/exp(`time')) * log( ($ML_y3 + exp(`missed_realdeaths') - $ML_y2 )/(($ML_y3 + exp(`missed_realdeaths'))*1/(1+exp(-`detected0'))) ), exp(`lnsigma')))
end

ml model lf reporting_delays ///
	(time: days_since_first_report = ) ///
	(detected0: total_deaths = ) ///
	(missed_realdeaths: min_realdeaths = i.end_week) ///
	(lnsigma: ) if end_week < date("20200501","YMD")
ml maximize

display "k="exp(_b[#1:_cons])
display "beta=limit*"(1-1/(1+exp(-_b[#2:_cons])))
display "alpha="(1/(1+exp(-_b[#2:_cons])))

gen delay_adj_total_deaths3 = total_deaths/(1-1/(1+exp(-_b[#2:_cons]))*exp(-exp(_b[#1:_cons])*days_since_first_report))

twoway scatter est_real_total_deaths days_to_report
twoway scatter delay_adj_total_deaths days_to_report
twoway scatter delay_adj_total_deaths2 days_to_report
twoway scatter delay_adj_total_deaths3 days_to_report

reg est_real_total_deaths days_to_report i.end_week
reg delay_adj_total_deaths days_to_report i.end_week
reg delay_adj_total_deaths2 days_to_report i.end_week
reg delay_adj_total_deaths3 days_to_report i.end_week

corr est_real_total_deaths delay_adj_total_deaths delay_adj_total_deaths2 delay_adj_total_deaths3
*/

log close
