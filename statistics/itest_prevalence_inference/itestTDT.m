% all_results = itestTDT(inputfilenames, outputfilename, decoding_measure, g_0, itest_i, alpha, identical)
%
% This function maps to the original itest.m function from 
%   https://github.com/satoshi-hirose/i-test/
% to perform permutation-based i-test with TDT.
%
% See demo_itest_TDTdata.m for more information on how to use and further
% explanations.
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
% IN
%   inputfilenames: EITHER
%     Cell array of input with size subjects x permutations
%     The original unpermuted input should be in subjects x 1
%     The cell array can either contain 
%         1. .img/.nii filenames (cellstr)
%         2. .mat filenames (cellstr) from TDT that contain
%                 OR
%     Struct containing the fields
%       inputfilenames.a:    a is datamatrix with dimensions V x N x P1(=Np+1), 
%           (number of voxels x number of subjects x first level
%           permutations per subject).
%           Note that the original unpermuted result image should be passed
%           as P1=1 for each subject.
%       inputfilenames.mask: logical 1d/2d/3d/probably nd matrix with 
%           size(mask) of the original data. Inmask voxels are true. The 
%           number of entries is always larger or equal to V, because V is 
%           the number of inmask voxels (V = sum(mask(:)));  
%     	inputfilenames.vol:  struct with at least these fields: 
%              .vol.dim: 1xn vector dimension of original image
%              .vol.mat: 4x4 matrix with rotation and translation
%                        Will be set to eye(4) if not provided
% OPTIONAL
%   outputfilename:   output image filename start. Set to 'DONTWRITE' if 
%                     results should not be written. By default, results
%                     will be written to itest* in the current
%                     directory.
%   decoding_measure: decoding measure that should be used to calculate the
%                     i-test statistic (e.g. 'accuracy_minus_chance'),
%                     for .mat files only. Only necessary if the mat file
%                     contains multiple decoding measures.
% and parameters of itest.m:
%   g_0, itest_i (variable i in itest.m), alpha, identical
%   for meaning, see "help itest"
%
% OUT
%   Results will be written to files (see outputfilename above). For your 
%   convenience, the script checks if files can be written when starting, 
%   to avoid tears on your side). Outputfiles are:
%   One file for each result of itest.m, i.e.
%     H: 1 if Prob < alpha, 0 otherwise
%     Prob: Probability 
%     stat: (structure)
%       .prob_min minimum probability. should be smaller than alpha.
%       .param    predetermined parameters (g_0,i,alpha) 
%                 & number of subjects (N), number of permutations(Np)
%       .order_stat     i-th order statistic of S (real number)
%       .P_0            
%   and in addition
%      _mask.nii: the mask that was used
%       _cfg.mat: all parameters necessary to restart the analysis.
%
%   The result is also returned as first argument all_results.
%   In addition, the struct contains:
%     all_results.vol = vol; % contains infos about the data, e.g.
%                            % transformation matrices, dimensions, roi 
%                            % names, etc.
%     all_results.itest_cfg: a struct that contains all parameters to
%                            redo the analysis.
%
% AUTHORS:
% i-test inference and itest.m: Satoshi Hirose
% adaptation to TDT: Kai
%
% REMARK:
% The i-test implementation in TDT is in an experimental state. It has not 
% been extensively tested by the authors of TDT. Use at own risk.
%
% DISCLAIMER: This function is in beta stage. It seem to work as it should,
%   but has not been extensively tested by the public, thus use with care.

% HIST:
%   2020/01/31: itest version 0.1 for TDT based on demo_pervalence_TDT.m

function all_results = itestTDT(inputfilenames, outputfilename, decoding_measure, g_0, itest_i, alpha, identical)

itest_version = 'itest TDT v0.1, 2020/01/31'
citation = [char(10) 'Please cite as:' char(10) ...
' Hirose, S. (2020). Valid and powerful group statistics for decoding' char(10) ...
'   accuracy: Information Prevalence Inference using the i-th order' char(10) ...
'   statistic (i-test). BioRxiv, 578930. https://doi.org/10.1101/578930' char(10) ...
' ' char(10) ...
' and prevalence inference analyis as:' char(10) ...
' Allefeld, C., Goergen, K., & Haynes, J.-D. (2016). ' char(10) ...
'   Valid population inference for information-based imaging: From the ' char(10) ...
'   second-level t-test to prevalence inference. NeuroImage. ' char(10) ...
'   http://doi.org/10.1016/j.neuroimage.2016.07.040' char(10)]; %#ok<*CHARTEN>
date_started = datestr(now);

fprintf('\n*** itest (previously also known as "iPIPI") ***\n\n')
disp(itest_version);
disp(['Started: ' date_started])
disp(citation);


