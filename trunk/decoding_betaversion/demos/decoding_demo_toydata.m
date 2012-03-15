% This script is a demo showing some simple decoding on toy data.
% The toy data are simple matlab matrices and no "real" fMRI or EEG data.

clear all

%% TEMP: To test set
cfg.results.setwise = 1;


%% Generate the toy data
% define number of "runs" and center means
nruns = 4; % lets simulate we have n runs
set2.mean = [0 0];
set1.mean = [.2 .2]; % should have the same dim as set1, otherwise it wont work (and would not make sense, either)

% generate the data

% two shifted lines
x = rand(nruns, 1);
dat = [x, x.*(-1) + 1];
data1 = dat + repmat(set1.mean, nruns, 1);
data2 = dat + repmat(set2.mean, nruns, 1);

% uniform
% data1 = rand(nruns, length(set1.mean)) + repmat(set1.mean, nruns, 1);
% data2 = rand(nruns, length(set2.mean)) + repmat(set2.mean, nruns, 1);

% put all together in a data matrix
data = [data1; data2]; 

%% add data description
% save the labels
cfg.files.label(1:nruns) = 1;
cfg.files.label(nruns+1:nruns+nruns) = 2;
% save the run number
cfg.files.step(1:nruns) = 1:nruns;
cfg.files.step(nruns+1:nruns+nruns) = 1:nruns;
% save a description
for ifile = 1:length(cfg.files.label)
    cfg.files.name(ifile) = {sprintf('class%i_run%i', cfg.files.label(ifile), cfg.files.step(ifile))};
end
% add an empty mask file
cfg.files.mask = '';

%% plot the data (if 2d)
if size(data, 2) == 2
    scatter(data(:, 1), data(:, 2), 30, cfg.files.label);
end

%% Prepare data for passing
passed_data.data = data;
passed_data.mask_index = 1:size(data, 2); % use all voxels
passed_data.files = cfg.files;
passed_data.hdr = ''; % we don't need a header, because we don't write img-files as output (but mat-files)
passed_data.dim = [length(set1.mean), 1, 1]; % add dimension information of the original data
% passed_data.voxelsize = [1 1 1];


%% Add defaults for the remaining parameters that we did not specify
cfg = decoding_defaults(cfg);

% Set the analysis that should be performed (here we only want to do 1
% decoding)
cfg.analysis = 'wholebrain';
% cfg.analysis = 'searchlight';
cfg.results.output = {'accuracy', 'binomial_probability', 'model_parameters', 'primal_SVM_weights'};
% Set the output directory where data will be saved
cfg.results.dir = fullfile(pwd, 'toyresults');

cfg.verbose = 2; % you want all information to be printed on screen

%% Nothing needs to be changed below for a standard leave-one-run out cross
% validation analysis.

% Create s leave-one-run-out cross validation design:
cfg.design = make_design_cv(cfg); 
%% add a not working design
% cfg.design.train(:, 5) = [ones(4,1); zeros(4,1)];
% cfg.design.test(:, 5) = [zeros(4,1); ones(4,1)];
% cfg.design.label(:, 5) = [1 1 2 2 1 1 2 2]';
% 
% cfg.design.set = [1 1 1 1 2];
design2 = make_design_boot_cv(cfg, 16); 

print_design(cfg);


%% Play around with the decoding parameters

% Parameters for libsvm (from their webpage):
% -s svm_type : set type of SVM (default 0)
% 	0 -- C-SVC
% 	1 -- nu-SVC
% 	2 -- one-class SVM
% 	3 -- epsilon-SVR
% 	4 -- nu-SVR
% -t kernel_type : set type of kernel function (default 2)
% 	0 -- linear: u'*v
% 	1 -- polynomial: (gamma*u'*v + coef0)^degree
% 	2 -- radial basis function: exp(-gamma*|u-v|^2)
% 	3 -- sigmoid: tanh(gamma*u'*v + coef0)
% -d degree : set degree in kernel function (default 3)
% -g gamma : set gamma in kernel function (default 1/num_features)
% -r coef0 : set coef0 in kernel function (default 0)
% -c cost : set the parameter C of C-SVC, epsilon-SVR, and nu-SVR (default 1)
% -n nu : set the parameter nu of nu-SVC, one-class SVM, and nu-SVR (default 0.5)
% -p epsilon : set the epsilon in loss function of epsilon-SVR (default 0.1)
% -m cachesize : set cache memory size in MB (default 100)
% -e epsilon : set tolerance of termination criterion (default 0.001)
% -h shrinking: whether to use the shrinking heuristics, 0 or 1 (default 1)
% -b probability_estimates: whether to train a SVC or SVR model for probability estimates, 0 or 1 (default 0)
% -wi weight: set the parameter C of class i to weight*C, for C-SVC (default 1)
% 
% The k in the -g option means the number of attributes in the input data.

% default: cost = 1
% cfg.decoding.train.classification.model_parameters = '-s 0 -t 0 -c 1 -b 0';

% very high costs: points lie on the boundary
cfg.decoding.train.classification.model_parameters = '-s 0 -t 0 -c 1000 -b 0';

% very low costs: points lie far away from the boundary
% cfg.decoding.train.classification.model_parameters = '-s 0 -t 0 -c 0.01 -b 0';



%% Run decoding
[results, cfg] = decoding(cfg, passed_data)

%% Print decision boundary in figure
% get first weights
weights = results.primal_SVM_weights.output(1).weights{1}; % [w0 (bias), w1, w2]
w = weights.w; w0 = weights.b;
% change 0 = w'x + w0 (where x: xy) in y = ax + b to easier plot the result

a = -w(1)/w(2);
b = -w0/w(2);

% plot function
x = [0, 1];
y = a*x + b;
hold all
plot(x, y);

% upper boundary
b_up = -(w0+1)/w(2);
y = a*x + b_up;
plot(x, y);

% lower boundary
b_lo = -(w0-1)/w(2);
y = a*x + b_lo;
plot(x, y);

xlim([-2 3])
ylim([-2 3])

%% plot weight vector
plot([0 w(1)], [0 w(2)])

%% predict some values to create a meshgrid
% [X, Y] = meshgrid(-2:.11:3);
% Z = X;
% [predicted, acc, decision_values] = svmpredict(zeros(size(X(:))),[X(:), Y(:)],weights.model,cfg.decoding.test.classification.model_parameters);
% Z(:) = decision_values;
% hold on
% contour(X,Y,Z, -5:5);

hold off