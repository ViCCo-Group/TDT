tests.basic = 0;
tests.subset = 0;
tests.nokernel = 0;
tests.multiple = 0; % multiple results
tests.writematonly = 0;
tests.nowrite = 0;
tests.wholebrain = 0; % include weights
tests.roi = 1; % testing one and multiple ROIs
tests.roi_setwise = 0; % testing same analysis with setwise settings
tests.sl_setwise = 0; % testing classical searchlight with setwise settings
tests.fs_filter = 0;
tests.fs_embedded = 0;
tests.fs_multilevel = 0;
tests.parameter_selection = 0; % testing basic parameter selection assumptions

%% Possibly, manually deactivate all non-base Matlab toolboxes before running this! And run with an old Matlab version!

try
decoding_defaults;
catch
    error('Add TDT to matlabpath.')
end

clear defaults

fdir = mfilename('fullpath');
fdir = fileparts(fdir);

addpath(genpath(fileparts(fdir)))

beta_dir = fullfile(fdir,'SPM_files','full');
labelname1 = 'up';
labelname2 = 'down';
defaults.files.mask = fullfile(beta_dir,'mask.img');
defaults = decoding_describe_data(defaults,{labelname1 labelname2},[1 -1],design_from_spm(beta_dir),beta_dir);
defaults.design = make_design_cv(defaults); 

%% First test:
% Check that normal searchlight analysis runs and returns correct results

if tests.basic
    
    clear cfg M
    cfg = defaults;
    cfg.results.filestart = 'SL10mm_makedesigncv_kernel';
    cfg.results.dir = fullfile(fdir,'results');
    cfg.searchlight.unit = 'mm';
    cfg.searchlight.radius = 10;
    cfg.searchlight.spherical = 1;
    cfg.verbose = 2; % checked verbosity: all good
    cfg.results.overwrite = 1;
    cfg.plot_design = 0;
%     cfg.files = rmfield(cfg.files,'mask'); % checked: running analysis without providing mask works just as well
    results = decoding(cfg);
        
    fnames = spm_select('fplistrec',fdir,['^' cfg.results.filestart '.*\.img$']);
    [all_same, diff_vol, diff_ind] = compare_volumes(fnames);
    if ~all_same
        error('Some voxels are not the same as the reference. Please check!')
    end
        
    
end

%% Second test
% Check that subset of searchlights are calculated correctly (then we can
% later calculate only the subset rather than all and save time)

if tests.subset
    clear cfg M
    cfg = defaults;
    cfg.analysis = 'searchlight';
    cfg.results.filestart = 'SL10mm_makedesigncv_kernel_subset';
    cfg.results.dir = fullfile(fdir,'results');
    cfg.searchlight.unit = 'mm';
    cfg.searchlight.radius = 10;
    cfg.searchlight.spherical = 1;
    cfg.verbose = 1;
    cfg.results.overwrite = 1;
    cfg.plot_design = 0;
    cfg.searchlight.subset = (30001:30050)';
    
    % first test get_n_decodings for searchlight subsets
    load(fullfile(fdir,'reference','mask_index_full.mat'))
    load(fullfile(fdir,'reference','sz.mat'))
    [n_decodings,decoding_subindex] = get_n_decodings(cfg,mask_index,sz);
    
    % Do same with coordinates to see if results are identical
    [M(:,1) M(:,2) M(:,3)] = ind2sub(sz,mask_index);
    cfg.searchlight.subset = M(cfg.searchlight.subset,:);
    [n_decodings2,decoding_subindex2] = get_n_decodings(cfg,mask_index,sz);
    
    if n_decodings2 ~= n_decodings || ~isequal(decoding_subindex,decoding_subindex2)
        error('Difference between methods detected!')
    end
    
    % Now run searchlight analysis
    results = decoding(cfg);
    
    % Finally, compare results at all 50 coordinates to the same
    % coordinates in the real brain volume
    origfname = spm_select('fplistrec',fullfile(fdir,'reference'),'^SL10mm_makedesigncv_kernel_acc.*\.img$');
    currfname = spm_select('fplistrec',fullfile(fdir,'results'),['^' cfg.results.filestart '_acc.*\.img$']);
    
    Vorig = spm_vol(char(origfname));
    Vcurr = spm_vol(char(currfname));
    
    M = cfg.searchlight.subset;
    Xorig = spm_sample_vol(Vorig,M(:,1),M(:,2),M(:,3),0);
    Xcurr = spm_sample_vol(Vcurr,M(:,1),M(:,2),M(:,3),0);
    if ~any(Xorig) || ~any(Xcurr)
        error('Wrong data in comparison!')
    end
    if any(Xorig-Xcurr)
        error('Difference in results detected')
    end
    
    Xcurr2 = spm_read_vols(Vcurr);
    mind = sub2ind(sz,M(:,1),M(:,2),M(:,3));
    dind = setdiff(mask_index,mind);
    if sum(abs(Xcurr2(dind)))
        error('Results written beyond subindex!')
    end
    
    disp('subset all good!')
    
