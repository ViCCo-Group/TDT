function all_combinations = param_string_number(cfg,default_params,parameters,all_value_combinations)

% Subfunction with the format:
% INPUT:
%   cfg: configuration script
%   default_params: which parameters have been passed as default (format
%       depending on the format chosen, in this case string)
%   parameters: which parameters should be searched (1xn cell array)
%   all_value_combinations: pre-computed combination of values (cell
%       matrix where dim1 is n_parameters and dim2 all combinations)
%
% OUTPUT:
%   all_combinations: all combinations of parameters, in 1xn_combinations
%       cell matrix.

separator = cfg.parameter_selection.format.separator;
separator_reg = [regexptranslate('escape',separator) '+'];

% This code is a bit difficult to read, but essentially it replaces all
% default numbers by placeholders that sprintf can read
for i_parameter = 1:length(parameters)
    [strstart strend] = regexpi(default_params,[num2str(parameters{i_parameter}) separator_reg]); % where does a parameter string start and end (including separator)
    if length(strstart)==1 % replace number following string (if number exists)
        numstart = strend+1;
        str = strfind(default_params,separator); % find separators between two entries
        numend = str(find(str>numstart,1))-1; % number goes until the next whitespace is found
        default_params = [default_params(1:numstart-1) '%f' default_params(numend+1:end)];
    elseif isempty(strstart) % if string doesn't exist, create it
        default_params = [default_params separator num2str(parameters{i_parameter}) separator '%f']; %#ok<AGROW>
    else
        error('String ''%s'' found more than once (%i times) in cfg.parameter_selection.decoding.train.(method).model_parameters . Use only once!',num2str(parameters{i_parameter}),length(strstart));
    end
end

all_combinations = cell(1,size(all_value_combinations,2));
for i_combination = 1:size(all_combinations,2)
    all_combinations{i_combination} = sprintf(default_params,all_value_combinations(:,i_combination));
end