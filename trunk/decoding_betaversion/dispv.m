function dispv(rule,str,varargin)

% function dispv(rule,str,varargin)
%
% Run fprintf with first the argument 'verbose argument level'.
% Input arguments:
%       rule: minimal level of the current argument at which is printed
%           (i.e. print only when this level or higher)
%       level: verbosity (0: no output, 1: normal output, 2: high output)
%       str: string to be printed
%       further input: optional input for fprintf

global verbose

% check whether we should display 
if isempty(verbose)
    display_string = 1; % if verbose was not defined, display everything
else
    % verbose level was defined, only display if rule is smaller
    display_string = verbose >= rule;
end


if display_string % if verbose was not defined, display everything
    str = [str '\n'];
    fprintf(str,varargin{:})
end    