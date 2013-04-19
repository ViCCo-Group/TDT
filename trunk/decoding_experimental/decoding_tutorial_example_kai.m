% This script is an example on how to perform a searchlight decoding
% analysis on brain image data. It is combined with a tutorial.
%
% Every decoding analysis needs a cfg structure as input. This structure 
% contains all information necessary to perform a decoding analysis.

%% First, set the defaults and define the analysis you want to perform

% add path to this toolbox
addpath('/Users/kai/Documents/!Projekte/Decoding_Toolbox/trunk/decoding_betaversion')

% add path to SPM
addpath('/Users/kai/Documents/!Studium/Software/matlab libraries/spm8')

% Get the decoding defaults
% You have to do this for all decodings unless you enter all possible
% parameters by hand

cfg = decoding_defaults;

 % the standard decoding method is searchlight, but we should still enter 
 % it to be on the safe side
cfg.analysis = 'searchlight';
% cfg.analysis = 'wholebrain';

% define what you want to get as outputs
cfg.results.output = {'accuracy_minus_chance', 'binomial_probability'}

cfg.results.overwrite = 1;
% cfg.testmode = 1;
% warning('RUNNING IN TEST MODE')
% keyboard

% cfg.searchlight.wrap_control = 1; % to check that wrapping works

% Specify where the results should be saved
if isfield(cfg, 'testmode') &&  cfg.testmode == 0
    cfg.results.dir = ['/Users/kai/Documents/!Projekte/Decoding_Toolbox/testdata/results'];
end
    
% If you now look at the cfg structure, you will see a lot of entries that have
% been set automatically. You can change each of these manually. They are
% all explained in the functions decoding and decoding_defaults.

%% Second, get the file names, labels and run number of each brain image file to use for decoding.

% For example, you might have 6 runs and two categories. That should give 
% you 12 images, one per run and category. Each image has an associated 
% filename, run number and label (= category).

% There are two ways to get the information we need, depending on what you 
% have done previously. The first way is easier.

% === Automatic Creation === 
% a) If you generated all parameter estimates (beta images) in SPM and were 
% using only one model for all runs (i.e. have only one SPM.mat file), use
% the following:

% this directory represents the filepath to your SPM.mat and all related
beta_dir = ['/Users/kai/Documents/!Projekte/Decoding_Toolbox/testdata/onesided_lr_presses_HRF_minus1.5'];
% the following label names are the names that you gave your regressors of
% interest in the SPM analysis (e.g. 'button left' and 'button right')
labelname1 = ['c1']; % e.g. 'button left';
labelname2 = ['c2'];

% Also get the brain mask (e.g. that created by SPM: mask.img):
cfg.files.mask = ['/Users/kai/Documents/!Projekte/Decoding_Toolbox/testdata/onesided_lr_presses_HRF_minus1.5/mask.img'];


% The following function extracts all beta names and corresponding run
% numbers from the SPM.mat
regressor_names = design_from_spm(beta_dir);

% Now with the names of the labels, we can extract the filenames and the 
% run numbers of each label. The labels will be -1 and 1.
cfg = decoding_describe_data(cfg,{labelname1 labelname2},[-1 1],regressor_names,beta_dir);

% === Manual Creation ===
% Otherwise, you have to load all images and labels you want to use separately, e.g.
% with spm_select. This is not part of this example, but you should end up
% with the following fields:
% cfg.files.name: a 1xn cell array of file names
% cfg.files.step: a 1xn vector of run numbers
% cfg.files.label: a 1xn vector of labels (you can choose any two numbers)

%% Third, create your design for the decoding analysis

% In a design, there are several matrices, one for training, one for test
% and one for the labels that are used (there is also a set vector which we
% don't need right now). In each matrix, a column represents one decoding 
% step (e.g. cross-validation run) while a row represents one sample (i.e.
% brain image). The decoding analysis will later iterate over the columns 
% of this design matrix. For example, you might start off with training on 
% the first 5 runs and leaving out the 6th run. Then the columns of the 
% design matrix will look as follows (we also add the run numbers and file
% names to make it clearer):
% cfg.design.train cfg.design.test cfg.design.label cfg.files.step cfg.files.name
%        1                0              -1               1        ..\beta_0001.img
%        1                0               1               1        ..\beta_0002.img
%        1                0              -1               2        ..\beta_0009.img 
%        1                0               1               2        ..\beta_0010.img 
%        1                0              -1               3        ..\beta_0017.img 
%        1                0               1               3        ..\beta_0018.img 
%        1                0              -1               4        ..\beta_0025.img 
%        1                0               1               4        ..\beta_0026.img 
%        1                0              -1               5        ..\beta_0033.img 
%        1                0               1               5        ..\beta_0034.img 
%        0                1              -1               6        ..\beta_0041.img 
%        0                1               1               6        ..\beta_0042.img 

% Again, a design can be created automatically (with a design function) or
% manually. If you use a design more often, then it makes sense to create
% your own design function.

% === Automatic Creation ===
% This creates the leave-one-run-out cross validation design:
cfg.design = make_design_cv(cfg); 

% === Manual Creation ===
% After having explained the structure of the design file above, it should
% be easy to create the structure yourself. You can then check it by visual
% inspection. Dependences between training and test set will be checked
% automatically in the main function.

%% Print your design to look at it
display_design(cfg);
plot_design(cfg);

% cfg.plot_design = 0; % does not plot your design
% cfg.plot_design = 1; % plots your design using the default file formats
% cfg.plot_design = {'-dpng', '-dmeta'}; % plots your design using the
                                         % specified formats (see print.m)

%% Fourth, set additional parameters manually

% This is an optional step. For example, you want to set the searchlight 
% radius and you have non-isotropic voxels (e.g. 3x3x3.75mm), but want the
% searchlight to be spherical in real space.

% Searchlight-specific parameters
% cfg.searchlight.unit = 'mm';
cfg.searchlight.radius = 3; % this will yield a searchlight radius 3 voxels
cfg.searchlight.spherical = 0;

% Other parameters of interest:
cfg.verbose = 2; % you want all information to be printed on screen

% standard parameters for libsvm
% cfg.decoding.train.classification.model_parameters = '-s 0 -t 0 -c 1 -b 0 -q'; % (linear SV classification, cost = 1)

%% Decide whether you want to plot the searchlight while it goes

cfg.plot_selected_voxels = 500; % 1: every step, 2: every second step, 100: every hundredth step...

%% only select a number of voxels to decode
% cfg.searchlight.subset = [5, 100, 1000, 1001]';

%% Fifth, run the decoding analysis

% Fingers crossed it will not generate any error messages ;)
[results, cfg] = decoding(cfg);
