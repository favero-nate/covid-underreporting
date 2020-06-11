clear all
capture log close
log using "..\logs\simple_indicator_of_covid_severity.txt", text replace

use "..\data\weeklydata.dta"


*** Nationwide Analysis ***

//note: treats missing as 0, and a handful of states aren't yet reporting cases (or more aren't reporting negative test results) in early years
//!!!! probably need to re-do these b/c not good to take state reporting delay adjustments and apply to nationally aggregated data: adj_covid_deaths adj_total_deaths adj_pneumon_influ_or_covid
foreach var of varlist adj_covid_deaths adj_total_deaths adj_pneumon_influ_or_covid covid_deaths expected_deaths expected_influ_pneu_deaths new_pos new_neg deathincrease {
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


reg us_adj_covid_deaths  l.us_new_pos if days_to_report > 10 & us_tag==1, nocons
capture drop us_naive_case_count
predict us_naive_case_count
la var us_naive_case_count "us_naive_case_count"

reg us_adj_covid_deaths  l.us_new_pos c.l.us_new_pos#c.l.us_p_pos if days_to_report > 10 & us_tag==1, nocons
capture drop us_estimated_death_count
predict us_estimated_death_count
la var us_estimated_death_count "us_estimated_death_count"

twoway (line us_adj_covid_deaths end_week) (line us_naive_case_count end_week) (line us_estimated_death_count end_week) if us_estimated_death_count != . & us_tag==1 & days_to_report > 10 & days_to_report!=.

twoway (line us_covid_deaths end_week) (line us_naive_case_count end_week) (line us_estimated_death_count end_week) if us_estimated_death_count != . & us_tag==1 & days_to_report > 14 & days_to_report!=.


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

reg adj_covid_deaths_pc c.l.new_pos_pc  if days_to_report > 14 & days_to_report <= 80 & l.p_pos != ., cluster(fips) nocons
capture drop naive_case_count_pc
predict naive_case_count_pc
la var naive_case_count_pc "Prediction from naïve case count (new cases)"

reg adj_covid_deaths_pc c.l.new_pos_pc c.l.new_pos_pc#c.l.p_pos  if days_to_report > 14 & days_to_report <= 80, cluster(fips) nocons
margins, dydx(l.new_pos_pc) at(l.p_pos=(5 25 45))
capture drop estimated_death_count_pc
predict estimated_death_count_pc
la var estimated_death_count_pc "Prediction from detection-adjusted cases (new cases X percent positive)"

// ten states w most covid cases_pc
tab state if covid_deaths_pc > 5 & covid_deaths_pc!=.

** Figure 2 **
twoway (line adj_excess_respir_deaths_pc end_week) (line naive_case_count_pc end_week) (line estimated_death_count_pc end_week) if estimated_death_count_pc != . & (fips==10 | fips==11 | fips==22 | fips==24 | fips==25 | fips==26 | fips==34 | fips==36 | fips==42 | fips==44) & days_to_report > 14 & days_to_report!=., by(state, note("") row(2)) ytitle("Deaths per 100,000 population") xtitle("") tlabel(21mar2020(14)9may2020) tmtick(##2) legend(col(1) order(1 "Deaths{sup:a}" 2 "Prediction from naïve case count (new cases){sup:b}" 3 "Prediction from detection-adjusted cases (new cases X percent positive){sup:c}")) xsize(7)

twoway (line adj_excess_respir_deaths_pc end_week) (line naive_case_count_pc end_week) (line estimated_death_count_pc end_week) if estimated_death_count_pc != . & state=="New York" & days_to_report > 14 & days_to_report <= 70, ytitle("Deaths per 100,000 population") tlabel(21mar2020(14)9may2020) tmtick(##2)
twoway (line adj_excess_respir_deaths_pc end_week) (line naive_case_count_pc end_week) (line estimated_death_count_pc end_week) if estimated_death_count_pc != . & state=="Rhode Island" & days_to_report > 14 & days_to_report <= 70, ytitle("Deaths per 100,000 population") tlabel(21mar2020(14)9may2020) tmtick(##2)
twoway (line adj_covid_deaths_pc end_week) (line naive_case_count_pc end_week) (line estimated_death_count_pc end_week) if estimated_death_count_pc != . & state=="California" & days_to_report > 14 & days_to_report <= 80, ytitle("Deaths per 100,000 population") tlabel(21mar2020(14)9may2020) tmtick(##2)

twoway  line new_tests_pc end_week if new_tests_pc!=. & dayscollapsed==7 & (fips==10 | fips==11 | fips==22 | fips==24 | fips==25 | fips==26 | fips==34 | fips==36 | fips==42 | fips==44), by(state, row(2))
twoway  line p_pos end_week if p_pos!=. & dayscollapsed==7 & (fips==10 | fips==11 | fips==22 | fips==24 | fips==25 | fips==26 | fips==34 | fips==36 | fips==42 | fips==44), by(state, row(2))
twoway  line p_pos end_week if p_pos!=. & dayscollapsed==7 & state=="California"


gen p_pos_wind = p_pos
replace p_pos_wind = 55 if p_pos == 100


gen hospitalizedcurrently_pc = hospitalizedcurrently * 100000 / population

reg hospitalizedcurrently_pc c.l.new_pos_pc  if dayscollapsed==7 & days_to_report <= 70 & l.p_pos != ., cluster(fips) 
reg hospitalizedcurrently_pc c.l.new_pos_pc c.l.new_pos_pc#c.l.p_pos  if dayscollapsed==7 & days_to_report <= 70, cluster(fips) 
margins, dydx(l.new_pos_pc) at(l.p_pos=(5 25 45))



reg f.adj_excess_respir_deaths_pc c.new_pos_pc c.new_pos_pc#c.p_pos  if f.days_to_report > 14 & f.days_to_report <= 70, cluster(fips)
capture drop estimated_death_count_pc
predict estimated_death_count_pc
la var estimated_death_count_pc "Prediction from detection-adjusted cases (new cases X percent positive)"

// ten states w most covid cases_pc
tab state if covid_deaths_pc > 5 & covid_deaths_pc!=.

** Figure 2 **
twoway line estimated_death_count_pc end_week if estimated_death_count_pc != . & dayscollapsed==7 & fips > 0 & fips <= 10, by(state, note("") row(2))
twoway line estimated_death_count_pc end_week if estimated_death_count_pc != . & dayscollapsed==7 & fips > 10 & fips <= 20, by(state, note("") row(2))
twoway line estimated_death_count_pc end_week if estimated_death_count_pc != . & dayscollapsed==7 & fips > 20 & fips <= 30, by(state, note("") row(2))
twoway line estimated_death_count_pc end_week if estimated_death_count_pc != . & dayscollapsed==7 & fips > 30 & fips <= 40, by(state, note("") row(2))
twoway line estimated_death_count_pc end_week if estimated_death_count_pc != . & dayscollapsed==7 & fips > 40 & fips <= 100, by(state, note("") row(2))



log close