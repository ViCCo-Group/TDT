% function cfg = decoding_parameter_selection(cfg,data_train,i_train_external)
%
% This function selects and changes parameters that are used for
% training the model (for example the cost variable C in SVM) and is an
% integral part of the decoding toolbox. This function is called from 
% decoding.m and should not be called directly. Currently the only 
% implemented method is 'grid search' in which all combinations of all 
% parameters that should be optimized are searched and the peak is selected.
%
% INPUT
% cfg: structure passed from decoding.m with at least the following fields:
%
%   parameter_selection: struct containing feature selection parameters
%     fields:
%       method:
%           'grid':       Performs parameter selection using grid search
%           'none':       Perform no parameter selection
%
%       parameters: string variable denoting parameter that should be
%           selected (see parameter descriptions in the classifier)
%           (for more than one parameter, this is a cell-matrix with
%           n_parameters x 1 fields), example: 'c'
%
%       parameter_range: n x 1 vector as range which to search (for more 
%           than one parameter, this is a cell-matrix with 
%           n_parameters x 1 fields), example: 2.^[-6 -4 -2 -1 0 1 2 4 6 8]
%
%       grid: (for method = 'grid'):
%            'peak':       Parameters are selected based on the highest
%                          overall response
%
% data_train: Training data (either vectors of actual data or data.kernel 
% containing the kernel matrix)
% i_train_external: Index of training data (from function decoding.m)


% Martin Hebart, 12/02/08

% TODO: externalize the "replacement of parameters" part which can be done
% once on the defaults

% TODO: add to help file that possibility to add parameters such as the design for nested CV exists.

% TODO: add example call:
%       cfg.parameter_selection.method = 'grid';
%       cfg.parameter_selection.parameters = {'c','e'};
%       cfg.parameter_selection.parameter_range = {10^(-5:5),10^(-2:7)};

% History
% Kai, 2013-09-05
%   Changed Kernel passing, now: data_train.kernel/data_test.kernel.

function cfg = decoding_parameter_selection(cfg,data_train,i_train_external)


% TODO: some parameters may be passed differently, e.g. not as a string.
% For now allow only string input (e.g. 'c', 's', etc.)

parameters = cfg.parameter_selection.parameters;
parameter_range = cfg.parameter_selection.parameter_range;

% basic checks
[cfg,parameters,parameter_range] = basic_checks(cfg,parameters,parameter_range);

%  Get the parameters from the method in the main function
cfg.parameter_selection.decoding.train.(cfg.decoding.method).model_parameters = cfg.decoding.train.(cfg.decoding.method).model_parameters;
default_params = cfg.parameter_selection.decoding.train.(cfg.decoding.method).model_parameters;

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
selected_parameters = run_nest(cfg,data_train,i_train_external,all_combinations,default_params);

cfg.decoding.train.(cfg.decoding.method).model_parameters = sprintf(default_params,selected_parameters);





%%%%%%%%%%%%%%%%%%
%% Subfunctions %%
%%%%%%%%%%%%%%%%%%

%% Basic checks
function [cfg,parameters,parameter_range] = basic_checks(cfg,parameters,parameter_range)

% TODO: move these checks to external function and run check only once in main decoding.m
% TODO: check which values of cfg and cfg.parameter_selection must match
% and make them match if they don't

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

% Possible mismatch between different levels of the function
if cfg.decoding.use_kernel
    cfg.parameter_selection.decoding.kernel.function = cfg.decoding.kernel.function;
end

cfg.parameter_selection.decoding.method = cfg.decoding.method;


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
function selected_parameters = run_nest(cfg,data,i_train_external,all_combinations,default_params)

% Create design for nested CV
try
    if isfield(cfg.parameter_selection,'design') && isfield(cfg.parameter_selection.design,'function')
        % do nothing
    else
        cfg.parameter_selection.design.function = cfg.design.function;
    end
    cfg.parameter_selection.files.mask = cfg.files.mask;
    cfg.parameter_selection.files.chunk = cfg.files.chunk(i_train_external);
    cfg.parameter_selection.files.label = cfg.files.label(i_train_external);
    cfg.parameter_selection.files.name = cfg.files.name(i_train_external);
    fhandle = str2func(cfg.parameter_selection.design.function.name);
    cfg.parameter_selection.design = feval(fhandle,cfg.parameter_selection);
catch %#ok<CTCH>
    error('Could not create design for nested cross-validation. Need correct information in field ''cfg.parameter_selection.design.function!''')
end

if ~isfield(cfg.parameter_selection,'scale')
    if isfield(cfg.parameter_selection,'scale')
        cfg.parameter_selection.scale = cfg.parameter_selection.scale; % manually determined scaling
    else
        cfg.parameter_selection.scale = cfg.scale; % use same scaling as in decoding.m
    end
    if strcmp(cfg.parameter_selection.scale,'all_used') || strcmp(cfg.parameter_selection.scale,'across')
        cfg.parameter_selection.scale = 'all';
    end
end

n_steps = size(cfg.parameter_selection.design.train,2);

decoding_out = struct('predicted_labels',{},'true_labels',{},'decision_values',{});

for i_step = 1:n_steps % loop over decoding steps (e.g. runs) within training data
    
    i_train = find(cfg.parameter_selection.design.train(:, i_step) > 0);
    i_test = find(cfg.parameter_selection.design.test(:, i_step) > 0);
    
    if cfg.decoding.use_kernel
        data_train.kernel = data.kernel(i_train, i_train);
        data_test.kernel = data.kernel(i_test, i_train);
        if cfg.decoding.kernel.pass_vectors
            data_train.vectors = data(i_train, :);
            data_test.vectors = data(i_test, :);
        end
    else
        data_train = data(i_train, :);
        data_test = data(i_test, :);
    end
    
    labels_train = cfg.parameter_selection.design.label(i_train, i_step);
    labels_test = cfg.parameter_selection.design.label(i_test, i_step);
    
    % Perform nested CV for each step
    for iteration = 1:size(all_combinations,2)
        
        % select model_parameters for current iteration
        curr_params = sprintf(default_params,all_combinations(:,iteration));
        
        cfg.parameter_selection.decoding.train.(cfg.parameter_selection.decoding.method).model_parameters = curr_params;
        
        % Train model
        % e.g. when software is libsvm, call function with name libsvm_train.m
        model(i_step,iteration) = cfg.parameter_selection.decoding.fhandle_train(labels_train,data_train,cfg.parameter_selection); %#ok<AGROW>
        
        % Test estimated model
        % e.g. when software is libsvm, call function with name libsvm_test.m
        decoding_out(i_step,iteration) = cfg.parameter_selection.decoding.fhandle_test(labels_test,data_test,cfg.parameter_selection,model(i_step,iteration));
        
    end
    
end

results.n_cond = cfg.design.n_cond; % init
results.n_cond_per_step = cfg.design.n_cond_per_step;

% transform decoding_out to result format that is requested
for iteration = 1:size(all_combinations,2)
    if numel(cfg.parameter_selection.results.output)>1,
        error(['More than one output selected in nested CV for parameter selection.\n',...
            'Change field ''cfg.parameter_selection.results.output'' to one entry. only.'])
    end
   results = decoding_generate_output(cfg.parameter_selection,results,decoding_out(:,iteration),iteration,iteration,model(:,iteration)); 
end

% Use parameters where output is highest
all_results = vertcat(results.(cfg.parameter_selection.results.output{1}).output);

s_ind = find(all_results == max(all_results));

% for several hits, use first (TODO: try to get more stable result in the future)
s_ind = s_ind(1);

selected_parameters = all_combinations(s_ind); 