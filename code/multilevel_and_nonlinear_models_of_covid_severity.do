clear all
capture log close
log using "..\logs\multilevel_and_nonlinear_models_of_covid_severity.txt", text replace

use "..\data\weeklydata.dta"

keep if days_to_report > 14 & days_to_report != . & l.p_pos != .

// check if slopes vary much by state or week; looks like there's not much variance in slopes along these dimensions
mixed adj_excess_respir_deaths_pc l.new_pos_pc if l.p_pos != . || _all:R.end_week || fips: l.new_pos_pc
mixed adj_excess_respir_deaths_pc l.new_pos_pc if l.p_pos != . || _all:R.fips || end_week: l.new_pos_pc

mixed adj_excess_respir_deaths_pc l.new_pos_pc if l.p_pos != . || fips: l.new_pos_pc
mixed adj_excess_respir_deaths_pc c.l.new_pos_pc##c.l.p_pos if l.p_pos != . || fips: l.new_pos_pc

mixed adj_excess_respir_deaths_pc l.new_pos_pc if l.p_pos != . || end_week: l.new_pos_pc
mixed adj_excess_respir_deaths_pc c.l.new_pos_pc##c.l.p_pos if l.p_pos != . || end_week: l.new_pos_pc


// try different lag values

mixed adj_excess_respir_deaths_pc new_pos_pc l.new_pos_pc l2.new_pos_pc if l.p_pos != . || _all:R.end_week || fips: 
mixed adj_excess_respir_deaths_pc c.new_pos_pc##c.p_pos c.l.new_pos_pc##c.l.p_pos || _all:R.end_week || end_week: new_pos_pc l.new_pos_pc
mixed adj_excess_respir_deaths_pc c.new_pos_pc##c.p_pos c.l.new_pos_pc##c.l.p_pos c.l2.new_pos_pc##c.l2.p_pos || _all:R.end_week || end_week: new_pos_pc l.new_pos_pc l2.new_pos_pc

// use non-linear least squares to create a single estimate (across multiple lag values) of how much to adjust case count by % positive)

reg adj_excess_respir_deaths_pc c.new_pos_pc##c.p_pos c.l.new_pos_pc##c.l.p_pos
nl (adj_excess_respir_deaths_pc = {b0} + {b1}*new_pos_pc*(1+{a}*p_pos) + {b2}*l.new_pos_pc*(1+{a}*l.p_pos)) if e(sample)==1, cluster(fips)

reg adj_excess_respir_deaths_pc c.new_pos_pc##c.p_pos c.l.new_pos_pc##c.l.p_pos c.l2.new_pos_pc##c.l2.p_pos
nl (adj_excess_respir_deaths_pc = {b0} + {b1}*new_pos_pc*(1+{a}*p_pos) + {b2}*l.new_pos_pc*(1+{a}*l.p_pos) + {b3}*l2.new_pos_pc*(1+{a}*l2.p_pos)) if e(sample)==1, cluster(fips)

// robustness check:
reg adj_excess_respir_deaths_pc c.new_pos_pc##c.p_pos c.l.new_pos_pc##c.l.p_pos c.l2.new_pos_pc##c.l2.p_pos if p_pos!=100 & l.p_pos!=100 & l2.p_pos!=100
nl (adj_excess_respir_deaths_pc = {b0} + {b1}*new_pos_pc*(1+{a}*p_pos) + {b2}*l.new_pos_pc*(1+{a}*l.p_pos) + {b3}*l2.new_pos_pc*(1+{a}*l2.p_pos)) if e(sample)==1, cluster(fips)



log close