end

%% Third test
% repeat without kernel method and compare

if tests.nokernel
    
    clear cfg M
    cfg = defaults;
    cfg.analysis = 'searchlight';
    cfg.results.filestart = 'SL10mm_makedesigncv_nokernel';
    cfg.results.dir = fullfile(fdir,'results');
    cfg.searchlight.unit = 'mm';
    cfg.searchlight.radius = 10;
    cfg.searchlight.spherical = 1;
    cfg.verbose = 1;
    cfg.results.overwrite = 1;
    cfg.plot_design = 0;
    cfg.searchlight.subset = (30001:30050)';
    cfg.decoding.method = 'classification';
    
    % Now run searchlight analysis
    results = decoding(cfg);
    
    % Finally, compare results at all 50 coordinates to the same
    % coordinates in the real brain volume
    origfname = spm_select('fplistrec',fullfile(fdir,'reference'),'^SL10mm_makedesigncv_kernel_subset_acc.*\.img$');
    currfname = spm_select('fplistrec',fullfile(fdir,'results'),['^' cfg.results.filestart '_acc.*\.img$']);
    
    Vorig = spm_vol(char(origfname));
    Vcurr = spm_vol(char(currfname));
    
    load(fullfile(fdir,'reference','mask_index_full.mat'))
    load(fullfile(fdir,'reference','sz.mat'))
    [M(:,1) M(:,2) M(:,3)] = ind2sub(sz,mask_index);
    M = M(cfg.searchlight.subset,:);
    Xorig = spm_sample_vol(Vorig,M(:,1),M(:,2),M(:,3),0);
    Xcurr = spm_sample_vol(Vcurr,M(:,1),M(:,2),M(:,3),0);
    if ~any(Xorig) || ~any(Xcurr)
        error('Wrong data in comparison!')
    end
    if any(Xorig-Xcurr)
        error('Difference in results detected')
    end

    
end

%% Fourth test: write multiple results

if tests.multiple
    clear cfg M
    cfg = defaults;
    cfg.analysis = 'searchlight';
    cfg.results.filestart = 'SL10mm_makedesigncv_multiple';
    cfg.results.dir = fullfile(fdir,'results');
    cfg.searchlight.unit = 'mm';
    cfg.searchlight.radius = 10;
    cfg.searchlight.spherical = 1;
    cfg.verbose = 1;
    cfg.results.overwrite = 1;
    cfg.plot_design = 0;
    cfg.searchlight.subset = (30001:30050)';
    cfg.decoding.method = 'classification_kernel';
    cfg.results.output = {'accuracy_minus_chance','AUC_minus_chance','sensitivity','dprime'};
    cfg.results.write = 2;
    
    % Now run searchlight analysis
    results = decoding(cfg);
    
    % Compare all results
    origfname = spm_select('fplistrec',fullfile(fdir,'reference'),'^SL10mm_makedesigncv_kernel_multiple.*\.img$');
    currfname = spm_select('fplistrec',fullfile(fdir,'results'),['^' cfg.results.filestart '.*\.img$']);
    
    Vorig = spm_vol(char(origfname));
    Vcurr = spm_vol(char(currfname));
    
    load(fullfile(fdir,'reference','mask_index_full.mat'))
    load(fullfile(fdir,'reference','sz.mat'))
    [M(:,1) M(:,2) M(:,3)] = ind2sub(sz,mask_index);
    M = M(cfg.searchlight.subset,:);
    
    for i = 1:length(Vorig)
        Xorig = spm_sample_vol(Vorig(i),M(:,1),M(:,2),M(:,3),0);
        Xcurr = spm_sample_vol(Vcurr(i),M(:,1),M(:,2),M(:,3),0);
        if ~any(Xorig) || ~any(Xcurr)
            error('Wrong data in comparison!')
        end
        if any(Xorig-Xcurr)
            error('Difference in results detected')
        end
    end
    
    disp('No difference found for accuracy_minus_chance, AUC_minus_chance, sensitivity and dprime')
