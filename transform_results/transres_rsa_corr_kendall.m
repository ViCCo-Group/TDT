% function output = transres_rsa_corr_kendall(decoding_out, chancelevel, varargin)
% 
% Run a classical correlation-based RSA (Kendall's tau) where a
% separate correlation coefficient is computed for each RSA component (i.e.
% model variable). The resulting correlation coefficients are returned as
% output.
%
% For Spearman rank correlation, run transres_rsa_corr_spearman
%
% See also TRANSRES_RSA_CORR_PEARSON, TRANSRES_RSA_CORR_SPEARMAN


% Martin Hebart, 2017-04-24

function output = transres_rsa_corr_kendall(decoding_out, chancelevel, varargin)

% varargin{1} is cfg

output = {corr(varargin{1}.design.components.matrix,decoding_out.opt(varargin{1}.design.components.index),'type','kendall')};