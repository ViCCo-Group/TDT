% function cfg = decoding_parameter_selection(cfg,vectors_train,i_step)
%
% This function selects and changes parameters that are used for
% training the model (for example the cost variable C in SVM) and is an
% integral part of the decoding toolbox. Currently the only implemented
% method is 'grid search' in which all combinations of all parameters that
% should be optimized are searched and the peak is selected.
%
% INPUT
% cfg: structure passed from decoding.m with at least the following fields:
%   parameter_selection: struct containing feature selection parameters
%   fields:
%       method:
%           'grid':       Performs parameter selection using grid search
%           'none':       Perform no parameter selection
%
%       parameters: string variable denoting parameter that should be
%           selected (see parameter descriptions in the classifier)
%           (for more than one parameter, this is a cell-matrix with
%           n_parameters x 1 fields)
%
%       parameter_range: n x 1 vector as range which to search (for more 
%           than one parameter, this is a cell-matrix with 
%           n_parameters x 1 fields)
%
%       grid: (for method = 'grid'):
%            'peak':       Parameters are selected based on the highest
%                          overall response

% (c) Martin Hebart, 12/02/08

% TODO: add to help file that possibility to add parameters such as the design for nested CV exists.

% TODO: add example call:
%       cfg.parameter_selection.method = 'grid';
%       cfg.parameter_selection.parameters = {'c','e'};
%       cfg.parameter_selection.parameter_range = {10^(-5:5),10^(-2:7)};

function cfg = decoding_parameter_selection(cfg,vectors_train,i_step)

if isfield(cfg.parameter_selection,'method') && strcmpi(cfg.parameter_selection.method,'none')
    return
end

% TODO: some parameters may be passed differently, e.g. not as a string.
% For now allow only string input (e.g. 'c', 's', etc.)

parameters = cfg.parameter_selection.parameters;
parameter_range = cfg.parameter_selection.parameter_range;

% basic checks
[parameters parameter_range] = basic_checks(cfg,parameters,parameter_range);

default_params = cfg.decoding.train.(cfg.decoding.method).model_parameters;

% This code is a bit difficult to read, but essentially it replaces all
% default numbers by placeholders that sprintf can read

% TODO: possibly replace by regexp for better readability
for i_parameter = 1:length(parameters)
    str = strfind(default_params,'-'); % find separators between two entries
    strpos = strfind(default_params,['-' num2str(parameters{i_parameter}) ' ']);
    if length(strpos)~=1, error('String ''%s'' not found once, but %i times',num2str(parameters{i_parameter}),length(strpos)); end
    numstart = strpos+2;
    try
        currstr = str(find(str == strpos)+1);
        numend = currstr-2;
        default_params = [default_params(1:numstart) '%f' default_params(numend+1:end)];
    catch %#ok<CTCH>
        default_params = [default_params(1:numstart) '%f'];
    end
    
end

% This function creates all combinations of all parameters that should be selected
all_combinations = []; % init
all_combinations = allperms(all_combinations,parameter_range);

% Then loop across all possible combinations in a nested CV and report
% maximum as output
[selected_parameters cfg.parameter_selection.design.msg] = run_nest(cfg,vectors_train,i_step,all_combinations,default_params);

cfg.decoding.train.(cfg.decoding.method).model_parameters = sprintf(default_params,selected_parameters);





%%%%%%%%%%%%%%%%%%
%% Subfunctions %%
%%%%%%%%%%%%%%%%%%

%% Basic checks
function [parameters parameter_range] = basic_checks(cfg,parameters,parameter_range)

if ~strcmpi(cfg.parameter_selection.method,'grid') && ~strcmpi(cfg.parameter_selection.method,'grid search')
   error('Unknown method ''%s'' for field ''cfg.parameter_selection.method',cfg.parameter_selection.method)
end

if ndims(parameter_range)~=2
    error('input ''cfg.parameter_selection.parameter_range'' has the wrong number of dimensions.')
end
if size(parameter_range,1)>1 && size(parameter_range,2)>1
    error(['Both dimensions of input ''cfg.parameter_seleciton.parameter_range'' have size > 1.\n',...
           'Use cell arrays along one dimension to uniquely assign values to parameters'])
end
if ~iscell(parameters)
    parameters = num2cell(parameters,2);
end
if ~iscell(parameter_range)
    if size(parameter_range,2)>size(parameter_range,1)
        parameter_range = parameter_range'; % in case input was flipped
    end
    parameter_range = num2cell(parameter_range,1);
end

%% Create all combinations in nested function
function all_combinations = allperms(all_combinations,parameter_range)

if isempty(parameter_range), return, end

parameter_range{1} = sort(parameter_range{1});

if size(parameter_range{1},1)~=1
    parameter_range{1} = parameter_range{1}';
end

if isempty(all_combinations)
    all_combinations = parameter_range{1};
