clear all
capture log close
log using "..\logs\simple_indicator_of_covid_severity.txt", text replace

use "..\data\weeklydata.dta"

gen l_new_pos_pc = l.new_pos_pc
gen l_p_pos = l.p_pos 

preserve
keep if days_to_report > 14 & days_to_report != . & l_p_pos != .

set scheme s2mono
format end_week %tdnn/dd

la var adj_excess_respir_deaths_pc "No. of estimated excess respiratory deaths"
la var adj_covid_deaths_pc "Deaths per 100,000 population"

*** State Analyses ***

// covid deaths

reg adj_covid_deaths_pc c.l_new_pos_pc if l_p_pos != ., cluster(fips) nocons
margins, dydx(l_new_pos_pc)
capture drop naive_case_count_pc
predict naive_case_count_pc
la var naive_case_count_pc "Prediction from naïve case count (new cases)"

reg adj_covid_deaths_pc c.l_new_pos_pc c.l_new_pos_pc#c.l_p_pos, cluster(fips) nocons
margins, dydx(l_new_pos_pc) at(l_p_pos=(5 15 25 35 45))
capture drop estimated_death_count_pc
predict estimated_death_count_pc
la var estimated_death_count_pc "Prediction from detection-adjusted cases (new cases X percent positive)"

twoway (line adj_covid_deaths_pc end_week) (line naive_case_count_pc end_week) (line estimated_death_count_pc end_week) if state=="New York", tlabel(21mar2020(7)16may2020)
twoway (line adj_covid_deaths_pc end_week) (line naive_case_count_pc end_week) (line estimated_death_count_pc end_week) if state=="California", tlabel(21mar2020(7)16may2020)

list end_week adj_covid_deaths_pc naive_case_count_pc estimated_death_count_pc new_tests_pc p_pos new_pos_pc if state=="New York"
list end_week adj_covid_deaths_pc naive_case_count_pc estimated_death_count_pc new_tests_pc p_pos new_pos_pc if state=="California"

// excess respiratory deaths

reg adj_excess_respir_deaths_pc c.l_new_pos_pc if l_p_pos != ., cluster(fips) nocons
margins, dydx(l_new_pos_pc)

reg adj_excess_respir_deaths_pc c.l_new_pos_pc c.l_new_pos_pc#c.l_p_pos, cluster(fips) nocons
margins, dydx(l_new_pos_pc) at(l_p_pos=(5 15 25 35 45))

// excess all-cause deaths

reg adj_excess_deaths_pc c.l_new_pos_pc if l_p_pos != ., cluster(fips) nocons
margins, dydx(l_new_pos_pc)

reg adj_excess_deaths_pc c.l_new_pos_pc c.l_new_pos_pc#c.l_p_pos, cluster(fips) nocons
margins, dydx(l_new_pos_pc) at(l_p_pos=(5 15 25 35 45))

// covid hospitalizations
restore
keep if dayscollapsed==7
gen hospitalizedcurrently_pc = hospitalizedcurrently * 100000 / population

reg hospitalizedcurrently_pc c.l_new_pos_pc if l_p_pos != ., cluster(fips) nocons
margins, dydx(l_new_pos_pc)
tab end_week if e(sample)==1

reg hospitalizedcurrently_pc c.l_new_pos_pc c.l_new_pos_pc#c.l_p_pos, cluster(fips) nocons
margins, dydx(l_new_pos_pc) at(l_p_pos=(5 15 25 35 45))
gen hospitalization_sample = e(sample)
tab state hospitalization_sample


log close