%% Check input arguments

% defaults for file names and config
if ~exist('outputfilename', 'var') || isempty(outputfilename)
    outputfilename = 'itest';
end
if ~exist('decoding_measure', 'var')
    decoding_measure = '';
end
if ~exist('itest_cfg', 'var')
    itest_cfg = [];
end

% set i-test parameters as empty if not provided, will take default
% parameters of i-test then. See defaults in itest.m
if ~exist('g_0', 'var')
    g_0 = '';
end
if ~exist('itest_i', 'var')
    itest_i = '';
end
if ~exist('identical', 'var')
    identical = '';
end
if ~exist('alpha', 'var')
    alpha = '';
end


%% Check output arguments
if nargout < 1 && strcmp(outputfilename, 'DONTWRITE')
    error('Files should not be written (outputfilename=''DONTWRITE'' but results are also not returned, aborting')
end

%% Check if we can write output files (otherwise better to abort here already)
if strcmp(outputfilename, 'DONTWRITE')
    disp('No outputfiles will be written because outputfilename = ''DONTWRITE''')
else
    fprintf('Testing if output files can be written...\n');
    [fdir, fname, fext] = fileparts(outputfilename);
    if ~exist(fdir, 'dir'), [s, m] = mkdir(fdir); end
    save([outputfilename '_test.mat'], 'date_started'); % test if we can save something, here the start date
    delete([outputfilename '_test.mat']);
end

%% load and prepare accuracies
if iscellstr(inputfilenames)
    % remark: we reuse the function from prevalence analysis to store data (no bug)
    [a, mask, vol] = prevalence_loaddata(inputfilenames, decoding_measure);
elseif isstruct(inputfilenames)
    disp('Data seem loaded already, using fields from provided struct without checking anything');
    a = inputfilenames.a; % a is datamatrix with dimensions V x N x P1(=Np+1), V: n voxels, N: n sbjs, P1: n permutations/sbj(=Np+1)
    mask = inputfilenames.mask; % logical 1d/2d/3d matrix with size(mask) of the original image. Inmask voxels are true, outmask voxels are false. The numer of entries is always larger or equal to V, because V is the number of inmask voxels (V = sum(mask(:)));  
    vol = inputfilenames.vol; % .vol needs to contain at least these fields: 
            % .vol.dim: 1x3 vector dimension of original image, empty if not provided
            % .vol.mat: 4x4 matrix with rotation and translation, empty if not provided
else
    error('unkown information passed in inputfilenames')
end

%% generate second-level permutations

% Data matrix a has dimensions V x N x P1(=Np+1), V: n voxels, N: n sbjs, P1: n permutations/sbj(=Np+1)
[V, N, P1] = size(a);

% init output
% H: 1 if Prob < alpha, 0 otherwise
% Prob: Probability 
% stat: (structure)
%       .prob_min minimum probability. should be smaller than alpha.
%       .param          predetermined parameters (g_0,i,alpha) 
%                 & number of subjects (N), number of permutations(Np)
%       .order_stat     i-th order statistic of S (real number)
%       .P_0            
clear results
results.H = nan(V, 1); 
results.prob = nan(V, 1);
% stat = cell(V, 1); % if you like to also store the stat output. uncomment this. if at all, the only interesting field however seems to be .P_0, you get one per participant per voxel
clear SD PD

% current implementation: one test per voxel (most likely faster when doing 
% all at once, but needs to be implemented)

start_time = now; % to display progress
msg_length = 0; % to display progress
for v_ind = 1:V
    % display progress
    if mod(v_ind, 1000) == 0 || (mod(v_ind, 100) == 0 && v_ind < 1000) || any(v_ind == [1, 2, 5, 10, V])
        disp_cfg.analysis = 'itest';
        try % no reason to abort
            [msg_length] = display_progress(disp_cfg,v_ind,V,start_time,msg_length);
        catch % do it the oldfashioned way
            fprintf('itest voxel: %i\n', v_ind);
        end
    end

    % Splitting data into original and permutation part
    SD(1:N, 1) = a(v_ind, :, 1)'; % Sample Decoding Accuracies from experiment (N x 1 matrix), first row in datamatrix
    PD = squeeze(a(v_ind, :, 2:end)); % Permutation Decoding Accuracies (N x Np matrix), remaining Np(=P1-1) rows in data matrix
    % verify that size is as expected
    [PD_N, PD_NP] = size(PD); if PD_N ~= N, error('Dimensions of PD are wrong. Most likely reason: squeeze above did not work, e.g. because there is only 1 permutation (which should in reality never happen, but in test runs). Please check'), end
    
    
    % ---------------------------------
    % DO itest 
    % original call: [H, prob, stat] = itest(SD,PD,g_0,i,alpha,identical)
    [results.H(v_ind), results.prob(v_ind)] = itest(SD,PD,g_0,itest_i,alpha,identical);
    
    % ---------------------------------
    
    % if you like to also save the "stat" returned from itest, e.g. to get 
    % P_0  for each step, use this instead of the line above and think 
    % about how to store it for your needs
    %     [results.H(v_ind), results.prob(v_ind), stats{v_ind}] = itest(SD, PD, g_0, itest_i, alpha, identical);