else
    
    sz = size(all_combinations,2);
    all_combinations = repmat(all_combinations,1,length(parameter_range{1}));
    all_combinations = [all_combinations; sort(repmat(parameter_range{1},1,sz))];
    
end

if length(parameter_range)>1
    parameter_range = parameter_range(2:end);
else
    parameter_range = [];
end

all_combinations = allperms(all_combinations,parameter_range);


%% Nested cross validation to determine optimal parameter combination
function [selected_parameters msg] = run_nest(cfg,data,i_step,all_combinations,default_params)

ps_cfg = cfg.parameter_selection;

% Create design for nested CV
try
    if isfield(cfg.files,'step') && isfield(cfg.files,'label')
        ps_ind = (cfg.files.step~=i_step);
        ps_cfg.files.step = cfg.files.step(ps_ind);
        ps_cfg.files.label = cfg.files.label(ps_ind);
        % check explicitly if a parameter has been provided
        if isfield(ps_cfg,'design') && isfield(ps_cfg.design,'function')
            fhandle = str2func(ps_cfg.design.function);
            ps_cfg.design = feval(fhandle,ps_cfg);
        % else check if design function had been used in main function and try same design
        elseif isfield(cfg.design,'info')
            strend = strfind(cfg.design.info.ver,' '); % extract function name from field
            fname = cfg.design.info.ver(1:strend(1)-1);
            fhandle = str2func(fname);
            ps_cfg.design = feval(fhandle,ps_cfg);
            warning('PARAMETER_SELECTION:DESTYP1','Design type was not provided explicitly. Using same as in main function: ''%s'' for nested cross-validation',fname)
        % otherwise try out leave-one-out CV
        else
            ps_cfg.design = make_design_cv(ps_cfg);
            warning('PARAMETER_SELECTION:DESTYP1','Design type was not provided explicitly. Using leave-one-run out CV for nested cross-validation')
        end
    end
catch %#ok<CTCH>
    error('Could not create design for nested cross-validation. Need correct information in field ''cfg.parameter_selection.design.function!''')
end

if ~isfield(cfg.parameter_selection,'msg')
    msg = [];
else
    msg = cfg.parameter_selection.msg;
end

% because training data are balanced, currently the default for scaling is 'all' or 'none'
if ~isfield(ps_cfg,'scale')
    if isfield(cfg.parameter_selection,'scale')
        ps_cfg.scale = cfg.parameter_selection.scale; % manually determined scaling
    else
        ps_cfg.scale = cfg.scale; % use same scaling as in decoding.m
    end
    if strcmp(ps_cfg.scale,'all_used') || strcmp(ps_cfg.scale,'across')
        ps_cfg.scale = 'all';
    end
end

n_steps = size(ps_cfg.design.train,2);

decoding_out = struct('predicted_labels',{},'true_labels',{},'decision_values',{});

for i_step = 1:n_steps % loop over decoding steps (e.g. runs) within training data
    
    itrain = find(ps_cfg.design.train(:, i_step) > 0);
    itest = find(ps_cfg.design.test(:, i_step) > 0);
    
    vectors_train = data(itrain, :);
    vectors_test = data(itest, :);
    labels_train = ps_cfg.design.label(itrain, i_step);
    labels_test = ps_cfg.design.label(itest, i_step);
    
    % Perform nested CV for each step
    for iteration = 1:size(all_combinations,2)
        
        % select model_parameters for current iteration
        curr_params = sprintf(default_params,all_combinations(:,iteration));
        
        ps_cfg.decoding.train.(ps_cfg.decoding.method).model_parameters = curr_params;
           
        % Train model
        fhandle = str2func([ps_cfg.decoding.software '_train']); % this format allows variable input
        % e.g. when software is libsvm, call function with name libsvm_train.m
        model = feval(fhandle,labels_train,vectors_train,ps_cfg);
        
        % Test estimated model
        fhandle = str2func([ps_cfg.decoding.software '_test']); % this format allows variable input
        % e.g. when software is libsvm, call function with name libsvm_test.m
        decoding_out(i_step,iteration) = feval(fhandle,labels_test,vectors_test,ps_cfg,model);
        
    end
    
end

results(1) = struct; % init
% transform decoding_out to result format that is requested
for iteration = 1:size(all_combinations,2)
    if numel(ps_cfg.results.output)>1,
        error(['More than one output selected in nested CV for parameter selection.\n',...
            'Change field ''cfg.parameter_selection.results.output'' to one entry. only.'])
    end
   results = decoding_generate_output(ps_cfg,results,decoding_out(:,iteration),iteration); 
end

% Use parameters where output is highest
all_results = vertcat(results.output);

s_ind = find(all_results == max(all_results));

% for several hits, use first (TODO: try to get more stable result in the future)
s_ind = s_ind(1);

selected_parameters = all_combinations(s_ind); 