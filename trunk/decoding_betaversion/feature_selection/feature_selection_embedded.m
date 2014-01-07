function [fs_index,n_vox_steps,output] = feature_selection_embedded(cfg,labels,data_scaled,n_vox,nested_n_vox,i_step)

output = []; % init

% TODO: set nested_n_vox here if it is a string (make sure it's not a
% single number, otherwise there won't be any range searched!)

% always make sure that number is descending
if length(n_vox) == 1
    n_vox_selected = n_vox;
elseif strcmp(n_vox,'automatic')
    n_vox = sort(nested_n_vox,'descend');
    [n_vox_selected,output,cfg.feature_selection.design.msg] = run_nest(cfg,data_scaled,i_step,n_vox,nested_n_vox); % determine optimal number of features
elseif length(n_vox) > 1
    n_vox = sort(n_vox,'descend');
    nested_n_vox = nested_n_vox(nested_n_vox>min(n_vox)); % because a minimum of n_vox will be selected later
    nested_n_vox = sort(unique([nested_n_vox n_vox]),'descend'); % include stopping value n_vox
    [n_vox_selected,output,cfg.feature_selection.design.msg] = run_nest(cfg,data_scaled,i_step,n_vox,nested_n_vox); % determine optimal number of features
else
    error('Variable ''n_vox'' has wrong size. n_vox = %s', num2str(n_vox) )
end

% Update nested_n_vox to stop at n_vox_selected
nested_n_vox = nested_n_vox(nested_n_vox>min(n_vox_selected)); % remove all nested_n_vox that are smaller than the stopping value n_vox (unneccessary to compute)
nested_n_vox = sort([nested_n_vox n_vox_selected],'descend');

fs_index = 1:size(data_scaled,2); % keep track of ranks to get original rank

% perform RFE
for iteration = 1:length(nested_n_vox)
    model = svmtrain(labels,data_scaled,cfg.feature_selection.decoding.train.classification.model_parameters); % training SVM
    w = model.SVs' * model.sv_coef;
    w = abs(w) .* std(data_scaled,0,1)'; % w scales inversely with the std of each feature
    [ind,ranks] = sort(w,'descend');
    fs_index = fs_index(ranks(1:nested_n_vox(iteration)));
    data_scaled = data_scaled(:,ranks(1:nested_n_vox(iteration))); % update vectors
end

n_vox_steps = nested_n_vox;

%% Subfunctions

%% Nested cross validation to determine optimal number of features
function [n_vox_selected,output,msg] = run_nest(cfg,data,i_step,n_vox,nested_n_vox)

% Create design for nested CV
try
    if isfield(cfg.feature_selection,'design') && isfield(cfg.feature_selection.design,'function')
        % do nothing
    else
        cfg.feature_selection.design.function = cfg.design.function;
    end
    cfg.feature_selection.files.mask = cfg.files.mask;
    cfg.feature_selection.files.chunk = cfg.files.chunk(i_train);
    cfg.feature_selection.files.label = cfg.files.label(i_train);
    cfg.feature_selection.files.name = cfg.files.name(i_train);
    fhandle = str2func(cfg.feature_selection.design.function.name);
    cfg.feature_selection.design = feval(fhandle,cfg.feature_selection);
catch %#ok<CTCH>
    error('Could not create design for nested cross-validation. Need correct information in field ''cfg.feature_selection.design.function!''')
end

% important step for design
if length(unique(cfg.feature_selection.design.set)) == 1
    cfg.feature_selection.results.setwise = 0;
end

if ~isfield(cfg.feature_selection.design,'msg')
    msg = [];
else
    msg = cfg.feature_selection.design.msg;
end

n_steps = size(cfg.feature_selection.design.train,2);

if isfield(cfg.feature_selection,'useall') && cfg.feature_selection.useall
    data = decoding_scale_data(cfg.feature_selection,data);
else
    data = decoding_scale_data(cfg.feature_selection,data);
end

decoding_out = struct('predicted_labels',{},'true_labels',{},'decision_values',{});

for j_step = 1:n_steps % loop over decoding steps (e.g. runs) within training data
    
    itrain = find(cfg.feature_selection.design.train(:, j_step) > 0);
    itest = find(cfg.feature_selection.design.test(:, j_step) > 0);
    
    vectors_train = data(itrain, :);
    vectors_test = data(itest, :);
    labels_train = cfg.feature_selection.design.label(itrain, j_step);
    labels_test = cfg.feature_selection.design.label(itest, j_step);
    
    % Perform nested CV for each step (these iterations are within the loop
    % to save time for loading data)
    for iteration = 1:length(nested_n_vox)
        
%         disp([num2str(j_step) '/' num2str(n_steps) ',' num2str(iteration) '/' num2str(length(nested_n_vox))])
        
        % Train model
        % e.g. when software is libsvm, call function with name libsvm_train.m
        model(j_step,iteration) = feval(cfg.feature_selection.decoding.fhandle_train,labels_train,vectors_train,cfg.feature_selection); % training
                
        % Test Estimated Model
        % e.g. when software is libsvm, call function with name libsvm_test.m    
        decoding_out(j_step,iteration) = feval(cfg.feature_selection.decoding.fhandle_test,labels_test,vectors_test,cfg.feature_selection,model(j_step,iteration));

        if strcmpi(cfg.feature_selection.embedded,'RFE')
           % TODO: make general purpose
           w = model(j_step,iteration).SVs' * model(j_step,iteration).sv_coef; 
           w = abs(w) .* std(vectors_train,0,1)'; % w scales inversely with the std of each feature
           [ind,ranks] = sort(w,'descend');
           vectors_train = vectors_train(:,ranks(1:nested_n_vox(iteration))); % update vectors
           vectors_test = vectors_test(:,ranks(1:nested_n_vox(iteration))); % update vectors
        end
       
    end
    
end

results.n_cond = length(unique(cfg.design.label(cfg.design.train | cfg.design.test))); % init

% transform decoding_out to result format that is requested
for iteration = 1:length(nested_n_vox)
    if numel(cfg.feature_selection.results.output)>1,
        error(['More than one output selected in nested CV for feature selection.\n',...
            'Change field ''cfg.feature_selection.results.output'' to one entry, only.'])
    end
   results = decoding_generate_output(cfg.feature_selection,results,decoding_out(:,iteration),iteration,iteration,model(:,iteration)); 
end

% Get number of features where output is highest
all_results = vertcat(results.(cfg.feature_selection.results.output{1}).output);

% kick out all nested_n_vox, leave only accuracies of n_vox, because only those interest us at the higher level
[i,reduce_ind] = intersect(nested_n_vox,n_vox);
all_results = all_results(reduce_ind);

if strcmpi(cfg.feature_selection.optimization_criterion,'select_peak')
n_vox_selected = select_peak(n_vox,all_results); % this function selects the peak and for several peaks the most stable one
else
    fhandle = str2func(cfg.feature_selection.optimization_criterion);
    n_vox_selected = fhandle(all_results);
    if isempty(n_vox_selected)
        error('Function %s yielded an empty matrix for feature selection. Please use a different function.',cfg.feature_selection.optimization_criterion)
    end
end
n_vox_selected = n_vox_selected(end);
output = all_results;

