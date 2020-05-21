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

insheet using "https://data.cdc.gov/resource/r8kw-7aab.csv", clear
export delimited using "..\data\past_reports\unprocessed_files/$S_DATE cdc_deaths_raw", replace
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

insheet using "https://www2.census.gov/programs-surveys/popest/datasets/2010-2019/national/totals/nst-est2019-alldata.csv", clear
rename state fips
rename name state
rename popestimate2019 population
keep if fips > 0 & fips < 60
keep fips state population
save "..\data\population.dta", replace

log close