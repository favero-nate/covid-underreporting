clear all
capture log close
log using "..\logs\estimating_reporting_delays.txt", text replace

insheet using "..\data\past_reports\nationwide_saturday_reports.csv"

rename end_week end_week_str
rename report_date report_date_str
gen end_week = date(end_week_str, "MDY")
gen report_date = date(report_date_str, "MDY")
format end_week %tdCCYYNNDD
format report_date %tdCCYYNNDD

gen days_to_report = report_date - end_week
sum days_to_report
gen days_since_first_report = days_to_report - r(min)

order end_week report_date days_to_report
sort end_week report_date

destring covid_deaths- pneumon_influ_or_covid, replace ignore(",")

xtset end_week report_date, delta(7)

gen growth_total_deaths = f.total_deaths / total_deaths

bys days_to_report: sum growth_total_deaths

gen est_real_total_deaths = 1.005286 * total_deaths if days_to_report==70
replace est_real_total_deaths = 1.005286 * 1.007821 * total_deaths if days_to_report==63
replace est_real_total_deaths = 1.005286 * 1.007821 * 1.014075 * total_deaths if days_to_report==56
replace est_real_total_deaths = 1.005286 * 1.007821 * 1.014075 * 1.015894 * total_deaths if days_to_report==49
replace est_real_total_deaths = 1.005286 * 1.007821 * 1.014075 * 1.015894 * 1.01353 * total_deaths if days_to_report==42
replace est_real_total_deaths = 1.005286 * 1.007821 * 1.014075 * 1.015894 * 1.01353 * 1.014131 * total_deaths if days_to_report==35
replace est_real_total_deaths = 1.005286 * 1.007821 * 1.014075 * 1.015894 * 1.01353 * 1.014131 * 1.024915 * total_deaths if days_to_report==28
replace est_real_total_deaths = 1.005286 * 1.007821 * 1.014075 * 1.015894 * 1.01353 * 1.014131 * 1.024915 * 1.055341 * total_deaths if days_to_report==21
replace est_real_total_deaths = 1.005286 * 1.007821 * 1.014075 * 1.015894 * 1.01353 * 1.014131 * 1.024915 * 1.055341 * 1.163302 * total_deaths if days_to_report==14
replace est_real_total_deaths = 1.005286 * 1.007821 * 1.014075 * 1.015894 * 1.01353 * 1.014131 * 1.024915 * 1.055341 * 1.163302 * 1.733615 * total_deaths if days_to_report==7

order est_real_total_deaths


capture program drop reporting_delays
program reporting_delays
	args lnf detected time alpha lnsigma
	quietly replace `lnf' = ///
		ln(normalden( $ML_y1,  `alpha' - `alpha'*exp(-(exp(`time') * $ML_y2 )), exp(`lnsigma'+`detected'*$ML_y2 )))
end

ml model lf reporting_delays ///
	(detected: total_deaths = ) ///
	(time: days_to_report = ) ///
	(alpha: i.end_week) ///
	(lnsigma: ) if end_week < date("20200418","YMD")
ml maximize

display "k="exp(_b[#2:_cons])

gen delay_adj_total_deaths = total_deaths / (1-exp(-exp(_b[#2:_cons])*days_to_report))




egen min_realdeaths = max(total_deaths), by(end_week)


capture program drop reporting_delays
program reporting_delays
	args lnf detected time missed_realdeaths lnsigma delta
	quietly replace `lnf' = ///
		ln(normalden( $ML_y1,  ($ML_y3 + exp(`missed_realdeaths')) - (1/(1+exp(-`delta')))*($ML_y3 + exp(`missed_realdeaths'))*exp(-(exp(`time') * $ML_y2 )), exp(`lnsigma'+`detected'*$ML_y2 )))
end

ml model lf reporting_delays ///
	(detected: total_deaths = ) ///
	(time: days_to_report = ) ///
	(missed_realdeaths: min_realdeaths = i.end_week) ///
	(lnsigma: ) /delta if end_week < date("20200418","YMD")
ml maximize

display "k="exp(_b[#2:_cons])


capture program drop reporting_delays
program reporting_delays
	args lnf time detected0 missed_realdeaths lnsigma
	quietly replace `lnf' = ///
		ln(normalden( $ML_y1,  -(1/exp(`time')) * log( ($ML_y3 + exp(`missed_realdeaths') - $ML_y2 )/(($ML_y3 + exp(`missed_realdeaths'))*1/(1+exp(-`detected0'))) ), exp(`lnsigma')))
end

ml model lf reporting_delays ///
	(time: days_since_first_report = ) ///
	(detected0: total_deaths = ) ///
	(missed_realdeaths: min_realdeaths = i.end_week) ///
	(lnsigma: ) if end_week < date("20200418","YMD")
ml maximize

display "k="exp(_b[#1:_cons])
display "beta=limit*"(1-1/(1+exp(-_b[#2:_cons])))
display "alpha="(1/(1+exp(-_b[#2:_cons])))

gen est_real_total_deaths2 = total_deaths/(1-1/(1+exp(-_b[#2:_cons]))*exp(-exp(_b[#1:_cons])*days_since_first_report))


log close