end


%% Fifth test: Write mat-file only

if tests.writematonly
    
    clear cfg M
    cfg = defaults;
    cfg.analysis = 'searchlight';
    cfg.results.filestart = 'SL10mm_makedesigncv_writematonly';
    cfg.results.dir = fullfile(fdir,'results');
    cfg.searchlight.unit = 'mm';
    cfg.searchlight.radius = 10;
    cfg.searchlight.spherical = 1;
    cfg.verbose = 1;
    cfg.results.overwrite = 1;
    cfg.plot_design = 0;
    cfg.searchlight.subset = (30001:30050)';
    cfg.decoding.method = 'classification_kernel';
    cfg.results.write = 1;
    
    % Now run searchlight analysis
    results = decoding(cfg);
    
    % Finally, compare results at all 50 coordinates to the same
    % coordinates in the real brain volume
    origfname = spm_select('fplistrec',fullfile(fdir,'reference'),'^SL10mm_makedesigncv_kernel_subset_acc.*\.mat$');
    currfname = spm_select('fplistrec',fullfile(fdir,'results'),['^' cfg.results.filestart '_acc.*\.mat$']);
    
    load(char(origfname))
    results_orig = results;
    load(char(currfname))
    results_curr = results;
    
    
    if any(results_orig.accuracy_minus_chance.output - results_curr.accuracy_minus_chance.output)
        error('Results do not match (check accuracy_minus_chance.output)')
    end
    
    if ~isequal(results_orig.mask_index,results_curr.mask_index)
        error('Mask indices do not match!')
    end
    
    
    
    disp('writing only results.mat is the same as writing .img and results.mat together')

    
end

%% Sixth test:
% Return results without writing and compare to written results (makes it even faster)

if tests.nowrite
    
    clear cfg M
    cfg = defaults;
    cfg.analysis = 'searchlight';
    cfg.results.filestart = 'SL10mm_makedesigncv_writematonly';
    cfg.results.dir = fullfile(fdir,'results');
    cfg.searchlight.unit = 'mm';
    cfg.searchlight.radius = 10;
    cfg.searchlight.spherical = 1;
    cfg.verbose = 2;
    cfg.results.overwrite = 1;
    cfg.plot_design = 0;
    cfg.searchlight.subset = (30001:30050)';
    cfg.decoding.method = 'classification_kernel';
    cfg.results.write = 0;
    
    % Now run searchlight analysis
    results = decoding(cfg);
    
    results_curr = results;
    
    % Finally, compare results at all 50 coordinates to the same
    % coordinates in the real brain volume
    origfname = spm_select('fplistrec',fullfile(fdir,'reference'),'^SL10mm_makedesigncv_kernel_subset_acc.*\.mat$');
    
    load(char(origfname))
    results_orig = results;
        
    
    if any(results_orig.accuracy_minus_chance.output - results_curr.accuracy_minus_chance.output)
        error('Results do not match (check accuracy_minus_chance.output)')
    end
    
    if ~isequal(results_orig.mask_index,results_curr.mask_index)
        error('Mask indices do not match!')
    end
    
    
    disp('unwritten results are the same as writing results.mat')

    
end

%% Seventh test: wholebrain
if tests.wholebrain
    
    clear cfg M
    cfg = defaults;
    cfg.analysis = 'wholebrain';
    cfg.results.filestart = 'wholebrain_makedesigncv';
    cfg.results.dir = fullfile(fdir,'results');
    cfg.verbose = 2;
    cfg.results.overwrite = 1;
    cfg.plot_design = 0;
    cfg.decoding.method = 'classification';
    cfg.results.write = 2;
    cfg.results.output = {'accuracy_minus_chance','SVM_weights'};
    
    % Now run searchlight analysis
    results = decoding(cfg);
    
end


