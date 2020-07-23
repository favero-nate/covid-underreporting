clear all
capture log close
local dropbox "C:\Users\favero\Dropbox\covid-trendlines"
log using "..\logs\7day_rolling_avg_with_coverage_adj.txt", text replace

use "..\data\population.dta"

merge 1:m fips using "..\data\covidtracking.dta", keep(2 3)

order date fips
sort fips state date

xtset fips date

gen d_pos = d.positive
gen d_neg = d.negative

// for negative values of new tests: create flag & replace negative values with zeros... cumulative case counts can't truly drop, so these reflect some sort of reporting error
gen smoothed_d_pos = d_pos
replace smoothed_d_pos = d_pos + f.d_pos if f.d_pos < 0
replace smoothed_d_pos = 0 if d_pos < 0
gen smoothed_d_neg = d_neg
replace smoothed_d_neg = d_neg + f.d_neg if f.d_neg < 0
replace smoothed_d_neg = 0 if d_neg < 0
// smoothing for 2nd time (allows for 2 consecutive days of artificially inflated reporting):
gen doublesmoothed_d_pos = smoothed_d_pos
replace doublesmoothed_d_pos = smoothed_d_pos + f.smoothed_d_pos if f.smoothed_d_pos < 0
replace doublesmoothed_d_pos = 0 if smoothed_d_pos < 0
gen doublesmoothed_d_neg = smoothed_d_neg
replace doublesmoothed_d_neg = smoothed_d_neg + f.smoothed_d_neg if f.smoothed_d_neg < 0
replace doublesmoothed_d_neg = 0 if smoothed_d_neg < 0
// smoothing for 3rd time (allows for 3 consecutive days of artificially inflated reporting):
gen new_pos = doublesmoothed_d_pos
replace new_pos = doublesmoothed_d_pos + f.doublesmoothed_d_pos if f.doublesmoothed_d_pos < 0
replace new_pos = 0 if new_pos < 0
gen new_neg = doublesmoothed_d_neg
replace new_neg = doublesmoothed_d_neg + f.doublesmoothed_d_neg if f.doublesmoothed_d_neg < 0
replace new_neg = 0 if new_neg < 0

gen new_pos_7d = (new_pos + l.new_pos + l2.new_pos + l3.new_pos + l4.new_pos + l5.new_pos + l6.new_pos)/7
gen new_neg_7d = (new_neg + l.new_neg + l2.new_neg + l3.new_neg + l4.new_neg + l5.new_neg + l6.new_neg)/7

gen p_pos_7d = new_pos_7d/(new_pos_7d+new_neg_7d)*100


// problematic data flag
gen problematic_data = (d_pos<-2|d_neg<-2)
replace problematic_data = 1 if d_neg <= 0 & l.d_neg <= 0 & l2.d_neg <= 0 & d_pos >= 5 & l.d_pos >= 5 & l2.d_pos >= 5
// entent out through 7 days
gen problematic_data_7d = problematic_data
replace problematic_data_7d = 1 if l.problematic_data==1 | l2.problematic_data==1 | l3.problematic_data==1 | l4.problematic_data==1 | l5.problematic_data==1 | l6.problematic_data==1 | l7.problematic_data==1
// add one last check based on 7 day average
replace problematic_data = 1 if p_pos_7d == 100
replace problematic_data_7d = 1 if p_pos_7d == 100


gen adj_case_count_pc_7d = new_pos_7d*(1+.026213*p_pos_7d) / population * 100000 // adjustment based on results from multilevel_and_nonlinear_models_of_covid_severity

order date fips state problematic_data problematic_data_7d adj_case_count_pc_7d new_pos_7d new_neg_7d p_pos_7d new_pos new_neg positive negative population
keep date-population

export delimited using "`dropbox'/covid_trendlines", replace

drop if population==.

format date %tdnn/dd
la var adj_case_count_pc_7d "Estimated prevalence (relative to population size)"
	
gen cound_7d_available = (adj_case_count_pc_7d!=.)
replace adj_case_count_pc_7d = 0 if problematic_data == 1 & adj_case_count_pc_7d == .

local c_date = c(current_date)
local c_date = subinstr("`c_date'", " ", "_", .)

set scheme s2color

