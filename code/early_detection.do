clear all
capture log close
log using "..\logs\early_detection.txt", text replace

use "..\data\population.dta" // start from this file because it has both fips codes and state names

merge 1:m fips using "..\data\covidtracking.dta", keep(2 3)
drop _merge

replace state = "Puerto Rico" if state == "PR"
replace fips = 72 if state=="Puerto Rico"
order date fips
sort fips state date

gen end_week = date + mod(6 - dow(date), 7)
format end_week %tdCCYYNNDD
order end_week, after(date)

encode dataqualitygrade, gen(datagrade)
order datagrade, after(dataqualitygrade)
drop dataqualitygrade

drop hash datechecked // new variables added to more recent versions of covidtracking's data that interfere with following code:
foreach var of varlist positive-datagrade death-grade {
	gen `var'_mis = (`var'==.)
}
gen dayscollapsed = 1
sort fips state date
collapse (firstnm) state (lastnm) positive-datagrade population risk_standardized_population (sum) deathincrease-dayscollapsed, by(end_week fips)
foreach var of varlist positive-datagrade deathincrease-grade {
	replace `var' = . if `var'_mis == dayscollapsed
}
drop *_mis

xtset fips end_week, delta(7)

gen new_pos = d.positive if d.positive>=0
gen new_neg = d.negative if d.negative>=0
gen p_pos = new_pos/(new_pos+new_neg)*100
order new_pos-p_pos, after(negative)

gen new_pos_pc = new_pos*100000/population
gen new_neg_pc = new_neg*100000/population
gen new_tests_pc = new_pos_pc + new_neg_pc
gen deathincrease_pc = deathincrease*100000/risk_standardized_population
gen hospitalizedcurrently_pc = hospitalizedcurrently * 100000 / population

drop if fips==. | fips==72
keep if dayscollapsed == 7


// four lags
reg deathincrease_pc c.new_pos_pc##c.p_pos l.c.new_pos_pc##c.l.p_pos l2.c.new_pos_pc##c.l2.p_pos l3.c.new_pos_pc##c.l3.p_pos l4.c.new_pos_pc##c.l4.p_pos, cluster(fips)
margins, dydx(new_pos_pc l.new_pos_pc l2.new_pos_pc l3.new_pos_pc l4.new_pos_pc) at(p_pos=(5) l.p_pos=(5) l2.p_pos=(5) l3.p_pos=(5) l4.p_pos=(5))
margins, dydx(new_pos_pc l.new_pos_pc l2.new_pos_pc l3.new_pos_pc l4.new_pos_pc) at(p_pos=(45) l.p_pos=(45) l2.p_pos=(45) l3.p_pos=(45) l4.p_pos=(45))

// five lags
reg deathincrease_pc c.new_pos_pc##c.p_pos l.c.new_pos_pc##c.l.p_pos l2.c.new_pos_pc##c.l2.p_pos l3.c.new_pos_pc##c.l3.p_pos l4.c.new_pos_pc##c.l4.p_pos l5.c.new_pos_pc##c.l5.p_pos, cluster(fips)
margins, dydx(new_pos_pc l.new_pos_pc l2.new_pos_pc l3.new_pos_pc l4.new_pos_pc l5.new_pos_pc) at(p_pos=(5) l.p_pos=(5) l2.p_pos=(5) l3.p_pos=(5) l4.p_pos=(5) l5.p_pos=(5))
margins, dydx(new_pos_pc l.new_pos_pc l2.new_pos_pc l3.new_pos_pc l4.new_pos_pc l5.new_pos_pc) at(p_pos=(45) l.p_pos=(45) l2.p_pos=(45) l3.p_pos=(45) l4.p_pos=(45) l5.p_pos=(45))

log close
