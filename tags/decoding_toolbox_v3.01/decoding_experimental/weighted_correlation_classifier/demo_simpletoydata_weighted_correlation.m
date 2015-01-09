% This script is a demo showing some simple decoding on simulated toy data.
% The toy data are simple matlab matrices and no "real" fMRI or EEG data.

clear all
dbstop if error % if something goes wrong

fpath = fileparts(fileparts(mfilename('fullpath')));
addpath(fpath)

% initialize TDT & cfg
cfg = decoding_defaults;

%% add weighted_correlation
if ~exist('weighted_correlation_classifier')
    warning('Trying to add weighted correlation classifier from experimental')
    p = fullfile(fileparts(which('decoding')), 'decoding_experimental/weighted_correlation_classifier');
    display(['Searching weighted correlation classifier in ' p])
    if ~exist(p, 'dir')
        error('Cant locate weighted correlation classifier, please check')
    end
    addpath(p)
    clear p
end

%% Set the output directory where data will be saved
% cfg.results.dir = % e.g. 'toyresults'
cfg.results.write = 0; % no results are written to disk

cfg.decoding.method = 'classification';
cfg.decoding.software = 'weighted_correlation_classifier';

%% generate some toy data
% define number of "runs" and center means
nruns = 6; % lets simulate we have n runs

% we need at least 3 dimensions here, because correlations is not defined
% for 2 or less datapoints
ndims = 3;

%% Data Generation: Specify data means
work_both = 1;  % 0: only euclidean, not correlation, 1: both

if work_both

    % Data means that works for correlation and euclidean distance
    set1.mean = randperm(ndims)*3;
    % make this pretty different from set1.mean
    splitpoint = floor(length(set1.mean)/2);
    set2.mean = set1.mean([(splitpoint+1):end, 1:splitpoint]) ; % should have the same dim as set1, otherwise it wont work (and would not make sense, either)

elseif ~work_both
    
    % Data means that do NOT work for correlation BUT for euclidean distance
    set1.mean = 10 * ones(1, ndims);
    set2.mean = -10 * ones(1, ndims);
    
end
%% 

% two independent gaussian point clouds
data1 = randn(nruns, ndims) + repmat(set1.mean, nruns, 1);
data2 = randn(nruns, ndims) + repmat(set2.mean, nruns, 1);

% alternative: uniform
% data1 = rand(nruns, length(set1.mean)) + repmat(set1.mean, nruns, 1);
% data2 = rand(nruns, length(set2.mean)) + repmat(set2.mean, nruns, 1);

% put all together in a data matrix
data = [data1; data2]; 

%% add data description
% save labels
cfg.files.label = [ones(size(data1,1), 1); 2*ones(size(data1,1), 1)];

% save run number
cfg.files.step = [1:nruns, 1:nruns]';

% save a description
for ifile = 1:length(cfg.files.label)
    cfg.files.name(ifile) = {sprintf('class%i_run%i', cfg.files.label(ifile), cfg.files.step(ifile))};
end

% add an empty mask
cfg.files.mask = '';

%% plot the data (if 2d or 3d)
if size(data, 2) == 2
    resfig = figure('name', 'Data');
    scatter(data(:, 1), data(:, 2), 30, cfg.files.label);
elseif size(data, 2) == 3
    resfig = figure('name', 'Data');
    scatter3(data(:, 1), data(:, 2), data(:, 3), 30, cfg.files.label);
end

%% Prepare data for passing
pass_data.data = data;
pass_data.mask_index = 1:size(data, 2); % use all voxels
pass_data.files = cfg.files;
pass_data.hdr = ''; % we don't need a header, because we don't write img-files as output (but mat-files)
pass_data.dim = [length(set1.mean), 1, 1]; % add dimension information of the original data


%% Set the analysis that should be performed (here we only want to do 1
% decoding)
cfg.analysis = 'wholebrain';
cfg.results.output = {'accuracy', 'model_parameters', 'decision_values'}; % add if you want to see the model

%% Nothing needs to be changed below for a standard leave-one-run out cross validation analysis.
% Create a leave-one-run-out cross validation design:
cfg.design = make_design_cv(cfg); 

