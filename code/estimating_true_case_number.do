clear all
capture log close
log using "..\logs\estimating_true_case_number.txt", text replace

use "..\data\weeklydata.dta"

reg f.excess_deaths_pc new_pos_pc new_tests_pc if days_to_report > 21 [aweight=population]
reg f.excess_deaths_pc c.new_pos_pc if days_to_report > 21 [aweight=population]
reg f.excess_deaths_pc c.new_pos_pc c.new_pos_pc#c.p_pos if days_to_report > 21 [aweight=population]
gen adj_pos = new_pos_pc*(1+_b[c.new_pos_pc#c.p_pos]/_b[new_pos_pc]*p_pos)
reg f.excess_deaths_pc adj_pos if days_to_report > 21 [aweight=population]

reg f.excess_deaths_pc c.new_pos_pc##c.p_pos##c.p_pos if days_to_report > 21 [aweight=population], cluster(fips)
reg f.excess_deaths_pc c.new_pos_pc c.new_pos_pc#c.p_pos if days_to_report > 21 [aweight=population], cluster(fips)
reg f.excess_deaths_pc c.new_pos_pc#c.p_pos if days_to_report > 21 [aweight=population], cluster(fips)
reg f.excess_deaths_pc c.new_pos_pc#c.p_pos c.new_pos_pc#c.p_pos#c.p_pos if days_to_report > 21 [aweight=population], cluster(fips)
reg f.excess_deaths_pc c.new_pos_pc c.new_pos_pc#c.p_pos i.fips if days_to_report > 21 [aweight=population]
xtreg f.excess_deaths_pc c.new_pos_pc c.new_pos_pc#c.p_pos if days_to_report > 21, re


reg f.excess_deaths_pc c.new_pos_pc#c.p_pos c.new_pos_pc#c.p_pos#c.p_pos if days_to_report > 21 [aweight=population], cluster(fips)
margins, at(p_pos=(5(5)30) new_pos_pc=(100 500))
marginsplot

gen f_excess_deaths_pc = f.excess_deaths_pc
gen f_covdeath_pc = f.covdeath_pc


capture program drop weibull_growth
program weibull_growth
	args lnf alpha pos tests delta
	quietly replace `lnf' = ///
		ln(normalden( $ML_y1,  `alpha' - `alpha'*exp(-(exp(`tests') * $ML_y2 )^(1/(1+exp(-`delta')))), exp(`pos')))
end

ml model lf weibull_growth ///
	(alpha: f_excess_deaths_pc, nocons) ///
	(pos: new_pos_pc = ) ///
	(tests: new_tests_pc = ) ///
	/delta ///
	if days_to_report > 21 & f_excess_deaths_pc >= 0 [aweight=population]
ml maximize

ml model lf weibull_growth ///
	(alpha: f_covdeath_pc, nocons) ///
	(pos: new_pos_pc = ) ///
	(tests: new_tests_pc = ) ///
	/delta ///
	if days_to_report > 21 [aweight=population]
ml maximize



capture program drop weibull_growth
program weibull_growth
	args lnf alpha pos tests lnsigma
	quietly replace `lnf' = ///
		ln(normalden( $ML_y1,  `alpha' + `pos'/(1-exp(-(exp(`tests') * $ML_y2 )^.5)), exp(`lnsigma')))
end

ml model lf weibull_growth ///
	(alpha: f_excess_deaths_pc = ) ///
	(pos: new_pos_pc, nocons) ///
	(tests: new_tests_pc = ) ///
	/lnsigma ///
	if days_to_report > 21 [aweight=population]
ml maximize


capture program drop weibull_growth
program weibull_growth
	args lnf alpha pos tests delta lnsigma
	quietly replace `lnf' = ///
		ln(normalden( $ML_y1,  `alpha' + `pos'/(1-exp(-(exp(`tests') * $ML_y2 )^(1/(1+exp(-`delta'))))), exp(`lnsigma')))
end

ml model lf weibull_growth ///
	(alpha: f_excess_deaths_pc = ) ///
	(pos: new_pos_pc, nocons) ///
	(tests: new_tests_pc = ) ///
	/delta /lnsigma ///
	if days_to_report > 21 [aweight=population]
ml maximize



xtset fips end_week, delta(7)


log close