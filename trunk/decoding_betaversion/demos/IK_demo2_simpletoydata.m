% This script is a demo showing some simple decoding on simulated toy data.
% The toy data are simple matlab matrices and no "real" fMRI or EEG data.

clear all
dbstop if error % if something goes wrong

%% Set the output directory where data will be saved
% cfg.results.dir = % e.g. 'toyresults'
cfg.results.write = 0; % no results are written to disk


%% generate some toy data
% define number of "runs" and center means
nruns = 4; % lets simulate we have n runs
set2.mean = [0 0];
set1.mean = [.2 .2]; % should have the same dim as set1, otherwise it wont work (and would not make sense, either)

% data on two shifted lines
x = rand(nruns, 1);
dat = [x, x.*(-1) + 1];
data1 = dat + repmat(set1.mean, nruns, 1);
data2 = dat + repmat(set2.mean, nruns, 1);

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

%% plot the data (if 2d)
if size(data, 2) == 2
    scatter(data(:, 1), data(:, 2), 30, cfg.files.label);
end

%% Prepare data for passing
pass_data.data = data;
pass_data.mask_index = 1:size(data, 2); % use all voxels
pass_data.files = cfg.files;
pass_data.hdr = ''; % we don't need a header, because we don't write img-files as output (but mat-files)
pass_data.dim = [length(set1.mean), 1, 1]; % add dimension information of the original data
% passed_data.voxelsize = [1 1 1];


%% Add defaults for the remaining parameters that we did not specify
cfg = decoding_defaults(cfg);

% Set the analysis that should be performed (here we only want to do 1
% decoding)
cfg.analysis = 'wholebrain';
cfg.results.output = {'accuracy'} % , 'model_parameters'}; % add if you want to see the model

%% Nothing needs to be changed below for a standard leave-one-run out cross
% validation analysis.

% Create a leave-one-run-out cross validation design:
cfg.design = make_design_cv(cfg); 
print_design(cfg);

%% Decoding Parameters

% default: -s 0 -t 0 -c 1 -b 0
cfg.decoding.train.classification.model_parameters = '-s 0 -t 0 -c 1000 -b 0';

%% Run decoding
[results, cfg] = decoding(cfg, pass_data);

%% Print decision boundary in figure
if isfield(results, 'model_parameters')
    svm_model = results.model_parameters.output(1).model(1); % get the model of the first SVM
    [X, Y] = meshgrid(-2:.11:3);
    Z = X;
    [predicted, acc, decision_values] = svmpredict(zeros(size(X(:))),[X(:), Y(:)],svm_model,cfg.decoding.test.classification.model_parameters);
    Z(:) = decision_values;
    hold on
    contour(X,Y,Z, -1:1);
    hold off
end