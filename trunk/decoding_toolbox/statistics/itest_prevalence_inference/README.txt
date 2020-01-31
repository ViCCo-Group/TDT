This is a demo how to perform the i-test prevalence analysis.

See:

Hirose, S. (2020). Valid and powerful group statistics for decoding 
  accuracy: Information Prevalence Inference using the i-th order 
  statistic (i-test). BioRxiv, 578930. 
  https://doi.org/10.1101/578930

The code added here comes from
  https://github.com/satoshi-hirose/i-test/

i-test has been released under GPL3 (see itest-core/LICENSE)

For the concept of prevalence analysis, see 

Allefeld, C., Goergen, K., & Haynes, J.-D. (2016). 
  Valid population inference for information-based imaging: From the 
  second-level t-test to prevalence inference. NeuroImage. 
  http://doi.org/10.1016/j.neuroimage.2016.07.040


For a demo, see demo_itest_TDTdata.m
-- 
Demo how to use itest with the TDT demo data. 
Note: This is really just a demo. It is statistically invalid 
(because we have only two demo data sets). See 
   demo8_demodata_decoding_tutorial_motion_direction.m 
how to create the input data for the demo and for your analysis.


Further files

itestTDT.m
-- 
Wrapper to perfrom itest with results from stats_permuation.m, use
demonstrated in demo_itest_TDTdata.m


itest-core/itest.m & helper files
---
The core i-test & helper files by Satoshi Hirose
Retrieved from https://github.com/satoshi-hirose/i-test/
2020-01-31
