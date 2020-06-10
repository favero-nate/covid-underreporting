clear all
capture log close
log using "..\logs\pulldata.txt", text replace

import delimited "https://covidtracking.com/api/v1/states/daily.csv", stringcols(1)
rename date olddate
gen date = date(olddate, "YMD")
format date %tdCCYYNNDD
order date
drop olddate
save "..\data\covidtracking.dta", replace

insheet using "..\data\source_files\State_Custom_Data.csv", clear
gen week_str = string(week,"%02.0f")
gen yr = substr(season,3,2) if week > 39
replace yr = substr(season,-2,2) if week <= 39
gen epi_week = "20"+yr+"w"+week_str
epiweek2 epi_week, start(weekstartingdate) end(date) // requires userwritten package EPIWEEK
format date %tdCCYYNNDD
destring numinfluenzadeaths-percentcomplete, replace ignore("Insufficient Data" "," ">" "<" "%")
drop percentpi week_str area agegroup yr weekstartingdate
order date
rename subarea state
replace state = "New York" if state == "New York City"
collapse (sum) numinfluenzadeaths-percentcomplete (first) season epi_week, by(state date)
save "..\data\cdc_historical_deaths.dta", replace

insheet using "https://data.cdc.gov/resource/r8kw-7aab.csv?%24offset=1000", clear
export delimited using "..\data\past_reports\unprocessed_files/$S_DATE cdc_deaths_raw2", replace
save "..\data\cdc_deaths.dta", replace
insheet using "https://data.cdc.gov/resource/r8kw-7aab.csv?%24offset=0", clear
export delimited using "..\data\past_reports\unprocessed_files/$S_DATE cdc_deaths_raw1", replace
append using "..\data\cdc_deaths.dta"
gen date = date(substr(end_week,1,10), "YMD")
format date %tdCCYYNNDD
gen report_date = date(substr(data_as_of,1,10), "YMD")
format report_date %tdCCYYNNDD
order date report_date
gen expected_deaths = total_deaths / percent_of_expected_deaths
order expected_deaths, after(total_deaths)
drop start_week group indicator percent_of_expected_deaths footnote
replace state = "New York" if state == "New York City"
rename pneumonia_influenza_or_covid pneumon_influ_or_covid

foreach var of varlist covid_deaths-pneumon_influ_or_covid {
	replace `var' = 5 if `var' == .
}
collapse (sum) covid_deaths-pneumon_influ_or_covid (first) report_date, by(state date)

save "..\data\cdc_deaths.dta", replace
save "..\data\past_reports/$S_DATE cdc_deaths.dta", replace

insheet using "..\data\source_files\R12565679_SL040.txt", clear
rename geo_fips fips
rename geo_name state
rename se_* *
rename t005_001 population
gen pop_0to9 = t005_002 + t005_003
gen pop_10to19 = t005_004 + t005_005
gen pop_20to29 = t005_006 + t005_007
gen pop_30to39 = t005_008 + t005_009
gen pop_40to49 = t005_010 + t005_011
gen pop_50to59 = t005_012 + t005_013
gen pop_60to69 = t005_014 + t005_015
gen pop_70to79 = t005_016 + t005_017
gen pop_80plus = t005_018 + t005_019
keep if fips > 0 & fips < 60
foreach var of varlist pop* {
	egen `var'_us = total(`var')
}
keep fips state pop*
gen tmp = 1
save "..\data\population.dta", replace

insheet using "..\data\source_files\verity_ifr_estimates.csv", clear
gen tmp = 1
merge 1:m tmp using "..\data\population.dta"
drop _merge tmp

foreach var of varlist _* {
	gen deaths`var'_us = `var' * pop`var'_us
}
egen deaths_us = rowtotal(deaths_*_us)
foreach var of varlist _* {
	gen weighted_pop`var' = (pop`var' * deaths`var'_us * population_us) / (deaths_us * pop`var'_us)
}
egen risk_standardized_population = rowtotal(weighted_pop*)
keep fips state population risk_standardized_population

save "..\data\population.dta", replace

log close