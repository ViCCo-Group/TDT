% This demo shows how to apply the i-test by Satoshi Hirose (Hirose, S, 
% 2020), a type of prevalence inference (Allefeld, Goergen, Haynes, 2016). 
% 
% The i-test TDT adaptation takes SPM images (.nii or .img) or TDT .mat 
% result as input  (works for searchlight, ROI or wholebrain analysis). 
%
% i-test can in general perform prevalence inference either using the 
% empirical permutation distribution or parametric assumptions as null 
% hypothesis. The parametric test is not implemented in this demo yet (see
% itest.m and the publication for that).
%
% To use this demo, either
%   a. download the demo data from 
%        https://sites.google.com/site/tdtdecodingtoolbox/home/download
% or 
%   b. create the demo data using 
%         demo8_demodata_decoding_tutorial_motion_direction.m 
%      from demo directory of tdt.
% or
%   c. figure out how to use a parametric assumption instead of the 
%       empirical permutation distribution (in this case, please notice us)
%
% Note: This demo is really just a demo how to use the code. Using the 
% prepared set is statistically invalid, because we have use the data for 
% the same participant as if it were the data of different participants.
% MAKE SURE that the data of different participants is loaded for your
% data.
%
%
% Please CITE i-test as: 
% Hirose, S. (2020). Valid and powerful group statistics for decoding 
%   accuracy: Information Prevalence Inference using the i-th order 
%   statistic (i-test). BioRxiv, 578930. https://doi.org/10.1101/578930
%
% and prevalence inference analyis as:
% Allefeld, C., Goergen, K., & Haynes, J.-D. (2016). 
%   Valid population inference for information-based imaging: From the 
%   second-level t-test to prevalence inference. NeuroImage. 
%   http://doi.org/10.1016/j.neuroimage.2016.07.040
%
%
% Authors: 
%   original itest.m code by Satoshi Hirose, 
%   Demo and adaption to TDT by Kai
%
% itest.m was retrieved from https://github.com/satoshi-hirose/i-test/
% i-test has been released under GPL3 (see itest-core/LICENSE)
%
% REMARK:
% The i-test implementation in TDT is in an experimental state. It has not 
% been extensively tested by the authors of TDT. Use at own risk.
%
% DISCLAIMER: This function is in beta stage. It seem to work as it should,
%   but has not been extensively tested by the public, thus use with care.

% HIST:
%   2020/01/31: itest version 0.1 for TDT based on demo_pervalence_TDT.m

%% Check that SPM and TDT are available on the path

if isempty(which('SPM')), error('Please add SPM to the path and restart'), end
if isempty(which('decoding_defaults')), error('Please add TDT to the path and restart'), end
decoding_defaults; % add all important directories to the path

%% Settings



%% Inputdata

% The analysis needs permutation data for multiple subjects as input.
%
% The data needs to be provided in the variable inputimages, which is a
% cell of dimension subjects x permutations. The original unpermuted input 
% for each subject should be provided as first entry for each subject, i.e. 
% as subjects x 1. The cell array can either contain file names with full
% path as
%    1. .img/.nii filenames (cellstr)
%    2. .mat filenames (cellstr) from TDT that contain
% or
%    3. directly 3d data as struct (see help prevalence or 
%         demo_prevalenceInference_provide_own_data.m)
%
% You can use
%    make_design_permutation()
% to create permutations for each subject in TDT (see e.g. demo8 and demo9)
% or you can download searchlight, wholebrain and ROI example data here:
%    https://sites.google.com/site/tdtdecodingtoolbox/home/download
% and then demo_prevalenceInference_TDTdata_demodata.zip.

%% Load data
% Here, we load some example images for each of 10 subjects
n_sbjs = 10;
decoding_measure = 'accuracy_minus_chance';

% folder that contains the original image directly and the permuted images
% in a "perm" subfolder (or set datadir manually below)
datadir = fullfile('TDT', 'example_data', 'sub01_GLM_3x3x3mm', 'results', 'motion_up_vs_down', 'searchlight');
if ~exist(datadir, 'dir')
    msg = 'Select directory containing decoding and permutation results from TDT example data (see demo8_demodata_decoding_tutorial_motion_direction.m)';
    fprintf(msg);
    datadir = uigetdir('', msg);