%% 8th test: ROI (one and multiple)
if tests.roi
    
    clear cfg M
    cfg = defaults;
    cfg.analysis = 'roi';
    cfg.results.filestart = 'roi_makedesigncv';
    cfg.files.mask = {fullfile(fdir,'SPM_files','roi','mt_both.img'),fullfile(fdir,'SPM_files','roi','v1.img')};
    cfg.results.dir = fullfile(fdir,'results');
    cfg.verbose = 2;
    cfg.results.overwrite = 1;
    cfg.plot_design = 0;
    cfg.decoding.method = 'classification';
    cfg.results.write = 2;
    cfg.results.output = {'accuracy_minus_chance','AUC_minus_chance','SVM_weights','SVM_weights_plusbias'};
    cfg.plot_selected_voxels = 1;
    
    % Now run searchlight analysis
    results = decoding(cfg);
    
end

%% 9th test: ROI (multiple) with four sets

% Here, images for accuracy_minus_chance and AUC_minus_chance should be
% written, but not for SVM_weights_plusbias, because the format is struct
% with two entries and the toolbox cannot decide which to choose
% Using SVM_weights does work only with set 2, because this
% set is unique and only has one cell vector as output that matches in size
% (other than sets 1, 3, and 4). Check if this accords to the results that
% we find here.

if tests.roi_setwise
    
    clear cfg M
    cfg = defaults;
    cfg.analysis = 'roi';
    cfg.design.set(:) = [1 2 3 4 1 3 3 4]; %use funny order (where 2 is unique)
    cfg.results.filestart = 'roi_makedesigncv_setwise';
    cfg.files.mask = {fullfile(fdir,'SPM_files','roi','mt_both.img'),fullfile(fdir,'SPM_files','roi','v1.img'),fullfile(fdir,'SPM_files','roi','m1_left.img')};
    cfg.results.dir = fullfile(fdir,'results');
    cfg.verbose = 2;
    cfg.results.overwrite = 1;
    cfg.plot_design = 0;
    cfg.decoding.method = 'classification';
    cfg.results.write = 2;
    cfg.results.output = {'accuracy_minus_chance','AUC_minus_chance','SVM_weights','SVM_weights_plusbias'};
    cfg.results.backgroundvalue = NaN;
    
    % Now run searchlight analysis
    results = decoding(cfg);
    
end

%% OTHER TESTS

if tests.sl_setwise
    
    clear cfg M
    cfg = defaults;
    cfg.design.set(:) = [1:4 4:-1:1]; %use funny order
    cfg.results.filestart = 'SL10mm_makedesigncv_kernel_setwise';
    cfg.results.dir = fullfile(fdir,'results');
    cfg.searchlight.unit = 'mm';
    cfg.searchlight.radius = 10;
    cfg.searchlight.spherical = 1;
    cfg.verbose = 2; % checked verbosity: all good
    cfg.results.overwrite = 1;
    cfg.plot_design = 1;
    cfg.decoding.method = 'classification';
    cfg.results.output = {'accuracy_minus_chance','AUC_minus_chance','SVM_weights','SVM_pattern'};

    results = decoding(cfg);
      
end

if tests.fs_filter
    
    clear cfg M
    cfg = defaults;
    cfg.analysis = 'roi';
    cfg.results.filestart = 'roi_makedesigncv_fs_filter';
    cfg.results.dir = fullfile(fdir,'results');
    cfg.files.mask = {fullfile(fdir,'SPM_files','roi','mt_both.img'),fullfile(fdir,'SPM_files','roi','v1.img'),fullfile(fdir,'SPM_files','roi','m1_left.img')};
    cfg.verbose = 2;
    cfg.results.overwrite = 1;
    cfg.plot_design = 0;
    cfg.decoding.method = 'classification_kernel';
    cfg.results.write = 2;
    cfg.results.output = {'accuracy_minus_chance','AUC_minus_chance','SVM_weights','SVM_weights_plusbias'};
    
    cfg.feature_selection.method = 'filter';
    cfg.feature_selection.filter = 'external';
    cfg.feature_selection.external_fname = cfg.files.name(1:8);
    cfg.feature_selection.n_vox = [1 5 10 20:5000];
    
    results = decoding(cfg);
    
end

