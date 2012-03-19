% This script is a demo showing some simple decoding on toy data.
% The toy data are simple matlab matrices and no "real" fMRI or EEG data.

% run this many times

for n_rep = 1:50

%% output dir
% cfg.results.dir = 'toyexample'
cfg.results.write = 0;

%% Generate the toy data
% define number of "runs" and center means
nruns = 6; % lets simulate we have n runs

set_red_square.mean = [1 1]; 
set_red_circle.mean = [-1 1]; 
set_green_square.mean = [1 -1]; 
set_green_circle.mean = [-1 -1];


% generate the data

% uniform
data_r_s = rand(nruns, length(set_red_square.mean)) + repmat(set_red_square.mean, nruns, 1);
data_r_c = rand(nruns, length(set_red_circle.mean)) + repmat(set_red_circle.mean, nruns, 1);
data_g_s = rand(nruns, length(set_green_square.mean)) + repmat(set_green_square.mean, nruns, 1);
data_g_c = rand(nruns, length(set_green_circle.mean)) + repmat(set_green_circle.mean, nruns, 1);


% put all together in a data matrix
data = [data_r_s; data_r_c; data_g_s; data_g_c]; 

%% add data description
% save the labels

% first analysis: squares vs circles
s_c_labels = [ 1 * ones(size(data_r_s, 1), 1);
              -1 * ones(size(data_r_c, 1), 1);
               1 * ones(size(data_r_s, 1), 1);
              -1 * ones(size(data_r_c, 1), 1)];

% second analyis: red vs green 
r_g_labels = [ 1 * ones(size(data_r_s, 1), 1);
               1 * ones(size(data_r_c, 1), 1);
              -1 * ones(size(data_r_s, 1), 1);
              -1 * ones(size(data_r_c, 1), 1)];

          
% save the run
cfg.files.step = [1:size(data_r_s, 1), 1:size(data_r_c, 1), 1:size(data_g_s, 1), 1:size(data_g_c, 1)]';
          
% save a description
for ifile = 1:size(data, 1)
    if s_c_labels(ifile) == 1
        form = 'square';
    else
        form = 'cirlce';
    end
    
    if r_g_labels(ifile) == 1
        color = 'red';
    else
        color = 'gre';
    end
    
    cfg.files.name(ifile) = {sprintf('%s_%s_run%i', form, color, cfg.files.step(ifile))};
end
% add an empty mask file
cfg.files.mask = '';

%% plot the data (if 2d)

if size(data, 2) == 2
    figure('name', 'data')

    hold all
    
    % plot s r
    filter = (s_c_labels == 1) & (r_g_labels == 1);
    plot(data(filter, 1), data(filter, 2), '+r');
    
    % plot s g
    filter = (s_c_labels == 1) & (r_g_labels == -1);
    plot(data(filter, 1), data(filter, 2), '+g');
    
    % plot c r
    filter = (s_c_labels == -1) & (r_g_labels == 1);
    plot(data(filter, 1), data(filter, 2), 'or');
    
    % plot c g
    filter = (s_c_labels == -1) & (r_g_labels == -1);
    plot(data(filter, 1), data(filter, 2), 'og');
end

legend({'sr', 'sg', 'cr', 'cg'})

%% create the design matrix

% set labels square vs circle
cfg.files.label = s_c_labels;

% train: red squares vs red circles
% test: red squares vs red circles
cfg.files.xclass = r_g_labels == 1;
design1_1 = make_design_xclass(cfg);
% the same with inverse train & test set
cfg.files.xclass = ~cfg.files.xclass;
design1_2 = make_design_xclass(cfg);

% train: red squares vs green circles
% test: green squares vs red circles
cfg.files.xclass = xor(r_g_labels == 1, s_c_labels == 1);
design1_3 = make_design_xclass(cfg);
% same with inverse labels
cfg.files.xclass = ~cfg.files.xclass;
design1_4 = make_design_xclass(cfg);


% put all in 1 design
cfg.design.train = [design1_1.train design1_2.train design1_3.train design1_4.train];
cfg.design.test = [design1_1.test design1_2.test design1_3.test design1_4.test];
cfg.design.label = [design1_1.label design1_2.label design1_3.label design1_4.label];
cfg.design.set = ones(1, size(cfg.design.train, 2));

print_design(cfg)

%% Prepare data for passing
passed_data.data = data;
passed_data.mask_index = 1:size(data, 2); % use all voxels
passed_data.files = cfg.files;
passed_data.hdr = ''; % we don't need a header, because we don't write img-files as output (but mat-files)
passed_data.dim = [length(set_green_circle.mean), 1, 1]; % add dimension information of the original data

%% Add defaults for the remaining parameters that we did not specify
cfg = decoding_defaults(cfg);

% Set the analysis that should be performed (here we only want to do 1
% decoding)
cfg.analysis = 'wholebrain';
% cfg.analysis = 'searchlight';
cfg.results.output = {'accuracy', 'binomial_probability', 'model_parameters'};
% Set the output directory where data will be saved
% cfg.results.dir = ''; fullfile(pwd, 'toyresults');

cfg.verbose = 2; % you want all information to be printed on screen

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

% RBF
cfg.decoding.train.classification.model_parameters = '-s 0 -t 0 -c 1 -b 0';

% default: cost = 1
% cfg.decoding.train.classification.model_parameters = '-s 0 -t 0 -c 1 -b 0';

% very high costs: points lie on the boundary
% cfg.decoding.train.classification.model_parameters = '-s 0 -t 0 -c 1000 -b 0';

% very low costs: points lie far away from the boundary
% cfg.decoding.train.classification.model_parameters = '-s 0 -t 0 -c 0.01 -b 0';



%% Run decoding
[results, cfg] = decoding(cfg, passed_data)
acc(n_rep) =  results.accuracy

%% end rep
end

%% predict some values to create a meshgrid
if size(data, 2) == 2

    hold on

    model = results.model_parameters.output(1).model(4)

    [X, Y] = meshgrid(-2:.1:2);
    Z = X;
    [predicted, acc, decision_values] = svmpredict(zeros(size(X(:))),[X(:), Y(:)],model,cfg.decoding.test.classification.model_parameters);
    Z(:) = decision_values;
    hold on
    contour(X,Y,Z, -1:1);   
    hold off
end