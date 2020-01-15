This is a demo how to do iPIPI (Hirose, 2019; see below) with TDT.

Files:

ipipi.m
-- 
Core file from Satoshi Hirose with minor adaptations (see ipipi.m)

ipipiTDT.m
-- 
Wrappter to perfrom ipipi with results from stats_permuation.m


demo_iPIPI_TDTdata.m
-- 
Demo how to use ipipi with the TDT demo data. 
Note: This is really just a demo. It is statistically invalid (because we 
have only two demo data sets). See 
   demo8_demodata_decoding_tutorial_motion_direction.m 
how to create the input data for the demo.




% REFERENCE to iPIPI:
% Hirose, S. (2019). Valid and powerful statistical test for decoding 
% accuracy—Proposal of Permutation-based Information Prevalence Inference 
% using the i-th order statistic. BioRxiv, 578930. 
% https://doi.org/10.1101/578930
%
% NOTE: To integrate iPIPI into TDT, this file has been downloaded from
%   http://www2.nict.go.jp/bnc/hirose/iPinPin/index.html
% on 2020-01-15. The file has tiny modifications of the text in the  header 
% above to allow the use of the standard matlab help command and a text
% displaying the reference to iPIPI at the end of the code. 
% No other changes have been done, esp. no changes to the remaining code.
% The code comes completely without warranty and is sole property of \n' ...
% Satoshi Hirose.
%
% This is an experimental implementation TDT and has not been extensively 
% tested by the authors of TDT. Use at your own risk.
%
% Kai, 2020-01-15