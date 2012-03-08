% function [fs_index,fs_results,fs_data] = decoding_feature_selection(cfg,fs_data)
% 
% This function performs feature selection of decoding data and is an
% integral part of the decoding toolbox. Currently there are two forms of
% feature selection implemented: filter methods and embedded methods (see
% Guyon et al, 2002, for what sorts of feature selection exist).
%
% INPUT
% cfg: structure passed from decoding.m with at least the following fields:
%   feature_selection: struct containing feature selection parameters
%   fields:
%       method:
%           'filter':       Performs feature selection using filter methods
%                           (univariate or multivariate)
%           'embedded':     Performs feature selection as part of the
%                           final classifier (e.g. using the same method to
%                           find the optimal feature subset)
%           'none':         Perform no feature selection
%
%       filter: (for method = 'filter'):
%            'F':           Voxels with the greatest discriminative
%                           response will be selected from the input voxels
%            'F0':          Voxels with the greatest overall response
%                           across both groups (=pooled) will be selected
%            'U':           Same as F, but non-parametric, using the
%                           Mann-Whitney U-test (also called Wilcoxon Rank
%                           Sum Test)
%            'W':           Uses classification weights on features in
%                           training set to determine the importance of
%                           each voxel.
%            'external':    External, previously computed image(s) will be
%                           used to provide ranks
%
%       embedded: (for method = 'embedded'):
%            'RFE':         Recursive feature elimination. Recursively
%                           trains classifier and eliminates feature
%                           subset n with the lowest weight until criterion
%                           is reached (see Guyon et al., 2002).
%
%       n_vox:       Determines number of to be selected voxels or range in
%                    which the number of to be selected voxels should be
%                    searched.
%                    When a range of numbers is entered, the optimal number
%                    of voxels is determined from this range (input as
%                    percentage between 0 and 1 or as total number of
%                    voxels). The optimum is determined by nested CV. When
%                    the string 'automatic' is entered, all voxels will be
%                    used for selection.
%
%       nested_n_vox:Optional input for method 'embedded.RFE'. Determines
%                    range of voxels in which to search in nested CV.
%                    Permitted input is the same as in 'n_vox', except that
%                    'automatic' leaves out sqrt(n) features per step
%
%       external_fname: Optional input for method 'filter.external'. 1 x n
%                    cell matrix of file names. Provides full path to files
%                    used as external ranking input (e.g. previously
%                    computed F-contrasts). May be one image (when contrast
%                    is independent of labels) or one per decoding step
%                    (e.g. one per run).
%
%       useall:      Uses both training and test data for feature selection.
%                    Useful if selection criterion is independent of data
%                    (e.g. when best features are selected on an
%                    independent t-map that does not carry information
%                    about the category which is decoded). Also, the output
%                    generated in results.feature_selection can be used to
%                    draw plots of information depending on number of
%                    features selected. Nested feature selection searches 
%                    are not permitted and will lead to the same results as
%                    a standard analysis to prevent unintentional abuse.
%
%   files.label: n_steps x 1 vector, specifying the label for each file
%   files.step:  n_steps x 1 vector, specifying the decoding step of each label
%   scale: Needed if different scaling than main experiment is wanted
%        scale.method: 'z', 'min0max1', or 'none', see decoding_scale_data.m
%        scale.estimation: 'all', 'all_used', 'traintest', 'none'. All
%           values other than 'none' will be treated as 'all'.
%
% fs_data: struct containing data for feature selection
% fields:
%   vectors_train: samples x features matrix, containing data on which
%       feature selection is based
%   vectors_test: samples x features matrix, adapted at end of function
%   labels_train: samples x 1 vector
%   i_step: current decoding step (e.g. run) in main experiment
%   external.ranks_image: image files used for ranking, loaded in previous
%       iterations
%   external.position_index: external reference to absolute positions of ROI voxels 
%       in volume
%
% OUTPUT
% fs_index:   index to voxels that should be used for training and testing
% fs_results: structure containing relevant information of feature selection
%   n_vox_selected: Number of voxels that have been selected
%   n_vox_steps: 1 x n vector with the range of voxels in which it was searched
%   output: 1 x n results vector, decoding accuracies across different
%       numbers of voxels in nested feature selection
%