if tests.fs_embedded
    
    clear cfg M
    cfg = defaults;
    cfg.analysis = 'roi';
    cfg.results.filestart = 'roi_makedesigncv_fs_embedded';
    cfg.results.dir = fullfile(fdir,'results');
    cfg.files.mask = {fullfile(fdir,'SPM_files','roi','mt_both.img'),fullfile(fdir,'SPM_files','roi','v1.img'),fullfile(fdir,'SPM_files','roi','m1_left.img')};
    cfg.verbose = 1;
    cfg.results.overwrite = 1;
    cfg.plot_design = 0;
    cfg.decoding.method = 'classification_kernel';
    cfg.results.write = 2;
    cfg.results.output = {'accuracy_minus_chance','AUC_minus_chance','SVM_weights','SVM_weights_plusbias'};
    
    cfg.feature_selection.method = 'embedded';
    cfg.feature_selection.embedded = 'RFE';
    cfg.feature_selection.optimization_criterion = 'select_peak';
    %     cfg.feature_selection.n_vox = [1 5 10 20:5000];

% Using option 'none' and doing only high-level RFE: works
%     cfg.feature_selection.nested_n_vox = 'none'; % checked: works

% Providing nested_n_vox seems to work (but not 100% sure)
%     cfg.feature_selection.nested_n_vox = [1:20]; % checked: seems to work

% Using percentage: works
%     cfg.feature_selection.n_vox = [0.00001 0.1 0.2 0.5 0.9 1]; % checked: works
%     cfg.feature_selection.nested_n_vox = [0.001 0.01:0.01:0.9]; % checked: works
    
% reversed order and mixing: works
%     cfg.feature_selection.n_vox = [20:5000 10 2 1];
%     cfg.feature_selection.nested_n_vox = [0.9 0.8 0.7 0.1];

    results = decoding(cfg);
    
    % test case where length(n_vox) is 1
    
end

if tests.fs_multilevel
    
    clear cfg M
    cfg = defaults;
    cfg.analysis = 'roi';
    cfg.results.filestart = 'roi_makedesigncv_fs_multilevel';
    cfg.results.dir = fullfile(fdir,'results');
    cfg.files.mask = {fullfile(fdir,'SPM_files','roi','mt_both.img'),fullfile(fdir,'SPM_files','roi','v1.img'),fullfile(fdir,'SPM_files','roi','m1_left.img')};
    cfg.verbose = 2;
    cfg.results.overwrite = 1;
    cfg.plot_design = 0;
    cfg.decoding.method = 'classification_kernel';
    cfg.results.write = 2;
    cfg.results.output = {'accuracy_minus_chance','AUC_minus_chance','SVM_weights','SVM_weights_plusbias'};
    
    cfg.feature_selection.feature_selection.method = 'filter';
    cfg.feature_selection.feature_selection.filter = 'external';
    cfg.feature_selection.feature_selection.external_fname = cfg.files.name(1:8);
    cfg.feature_selection.feature_selection.n_vox = [0.5 0.6 0.7];
    
    cfg.feature_selection.method = 'embedded';
    cfg.feature_selection.embedded = 'RFE';
    cfg.feature_selection.direction = 'backward';
    cfg.feature_selection.n_vox = [0.5 0.6 0.7 0.8 0.9 1.0];
    cfg.feature_selection.nested_n_vox = 'automatic';
    
    results = decoding(cfg);
    
    % TODO: create simulated data with 200 voxels where an effect is present in 100 voxels and of
    % those voxels, there is a maximal weight on 10 voxels. Check if
    % decoding_feature_selection provides the correct indices
    
end

% regression
% parameter selection
% feature selection
% feature transformation

% possible sources of problems:
% (1) methods not compatible with kernel approach (check IN feature_selection,
%   IN parameter_selection, scaling and data_transformation)
% (2) some transformation of data happens that later does not pass this
%   transformation to current_data in decoding_transform_results
%  HAPPENS IN:
%   decoding_feature_transformation with across option
%   irrelevant for parameter selection
%   feature selection
%   scaling
%   
%
% (3) scaling might be wrong or not working within feature_selection,
%   parameter_selection, and feature_transformation
% (4) Probably not possible to combine feature_transformation with
%   feature_selection
% (5) Skip training option may give false results when many of the above are switched on
% (6) Skip feature selection might not be working


% SNIPPET

% try, mkdir(fullfile(fdir,'reference',cfg.results.filestart)), end
% sourcefiles = spm_select('list',fullfile(fdir,'results'),['^' cfg.results.filestart '.*\.(mat|img|hdr)']);
% for i = 1:size(sourcefiles,1)
% copyfile(fullfile(fdir,'results',sourcefiles(i,:)),fullfile(fdir,'reference',cfg.results.filestart,sourcefiles(i,:)))
% end