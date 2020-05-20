gen influ_pc = influenzaandpneumonia*1000000/population
gen loginflu_pc = log(1+influenzaandpneumonia*1000000/population)

gen fluyear = .
replace fluyear = 2014 if end_week<td(16/8/2014)
replace fluyear = 2015 if (end_week>=td(16/8/2014))&(end_week<td(16/8/2015))
replace fluyear = 2016 if (end_week>=td(16/8/2015))&(end_week<td(16/8/2016))
replace fluyear = 2017 if (end_week>=td(16/8/2016))&(end_week<td(16/8/2017))
replace fluyear = 2018 if (end_week>=td(16/8/2017))&(end_week<td(16/8/2018))
replace fluyear = 2019 if (end_week>=td(16/8/2018))&(end_week<td(16/8/2019))
replace fluyear = 2020 if (end_week>=td(16/8/2019))&(end_week<td(1/2/2020))

capture program drop baseline_deaths_model
program baseline_deaths_model
	args lnf beta1 beta2 alpha lnsigma
	quietly replace `lnf' = ///
		ln(normalden( $ML_y1, `alpha' + `beta2' + `beta1'*`beta2', exp(`lnsigma')))
end

ml model lf baseline_deaths_model ///
	(beta1: loginflu_pc = fluseason1314 fluseason1516 fluseason1617 fluseason1718 fluseason1819, nocons) ///
	(beta2: b33.mmwrweek, nocons) ///
	(alpha: i.fips) ///
	/lnsigma if mmwrweek < 53 [aweight=population]
ml maximize

reg influ_pc i.mmwrweek#i.fluyear i.fips if mmwrweek < 53 [aweight=population], nocons
forvalues x=1/52 {
	display "`x'"
	test `x'.mmwrweek#2015.fluyear=`x'.mmwrweek#2016.fluyear=`x'.mmwrweek#2017.fluyear=`x'.mmwrweek#2018.fluyear=`x'.mmwrweek#2019.fluyear
}