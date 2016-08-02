% This demo shows how to apply prevalence inference as statistics. It 
% takes the test data from  Cichy, Chen & Haynes (NeuroImage 2011; used 
% with permission) that were used as demo in the prevalence inference paper 
% (Allefeld et al 2016) and can be downloaded from the github page below. 
% Further explanations about the analysis in the paper below.
%
% For how to use TDT data or your own data, see 
%   demo_prevalanceInference_TDTdata.m
%   demo_prevalanceInference_provide_own_data.m
% or the github page: https://github.com/allefeld/prevalence-permutation
%
% To run the script, DOWNLOAD the INPUT DATA Cichy2011 here:
%   https://github.com/allefeld/cichy-2011-category-smoothedaccuracy/releases
% Unzip it, and adapt the input path below accordingly.
% 
% If you like, you can compare the results of this script (with the same 
% paramters and the same seed) to the results saved in 
% prevalenceResultsDemoCichy11.zip contained in this folder. See comment at
% the end of this file. 
%
% Please CITE prevalence analysis as: 
%   Allefeld, C., Goergen, K., & Haynes, J.-D. (2016). 
%       Valid population inference for information-based imaging: From the 
%       second-level t-test to prevalence inference. NeuroImage. 
%       http://doi.org/10.1016/j.neuroimage.2016.07.040
%
% A longer, more didactic, previous version of the manuscript exists here:   
%   Allefeld, C., Goergen, K., & Haynes, J.-D. (2015). http://arxiv.org/abs/1512.00810
%
% The original code for the prevalence inference has been written by 
% Carsten Allefeld. Adaptation to TDT by Kai. 2016/07/26

%% Check that SPM and TDT are available on the path
clear all

if isempty(which('SPM')), error('Please add SPM to the path and restart'), end
if isempty(which('decoding_defaults')), error('Please add TDT to the path and restart'), end
decoding_defaults; % add all important directories to the path

%% Settings

P2 = 200000; % number of 2nd level permutations, should be put to something like 1e6 or 1e7 for a real analysis
rng(42);

warning(['In this demo, we use an unrealistic low number of second level permutations (P2=' int2str(P2) '). ', ...
    'You should clearly increase that for a real analysis. ', ...
    'You should also remove the randomization seed that we set above.', ...
    'See prevalenceCore.m and the paper.'])
display('Type "dbcont" to acknowledge that you have understood the warning above')
keyboard

%% Load data

% Path to "cichy-2011-category-smoothedaccuracy", that contains the
% accuracy maps that were used as demo in Allefeld et al, 2016 as
% subdirectories.

datadir = '/TDT/cichy-2011-category-smoothedaccuracy';
if ~exist(datadir, 'dir'), error('Could not find directory %s, please check', datadir); end

% collect input image filenames (The first image is always the unpermuted one)
N = 12;
P1 = 16;
ifnPat = '%02d/sa_C0002_P%04d.nii.gz';
inputimages = cell(N, P1);
for k = 1 : N
    for i = 1 : P1
        inputimages{k, i} = fullfile(datadir, sprintf(ifnPat, k, i));
    end
end

%% Define where to save the results
resultdir = fullfile(datadir, 'prevalenceResultsDemoCichy11');
mkdir(resultdir);
resultfilenames = fullfile(resultdir, 'prevalence');
display(['Writing result to ' resultfilenames '*.*']);

%% Do the analysis
% The call will start the processing. As the function says, calculation can
% be stopped any time by closing the Figure that pops up. The result at 
% this moment in time will be saved as image and/or returned.

% run prevalence analysis
prevalenceTDT(inputimages, P2, resultfilenames);

% The function returns images with the resuilts. See prevalenceCore.m for
% information about the output files.
%
% If you really wish not to write the result images to disk, use
% all_results = prevalence(inputimages, [], 'DONTWRITE');
%
% For all further options, see help prevalence.m
%
% Enjoy!

display('Prevalence analysis finished.')
display(['Results in: ' resultfilenames])

% On Linux or with an matlab md5 implementation, you can check that the
% files are as they should be. Or you can compare the results to the
% results in this folder manually.
%
% The checksum only will be the same if the seed has been set to rng(42) at
% the beginning. For a random seed, the images might deviate a bit, and
% thus the checksums are different.
% 
% The checksums here are different to the checksums produced by 
% prevalenceTest.m from the github page because we write a slightly 
% different header, and thus the chechsums are completely different.
%
% The checksums here have been produced with SPM12b (6080) and Matlab 2015a
% on 2016/08/01.
%
% If the md5 checksums are not the same as you find below, check if the 
% content is the same -- the checksums could be different just because e.g.
% informations in the header are different.
%
% $/TDT/prevalenceResultsDemoCichy11$ md5sum *.nii
% 217d4eaef80b138a0828ad85c6e64c7a  prevalence_aTypical.nii
% 4d6d3f4e6d36e72972d54cf2c71f8661  prevalence_gamma0.nii
% 93e2c146befe174c08547dedec47f717  prevalence_mask.nii
% 08f89af34d8167d9dcbd15535a113d9e  prevalence_pcGN.nii
% 57dd6fde6c75a83c25ede268e0950d53  prevalence_pcMN.nii
% aa8ab2b4e5ed54f87c16b1fb64e6792f  prevalence_puGN.nii
% e295fd5d97d5f3ccc6f3fbf31d4ddeef  prevalence_puMN.nii
