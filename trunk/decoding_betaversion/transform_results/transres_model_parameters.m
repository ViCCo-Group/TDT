% output = transres_model_parameters(decoding_out, varargin)
% 
% This function returns the raw model parameters for the last decodings
%
% To use it, use
%
%   cfg.results.output = {'model_parameters'}
%
% Kai, 2012-03-12

function output = transres_model_parameters(decoding_out, varargin)

% return the model only
output.model = [decoding_out.model];
