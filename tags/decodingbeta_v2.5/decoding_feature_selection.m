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
%                    used for selection and the optimal number will be
%                    determined automatically.
%
%       nested_n_vox:Optional input for method 'embedded.RFE'. Determines
%                    how many voxels are initially picked for RFE and how
%                    many are eliminated in each step.
%                    Permitted input is the same as in 'n_vox', except that
%                    'automatic' leaves out sqrt(n) features per step
%                    Example: [50 60 80 100] will start with 100 voxels,
%                    then will leave in 80, then 60, etc. and will
%                    terminate at n_vox. When n_vox is larger than a 
%                    value in nested_n_vox, this value in nested_n_vox will
%                    be discarded.
%
%       external_fname: Optional input for method 'filter.external'. 1 x n
%                    cell matrix of file names. Provides full path to files
%                    used as external ranking input (e.g. previously
%                    computed F-contrasts). Can be one image (when contrast
%                    is independent of labels) or one per decoding step
%                    (e.g. one per run).
%
%       useall:      Uses both training and test data for feature selection.
%                    Useful if selection criterion is independent of data
%                    (e.g. when best features are selected on an
%                    independent t-map that does not carry information
%                    about the category which is decoded). Also, the output
%                    generated in results.feature_selection can be used to
%                    draw plots of information depending on the number of
%                    features selected. Nested feature selection searches 
%                    are not permitted and will lead to the same results as
%                    a standard analysis to prevent unintentional misuse.
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
%   labels_train: samples x 1 vector
%   i_step: current decoding step (e.g. run) in main experiment
%   i_train: original index for training data (needed for selecting relevant data)
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

if strcmpi(cfg.feature_selection.method,'filter') && strcmpi(cfg.feature_selection.filter,'external') && length(cfg.feature_selection.external_fname)>1
   % do nothing
elseif isfield(cfg.feature_selection,'useall') && cfg.feature_selection.useall && fs_data.i_step ~= 1
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
labels = fs_data.labels_train;
i_step = fs_data.i_step;
i_train = fs_data.i_train;

if isfield(cfg.feature_selection,'useall') && cfg.feature_selection.useall == 1
    warningv('DECODING_FEATURE_SELECTION:Nonindependence',['Training and test data are both used for feature selection. ',...
        'Feature selection results will not be applied to main decoding, but ',...
        'can be used for illustrative purposes!'])
end

% Run basic checks
[cfg,n_vox,nested_n_vox] = basic_checks(cfg,size(data,2),i_step);

% Scale features first
data_scaled = decoding_scale_data(cfg.feature_selection,data); % because training data are balanced, currently the default for scaling is 'all' or 'none'

%% Run feature selection as filter
if strcmpi(cfg.feature_selection.method,'filter')

[fs_index,fs_data,n_vox_steps,output] = feature_selection_filter(cfg,fs_data,labels,data_scaled,n_vox,i_step,i_train);
    
%% Run feature selection as embedded method (currently only RFE)

elseif strcmpi(cfg.feature_selection.method,'embedded')
    
    if ~strcmpi(cfg.feature_selection.embedded,'RFE')
        error(['Currently, for embedded feature selection methods, only recursive ',...
               'feature elimination is implemented. Please set cfg.feature_selection.embedded = ''RFE'''])
    end

[fs_index,n_vox_steps,output] = feature_selection_embedded(cfg,labels,data_scaled,n_vox,nested_n_vox,i_step,i_train);

end

%% Generate ouput

fs_results.n_vox_steps = n_vox_steps;
fs_results.output = output;
fs_results.n_vox_selected = length(fs_index);

if isfield(cfg.feature_selection,'useall') && cfg.feature_selection.useall
    fs_index = 1:size(data,2); % do not change decoding for next step when all data is used
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Feature selection subfunctions %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Basic subfunctions

%---------------------------------------------------
% Set n_vox and nested_n_vox and run basic checks to prevent wrong use of n_vox and nested_n_vox
function [cfg,n_vox,nested_n_vox] = basic_checks(cfg,n_features,i_step)

if ~strcmpi(cfg.feature_selection.method,'none') && ~strcmpi(cfg.feature_selection.method,'filter') && ~strcmpi(cfg.feature_selection.method,'embedded')
    warningv('DECODING_FEATURE_SELECTION:noSelection',['No feature selection performed!\n'...
        'Unknown feature selection type.']);
end

if ~isfield(cfg.feature_selection,'n_vox')
    error(['Missing field ''nvox'' in cfg.feature_selection. You need to specify the range ',...
                'in which to search. Type ''help feature_selection'' for details.'])
end

if ~isempty(strfind(cfg.feature_selection.decoding.method, '_kernel'))
    newmethod = strrep(cfg.feature_selection.decoding.method,'_kernel','');
    str = sprintf(['Use of kernel methods in feature selection has not been implemented',... 
                   '(and would only make sense for nested cross-validation in filter methods).',...
                   'Method is now reverted to ''%s''.'],newmethod);
    warningv('BASIC_CHECKS:KernelAndFeatureSelection',str)
    cfg.feature_selection.decoding.method = newmethod;
end

if ~isfield(cfg.feature_selection,'n_vox')
    if i_step == 1
        warningv('DECODING_FEATURE_SELECTION:noSelection',['No feature selection performed!\n'...
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
        warningv('DECODING_FEATURE_SELECTION:MaxIterExceeded','Some iterations exceed maximum number of available features. Removing these iterations!');
        n_vox = n_vox(n_vox<=n_features);
        if isempty(n_vox), n_vox = n_features; end
    end
    
    n_vox = unique(n_vox); % Needed if steps are very small to prevent repetitions % TODO: repetitions should be noted, but filled in anyhow!
    n_vox = n_vox(n_vox>0);
end
    
if strcmpi(cfg.feature_selection.method,'filter')
    nested_n_vox = n_vox; % for filtering, give nested_n_vox as output because output is requested % TODO: try giving [] as output

elseif strcmpi(cfg.feature_selection.method,'embedded') % gets nested_n_vox for embedded methods

    if isfield(cfg.feature_selection,'nested_n_vox')
        nested_n_vox = cfg.feature_selection.nested_n_vox;
    else
        error('DECODING_FEATURE_SELECTION:noSelection',['No feature selection performed!\n'...
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
            warningv('DECODING_FEATURE_SELECTION:MaxIterExceeded','Some iterations exceed maximum number of available features. Removing these iterations!');
            nested_n_vox = nested_n_vox(nested_n_vox<=n_features);
        end
        
        nested_n_vox = unique(nested_n_vox); % Needed if steps are very small to prevent repetitions
        nested_n_vox = nested_n_vox(nested_n_vox>0);        
    end
    
    if any(nested_n_vox > n_features)
        error('DECODING_FEATURE_SELECTION:noSelection',['No feature selection performed!\n'...
            'Number of specified features to be selected is larger than number of existing features.']);
    end
    
end