% TODO list:
%   - vectors_train and data are used in a confusing manner. Rename to make
%   clearer (e.g. data_scaled, vectors_train_scaled, or similar)
%   - introduce decoding_transform_results and other subfunctions used in decoding.m
%   - find a good way to automatically split training data into well-sized
%   chunks (one possibility: use same number of test samples as in the main
%   experiment; problem if cross-classification
%      -> problem: some samples should not be mixed (e.g. data from one run
%      should stay together) --> solution: explicitly set design file in cfg
%   - introduce random forests for feature ranking
%   - introduce pca (and supervised pca?)
%   - allow the use of external functions under filter, wrapper, and
%   embedded methods (thus provide only the selection structure)

function [fs_index,fs_results,fs_data] = decoding_feature_selection(cfg,fs_data)

if isfield(cfg.feature_selection,'method') && strcmpi(cfg.feature_selection.method,'none')
    return
end

if isfield(cfg.feature_selection,'useall') && cfg.feature_selection.useall && fs_data.i_step ~= 1
    fs_index = 1:size(fs_data.vectors_train,2);
    fs_results = [];
%     fs_results = results.feature_selection(i_decoding);
    return % in this case only do FS once, because all others will be identical
end
    
% Unpack data
% if isfield(results,'feature_selection') && length(results.feature_selection)>=i_decoding
%     fs_results = results.feature_selection;
% end
data = fs_data.vectors_train;
vectors_leftout = fs_data.vectors_test;
labels = fs_data.labels_train;
labels_leftout = fs_data.labels_test;
i_step = fs_data.i_step;

if isfield(cfg.feature_selection,'useall') && cfg.feature_selection.useall == 1
    warning(['Training and test data are both used for feature selection. ',...
        'This will yield non-independent results for decoding. Results can only be used ',...
        'for illustrative purposes!']) %#ok<WNTAG>
    itrain = cfg.design.train(:, i_step) > 0;
    itest = cfg.design.test(:, i_step) > 0;
    data_x(itrain,:) = data;
    data_x(itest,:) = vectors_leftout;
    labels_x(itrain,:) = labels;
    labels_x(itest,:) = labels_leftout;
    data = data_x;
    labels = labels_x;
end

% Run basic checks
[n_vox,nested_n_vox] = basic_checks(cfg,size(data,2),i_step);

% Scale features first
data_scaled = decoding_scale_data(cfg,data); % because training data are balanced, currently the default for scaling is 'all' or 'none'

%% Run feature selection as filter
if strcmpi(cfg.feature_selection.method,'filter')

[fs_index,n_vox_steps,output] = feature_selection_filter(cfg,fs_data,labels,data_scaled,n_vox,nested_n_vox,i_step);
    
%% Run feature selection as embedded method (currently only RFE)

elseif strcmpi(cfg.feature_selection.method,'embedded') && ...
       strcmpi(cfg.feature_selection.embedded,'RFE')

[fs_index,n_vox_steps,output] = feature_selection_embedded(cfg,labels,data_scaled,n_vox,nested_n_vox,i_step);

end

%% Generate ouput

fs_results.n_vox_selected = n_vox_selected;
if isfield(cfg.feature_selection,'useall') && cfg.feature_selection.useall
    fs_results.n_vox_steps = n_vox_steps;
    fs_results.output = output;
    fs_index = 1:length(ranks); % do not change decoding for next step when all data is used
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Feature selection subfunctions %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Basic subfunctions

%---------------------------------------------------
% Set n_vox and nested_n_vox and run basic checks to prevent wrong use of n_vox and nested_n_vox
function [n_vox,nested_n_vox] = basic_checks(cfg,n_features,i_step)

% TODO: pass warning msg id to n_vox and return to invoking function
msg_id = []; % TODO: introduce persistent variable that prevents that warnings are issued again

if ~strcmpi(cfg.feature_selection.method,'none') && ~strcmpi(cfg.feature_selection.method,'filter') && ~strcmpi(cfg.feature_selection.method,'embedded')
    [msg,msg_id] = warning('DECODING_FEATURE_SELECTION:noSelection',['No feature selection performed!\n'...
        'Unknown feature selection type.']);
end

if ~isfield(cfg.feature_selection,'n_vox')
    if i_step == 1
        [msg,msg_id] = warning('DECODING_FEATURE_SELECTION:noSelection',['No feature selection performed!\n'...
        	'No field ''n_vox'' in cfg.feature_selection.\n']);
    end
else
    n_vox = cfg.feature_selection.n_vox;
end
    
if ischar(n_vox)
    if ~strcmp(n_vox,'automatic')
        error('Unknown input %s in field ''n_vox''. Use any number, allowed strings, or do not specify.',n_vox)
    end
    
elseif length(n_vox)>=1 % if range of voxels is entered
    
    if any(n_vox<1) % when n_vox is given as percentage
        if any(n_vox>1), error('Unclear if field ''n_vox'' is provided as percentage or absolute numbers.'), end
        n_vox = round(n_vox * n_features);
    end

    if any(n_vox> n_features)
        warning('Some iterations exceed maximum number of available features. Removing these iterations!') %#ok<WNTAG>
        n_vox = n_vox(n_vox<=n_features);
        if isempty(n_vox), n_vox = n_features; end
    end
    
    n_vox = unique(n_vox); % Needed if steps are very small to prevent repetitions % TODO: repetitions should be noted, but filled in anyhow!
    n_vox = n_vox(n_vox>0);
end
    
if any(n_vox > n_features)
    [msg,msg_id] = warning('DECODING_FEATURE_SELECTION:noSelection',['No feature selection performed!\n'...
        'Number of specified features to be selected is larger than number of existing features.']);
end

if strcmpi(cfg.feature_selection.method,'filter')
    nested_n_vox = n_vox; % for filtering, give nested_n_vox as output because output is requested % TODO: try giving [] as output

elseif strcmpi(cfg.feature_selection.method,'embedded') % gets nested_n_vox for embedded methods

    if isfield(cfg.feature_selection,'nested_n_vox')
        nested_n_vox = cfg.feature_selection.nested_n_vox;
    else
        [msg,msg_id] = error('DECODING_FEATURE_SELECTION:noSelection',['No feature selection performed!\n'...
            'nested_n_vox was not specified for feature selection method ''embedded''.']);
    end
    
    if ischar(nested_n_vox)
        if ~strcmp(nested_n_vox,'automatic')
            error('Unknown input in field ''n_vox''. Use any number, allowed strings, or do not specify.')
        end
        
        % automatic: uses sqrt(n)-RFE 
        nested_n_vox = n_features;
        i = nested_n_vox;
        while i > 1
            i = nested_n_vox(end)-floor(sqrt(nested_n_vox(end)));
            nested_n_vox = [nested_n_vox i]; %#ok<AGROW>
        end
        
    elseif length(nested_n_vox)>1 % if range of voxels is entered
        
        if any(nested_n_vox<1) % when n_vox is given as percentage
            if any(nested_n_vox>1), error('Unclear if field ''n_vox'' is provided as percentage or absolute numbers.'), end
            nested_n_vox = round(nested_n_vox * n_features);
        end
        
        if any(nested_n_vox > n_features)
            warning('Some iterations exceed maximum number of available features. Removing these iterations!') %#ok<WNTAG>
            nested_n_vox = nested_n_vox(nested_n_vox<=n_features);
        end
        
        nested_n_vox = unique(nested_n_vox); % Needed if steps are very small to prevent repetitions
        nested_n_vox = nested_n_vox(nested_n_vox>0);        
    end
    
    if any(nested_n_vox > n_features)
        [msg,msg_id] = error('DECODING_FEATURE_SELECTION:noSelection',['No feature selection performed!\n'...
            'Number of specified features to be selected is larger than number of existing features.']);
    end
    
end

% below reduces number of times warning messages are displayed to a minimum
if ~isempty(msg_id)
    warning('off',msg_id)
elseif i_step == 1 && isempty(msg_id)
%     warning('on',msg_id)
end