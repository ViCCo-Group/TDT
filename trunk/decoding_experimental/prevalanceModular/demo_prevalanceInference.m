% DISCLAIMER: This function is work in progress.
%   It indeed works for TDT (and probably for SPM-files, too), but it
%   remains to be improved.
%
% Current TODOs or restrictions:
%   Issues with TDT output in .mat-files
%       - Works only for SL maps if mat-files are used
%       - Cannot put the result at the correct location because the affine
%         parameters are currently not stored stored in the mat-files
%       - Can only deal with Searchlight results so far (not a bit issue to 
%         implement ROI analyses as well, we just need to use the usual
%         output format instead of only writing an image)
%  Issues with directly providing preloaded data
%       - Not implemented yet
%  General potential improvement: Show remaining time in addition to passed 
%       time (plus Carstens message that the user can stop any time).
%
% MAKE SURE TO UPDATE THE prevalence.m header in the end!
%
%
% This demo shows how to apply prevalence inference as statistics to a toy
% dataset. Find further explanations about the analysis in the paper below.
%
% If you employ the analysis, please cite as:
%   !Please check if a newer reference is available (currently in revision 
%                           at Neuroimage)!
%   otherwise use:   
%   Allefeld, C., Goergen, K., & Haynes, J.-D. (2015). Valid population 
%       inference for information-based imaging: Information prevalence 
%       inference. arXiv:1512.00810 [q-Bio, Stat]. 
%       Retrieved from http://arxiv.org/abs/1512.00810
%
% The code for the prevalence inference has been written by Carsten
% Allefeld (with slight modifications for TDT by Kai).

%% Check that SPM and TDT are available on the path
clear all

if isempty(which('SPM')), error('Please add SPM to the path and restart'), end
if isempty(which('decoding_defaults')), error('Please add TDT to the path and restart'), end
decoding_defaults; % add all important directories to the path

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
%    3. directly 3d data in each cell
%
% You can use
%    make_design_permutation()
% to create permutations for each subject in TDT.

% Here, we load some example images for each of 10 subjects.

n_sbjs = 10;
decoding_measure = 'accuracy_minus_chance';

clear orig_* perm_*
orig_inputdir(1:n_sbjs) = {'/TDT/sub01_firstlevel_reducedResolution/sub01_GLM_3x3x3mm/results/motion_up_vs_down/searchlight'};
orig_filemask(1:n_sbjs) = {['res_' decoding_measure '.mat']}; % regular expression, for more see help spm_select
%                                                      From  help spm_select:
%                                                      e.g. DCM*.mat files should have a typ of '^DCM.*\.mat$'
perm_inputdir(1:n_sbjs) = {'/TDT/sub01_firstlevel_reducedResolution/sub01_GLM_3x3x3mm/results/motion_up_vs_down/searchlight/perm'};
perm_filemask(1:n_sbjs) = {['^perm.*_' decoding_measure '\.mat$']}; % 

inputimages = {};
for sbj = 1:n_sbjs   
    % get the original unpermuted result image as first image (required by the package)
    orig_image = cellstr(spm_select('FPList',orig_inputdir{sbj},orig_filemask{sbj}));
    if length(orig_image) ~= 1
        error('There should be exactly 1 unpermuted image, but we found %i, please check', length(orig_image))
    end
    inputimages(sbj, 1) = orig_image;
    
    % put permuted images afterwards
    permuted_images = cellstr(spm_select('FPList',perm_inputdir{sbj},perm_filemask{sbj}));
    inputimages(sbj, 2:length(permuted_images)+1) = permuted_images;
end

warning(['In this demo, we use the same images for all "sbjs". ' ...
    'In a real analysis the data should of course be different for every subj!'])
display('Type "dbcont" to acknowledge that you have understood the warning above')
keyboard

%% Define where to save the results
resultdir = fullfile(orig_inputdir{1}, 'prevalenceModular');
mkdir(resultdir);
resultfilenames = fullfile(resultdir, 'prevalence');
display(['Writing result to ' resultfilenames '*.*']);

%% Do the analysis
% The call will start the processing. As the function says, calculation can
% be stopped any time by closing the Figure that pops up (which might take 
% a bit). The result at this moment in time will be saved as image.

% run prevalence analysis
prevalence(inputimages, [], resultfilenames);

% The function returns three images: 
%   prevalence_gamma0.nii: The prevalance value, see paper
%   prevalence_typical.nii: The typical above-chance accuracies at
%       positions where the majority of subject shows an effect (the median 
%       of all accuracies)
%   prevalence_mask.nii: The mask where permutations have been computed.

% TODO: Check toy data or remove option

display('Prevalence analysis finished.')
display(['Results in: ' resultfilenames])





