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

gen problematic_data = (d_pos<-2|d_neg<-2)
replace problematic_data = 1 if d_neg <= 0 & l.d_neg <= 0 & l2.d_neg <= 0 & d_pos >= 5 & l.d_pos >= 5 & l2.d_pos >= 5
replace problematic_data = 1 if p_pos_7d == 100

gen adj_case_count_pc_7d = new_pos_7d*(1+.026213*p_pos_7d) / population * 100000 // adjustment based on results from multilevel_and_nonlinear_models_of_covid_severity

order date fips state problematic_data adj_case_count_pc_7d new_pos_7d new_neg_7d p_pos_7d new_pos new_neg positive negative population
keep date-population

export delimited using "`dropbox'/covid_trendlines", replace

drop if population==.

format date %tdnn/dd
la var adj_case_count_pc_7d "Estimated severity"
    //twoway (line adj_case_count_pc_7d date) (scatter adj_case_count_pc_7d date if problematic_data==1) if state_id==2, by(state, note("")) title("Relative prevalence of newly confirmed cases," "adjusted for testing volume (7-day rolling average)") xtitle("") ylabel(0 50 100) note("Data sources: covidtracking.com, US Census Bureau (Social Explorer)") legend(order(2 "Inconsistent data reports"))
	
gen cound_7d_available = (adj_case_count_pc_7d!=.)
replace adj_case_count_pc_7d = 0 if problematic_data == 1 & adj_case_count_pc_7d == .

egen state_id = group(fips)
forvalues i = 1/51 {
    quietly sum problematic_data if state_id==`i'
	if r(mean) == 0 {
		twoway (line adj_case_count_pc_7d date) if state_id==`i' & cound_7d_available==1, by(state, note("Graph by covidtrendlines.com; data from covidtracking.com (CC BY-NC-4.0)")) title("Relative prevalence of newly confirmed cases," "adjusted for testing volume (7-day rolling average)") xtitle("") ylabel(0 50 100)
		graph export "`dropbox'/state`i'.png", replace width(1500)
	    
	}
	else {
		twoway (line adj_case_count_pc_7d date if cound_7d_available==1) (scatter adj_case_count_pc_7d date if problematic_data==1) if state_id==`i', by(state, note("Graph by covidtrendlines.com; data from covidtracking.com (CC BY-NC-4.0)")) title("Relative prevalence of newly confirmed cases," "adjusted for testing volume (7-day rolling average)") xtitle("") ylabel(0 50 100) legend(order(2 "Inconsistent/suspect data reports"))
		graph export "`dropbox'/state`i'.png", replace width(1500)
	}
}

log close

