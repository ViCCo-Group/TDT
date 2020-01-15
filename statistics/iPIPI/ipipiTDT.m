% all_results = ipipiTDT(inputfilenames, outputfilename, decoding_measure, g_0, ipipi_i, alpha, homogeneity)
%
% This function is adapted from the original ipipi.m function from 
%   http://www2.nict.go.jp/bnc/hirose/iPinPin/index.html
% to perform permutation-based iPIPI with TDT.
%
% See the demo_iPIPI*.m files for more information on how to use.
% The iPIPI paper explains the meaning of the outputfiles:
%
% AUTHOR: Satoshi Hirose
%
% REFERENCE to iPIPI:
% Hirose, S. (2019). Valid and powerful statistical test for decoding 
% accuracy—Proposal of Permutation-based Information Prevalence Inference 
% using the i-th order statistic. BioRxiv, 578930. 
% https://doi.org/10.1101/578930
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
%                     will be written to ipipi* in the current
%                     directory.
%   decoding_measure: decoding measure that should be used to calculate the
%                     ipipi statistic (e.g. 'accuracy_minus_chance'),
%                     for .mat files only. Only necessary if the mat file
%                     contains multiple decoding measures.
% and parameters of ipipi.m
%   ipipi_i:     i of ipipi.m, index of order statistics (Postive Integer, 
%                default: 1)
%   alpha:       statistical threshold (Real number between 0 and 1 
%                default:0.05)
%   homogeneity: 1 if you assume the homogeneity of DA distribution 
%                among participants (boolean, default: 0)
%
% OUT
%   Results will be written to files (see outputfilename above). For your 
%   convenience, the script checks if files can be written when starting, 
%   to avoid tears on your side). Outputfiles are:
%   One file for each result of ipipi.m, i.e.
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
%     all_results.ipipi_cfg: a struct that contains all parameters to
%                            redo the analysis.
%
% Please CITE iPIPI as: 
% Hirose, S. (2019). Valid and powerful statistical test for decoding 
% accuracy—Proposal of Permutation-based Information Prevalence Inference 
% using the i-th order statistic. BioRxiv, 578930. 
% https://doi.org/10.1101/578930
%
% Link to TDT: Kai
%
% The iPIPI implementation in TDT is in an experimental  state. It has not 
% been extensively tested by the authors of TDT. Use at own risk.
%
% HIST:
%   2020/01/15: Version 1 for TDT based pervalenceTDT.m
%
% DISCLAIMER: This function is in beta stage. It seem to work as it should,
%   but has not been extensively tested by the public, thus use with care.


function all_results = ipipiTDT(inputfilenames, outputfilename, decoding_measure, g_0, ipipi_i, alpha, homogeneity)

ipipi_version = 'iPIPI TDT v0.1, 2020/01/15';
citation = [char(10) 'Please cite as:' char(10) ...
'Hirose, S. (2019). Valid and powerful statistical test for decoding' char(10) ... 
'  accuracy—Proposal of Permutation-based Information Prevalence Inference' char(10) ... 
'  using the i-th order statistic. BioRxiv, 578930. ' char(10) ...
'  https://doi.org/10.1101/578930'];
date_started = datestr(now);

fprintf('\n*** iPIPI ***\n\n')
disp(ipipi_version);
disp(['Started: ' date_started])
disp(citation);


%% Check input arguments

% defaults for file names and config
if ~exist('outputfilename', 'var') || isempty(outputfilename)
    outputfilename = 'ipipi';
end
if ~exist('decoding_measure', 'var')
    decoding_measure = '';
end
if ~exist('ipipi_cfg', 'var')
    ipipi_cfg = [];
end

% defaults for ipipi(SD,PD,g_0,i,alpha,homogeneity)

% g_0:  Prevalence threshold, gamma0 (Real number between 0 and 1 default:0.5)
if ~exist('g_0', 'var') || isempty(g_0)
    g_0 = 0.5;
end

% i:    Index of order statistics (Postive Integer, default: 1)
if ~exist('ipipi_i', 'var') || isempty(ipipi_i)
    ipipi_i = 1;
end

% homogeneity: 1 if you assume the homogeneity of DA distribution among participants 
if ~exist('homogeneity', 'var') || isempty(homogeneity)
    homogeneity = 0; % default in iPIPI: no homogeneity
end

