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

la var adj_excess_respir_deaths_pc "No. of estimated excess respiratory deaths"
la var us_adj_excess_respir_deaths "No. of estimated excess respiratory deaths"
la var us_covid_deaths "COVID-19 deaths - unadjusted for reporting delay"
la var us_adj_covid_deaths "COVID-19 deaths - adjusted for reporting delay"
//la var us_adj_excess_respir_deaths "Excess respiratory deaths"
la var us_new_pos "No. of new cases"
la var us_p_posXnew_pos "No. of new cases X percent positive"

twoway (line us_adj_excess_respir_deaths end_week, yaxis(1)) (line us_p_posXnew_pos end_week, yaxis(2)) (line us_new_pos end_week, yaxis(3)) if us_p_posXnew_pos != . & us_tag==1 & days_to_report > 14 & days_to_report!=.

** figure 1 **
twoway (line us_adj_excess_respir_deaths end_week, yaxis(1)) (line us_new_pos end_week, yaxis(3)) if us_p_posXnew_pos != . & us_tag==1 & days_to_report > 14 & days_to_report!=., tlabel(14mar2020(7)9may2020) xtitle("") title("Deaths & cases") legend(order(1 "Deaths{sup:b}" 2 "New cases or detection-adjusted cases{sup:c}")) name(figure1a, replace)
twoway (line us_adj_excess_respir_deaths end_week, yaxis(1)) (line us_p_posXnew_pos end_week, yaxis(2)) if us_p_posXnew_pos != . & us_tag==1 & days_to_report > 14 & days_to_report!=., tlabel(14mar2020(7)9may2020) xtitle("") title("Deaths & detection-adjusted cases") legend(off) name(figure1b, replace)
grc1leg figure1a figure1b, legendfrom(figure1a) xsize(7) // xsize doesn't work with this command, so have to do it manually

// (potential replacement for figure 2)
twoway (line us_covid_deaths end_week, yaxis(1)) (line us_p_posXnew_pos end_week, yaxis(2)) (line us_adj_covid_deaths end_week, yaxis(1)) if us_p_posXnew_pos != . & us_tag==1 & days_to_report > 14 & days_to_report!=., tlabel(14mar2020(14)9may2020) xtitle("") ytitle("COVID-19 deaths") legend(order(1 "Deaths - unadjusted for reporting delays" 2 "Deaths - adjusted for reporting delays" 3 "Detection-adjusted cases") col(1)) name(figure2a, replace)
//twoway (line us_adj_covid_deaths end_week, yaxis(1)) (line us_p_posXnew_pos end_week, yaxis(2)) if us_p_posXnew_pos != . & us_tag==1 & days_to_report > 14 & days_to_report!=., tlabel(14mar2020(14)9may2020) xtitle("") legend(off) name(figure2b, replace)
//twoway (line us_adj_excess_deaths end_week, yaxis(1)) (line us_p_posXnew_pos end_week, yaxis(2)) if us_p_posXnew_pos != . & us_tag==1 & days_to_report > 14 & days_to_report!=., tlabel(14mar2020(14)9may2020) tmtick(##2) name(figure2c, replace)
//grc1leg figure2a figure2b, legendfrom(figure2a) xsize(7.5) // xsize doesn't work with this command, so have to do it manually


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

reg adj_excess_respir_deaths_pc c.new_pos_pc c.l.new_pos_pc  if days_to_report > 14 & days_to_report <= 66
capture drop naive_case_count_pc
predict naive_case_count_pc
la var naive_case_count_pc "Prediction from naïve case count (new cases)"

reg adj_excess_respir_deaths_pc c.new_pos_pc#c.p_pos c.l.new_pos_pc#c.l.p_pos  if days_to_report > 14 & days_to_report <= 66
capture drop estimated_death_count_pc
predict estimated_death_count_pc
la var estimated_death_count_pc "Prediction from detection-adjusted cases (new cases X percent positive)"

// ten states w most covid cases_pc
tab state if covid_deaths_pc > 5 & covid_deaths_pc!=.

** Figure 2 **
twoway (line adj_excess_respir_deaths_pc end_week) (line naive_case_count_pc end_week) (line estimated_death_count_pc end_week) if estimated_death_count_pc != . & (fips==10 | fips==11 | fips==22 | fips==24 | fips==25 | fips==26 | fips==34 | fips==36 | fips==42 | fips==44) & days_to_report > 14 & days_to_report!=., by(state, note("") row(2)) ytitle("Deaths per 100,000 population") xtitle("") tlabel(21mar2020(14)9may2020) tmtick(##2) legend(col(1) order(1 "Deaths{sup:a}" 2 "Prediction from naïve case count (new cases){sup:b}" 3 "Prediction from detection-adjusted cases (new cases X percent positive){sup:c}")) xsize(7)

//not used: drop Louisiana b/c reported number of negative cases is missing for part of series (not obvious on graphs)
twoway (line adj_excess_respir_deaths_pc end_week) (line naive_case_count_pc end_week) (line estimated_death_count_pc end_week) if estimated_death_count_pc != . & (fips==10 | fips==22 | fips==24 | fips==25 | fips==26 | fips==34 | fips==36 | fips==42 | fips==44) & days_to_report > 14 & days_to_report!=., by(state, note("")) ytitle("Deaths per 100,000 population") xtitle("") ylabel(0(20)40) ymtick(##2) tlabel(21mar2020(14)9may2020) tmtick(##2) legend(col(1))





log close