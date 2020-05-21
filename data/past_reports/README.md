# past_reports

This folder contains (CDC) files released/downloaded at various points in time, which I can use to evaluate reporting delays.

nationwide_saturday_reports.csv: weekly changes in reported deaths (on Saturdays), assembled based on Internet Archive (IA) records of a CDC webpage (https://www.cdc.gov/nchs/nvss/vsrr/covid19/index.htm); based on earliest crawl available from IA on each Saturday
* https://web.archive.org/web/20200411005433/https://www.cdc.gov/nchs/nvss/vsrr/covid19/index.htm
* https://web.archive.org/web/20200418084016/https://www.cdc.gov/nchs/nvss/vsrr/covid19/index.htm
* https://web.archive.org/web/20200425031314/https://www.cdc.gov/nchs/nvss/vsrr/covid19/index.htm
* https://web.archive.org/web/20200502031208/https://www.cdc.gov/nchs/nvss/vsrr/covid19/index.htm
* https://web.archive.org/web/20200509055545/https://www.cdc.gov/nchs/nvss/vsrr/covid19/index.htm
* https://web.archive.org/web/20200516012808/https://www.cdc.gov/nchs/nvss/vsrr/covid19/index.htm

[date] cdc_deaths.dta
* These files are based on my own pulling of data (see "../code/pulldata.do") from this API on various days: https://data.cdc.gov/resource/r8kw-7aab.csv
* These data files have been lightly processed (again, see "../code/pulldata.do"), and I unfortunately did not save the original files
  * I did change the way I was handling missing (suppressed because underlying value is between 1-9) data at one point (in later files, missing/suppressed is replaced by 5)
* May9_cdc_deaths.dta file is problematic
  * From what I can tell, this pull had multiple (semi-duplicate) entries for each state-week; I believe these were duplicate entries based on different reporting dates, but I can't be sure
  * Because of the way I collapse data from NYC and NY-minus-NYC, I ended up combining these duplicate entries into a single entry in many cases, leading to inflated (approximately doubled) values for the first 228 observation in this file (I believe); the remaining 514 observations should who only the first entry available in the CDC data file
  * In many cases, the first 228 observations appear to simply be doubled (especially for older dates, where less new reporting comes in); in other cases, the value is an odd number, indicating that there were different numbers reported in the two entries in the CDC file
  * For some reason, when Stata reads in data from this API on my machine (haven't tried on others), only the first 1000 lines are being read in (this can be seen in the log file from this pull). Thus, the second (duplicate) set of entries was presumably only read in for the first 228 observations
  * I don't actually know (at this point) whether the first set of entries or the second set of entries in the CDC file is more recent. This might be something I can get a rough idea of based on comparing to May7_cdc_deaths.dta (Are numbers essentially unchanged for final 514 observations? They would be identical if 1st set of entries was just same version of data as was available on May 7.)

Potential alternative source of historical records (brought to my attention by Daniel Weinberger's excellent project: https://github.com/weinbergerlab/excess_pi_covid, https://www.medrxiv.org/content/10.1101/2020.04.15.20066431v2):
* follows this syntax: https://www.cdc.gov/flu/weekly/weeklyarchives2019-2020/data/NCHSData20.csv
* note that only nationwide figures are available here too; not sure where/how to get state-level historical data