% alpha: statistical threshold (Real number between 0 and 1 default:0.05)
if ~exist('alpha', 'var') || isempty(alpha)
    alpha = 0.05;
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
    [a, mask, vol] = prevalence_loaddata(inputfilenames, decoding_measure); % reusing loaddata function from prevalence demo
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
for v_ind = 1:V
    if mod(v_ind, 100) == 0 || any(v_ind == [1, 2, 5, 10])
        fprintf('ipipi voxel: %i\n', v_ind);
    end
    % Splitting data into original and permutation part
    SD(1:N, 1) = a(v_ind, :, 1)'; % Sample Decoding Accuracies from experiment (N x 1 matrix), first row in datamatrix
    PD = squeeze(a(v_ind, :, 2:end)); % Permutation Decoding Accuracies (N x Np matrix), remaining Np(=P1-1) rows in data matrix
    % verify that size is as expected
    [PD_N, PD_NP] = size(PD); if PD_N ~= N, error('Dimensions of PD are wrong. Most likely reason: squeeze above did not work, e.g. because there is only 1 permutation (which should in reality never happen, but in test runs). Please check'), end
    
    
    % ---------------------------------
    % DO iPIPI
    [results.H(v_ind), results.prob(v_ind)] = ipipi(SD, PD, g_0, ipipi_i, alpha, homogeneity);
    % ---------------------------------
    
    % if you like to also save the "stat" returned from ipipi, e.g. to get 
    % P_0  for each step, use this instead of the line above and think 
    % about how to store it for your needs
    %     [results.H(v_ind), results.prob(v_ind), stats{v_ind}] = ipipi(SD, PD, g_0, ipipi_i, alpha, homogeneity);
end

%% gather and save parameters
% save filenames or info that data has been passed directly

try
    params = []; % to also store later
    params.g_0 = g_0;
    params.ipipi_i = ipipi_i;
    params.alpha = alpha;
    params.homogeneity = homogeneity;
    params.N = N;
    params.Np = P1-1; 
    ipipi_cfg.params = params;
    if iscellstr(inputfilenames)
        ipipi_cfg.inputfilenames = inputfilenames;
    else
        ipipi_cfg.inputfilenames = sprintf('No filenames have been provided, but a data matrix directly (size data matrix a [V x N x P1]: [%s], size mask: [%s]. See ipipi_cfg.dbstack(2) which function provided the data.', num2str(size(a)), num2str(size(mask)));
    end
    ipipi_cfg.dbstack = dbstack; % caller functions
    ipipi_cfg.datestr_started = datestr(date_started);
    ipipi_cfg.datestr_finished = datestr(now);
    ipipi_cfg.outputfilename = outputfilename;
    if exist('decoding_measure', 'var'), ipipi_cfg.decoding_measure = decoding_measure; end
    
    % write to file
    if ~strcmp(outputfilename, 'DONTWRITE')
        ipipi_cfg_file = [outputfilename '_cfg.mat'];
        disp(['Saving ipipiTDT parameters to: ' ipipi_cfg_file]);
        save(ipipi_cfg_file, 'ipipi_cfg');
    end
catch e
    try e.getReport, end %#ok<TRYNC>
    keyboard
    warning('ipipi:writing_config_failed', 'Could not write config file for ipipi, please check why.')
end

%% save results to disk
if strcmp(outputfilename, 'DONTWRITE')
    disp('Skip writing outputfiles because outputfilename = ''DONTWRITE''')
else
    source_and_ref = ' from iPIPI, Hirose (2019) BioRxiv doi.org/10.1101/578930';
    % set a default transformation matrix in case we have non
    if ~exist('vol', 'var') || ~isfield(vol, 'mat') || isempty(vol.mat)
        % check if the tranformation matrix has been provided as trans_mat
        if exist('trans_mat', 'var')
            vol.mat = trans_mat;
        else
            warning('The transformation matrix has not been stored in the file. The transformation matrix is set to the identity, which is most likely wrong.')
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
            prevalence_savedata_to_images(curr_outputfilename, mask{1}, vol, results, m_ind, source_and_ref); % save value of current ROI to all voxels of the current ROI
                                                                                                              % reuse prevalence_savedata_to_images
        end
    else
        
        % normal anlysis, write all fields to one image
        % reuse prevalence_savedata_to_images
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
    all_results.ipipi_cfg = ipipi_cfg; % contains params    
    all_results.vol = vol; % will contain e.g. transformation mat and other things
    all_results.info = {'iPIPI result, see ';
                        citation;
                        ipipi_version;
                        datestr(now);
                        'mask:     original volume, use to reconstruct data, e.g. as data = nan(size(all_results.mask)); data(all_results.mask) = all_results.typical;';
                        };
end
%% Done
disp(ipipi_version);
disp(citation);
disp('Prevalence done')