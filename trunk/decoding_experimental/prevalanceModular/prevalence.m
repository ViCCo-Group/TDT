% prevalence(inputfilenames, P2 = 1e6, outputfilename = 'prevalence', alpha = 0.05, trans_mat, decoding_measure)
%
% permutation-based prevalence inference
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
%       inputfilenames.a:    a is datamatrix with dimensions V x N x P1, see below
%       inputfilenames.mask: logical 1d/2d/3d matrix with size(mask) of the original image. Inmask voxels are true, outmask voxels are false. The numer of entries is always larger or equal to V, because V is the number of inmask voxels (V = sum(mask(:)));  
%     	inputfilenames.vol:  struct with at least these fields: 
%              .vol.dim: 1x3 vector dimension of original image, empty if not provided
%              .vol.mat: 4x4 matrix with rotation and translation, empty if not provided
% OPTIONAL
%   P2:               number of second-level permutations to perform
%   outputfilename:   output image filename, set to 'DONTWRITE' if results
%                     should not be written
%   alpha:            significance level
%   decoding_measure: decoding measure that should be used to calculate the
%                     prevalanced statistic (e.g. 'accuracy_minus_chance'),
%                     for .mat files only. Only necessary if the mat file
%                     contains multiple decoding measures.
% OUT
%   Results will be typically be written to the current folder staring with
%   'prevalence'. See input argument how to suppress that.
%   A struct with all results can be returned are passed back containing:
%     all_results.mask = mask; % true where data comes from, size(mask) is size of the original image. Use e.g.
%                              %    data = nan(size(all_results.mask));
%                              %    data(all_results.mask) = all_results.typical;
%                              % to reconstruct the datafields        
%     all_results.gamma0 =  gamma0; 
%     all_results.typical = at;
%     all_results.vol = vol; % will contain e.g.
%
% Please cite as: Allefeld, Goergen, Haynes (2016). TODO: ADD TITLE AND STUFF (ADD as var citation below) Neuroimage
% Old citation   
%   Allefeld, C., Goergen, K., & Haynes, J.-D. (2015). Valid population 
%       inference for information-based imaging: Information prevalence 
%       inference. arXiv:1512.00810 [q-Bio, Stat]. 
%       Retrieved from http://arxiv.org/abs/1512.00810
%
% Author: Carsten Allefeld, 2016/3/9, adaptation to TDT by Kai
%
% DISCLAIMER: This function is work in progress.
%   It indeed works for TDT (and probably for SPM-files, too), but it
%   remains to be improved.

% Changes:
%   Kai, 2016/07/25
%   - Added possibility to provide data directly as inputfilenames
%   - Added possibility to load data from .mat-files
%
%
% Current TODOs or restrictions:
%   Add carstens correct GPL
%   Issues with TDT output in .mat-files
%       - Works only for SL maps if mat-files are used
%   No checks there

function all_results = prevalence(inputfilenames, P2, outputfilename, alpha, decoding_measure)

prevalence_version = 'TDT_alpha0.5, 2016/07/25';
citation = 'Allefeld, Goergen, Haynes (2016) Neuroimage';

fprintf('\n*** prevalence ***\n\n')
display(prevalence_version);
display(citation);

%% Check input arguments
if ~exist('P2', 'var') || isempty(P2)
    P2 = 1e6;
end
if ~exist('outputfilename', 'var') || isempty(outputfilename)
    outputfilename = 'prevalence';
end
if ~exist('alpha', 'var') || isempty(alpha)
    alpha = 0.05;
end
if ~exist('decoding_measure', 'var')
    decoding_measure = '';
end

%% Check output arguments
if nargout < 1 && strcmp(outputfilename, 'DONTWRITE')
    error('Files should not be written (outputfilename=''DONTWRITE'' but results are also not returned, aborting')
end

%% load and prepare accuracies
if iscellstr(inputfilenames)
    if exist('decoding_measure', 'var')
        [a, mask, vol] = prevalence_loaddata(inputfilenames, decoding_measure);
    else
        
    end
elseif isstruct(inputfilenames)
    display('Data seem loaded already, using fields from provided struct without checking anything');
    a = inputfilenames.a; % a is datamatrix with dimensions V x N x P1, see below
    mask = inputfilenames.mask; % logical 1d/2d/3d matrix with size(mask) of the original image. Inmask voxels are true, outmask voxels are false. The numer of entries is always larger or equal to V, because V is the number of inmask voxels (V = sum(mask(:)));  
    vol = inputfilenames.vol; % .volneeds to contain at least these fields: 
            % .vol.dim: 1x3 vector dimension of original image, empty if not provided
            % .vol.mat: 4x4 matrix with rotation and translation, empty if not provided
end


%% generate second-level permutations
fh = figure('name', 'Prevalence analysis');
title({'Prevalence', 'Close window to stop and wait for the results (that then will take a bit)'})
drawnow

