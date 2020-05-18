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

/*
insheet using "https://data.cdc.gov/resource/xkkf-xrst.csv", clear
gen date = date(substr(week_ending_date,1,10), "YMD")
format date %tdCCYYNNDD
order date
keep date state 
save "..\data\allcause.dta", replace
*/

insheet using "..\data\Weekly_Counts_of_Deaths_by_State_and_Select_Causes__2014-2018.csv", clear
gen date = date(weekendingdate, "MDY")
format date %tdCCYYNNDD
rename jurisdictionofoccurrence state
replace state = "New York" if state == "New York City"
foreach var of varlist allcause-cerebrovasculardiseasesi60i69 {
	replace `var' = 5 if `var' == .
}
collapse (sum) allcause-cerebrovasculardiseasesi60i69 (first) mmwryear mmwrweek, by(state date)
save "..\data\cdc_1418deaths.dta", replace

insheet using "..\data\Weekly_Counts_of_Deaths_by_State_and_Select_Causes__2019-2020.csv", clear
gen date = date(weekendingdate, "MDY")
format date %tdCCYYNNDD
rename jurisdictionofoccurrence state
replace state = "New York" if state == "New York City"
foreach var of varlist allcause-cerebrovasculardiseasesi60i69 {
	replace `var' = 5 if `var' == .
}
collapse (sum) allcause-cerebrovasculardiseasesi60i69 (first) mmwryear mmwrweek, by(state date)
save "..\data\cdc_1920deaths.dta", replace

insheet using "https://data.cdc.gov/resource/r8kw-7aab.csv", clear
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

insheet using "https://www2.census.gov/programs-surveys/popest/datasets/2010-2019/national/totals/nst-est2019-alldata.csv", clear
rename state fips
rename name state
rename popestimate2019 population
keep if fips > 0 & fips < 60
keep fips state population
save "..\data\population.dta", replace

log close