end

%% gather and save parameters
% save filenames or info that data has been passed directly

try
    params = []; % to also store later
    params.g_0 = g_0;
    params.itest_i = itest_i;
    params.alpha = alpha;
    params.identical = identical;
    params.N = N;
    params.Np = P1-1; 
    itest_cfg.params = params;
    if iscellstr(inputfilenames)
        itest_cfg.inputfilenames = inputfilenames;
    else
        itest_cfg.inputfilenames = sprintf('No filenames have been provided, but a data matrix directly (size data matrix a [V x N x P1]: [%s], size mask: [%s]. See itest_cfg.dbstack(2) which function provided the data.', num2str(size(a)), num2str(size(mask)));
    end
    itest_cfg.dbstack = dbstack; % caller functions
    itest_cfg.datestr_started = datestr(date_started);
    itest_cfg.datestr_finished = datestr(now);
    itest_cfg.outputfilename = outputfilename;
    if exist('decoding_measure', 'var'), itest_cfg.decoding_measure = decoding_measure; end
    
    % write to file
    if ~strcmp(outputfilename, 'DONTWRITE')
        itest_cfg_file = [outputfilename '_cfg.mat'];
        disp(['Saving itestTDT parameters to: ' itest_cfg_file]);
        save(itest_cfg_file, 'itest_cfg');
    end
catch e
    try e.getReport, end %#ok<TRYNC>
    keyboard
    warning('itest:writing_config_failed', 'Could not write config file for itest, please check why.')
end

%% save results to disk
if strcmp(outputfilename, 'DONTWRITE')
    disp('Skip writing outputfiles because outputfilename = ''DONTWRITE''')
else
    source_and_ref = ' from itest, Hirose (2020) BioRxiv doi.org/10.1101/578930';
    % set a default transformation matrix in case we have non
    if ~exist('vol', 'var') || ~isfield(vol, 'mat') || isempty(vol.mat)
        % check if the tranformation matrix has been provided as trans_mat
        if exist('trans_mat', 'var')
            vol.mat = trans_mat;
        else
            warning('The transformation matrix has not been stored in the file. The transformation matrix is set to the identical, which is most likely wrong.')
            vol.mat = eye(4); % default
            if strcmp(inputformat, 'mat')
                vol.mat(eye(4)==1) = [currmat.results.datainfo.voxelsize, 1]; % we are nice and at least have the right voxels size
            end
            disp(vol.mat)
        end
    end
    
    % Check if ROI analysis or normal analys
    if iscell(mask)
        
        % ROI analysis, write each ROI separately
        for m_ind = 1:length(mask)
            if isfield(vol, 'roi_names')
                curr_outputfilename = [outputfilename '_' vol.roi_names{m_ind}]; % add ROI name to image
            else
                curr_outputfilename = [outputfilename '_mask' int2str(m_ind)]; % add mask number to image
            end
            % remark: we reuse the function from prevalence analysis to store data (no bug)
            prevalence_savedata_to_images(curr_outputfilename, mask{1}, vol, results, m_ind, source_and_ref); % save value of current ROI to all voxels of the current ROI
        end
    else
        
        % normal analysis, write all fields to one image
        % remark: we reuse the function from prevalence analysis to store data (no bug)
        prevalence_savedata_to_images(outputfilename, mask, vol, results, [], source_and_ref);
    end
end

%% Write params as extra txt/mat file

try
    params_txtfile = [outputfilename '_params.txt'];
    disp(['Trying to write parameters to text file ' params_txtfile ])
    writetable(struct2table(params), params_txtfile); % works from matlab 2013b
catch
    warning('Writing parameters to txt file failed, maybe because matlab is too old (should work from 2013b). Use the parameters from the .mat file')
end

%% Return data 
if nargout >= 1
    all_results = results;
    all_results.itest_cfg = itest_cfg; % contains params    
    all_results.vol = vol; % will contain e.g. transformation mat and other things
    all_results.info = {'itest result, see ';
                        citation;
                        itest_version;
                        datestr(now);
                        'mask:     original volume, use to reconstruct data, e.g. as data = nan(size(all_results.mask)); data(all_results.mask) = all_results.typical;';
                        };
end
%% Done
disp(itest_version);
disp('itest done')
disp(citation);