% DISCLAIMER: This function is work in progress.
%   It indeed works for TDT (and probably for SPM-files, too), but it
%   remains to be improved.
%
% Current TODOs or restrictions:
%   Add carstens correct GPL
%   Issues with TDT output in .mat-files
%       - Works only for SL maps if mat-files are used
%       - Cannot put the result at the correct location because the affine
%         parameters are currently not stored stored in the mat-files [solved, new version of TDT saves mat, will ask for mat if not clear]
%       - Can only deal with Searchlight results so far (not a bit issue to 
%         implement ROI analyses as well, we just need to use the usual
%         output format instead of only writing an image)
%  Issues with directly providing preloaded data
%       - Not implemented yet

function gamma0max = prevalence(inputfilenames, P2, outputfilename, alpha, decoding_measure)

% permutation-based prevalence inference
%
% prevalence(inputfilenames, P2 = 1e6, outputfilename = 'prevalence', alpha = 0.05, trans_mat, decoding_measure)
%
% inputfilenames:   Cell array of input with size subjects x permutations
%                   The original unpermuted input should be in subjects x 1
%                   The cell array can either contain 
%                       1. .img/.nii filenames (cellstr)
%                       2. .mat filenames (cellstr) from TDT that contain
%                          TODO specify what exactly
%                          (also see decoding_measure below)
%                       3. 3d data in each cell
% P2:               number of second-level permutations to perform
% outputfilename:   output image filename
% alpha:            significance level
% decoding_measure: decoding measure that should be used to calculate the
%                   prevalanced statistic (e.g. 'accuracy_minus_chance'),
%                   for .mat files only. Only necessary if the mat file
%                   contains multiple decoding measures.
%
% Please cite as:
%  !Please check if a newer reference is available (currently in revision 
%                           at Neuroimage)!
%  Otherwise use:   
%   Allefeld, C., Goergen, K., & Haynes, J.-D. (2015). Valid population 
%       inference for information-based imaging: Information prevalence 
%       inference. arXiv:1512.00810 [q-Bio, Stat]. 
%       Retrieved from http://arxiv.org/abs/1512.00810

% Author: Carsten Allefeld, 2016/3/9
% Changes:
%   Kai, 2016/03/10
%   - Added author and citation information
%   - Added possibility to provide data directly as inputfilenames
%             TODO
%   - Added possibility to load data from .mat-files
%             TODO


if (nargin < 2) || isempty(P2)
    P2 = 1e7;
end
if (nargin < 3) || isempty(outputfilename)
    outputfilename = 'prevalence';
end
if nargin < 4 || (exist('alpha', 'var') && isempty(alpha))
    alpha = 0.05;
end
[N, P1] = size(inputfilenames);


%% load and prepare accuracies

fprintf('\n*** prevalence ***\n\n')

% get format of first input

if iscellstr(inputfilenames) && strcmp(inputfilenames{1}(end-3:end), '.mat')
    inputformat = 'mat';
elseif iscellstr(inputfilenames)
    inputformat = 'SPM'; % not a mat file, lets assume SPM can handle it
else
    inputformat = 'data'; % lets assume that its data for the moment
    error('Not implemented yet, please do (its just assigning the data correctly, also needs mask voxels)')
end
    
