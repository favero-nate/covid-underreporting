clear all
capture log close
log using "..\logs\simple_indicator_of_covid_severity.txt", text replace

use "..\data\weeklydata.dta"

gen l_new_pos_pc = l.new_pos_pc
gen l_p_pos = l.p_pos

set scheme s2mono
format end_week %tdnn/dd

foreach var of varlist adj_covid_deaths_pc adj_excess_respir_deaths_pc adj_excess_deaths_pc {
	replace `var' = . if days_to_report <= 14
}

preserve
keep if days_to_report > 14 & dayscollapsed == 7 & l_p_pos != . & fips != . & fips != 72

*** State Analyses ***

// covid deaths

reg adj_covid_deaths_pc c.l_new_pos_pc if l_p_pos != ., cluster(fips) nocons
	local naive_coef = _b[l_new_pos_pc]
	estimates store dv1_1, title("COVID-19 deaths")
	margins, dydx(l_new_pos_pc)

reg adj_covid_deaths_pc c.l_new_pos_pc c.l_new_pos_pc#c.l_p_pos, cluster(fips) nocons
	local cov_adj_coef1 = _b[l_new_pos_pc]
	local cov_adj_coef2 = _b[l_new_pos_pc#l_p_pos]
	estimates store dv1_2, title(" ")
	margins, dydx(l_new_pos_pc) at(l_p_pos=(5 15 25 35 45))
	tab end_week if e(sample)==1
	tab dayscollapsed if e(sample)==1, missing

// excess respiratory deaths

reg adj_excess_respir_deaths_pc c.l_new_pos_pc if l_p_pos != ., cluster(fips) nocons
	estimates store dv2_1, title("Excess select respiratory illness deaths")
	margins, dydx(l_new_pos_pc)

reg adj_excess_respir_deaths_pc c.l_new_pos_pc c.l_new_pos_pc#c.l_p_pos, cluster(fips) nocons
	estimates store dv2_2, title(" ")
	margins, dydx(l_new_pos_pc) at(l_p_pos=(5 15 25 35 45))
	tab end_week if e(sample)==1
	tab dayscollapsed if e(sample)==1, missing

// excess all-cause deaths

reg adj_excess_deaths_pc c.l_new_pos_pc if l_p_pos != ., cluster(fips) nocons
	estimates store dv3_1, title("Excess all-cause deaths")
	margins, dydx(l_new_pos_pc)

reg adj_excess_deaths_pc c.l_new_pos_pc c.l_new_pos_pc#c.l_p_pos, cluster(fips) nocons
	estimates store dv3_2, title(" ")
	margins, dydx(l_new_pos_pc) at(l_p_pos=(5 15 25 35 45))
	tab end_week if e(sample)==1
	tab dayscollapsed if e(sample)==1, missing

// covid hospitalizations
restore
preserve
keep if dayscollapsed==7 & fips != . & fips != 72 & l_p_pos != .

reg hospitalizedcurrently_pc c.l_new_pos_pc if l_p_pos != ., cluster(fips) nocons
	estimates store dv4_1, title("Current COVID-19 hospitalizations")
	margins, dydx(l_new_pos_pc)
	tab end_week if e(sample)==1
	tab dayscollapsed if e(sample)==1, missing

reg hospitalizedcurrently_pc c.l_new_pos_pc c.l_new_pos_pc#c.l_p_pos, cluster(fips) nocons
	estimates store dv4_2, title(" ")
	margins, dydx(l_new_pos_pc) at(l_p_pos=(5 15 25 35 45))
	gen hospitalization_sample = e(sample)
	tab state hospitalization_sample

// figure
restore
preserve

replace adj_covid_deaths = . if fips!=.
gen state_reporting = 1 if new_neg != . & new_pos != .
collapse (firstnm) adj_covid_deaths days_to_report (sum) new_pos new_neg state_reporting, by(end_week)

tsset end_week, delta(7)
gen l_new_pos = l.new_pos
gen l_p_pos = l.new_pos/(l.new_pos+l.new_neg)*100
drop if end_week<date("2020/03/21", "YMD") | days_to_report <= 14 | days_to_report == .

display "Adjustment factor: "+`cov_adj_coef2'/`cov_adj_coef1' 
gen cov_adj_case_count = l_new_pos*(1+`cov_adj_coef2'/`cov_adj_coef1'*l_p_pos)
reg adj_covid_deaths l_new_pos
predict naive_count_prediction
la var naive_count_prediction "Prediction from naïve case count (new cases)"
reg adj_covid_deaths cov_adj_case_count
predict cov_adj_prediction
la var cov_adj_prediction "Prediction from detection-adjusted cases"

/*
gen naive_count_prediction = `naive_coef'*l_new_pos
la var naive_count_prediction "Prediction from naïve case count (new cases)"
gen cov_adj_prediction = `cov_adj_coef1'*l_new_pos + `cov_adj_coef2'*l_new_pos*l_p_pos
la var cov_adj_prediction "Prediction from detection-adjusted cases"
*/

twoway (line adj_covid_deaths end_week) (line naive_count_prediction end_week) (line cov_adj_prediction end_week), tlabel(21mar2020(7)30may2020)

list end_week adj_covid_deaths naive_count_prediction cov_adj_prediction state_reporting l_p_pos


// make tables
restore
keep if dayscollapsed==7 & l_p_pos!=. & fips != . & fips != 72 & (adj_covid_deaths_pc!=. | adj_excess_respir_deaths_pc!=. | adj_excess_deaths_pc!=. | hospitalizedcurrently_pc!=.)
tab end_week

la var l_new_pos_pc "Newly confirmed cases"
la var l_p_pos "Percent positive (among new tests)"
la var adj_covid_deaths_pc "COVID-19 deaths"
la var adj_excess_respir_deaths_pc "Excess select respiratory illness deaths"
la var adj_excess_deaths_pc "Excess all-cause deaths"
la var hospitalizedcurrently_pc "Current COVID-19 hospitalizations"

estpost tabstat l_new_pos_pc l_p_pos adj_covid_deaths_pc adj_excess_respir_deaths_pc adj_excess_deaths_pc hospitalizedcurrently_pc, statistics(count mean sd min max) columns(statistics)

esttab, title(Supplemental exhibit 1. Descriptive statistics) cells("count mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2))") nomtitle nonumber label noobs addnotes("Abbreviations: sd = standard deviation; min = minimum; max = maximum"), using "tables.rtf", replace

esttab dv?_?, ///
   title(Supplemental exhibit 2. Regression results) /// 
   nonum mlabels(,titles) cells(b(fmt(a2) star) se(par fmt(a2))) ///
   legend starlevels(* 0.05 ** 0.01 *** 0.001) label ///
   stats(r2 N, fmt(3 0) label("R-sqr" N)) ///
   coef(l_new_pos_pc "New cases" c.l_new_pos_pc#c.l_p_pos "New cases X % Pos.") ///
   addnotes("(two-tailed). Standard errors (se), in parentheses, are robust to clustering by state.") ///
   , using "tables.rtf", append


log close