% get dimensions of inputdata
[V, N, P1] = size(a); %: V: number of inmask voxels, N: number of subjects, P1: number of permutations per subject (have to be all the same at the moment)
fprintf('\ngenerating %d of %d permutations\n\n', P2, P1 ^ N)
fprintf('computation can be stopped by closing output window\n\n')
gamma0max = alpha^(1/N);
nPermsReport = 10000;
uRank = zeros(1, V);
cRank = zeros(1, V);
tic
for j = 1 : P2
    % select first-level permutations
    if j == 1
        % neutral permutations
        sp = ones(N, 1);
    else
        % randomly selected permutations
        sp = randi(P1, N, 1);
    end
    % select permutation values for each subject
    ind = sub2ind([N, P1], (1 : N)', sp);
    
    % test statistic: minimum across subjects
    m = min(a(:, ind)');                                                        %#ok<UDIM>
    % store result of neutral permutation,
    % i.e. actual value, for each voxel
    if j == 1
        m1 = m;
    end
    
    % compare actual value with permutation value
    % for each voxel separately:
    % determines uncorrected p-values for global null
    uRank = uRank + (m >= m1);
    % compare actual value at each voxel
    % with maximum of permutation values across voxels:
    % determines corrected p-values for global null
    cRank = cRank + (max(m) >= m1);
    
    % compute and report results
    if (mod(j, nPermsReport) == 0) || (j == P2)
        drawnow
        stop = (j == P2) || ~ishandle(fh);
        
        % uncorrected p-values for global null hypothesis
        puGN = uRank / j;
        % corrected p-values for global null hypothesis
        pcGN = cRank / j;
        % corrected significance level for global null hypothesis
        alphac = (alpha - pcGN) ./ (1 - pcGN);
        % significant voxels for global null hypothesis
        sigGN = (puGN <= alphac);      % not necessarily the same as (pcGN <= alpha)!
        % lower bound for gamma
        alphac(~sigGN) = nan;
        gamma0 = (alphac .^ (1/N) - puGN .^ (1/N)) ./ (1 - puGN .^ (1/N));
        
%         gamma0_c = 0.5;
%         % uncorrected p-values for prevalence null hypothesis
%         puPN = ((1 - gamma0_c) * puGN .^ (1/N) + gamma0_c) .^ N;
%         % corrected p-values for prevalence null hypothesis
%         pcPN = pcGN + (1 - pcGN) .* puPN;
        
        % print
        fprintf('\n  %d permutations  = %.1f %%,  in %.1f min\n', ...
            j, j / P2 * 100, toc / 60)
        fprintf('    minimal uncorrected rank: %d, reached at %d voxels\n', min(uRank), sum(uRank == min(uRank)))
        fprintf('    minimal corrected rank: %d, reached at %d voxels\n', min(cRank), sum(cRank == min(cRank)))
        fprintf('    minimal uncorrected p-value for global null: %g\n', min(puGN))
        fprintf('    minimal corrected p-value for global null: %g\n', min(pcGN))
        fprintf('    significant voxels for global null: %d\n', sum(sigGN))
        fprintf('    maximal prevalence: %g\n', max(gamma0))
        fprintf('\n')
        
        % plot
        if ~ishandle(fh)
            fh = figure('name', 'Prevalence analysis');
        else
            figure(fh)
            clf
        end
        % plot prevalences
        plot(gamma0, '.')
        line([0, V + 1], gamma0max * [1 1], 'Color', 'k')
        xlim([0, V + 1])
        xlabel('voxel')
        ylabel('\gamma_0')
        title({'Prevalence', 'Close window to stop and wait for the results (can take a bit)'})
        
        drawnow
        if stop
            fprintf('stopping, please wait...\n')
            break
        end
    end
    
end
if nargout == 0
    clear gamma0max
end

%% determine typical above-chance accuracies
V = size(a, 1);
at = nan(V, 1);
% where the majority show an effect, compute median
at(gamma0 >= 0.5) = median(a(gamma0 >= 0.5, :, 1), 2);

%% save results to disk
if strcmp(outputfilename, 'DONTWRITE')
    display('Skip writing outputfiles because outputfilename = ''DONTWRITE''')
else
    fprintf('Writing output files...\n')
    data = nan(size(mask));
    data(mask) = gamma0;
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

    saveMRImage(data, [outputfilename '_gamma0.nii'], vol.mat, 'prevalence map')
    data = nan(size(mask));
    data(mask) = at;
    saveMRImage(data, [outputfilename '_typical.nii'], vol.mat, 'typical map')
    saveMRImage(uint8(mask), [outputfilename '_mask.nii'], vol.mat, 'prevalence map mask')
    % stored mask values end up to be 1.00000005913898 instead of 1 - why?
end

%% Return data 
if nargout >= 1
    all_results.mask = mask; % true where data comes from, size(mask) is size of the original image. Use e.g.
                             %    data = nan(size(all_results.mask));
                             %    data(all_results.mask) = all_results.typical;
                             % to reconstruct the datafields        
    all_results.gamma0 =  gamma0; 
    all_results.typical = at;
    all_results.vol = vol; % will contain e.g. transformation mat and other things
    all_results.info = {'Prevalence result, see ';
                        citation;
                        prevalence_version;
                        datestr(now);
                        'gamma0:  prevalance map';
                        'typical: typical map';
                        'mask:    original volume use e.g. as data = nan(size(all_results.mask)); data(all_results.mask) = all_results.typical; to reconstruct';
                        };
end
%% Done
display('Prevalence done')