encode state, gen(state_id)
forvalues i = 1/51 {
    local state : label state_id `i'
	quietly sum problematic_data_7d if state_id==`i'
	if r(mean) == 0 {
		twoway (line adj_case_count_pc_7d date) if state_id==`i' & cound_7d_available==1, title("`state'") subtitle("Prevalence of newly confirmed COVID-19 cases, adjusted for" "testing volume (lags 2-4 weeks behind initial infections)") note("Estimates by covidtrendlines.com; data from covidtracking.com (CC BY-NC-4.0)") xtitle("") ylabel(0 55 110) tlabel(1mar2020(14)19jul2020) tmtick(##2) xsize(5.5) ysize(4)
		graph export "`dropbox'/`state'_`c_date'.png", replace width(1500)
	}
	else {
		twoway (line adj_case_count_pc_7d date if cound_7d_available==1) (scatter adj_case_count_pc_7d date if problematic_data_7d==1) if state_id==`i', title("`state'") subtitle("Prevalence of newly confirmed COVID-19 cases, adjusted for" "testing volume (lags 2-4 weeks behind initial infections)") note("Estimates by covidtrendlines.com; data from covidtracking.com (CC BY-NC-4.0)") xtitle("") ylabel(0 55 110) tlabel(1mar2020(14)19jul2020) tmtick(##2) xsize(5.5) ysize(4) legend(order(2 "Inconsistent or unusual data reported") position(6))
		graph export "`dropbox'/`state'_`c_date'.png", replace width(1500)
	}
}


// national analysis

gen full_reporting = (new_neg_7d!=. & new_pos_7d!=.)
collapse (sum) new_pos_7d new_neg_7d population full_reporting, by(date)
drop if full_reporting < 51
drop if population < 327167434

gen p_pos_7d = new_pos_7d/(new_pos_7d+new_neg_7d)*100
gen adj_case_count_7d = new_pos_7d*(1+.026213*p_pos_7d) // adjustment based on results from multilevel_and_nonlinear_models_of_covid_severity
gen cound_7d_available = (adj_case_count_7d!=.)
la var adj_case_count_7d "Estimated prevalence"

twoway (line adj_case_count_7d date) if cound_7d_available==1, title("United States (50 states + DC)") subtitle("Prevalence of newly confirmed COVID-19 cases, adjusted for" "testing volume (lags 2-4 weeks behind initial infections)") note("Estimates by covidtrendlines.com; data from covidtracking.com (CC BY-NC-4.0)") ylabel(0) xtitle("") tlabel(1mar2020(14)19jul2020) tmtick(##2) xsize(5.5) ysize(4)
graph export "`dropbox'/USA_`c_date'.png", replace width(1500)

la var new_pos_7d "How many cases are reported"
la var adj_case_count_7d "My estimates of how many cases we'd find under broader testing"

twoway (line adj_case_count_7d date) (line new_pos_7d date, lpattern(dash)) if cound_7d_available==1, subtitle("Comparison of my adjusted case estimates to how" "many cases were reported (50 states + DC)") note("Estimates by covidtrendlines.com; data from covidtracking.com (CC BY-NC-4.0)") ylabel(0(25000)50000) xtitle("") ytitle("Detected cases per day (7-day rolling avg.)") tlabel(1mar2020(14)19jul2020) tmtick(##2) xsize(5.5) ysize(4) legend(col(1))
graph export "`dropbox'/methodology1_`c_date'.png", replace width(1500)

la var p_pos_7d "Percent positive tests"

twoway (line p_pos_7d date) if cound_7d_available==1, subtitle("Percent positive tests, used to adjust simple" "confirmed case count (50 states + DC)") note("Estimates by covidtrendlines.com; data from covidtracking.com (CC BY-NC-4.0)") ylabel(0(10)20) xtitle("") tlabel(1mar2020(14)19jul2020) tmtick(##2) xsize(5.5) ysize(4)
graph export "`dropbox'/methodology2_`c_date'.png", replace width(1500)

gen total_tests_7d = new_pos_7d + new_neg_7d
la var total_tests_7d "Total tests per day (7-day rolling avg.)"

twoway (line total_tests_7d date) if cound_7d_available==1, subtitle("Total number of tests (50 states + DC)") note("Estimates by covidtrendlines.com; data from covidtracking.com (CC BY-NC-4.0)") xtitle("") tlabel(1mar2020(14)19jul2020) ylabel(0(250000)500000) tmtick(##2) xsize(5.5) ysize(4)
graph export "`dropbox'/methodology3_`c_date'.png", replace width(1500)


log close

