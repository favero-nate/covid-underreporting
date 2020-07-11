clear all
capture log close
local dropbox "C:\Users\favero\Dropbox\covid-trendlines"
log using "..\logs\deaths_to_hospitalizations.txt", text replace

use "..\data\covidtracking.dta"

drop if state == "NJ" & date == date("2020/06/25", "YMD") // highly unusual datapoint; I'm guessing NJ must have reported a bunch of backlogged deaths in batch (adding probable deaths to their reporting?); at any rate, getting dropping because this data point doesn't appear to be present in graph I'm reproducing

preserve

*** Reproduce the original (misleading) graph created by someone else (https://bit.ly/3eh5QXS) ***

codebook state if date == date("2020/03/17", "YMD") & deathincrease > 0 & deathincrease != .
codebook state if date == date("2020/03/18", "YMD") & deathincrease > 0 & deathincrease != .
codebook state if date == date("2020/03/19", "YMD") & deathincrease > 0 & deathincrease != .
codebook state if date == date("2020/03/20", "YMD") & deathincrease > 0 & deathincrease != .
codebook state if date == date("2020/03/21", "YMD") & deathincrease > 0 & deathincrease != .
codebook state if date == date("2020/03/22", "YMD") & deathincrease > 0 & deathincrease != .

codebook state if date >= date("2020/03/17", "YMD") & date <=date("2020/03/21", "YMD") & deathincrease > 0 & deathincrease != .


// Commented out because original graph kept these observations
//keep if hospitalizedcurrently != .

collapse (sum) hospitalizedcurrently deathincrease, by(date)

replace hospitalizedcurrently = . if hospitalizedcurrently == 0

tsset date

keep if date >= date("2020/03/17", "YMD") &  date < date("2020/07/07", "YMD")

forvalues i = 1/6 {
    gen l`i'_hospitalizedcurrently = l`i'.hospitalizedcurrently
    gen l`i'_deathincrease = l`i'.deathincrease
}

egen hospitalizedcurrently_7d = rowtotal(hospitalizedcurrently l?_hospitalizedcurrently)
egen deathincrease_7d = rowtotal(deathincrease l?_deathincrease)
gen deaths_as_p_of_hosp_7d = deathincrease_7d / hospitalizedcurrently_7d * 100
drop l?_*

gen hosp_in_10s = hospitalizedcurrently / 10

la var deathincrease "Daily COVID-19 Deaths"
la var hosp_in_10s "COVID-19 Hospitalization (Divided by 10 for Comparison)"
la var deaths_as_p_of_hosp_7d "Deaths as a share of Hospitalizations (7-Day Average)"
format date %tdnn/dd

twoway (bar hosp_in_10s date, yaxis(1) color(gs14)) (bar deathincrease date, yaxis(1) color(blue)) (line deaths_as_p_of_hosp_7d date, yaxis(2) color(orange)), tlabel(17mar2020(14)7jul2020) legend(col(1)) ylabel(0(1000)7000, axis(1) angle(0)) ylabel(0 "0%" 1 "1%" 2 "2%" 3 "3%" 4 "4%" 5 "5%" 6 "6%" 7 "7%" 8 "8%", axis(2) angle(0)) ytitle("") ytitle("", axis(2)) xtitle("") title("Replication of original (highly misleading) graph") note("covidtrendlines.com; data from covidtracking.com (CC BY-NC-4.0)" "original graph at https://bit.ly/3eh5QXS")
graph export "`dropbox'/misleading_graph.png", replace

list date deaths_as_p_of_hosp_7d if deaths_as_p_of_hosp_7d >= 6
list date deaths_as_p_of_hosp_7d if date <= date("2020/03/22", "YMD")

restore

*** Creating a better graph (still doesn't account for lag between hospitalizations and deaths) ***

//Repeat process except now I drop any observations were current hospitalizations variable is missing:
keep if hospitalizedcurrently != .

tab state if date == date("2020/03/17", "YMD")
tab state if date == date("2020/03/18", "YMD")
tab state if date == date("2020/03/19", "YMD")
tab state if date == date("2020/03/20", "YMD")
tab state if date == date("2020/03/21", "YMD")
tab state if date == date("2020/03/22", "YMD")

collapse (sum) hospitalizedcurrently deathincrease, by(date)

replace hospitalizedcurrently = . if hospitalizedcurrently == 0

tsset date

keep if date >= date("2020/03/17", "YMD") &  date < date("2020/07/07", "YMD")

forvalues i = 1/6 {
    gen l`i'_hospitalizedcurrently = l`i'.hospitalizedcurrently
    gen l`i'_deathincrease = l`i'.deathincrease
}

egen hospitalizedcurrently_7d = rowtotal(hospitalizedcurrently l?_hospitalizedcurrently)
egen deathincrease_7d = rowtotal(deathincrease l?_deathincrease)
gen deaths_as_p_of_hosp_7d = deathincrease_7d / hospitalizedcurrently_7d * 100
drop l?_*

gen hosp_in_10s = hospitalizedcurrently / 10

la var deathincrease "Daily COVID-19 Deaths"
la var hosp_in_10s "COVID-19 Hospitalization (Divided by 10 for Comparison)"
la var deaths_as_p_of_hosp_7d "Deaths as a share of Hospitalizations (7-Day Average)"
format date %tdnn/dd

twoway (bar hosp_in_10s date, yaxis(1) color(gs14)) (bar deathincrease date, yaxis(1) color(blue)) (line deaths_as_p_of_hosp_7d date, yaxis(2) color(orange)), tlabel(17mar2020(14)7jul2020) legend(col(1)) ylabel(0(1000)7000, axis(1) angle(0)) ylabel(0 "0%" 1 "1%" 2 "2%" 3 "3%" 4 "4%" 5 "5%" 6 "6%" 7 "7%" 8 "8%", axis(2) angle(0)) ytitle("") ytitle("", axis(2)) xtitle("") title("Only counting deaths from states reporting hospitalizations") note("covidtrendlines.com; data from covidtracking.com (CC BY-NC-4.0)" "original graph at https://bit.ly/3eh5QXS")
graph export "`dropbox'/corrected_graph.png", replace

log close
