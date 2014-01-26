function output = transres_RSA_dist_corr(decoding_out,chancelevel,cfg,data)

% function output = transres_RSA_dist_corr(decoding_out,chancelevel,cfg,data)
% 
% Calculates the correlation between all datapoints of the full datamatrix.
%

output = {1-correlmat(data')};