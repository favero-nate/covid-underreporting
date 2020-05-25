clear all
capture log close
log using "..\logs\simple_indicator_of_covid_severity.txt", text replace

use "..\data\weeklydata.dta"


*** Nationwide Analysis ***

//note: treats missing as 0, and a handful of states aren't yet reporting cases (or more aren't reporting negative test results) in early years
foreach var of varlist covid_deaths adj_covid_deaths adj_total_deaths expected_deaths adj_pneumon_influ_or_covid expected_influ_pneu_deaths new_pos new_neg deathincrease {
	egen us_`var' = total(`var'), by(end_week) missing
}

gen us_p_pos = us_new_pos/(us_new_pos+us_new_neg)*100
gen us_p_posXnew_pos = us_p_pos*us_new_pos
gen us_adj_excess_deaths = (us_adj_total_deaths-us_expected_deaths)
gen us_adj_excess_respir_deaths = (us_adj_pneumon_influ_or_covid-us_expected_influ_pneu_deaths)

egen us_tag = tag(end_week)

set scheme s2mono
format end_week %tdnn/dd

twoway (line us_adj_excess_respir_deaths end_week, yaxis(1)) (line us_p_posXnew_pos end_week, yaxis(2)) (line us_new_pos end_week, yaxis(3)) if us_p_posXnew_pos != . & us_tag==1 & days_to_report > 14 & days_to_report!=.


reg us_adj_covid_deaths us_new_pos l.us_new_pos if days_to_report > 14 & us_tag==1, cluster(fips) nocons
predict us_naive_case_count
la var us_naive_case_count "us_naive_case_count"

reg us_adj_covid_deaths c.us_new_pos#c.us_p_pos c.l.us_new_pos#c.l.us_p_pos if days_to_report > 14 & us_tag==1, cluster(fips) nocons
predict us_estimated_death_count
la var us_estimated_death_count "us_estimated_death_count"

twoway (line us_estimated_death_count end_week) (line us_adj_covid_deaths end_week) (line us_naive_case_count end_week) if us_estimated_death_count != . & us_tag==1 & days_to_report > 14 & days_to_report!=.

twoway (line us_estimated_death_count end_week) (line us_covid_deaths end_week) (line us_naive_case_count end_week) if us_estimated_death_count != . & us_tag==1 & days_to_report > 14 & days_to_report!=.


reg us_adj_excess_respir_deaths us_new_pos l.us_new_pos if days_to_report > 14 & us_tag==1, cluster(fips) nocons
predict us_naive_case_count2
la var us_naive_case_count2 "us_naive_case_count2"

reg us_adj_excess_respir_deaths c.us_new_pos#c.us_p_pos c.l.us_new_pos#c.l.us_p_pos if days_to_report > 14 & us_tag==1, cluster(fips) nocons
predict us_estimated_death_count2
la var us_estimated_death_count2 "us_estimated_death_count2"

twoway (line us_estimated_death_count2 end_week) (line us_adj_excess_respir_deaths end_week) (line us_naive_case_count2 end_week) if us_estimated_death_count != . & us_tag==1 & days_to_report > 14 & days_to_report!=.


reg us_adj_excess_deaths us_new_pos l.us_new_pos if days_to_report > 14 & us_tag==1, cluster(fips) nocons
predict us_naive_case_count3
la var us_naive_case_count3 "us_naive_case_count3"

reg us_adj_excess_deaths c.us_new_pos#c.us_p_pos c.l.us_new_pos#c.l.us_p_pos if days_to_report > 14 & us_tag==1, cluster(fips) nocons
predict us_estimated_death_count3
la var us_estimated_death_count3 "us_estimated_death_count3"

twoway (line us_estimated_death_count3 end_week) (line us_adj_excess_deaths end_week) (line us_naive_case_count3 end_week) if us_estimated_death_count != . & us_tag==1 & days_to_report > 14 & days_to_report!=.


*** State Analyses ***

reg adj_excess_respir_deaths_pc c.new_pos_pc c.l.new_pos_pc  if days_to_report > 14, nocons
capture drop naive_case_count_pc
predict naive_case_count_pc
la var naive_case_count_pc "naive_case_count_pc"

reg adj_excess_respir_deaths_pc c.new_pos_pc#c.p_pos c.l.new_pos_pc#c.l.p_pos  if days_to_report > 14, nocons
capture drop estimated_death_count_pc
predict estimated_death_count_pc
la var estimated_death_count_pc "estimated_death_count_pc"

// ten states w most covid cases_pc
twoway (line adj_excess_respir_deaths_pc end_week) (line estimated_death_count_pc end_week) (line naive_case_count_pc end_week) if estimated_death_count_pc != . & (fips==10 | fips==11 | fips==22 | fips==24 | fips==25 | fips==26 | fips==34 | fips==36 | fips==42 | fips==44) & days_to_report > 14 & days_to_report!=., by(state)
//drop Louisiana b/c reported number of negative cases drops half way through series
twoway (line adj_excess_respir_deaths_pc end_week) (line estimated_death_count_pc end_week) (line naive_case_count_pc end_week) if estimated_death_count_pc != . & (fips==10 | fips==11 | fips==24 | fips==25 | fips==26 | fips==34 | fips==36 | fips==42 | fips==44) & days_to_report > 14 & days_to_report!=., by(state)





log close