% figure('name', 'Design') % done by the toolbox
% plot_design(cfg);

%% Run decoding
[results, cfg] = decoding(cfg, pass_data);

%% Display results
display('For accuracy, "output" should be larger than "chancelevel" (at least when repeating this many times or using many runs)')
results.accuracy

%% Show a MDS plot
% not working at the moment, we need the full matrix for this
% what we could do is just one step with training and test the same, then
% we would get it

%% Do the same with the weighted classifier for correlation distance

display('Repeating the same with more general method (should return the same, except that voting values are now 1-correlation)')
cfg.decoding.software = 'weighted_distance_classifier';
cfg.decoding.distance_classifier.pdist_distance = 'correlation';
cfg.decoding.distance_classifier.mean_before = 0; % 1: training patterns per class are averaged before distance calculation, 0: distance between all training x test pattern are calcualted first and then averaged for each class
[results, cfg] = decoding(cfg, pass_data);

%% Do the same with the weighted classifier for correlation distance

display('Repeating the same with more general method, but average the training patterns for each class first (should return something similar to 1-correlation)')
cfg.decoding.software = 'weighted_distance_classifier';
cfg.decoding.distance_classifier.pdist_distance = 'correlation';
cfg.decoding.distance_classifier.mean_before = 1; % 1: training patterns per class are averaged before distance calculation, 0: distance between all training x test pattern are calcualted first and then averaged for each class
[results, cfg] = decoding(cfg, pass_data);

% Display results
display('For accuracy, "output" should be larger than "chancelevel" (at least when repeating this many times or using many runs)')
results.accuracy

%% Do the same with the weighted classifier for euclidean distance

display('Calculating the eudlidean distance (should return something different)')
cfg.decoding.software = 'weighted_distance_classifier';
cfg.decoding.distance_classifier.pdist_distance = 'euclidean';
cfg.decoding.distance_classifier.mean_before = 0; % 1: training patterns per class are averaged before distance calculation, 0: distance between all training x test pattern are calcualted first and then averaged for each class
[results, cfg] = decoding(cfg, pass_data);

% Display results
display('For accuracy, "output" should be larger than "chancelevel" (at least when repeating this many times or using many runs)')
results.accuracy

%% Do the same with the weighted classifier for euclidean distance

display('Calculating the eudlidean distance, but average the training patterns for each class first (should return something similar to euclidean')
cfg.decoding.software = 'weighted_distance_classifier';
cfg.decoding.distance_classifier.pdist_distance = 'euclidean';
cfg.decoding.distance_classifier.mean_before = 1; % 1: training patterns per class are averaged before distance calculation, 0: distance between all training x test pattern are calcualted first and then averaged for each class
[results, cfg] = decoding(cfg, pass_data);

% Display results
display('For accuracy, "output" should be larger than "chancelevel" (at least when repeating this many times or using many runs)')
results.accuracy

%% Do the same with the weighted classifier for cosine distance

display('Calculating the cosine distance (should return something different)')
cfg.decoding.software = 'weighted_distance_classifier';
cfg.decoding.distance_classifier.pdist_distance = 'cosine';
cfg.decoding.distance_classifier.mean_before = 0; % 1: training patterns per class are averaged before distance calculation, 0: distance between all training x test pattern are calcualted first and then averaged for each class
[results, cfg] = decoding(cfg, pass_data);

% Display results
display('For accuracy, "output" should be larger than "chancelevel" (at least when repeating this many times or using many runs)')
results.accuracy

%% Do the same with the weighted classifier for cosine distance

display('Calculating the cosine distance, but average the training patterns for each class first (not clear how much sense this makes at the moment)')
cfg.decoding.software = 'weighted_distance_classifier';
cfg.decoding.distance_classifier.pdist_distance = 'cosine';
cfg.decoding.distance_classifier.mean_before = 1; % 1: training patterns per class are averaged before distance calculation, 0: distance between all training x test pattern are calcualted first and then averaged for each class
[results, cfg] = decoding(cfg, pass_data);

% Display results
display('For accuracy, "output" should be larger than "chancelevel" (at least when repeating this many times or using many runs)')
results.accuracy