end

if ~exist(fullfile(datadir, 'perm'), 'dir')
    % check if the directory is the one above
    if exist(fullfile(datadir, '..', 'perm'), 'dir')
        datadir = fullfile(datadir, '..')
    else
        error('Could not find the permutation directory ''perm'' in %s. To get the required data, download the demo data from the TDT website and calculate permutation results of the demo data as described in TDT\\statistics\\prevalence_inference\\README.txt (where TDT is the base directory of TDT).', datadir); 
    end
end

%% directories and file masks for unpermuted and permuted images
orig_inputdir = {};
orig_inputdir(1:n_sbjs,1) = {datadir};
orig_filemask(1:n_sbjs,1) = {['res_' decoding_measure '.mat']}; % regular expression, for more see help spm_select
%                                                      From  help spm_select:
%                                                      e.g. DCM*.mat files should have a typ of '^DCM.*\.mat$'
perm_inputdir = {};
perm_inputdir(1:n_sbjs,1) = {fullfile(datadir, 'perm')};
perm_filemask = {};
perm_filemask(1:n_sbjs,1) = {['^perm.*_' decoding_measure '\.mat$']}; % 

inputimages = {};
for sbj = 1:n_sbjs   
    % get the original unpermuted result image as first image (required by the package)
    orig_image = cellstr(spm_select('FPList',orig_inputdir{sbj},orig_filemask{sbj}));
    if length(orig_image) ~= 1
        error('There should be exactly 1 unpermuted input file for %s, but we found %i, please check', orig_image, length(orig_image)) %#ok<PFCEL>
    elseif isempty(orig_image{1})
        error('No file found for %s %s, please check', orig_inputdir{sbj}, orig_filemask{sbj}, length(orig_image))
    end
    inputimages(sbj, 1) = orig_image;
    
    % put permuted images afterwards
    permuted_images = cellstr(spm_select('FPList',perm_inputdir{sbj},perm_filemask{sbj}));
    if length(permuted_images) == 1 && isempty(permuted_images{1})
        error('  No permuted images found for sbj %i with %s %s', sbj, perm_inputdir{sbj},perm_filemask{sbj});
    else
        fprintf('  Found %i permuted images for sbj %i\n', length(permuted_images), sbj);
    end
    
    inputimages(sbj, 2:length(permuted_images)+1) = permuted_images;
end

warning(['In this demo, we REUSE THE PERMUTATION DATA FROM 1 SUBJECT TO SIMULATE DIFFERENT SUBJECTS.' char(10) ...
    'This means that in the permutations for all "subjects" will be identical.' char(10) ...
    'This is done becase we dont have multiple subjects in the TDT example dataset, but want to demonstrate how multiple subjects work.' char(10) ...
    'IN A REAL ANALYSIS YOU WILL OF COURSE NEED DIFFERENT PERMUTATION DATA FOR DIFFERENT SUBJECTS!!! ' char(10) ...
    'For information on itest, see Hirose (2020) https://doi.org/10.1101/578930'])
str = input('If you have understood the above warning, type ''yes'': ','s');
if strcmpi(str,'yes') || strcmpi(str,'y')
    % do nothing
else
    disp('Quitting demo...')
    return
end

%% Define where to save the results
resultdir = fullfile(orig_inputdir{1}, 'itest_demo');
mkdir(resultdir);
resultfilenames = fullfile(resultdir, 'itest_demo');
disp(['Writing result to ' resultfilenames '*.*']);

%% Do the analysis
% The call will start the processing. As the function says, calculation can
% be stopped any time by closing the Figure that pops up. The result at 
% this moment in time will be saved as image and/or returned.

% run prevalence analysis
itestTDT(inputimages, resultfilenames);

% Without output, the function creates images with the results.
%
% If you really wish not to write the result images to disk, use
% all_results = itestTDT(inputimages, 'DONTWRITE');
%
% For all further options, see "help itestTDT" and "help itest"
%
% Enjoy!

disp('itest TDT demo analysis finished.')
disp(['Results in: ' resultfilenames])