if strcmp(inputformat, 'SPM') || strcmp(inputformat, 'mat')
    fprintf('loading data\n')

    % load accuracy images
    a = cell(N, P1);
    for k = 1 : N
        fprintf('  subject #%d: ', k)
        for i = 1 : P1
            if strcmp(inputformat, 'SPM')
                vol = spm_vol(inputfilenames{k, i});
                Y = spm_read_vols(vol);
                a{k, i} = Y(:);
            elseif strcmp(inputformat, 'mat')
                currmat = load(inputfilenames{k, i});
                if ~exist('decoding_measure', 'var')
                    % check if only 1 measure exists and if so use it
                    fnames = fieldnames(currmat.results);
                    decoding_measure_ind = structfun(@(x) isfield(x, 'output'), currmat.results); % find all fields that contain .output
                    if sum(decoding_measure_ind) == 0
                        error('%s: No decoding measure has been provided and could not detect any decoding measure, please check.', inputfilenames{k, i})
                    elseif sum(decoding_measure_ind) >= 2
                        found_decoding_measures = fnames(decoding_measure_ind) %#ok<NOPRT,NASGU>
                        error('%s: Found multiple decoding measures (above), please provide one of those as argument to the function', inputfilenames{k, i})
                    else
                        decoding_measure = fnames{decoding_measure_ind};
                        dispv(1, '%s: Detected decoding measure: %s, using this for prevalance analysis', inputfilenames{k, i}, decoding_measure);
                    end
                    clear fnames decoding_measure_ind
                end
                a{k, i} = currmat.results.(decoding_measure).output;
                % check output format & size
                if ~isnumeric(a{k, i})
                    error('%s: Input measure %s is not numeric, aborting',  inputfilenames{k, i}, decoding_measure)
                elseif (size(a{k, i}, 1) ~= 1 && size(a{k, i}, 2) ~= 1) || length(size(a{k, i})) > 2
                    size(a{k, i})
                    error('%s: Input measure %s is not a vector but of size above, aborting', inputfilenames{k, i}, decoding_measure)
                elseif (k>1 || i>1) && length(a{k, i})~= length(a{1,1}) % check same number of entries for all input data by checking to the first
                    error('%s: Data has a different length (%i) than the data of image 1 (%s: %i), aborting', inputfilenames{k, i}, length(a{k, i}), inputfilenames{1, 1}, length(a{1,1}))
                elseif ~strcmp(currmat.results.analysis, 'searchlight') % also check that data is from a searchlight analysis
                    error('Prevalence analysis is currently only implemented for searchlight analyses, but you use a %s analysis. Please contact us so we can implement it for other analysis as well.', currmat.results.analysis);
                end
                % get transformation matrix from image
                
                try
                    vol.mat = currmat.results.datainfo.mat;
                catch
                    warning('Could not get transformation matrix from loaded mat file. This might be the case if the mat files have been created with an old version of TDT. In this case, you need to provide the orientation at the end of the function')
                    vol.mat = [];
                end
                    
                
            end
            
            % check that orientation matrices are the same
            if ~exist('mat', 'var')
                mat = vol.mat; % save orientation matrix from first image to compare to others
            end
            if ~isempty(vol.mat) || ~isempty(mat)
                mat_diff = abs(vol.mat(:)-mat(:));
                tolerance = 32*eps(max(vol.mat(:),mat(:)));
                if any(mat_diff > tolerance) % like isequal, but allows for rounding errors
                    error('Rotation & translation matrix of image in file \n %s \n is different from rotation & translation matrix of the first file.\n The .mat entry defines rotation & translation of the image.\n That both differ means that at least one of both has been rotated.\n Please use reslicing (e.g. from SPM) to have all images in the same position.', inputfilenames{k, i})
                end
            end
            
            fprintf('.')
        end
        fprintf('\n')
    end
    % a is now a cell array of size N x P1, where each cell contains voxel
    % values in one column vector
    a = cell2mat(reshape(a, [1, N, P1]));
    % a is now a matrix of size (number of voxels) x N x P1

    % get mask
    if strcmp(inputformat, 'SPM')
        % determine mask from data; out-of-mask voxels may be NaN or 0
        mask = all(all(~isnan(a), 2), 3) & ~any(all(a == 0, 3), 2);
        mask = reshape(mask, size(Y));
        
        % truncate data to in-mask voxels
        a = a(mask, :, :);
        V = sum(mask(:)); % number of elements
        % a is now a matrix of size V x N x P1
        
    elseif strcmp(inputformat, 'mat')
        if strcmp(currmat.results.analysis, 'searchlight')
            % get mask from datainfo of last file
            mask = false(currmat.results.datainfo.dim);
            mask(currmat.results.mask_index) = true;
            % truncation not needed, only inmask voxels in mat.
            V = length(currmat.results.mask_index); % number of voxels
        else
            error('Todo: Think about what to do with other then searchlight analyses here (its just about the output in the end)')
        end
    elseif strcmp(inputformat, 'data')
        error('Todo: Please implement here where to get the dimensions of the mask from and create the mask')
    end

else
    fprintf('\n*** prevalence ***\n\n')
    
end
    

%% generate second-level permutations

fh = figure;
fprintf('\ngenerating %d of %d permutations\n\n', P2, P1 ^ N)
fprintf('computation can be stopped by closing output window (can take a bit before the window will appear)\n\n')
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
            fprintf('stopping, please wait, writing output files...\n')
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


%% save results

data = nan(size(mask));
data(mask) = gamma0;
if ~exist('vol', 'var') || ~isfield(vol, 'mat') || isempty(vol.mat)
    % check if the tranformation matrix has been provided as trans_mat
    if exist('trans_mat', 'var')
        vol.mat = trans_mat;
    else

        warning('Computations have been done, but it seems that the transformation matrix has not been stored in the file. We know assume a transformation matrix, but that is sure to be wrong. So dont wonder if the image looks strange.')
        vol.mat = eye(4); % default
        if strcmp(inputformat, 'mat')
           vol.mat(eye(4)==1) = [currmat.results.datainfo.voxelsize, 1]; % we are nice and at least have the right voxels size
        end
        disp(vol.mat)
        display('Type "dbcont" to accept the above matrix, or use the debuger to set vol.mat as proper transformation matrix');
        keyboard
    end
end

saveMRImage(data, [outputfilename '_gamma0.nii'], vol.mat, 'prevalence map')
data = nan(size(mask));
data(mask) = at;
saveMRImage(data, [outputfilename '_typical.nii'], vol.mat, 'typical map')
saveMRImage(uint8(mask), [outputfilename '_mask.nii'], vol.mat, 'prevalence map mask')
% stored mask values end up to be 1.00000005913898 instead of 1 – why?

