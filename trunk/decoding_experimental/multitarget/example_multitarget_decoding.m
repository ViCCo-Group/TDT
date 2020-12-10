% This script is a template that can be used for a decoding analysis on 
% brain image data. It is for people who have betas available from an 
% SPM.mat and want to automatically extract the relevant images used for
% classification, as well as corresponding labels and decoding chunk numbers
% (e.g. run numbers). If you don't have this available, then use
% decoding_template_nobetas.m

% Make sure the decoding toolbox and your favorite software (SPM or AFNI)
% are on the Matlab path (e.g. addpath('/home/decoding_toolbox') )
assert(~isempty(which('decoding_defaults', 'function')), 'TDT not found in path, please add')
assert(~isempty(which('spm', 'function')), 'SPM not found in path, please add')

assert(~isempty(which('example_multitarget_decoding.m')), 'Could not find this file in path, please add')

% Set defaults
cfg = decoding_defaults;

% Set the analysis that should be performed (default is 'searchlight')
cfg.analysis = 'wholebrain';
% cfg.searchlight.radius = 3; % use searchlight of radius 3 (by default in voxels), see more details below

% Set the output directory where data will be saved, e.g. 'c:\exp\results\buttonpress'
cfg.results.dir = 'C:\kai\tdt\decodingtoolbox-code\decoding_experimental\multitarget\results'

% Set the filepath where your SPM.mat and all related betas are, e.g. 'c:\exp\glm\model_button'
beta_loc = 'C:\kai\tdt\decodingtoolbox-code\benchmark\SPM_files\full\'

% Set the filename of your brain mask (or your ROI masks as cell matrix) 
% for searchlight or wholebrain e.g. 'c:\exp\glm\model_button\mask.img' OR 
% for ROI e.g. {'c:\exp\roi\roimaskleft.img', 'c:\exp\roi\roimaskright.img'}
% You can also use a mask file with multiple masks inside that are
% separated by different integer values (a "multi-mask")
cfg.files.mask = 'C:\kai\tdt\decodingtoolbox-code\benchmark\SPM_files\full\mask.img'

%% Set additional parameters
% Set additional parameters manually if you want (see decoding.m or
% decoding_defaults.m). Below some example parameters that you might want 
% to use a searchlight with radius 12 mm that is spherical:

% cfg.searchlight.unit = 'mm';
% cfg.searchlight.radius = 12; % if you use this, delete the other searchlight radius row at the top!
% cfg.searchlight.spherical = 1;
% cfg.verbose = 2; % you want all information to be printed on screen

% use a regression (-s 4) with RBF kernel (-t 2)
cfg.decoding.method = 'regression';
cfg.decoding.train.classification.model_parameters = '-s 4 -t 2 -c 1 -n 0.5 -b 0 -q'; % nu-SVR (adapt cost to control speed) regression (-s 4) with RBF kernel (-t 2)

% Some other cool stuff
% Check out 
%   combine_designs(cfg, cfg2)
% if you like to combine multiple designs in one cfg.

%% Decide whether you want to see the searchlight/ROI/... during decoding
cfg.plot_selected_voxels = 500; % 0: no plotting, 1: every step, 2: every second step, 100: every hundredth step...

%% Select multitarget decoding software and output transformation

cfg.multitarget = 1; % needed to avoid some basic checks
cfg.decoding.software = 'libsvm_multitarget';
cfg.results.output = {'predicted_labels_multitarget'};
% cfg.results.output = {'accuracy_minus_chance', 'AUC'}; % 'accuracy_minus_chance' by default

%% CV design + run decoding

% The following function extracts all beta names and corresponding run
% numbers from the SPM.mat
regressor_names = design_from_spm(beta_loc);

labelname1 = 'up'
labelname2 = 'down'
labelval1 = {[1 7]}
labelval2 = {[-1 2]}

% Extract all information for the cfg.files structure (labels will be [1 -1] )
cfg = decoding_describe_data(cfg,{labelname1 labelname2},[labelval1 labelval2],regressor_names,beta_loc);

% This creates the leave-one-run-out cross validation design:
cfg.design = make_design_cv(cfg); 

%% Run decoding
results = decoding(cfg);