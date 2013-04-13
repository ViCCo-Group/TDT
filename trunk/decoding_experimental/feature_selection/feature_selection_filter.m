function [fs_index,n_vox_steps,output] = feature_selection_filter(cfg,fs_data,labels,data_scaled,n_vox,i_step)

output = []; % init
% Rank features for feature selection
[ranks,ind,fs_data.external] = rank_features(cfg,fs_data.external,labels,data_scaled,i_step);

if ~ischar(n_vox)
    
    % If the number of features to be selected is predefined
    if length(n_vox) == 1
        n_vox_selected = n_vox;
        % If a range of numbers of features to be selected is entered
    elseif length(n_vox) > 1
        [n_vox_selected,output,cfg.feature_selection.design.msg] = run_nest(cfg,data_scaled,fs_data.external,i_step,n_vox); % Run nested CV to find optimal number of voxels
    else
        error('Variable ''n_vox'' has wrong size. n_vox = %s', num2str(n_vox) )
    end
    
elseif ischar(n_vox)
    
    % If the number of feature should be selected automatically
    if strcmp(n_vox,'automatic')
        n_vox = 1:size(data_scaled,2);
        [n_vox_selected,output,cfg.feature_selection.design.msg] = run_nest(cfg,data_scaled,fs_data.external,i_step,n_vox); % determine optimal number of features
    else
        error('Unknown method %s for field ''n_vox''.',n_vox)
    end
else
    error('Field ''nvox'' mus have string or numerical format.')
end

n_vox_steps = n_vox;

fs_index = ranks(1:n_vox_selected);


%% Subfunctions

%% Nested cross validation to determine optimal number of features
function [n_vox_selected,output,msg] = run_nest(cfg,data,external,i_step,n_vox)

% Create design for nested CV
try
    if isfield(cfg.files,'step') && isfield(cfg.files,'label')
        fs_ind = (cfg.files.step~=i_step);
        cfg.feature_selection.files.step = cfg.files.step(fs_ind);
        cfg.feature_selection.files.label = cfg.files.label(fs_ind);
        % check explicitly if a parameter has been provided
        if isfield(cfg.feature_selection,'design') && isfield(cfg.feature_selection.design,'function')
            fhandle = str2func(cfg.feature_selection.design.function);
            cfg.feature_selection.design = feval(fhandle,cfg.feature_selection);
        % else check if design function had been used in main function and try same design
        elseif isfield(cfg.design,'info')
            strend = strfind(cfg.design.info.ver,' '); % extract function name from field
            fname = cfg.design.info.ver(1:strend(1)-1);
            fhandle = str2func(fname);
            cfg.feature_selection.design = feval(fhandle,cfg.feature_selection);
            msg_id = warning('FEATURE_SELECTION_FILTER:DESTYP1','Design type was not provided explicitly. Using same as in main function: ''%s'' for nested cross-validation',fname);
        % otherwise try out leave-one-out CV
        else
            cfg.feature_selection.design = make_design_cv(cfg.feature_selection);
            msg_id = warning('FEATURE_SELECTION_FILTER:DESTYP1','Design type was not provided explicitly. Using leave-one-run out CV for nested cross-validation');
        end
    end
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
    
    % Rank features in nested training data, only
    ranks = rank_features(cfg,external,labels_train,vectors_train,j_step);
    
    % Perform nested CV for each step (these iterations are within the loop
    % to save time for loading data)
    for iteration = 1:length(n_vox)
        
        ranks_index = ranks(1:n_vox(iteration));

        % Train model
        fhandle = str2func([cfg.feature_selection.decoding.software '_train']); % this format allows variable input
        % e.g. when software is libsvm, call function with name libsvm_train.m
        model = feval(fhandle,labels_train,vectors_train(:,ranks_index),cfg.feature_selection);
        
        % Test Estimated Model
        fhandle = str2func([cfg.feature_selection.decoding.software '_test']); % this format allows variable input
        % e.g. when software is libsvm, call function with name libsvm_test.m        
        decoding_out(j_step,iteration) = feval(fhandle,labels_test,vectors_test(:,ranks_index),cfg.feature_selection,model);

    end
    
end

results = []; % init
% transform decoding_out to result format that is requested
for iteration = 1:length(n_vox)
    if numel(cfg.feature_selection.results.output)>1,
        error(['More than one output selected in nested CV for feature selection.\n',...
            'Change field ''cfg.feature_selection.results.output'' to one entry. only.'])
    end
   results = decoding_generate_output(cfg.feature_selection,results,decoding_out(:,iteration),iteration); 
end

% Get number of features where output is highest
all_results = vertcat(results.output);

s_ind = find(all_results == max(all_results));

% if several indices, use the most stable value (indicated by a combination
% of cluster center, accuracy of surrounding values, and for large clusters
% a tendency towards a larger number of voxels)
n_s_ind = length(s_ind);
if n_s_ind>1
    neighbors = 0;
    while 1
        neighbors = neighbors + 1;
        temp_acc = zeros(1,n_s_ind);
        for i_s_ind = s_ind
            temp_s_ind = i_s_ind-neighbors:i_s_ind+neighbors;
            temp_s_ind = temp_s_ind(temp_s_ind<=length(all_results)&temp_s_ind>0);
            temp_acc(s_ind==i_s_ind) = mean(all_results(temp_s_ind));
        end
        temp_ind = temp_acc == max(temp_acc);
        s_ind = s_ind(temp_ind);
        if length(s_ind) == 1 || neighbors > 5, break, else n_s_ind = length(s_ind); end
        % to make sure it doesn't prefer extremes, remove extremes after i neighbors
        s_ind = s_ind(s_ind<length(all_results)-neighbors+1);
        if length(s_ind) == 1, break, else s_ind = s_ind(s_ind>neighbors); end
        if length(s_ind) == 1, break, end
    end
end

% result is quite stable when more than 5 neighbors are the same, so if still not clear just pick more voxels rather than less
n_vox_selected = n_vox(s_ind(1)); 
output = all_results;

% below reduces number of times warning messages are displayed to a minimum
if ~isempty(msg_id)
    warning('off',msg_id)
elseif i_step == 1 && isempty(msg_id)
%     warning('on',msg_id)
end


%% Feature ranks
function [ranks,ind,external] = rank_features(cfg,external,labels_train,vectors_train,i_step)

switch lower(cfg.feature_selection.filter)
    case 'f'
        [ranks,ind] = fget(labels_train,vectors_train);
    case 'f0'
        [ranks,ind] = fget(labels_train,vectors_train,0);
    case 'u'
        [ranks,ind] = uget(labels_train,vectors_train);
    case 'w'
        [ranks,ind] = wget(labels_train,vectors_train);
    case 'external'
        [ranks,ind,external] = eget(cfg,external,i_step);
    otherwise
        error('Unknown ranking method %s',cfg.feature_selection.method)
end