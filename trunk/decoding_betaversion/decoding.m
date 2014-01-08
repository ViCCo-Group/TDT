% function [results, cfg, passed_data] = decoding(cfg, passed_data)
%
% Decoding Toolbox, Version: 2.6 beta, by Martin Hebart & Kai Goergen
%
% This is the main function of the decoding toolbox which links to all
% subfunctions performed for brain image decoding. This toolbox is capable
% of running several different brain image decoding analyses (searchlight
% decoding, region of interest (ROI) decoding, and wholebrain decoding).
% Several commonly used methods are implemented, including classification,
% regression, and correlation.
% The toolbox has several subfunctions to which new methods can easily be
% appended for individual adjustments (see tutorial for details).
%
% To get started, type "help decoding_example" and run that function
% to perform a standard decoding analysis (searchlight, ROI, or wholebrain)
% on your specified data.
%
% REQUIRED INPUT:
%   cfg: Structure containing all necessary configuration information
%       Required fields:
%           files: Information about the input files.
%               cfg.files must contain
%           files.name: Full path to each input file
%           files.descr: (optional) description of each file (e.g. the SPM
%               regressor name)
%
%           design: Design matrix with entries label, train, test, and set
%               (see folder 'design' for example functions on how to
%               generate a design and the necessary structure).
%           design.train: n_files x n_steps matrix, specifying the files
%               used as training data for each decoding step (e.g. run)
%           design.test: n_files x n_steps matrix, specifying the files
%               used as test data for each decoding step (e.g. run)
%           design.label: n_files x n_steps matrix, specifying the labels
%               of each file for each decoding step (e.g. run)
%           design.set: 1 x n vector, describing the set number of each
%               step. The set number can also be used to save results of each
%               decoding_step independently (see cfg.results.setwise).
%       Alternatively, you can create the design in this function by
%       providing the following field:
%           design.function: string named after the design creation
%               function that should be used (e.g. 'make_design_cv'). Check
%               the folder 'design' for all options.
%
% PROGRESS DISPLAY:
%       cfg.plot_selected_voxels: if positive, plots searchlight in 3d.
%           For many ROIs (as is the case for searchlight analyses), this
%           slows down decoding ENORMOUSLY if every step is plotted, but
%           looks nice and might be helpful for bug-tracking.
%           Any number n means:
%               1: plot every step,
%               2: every second step, 100: every hundredth step...
%           Default: 0 (no plotting)
%       cfg.fighandles.plot_selected_voxels (optional): Figure handle to
%           plot selected voxels (updated in background)
%       cfg.display_progress.string: Can contain any string that will be
%           shown in front of the progress display (e.g. 'Bin2/8')
%
% DISPLAY:
%   cfg.plot_design = 1 (default); will plot your design. 
%       See decoding_defaults for possible values. 
%   cfg.fighandles.plot_design (optional): Figure handle to plot design 
%
% OUTPUT:
%   results: 1 x n structure array, containing the decoding results of each
%       of the n requested outputs (see. cfg.results.output)
%       Fields of results:
%           output: contains the results of the decoding analysis (e.g. all
%               searchlight analyses or all ROI analyses)
%           mask_index: contains the brain mask indices of all masks in
%               case they are needed again.
%   cfg: returns the configuration file that was used in the decoding.
%   passed_data: all brain imaging data is necessary to pass to decoding.m
%        to perform another analyses using the same data.
%
%
% All other input is provided in decoding_defaults unless changed.
% The most important of these input fields are:
%   cfg.analysis: Determines the type of analysis that is performed
%       ('searchlight', 'ROI', or 'wholebrain')
%   cfg.decoding.method: method of decoding ('classification', 'regression',
%       or other [default = 'classification']
%   cfg.decoding.software: Software used for decoding [default = 'libsvm']
%   cfg.decoding.train.classification.model_parameters: Model parameters
%       that the external software needs for training [set for libsvm classification]
%   cfg.decoding.test.classification.model_parameters: Model parameter that the external
%       software needs for testing [default = '']
%   cfg.results.write: Should results be written to hard disk [default = 1]
%   cfg.results.output: 1xn cell array specifying which output should be
%       generated, with possible fields specified in function
%       decoding_transform_results.m  [default = {'accuracy'}]
%   cfg.results.dir: Output directory [default = fullfile(pwd,'decoding_results')]
%   cfg.software: Software used to access images and files [default = 'SPM8']
%
% If searchlight analysis is selected, often the following parameters want
% to be set manually:
%   cfg.searchlight.unit: searchlight unit ('voxels' or 'mm') [default = 'voxels']
%   cfg.searchlight.radius: searchlight radius [default = 4]
%   cfg.searchlight.spherical: should the searchlight be spherical, i.e. 
%       should we correct for a non-isotropic voxel [default = 0]
%
% Other optional input includes:
%   cfg.scale: Perform scaling on data (may improve decoding performance)
%       See function 'decoding_scale_data' for details
%   cfg.parameter_selection: Optimize parameters for decoding in nested CV
%       See function 'decoding_parameter_selection' for details
%   cfg.feature_selection: Select most important features (voxels) for
%       decoding. See function 'decoding_feature_selection' for details
%   cfg.searchlight.subset: if you want to execute only a subset of
%       searchlights, you can either enter an Nx1 vector where each value of
%       n corresponds to the index within the searchlight mask is executed
%       (not the voxel index of the whole volume!), or you can enter an
%       Nx3 matrix corresponding to the XYZ coordinates of the volume
%   cfg.decoding.kernel.function: Kernel function passed, (default linear: @(X,Y) X*Y')
%       Will only be used, if cfg.design.method ends on "_kernel"
%   cfg.decoding.kernel.pass_vectors: If 1, the original data will be passed 
%       in addition to the kernel as data_train.vectors/data_test.vectors
%   cfg.results.overwrite: Overwrite existing result file(s) [default = 0]
%   cfg.results.setwise: Save results of each set separately [default = 0]
%   cfg.results.filestart: Manually define start of output filename [default: 'res']
%   cfg.sn: Provide subject number for status messages
%   cfg.verbose: How much output should be printed to the screen
%       (0 = minimum, 1 = normal, 2 = all) [default = 1]
%   cfg.testmode: Test mode, only the first decoding step (e.g. the first
%       searchlight) will be calculated
%
% Explanation of important variables:
%   n_steps: Number of decoding steps, e.g. cross-validation iterations.
%       Essentially the number of times a train/test cycle is performed to
%       achieve one results.
%   n_decodings: Number of decoding analyses that are performed, e.g.
%       number of ROIs or number of searchlight voxels.
%   n_sets: Number of decoding sets which are performed. Several decodings
%       with different outputs may be performed interleaved (e.g. when
%       doing cross-classification with different test data in each set).
%       These could of course be called in different analyses, but it saves
%       time to do them all together.
%
%
% PASSING DATA (optional):
% If you pass passed_data, then these will be
% taken instead of reading both from files. Some checks are done to
% assure that the data fits to the filenames.
%
%   passed_data: struct with all data that is necessary to do the decodings
%                as provided by decoding_load_data.
%       Required fields:
%       .data: nSamples x nVoxels matrix of data that is used for decoding.
%              This is not all data from the data files, but only the data
%              that corresponds to the voxels that are selected in
%              .mask_index.
%       .mask_index: indices of those voxels that were selected by the
%                    mask minus those that are NaN in the input data. When
%                    spatial information is not important, a  vector of 
%                    1:nVoxels is sufficient.
%                    These are only the voxels of the input data that  were 
%                    masked, NOT ROI masks. See .masks.mask_data{} below 
%                    on how to pass ROI masks.
%       .files: Contains file information as in cfg.files, especially
%               filenames of datafiles (.name) and mask(s) (.mask) as cell
%               of strings
%       .hdr: a header from either a mask or a data file (if
%             cfg.files.mask{1} == 'all voxels'). '' is ok if no hdr is
%             needed for writing results.
%       .dim: 1x3 vector containing the dimension of original
%             dimensionality of the data.
%       .voxelsize: voxelsize in mm (nan, if voxelsize could not be
%                   calculated)
%       Optional fields (passed_data):
%       .masks.mask_data{}: each cell contains one binary mask of the same 
%                           size as the original images containing the mask 
%                           specified in .files.mask{}. This input is 
%                           optional for passed_data. Remark: mask_data
%                           does not contain the indices as mask_index, but
%                           the same data as loaded from a maskfile.


% TODO: for further slight speed-up, replace the repeating strcmpi's with
% fixed values.
% TODO: add check to basic checks that chosen software can perform
%   classification, regression or correlation (see also next)
% TODO: better: check that current software can deliver the requested
%   output

% HISTORY
% 2014-07-01 Martin
%   Changed cfg.files.step to cfg.files.chunk, because steps (i.e. decoding
%   iterations, e.g. cross-validation steps) can be different from chunks
%   (i.e. data that should be kept together when cross-validation is
%   performed)
% 2013-09-05 Kai
%   Added passed_data.masks.mask_data{} to provide ROI data.
% 2013-09-05 Kai
%   Changed Kernel passing, now: data_train.kernel/data_test.kernel.
%   Pervious version had too much potential for confusion. 
%   Original data vectors can be passed additionally using 
%   cfg.decoding.kernel.pass_vectors.
% 2013-04-23 Kai
%   Rewrote Kernel related stuff
% 2013-04-22 Martin
%   Added possibility to use kernels
% 2013-04-16 Kai
%   Added cfg.files in help description
% 2013-04-14 Kai
%   Separated i_decoding into i_decoding and curr_decoding. Detailed
%   explanation what is what below.

%% Main start
function [results, cfg, passed_data] = decoding(cfg, passed_data)

%% Prepare decoding analysis

cfg = decoding_defaults(cfg); % set defaults
cfg.parameter_selection = decoding_defaults(cfg.parameter_selection);
cfg.feature_selection = decoding_defaults(cfg.feature_selection);

cfg.progress.starttime = datestr(now);

dispv(1,'Preparing analysis: ''%s''',cfg.analysis)

global verbose % MH: don't worry, Kai, this is the only case where global is better than passing!! ;)
global reports % and this is the second only case (there actually is a third somewhere else)...
verbose = cfg.verbose;
reports = []; % init

% Display version
ver = [mfilename ', Martin Hebart & Kai Goergen, v2014/01/07 2.6 beta'];
cfg.info.ver = ver;
dispv(1,ver)

%% try show design to user and save to result dir
% plot design if required
try
    if cfg.plot_design == 1 % plot + save fig, save hdl
        cfg.fighandles.plot_design = plot_design(cfg);
        if cfg.results.write
            if ~isdir(cfg.results.dir), mkdir(cfg.results.dir), end
            save_fig(fullfile(cfg.results.dir, 'design'), cfg); 
        end
        drawnow;
    elseif cfg.plot_design == 2 % only save fig, plot invisible, dont save hdl
        fighdl = plot_design(cfg, 0); 
        if cfg.results.write
            save_fig(fullfile(cfg.results.dir, 'design'), cfg); 
        end
        close(fighdl); clear fighdl
    end
catch
    warningv('DECODING:PlotDesignFailed', 'Failed to plot design')
end
% show design as text
try display_design(cfg); catch, warningv('DECODING:PrintDesignFailed', 'Failed to print design to screen'), end

%% Basic checks
[cfg, n_files, n_steps] = decoding_basic_checks(cfg,nargout);

%% open file to write all filenames that we load
if cfg.results.write == 1
    % Open filename to save details for each decoding step
    inputfilenames_fname = [cfg.results.filestart '_' cfg.results.output{1} '_filedetails.txt'];
    inputfilenames_fpath = fullfile(cfg.results.dir,inputfilenames_fname);
    dispv(1,'Writing input filenames for each decoding iteration to %s', inputfilenames_fpath)
    inputfilenames_fid = fopen(inputfilenames_fpath, 'wt');
else
    inputfilenames_fid = '';
end

%% Load masked data

if ~exist('passed_data', 'var')
    % load data
    [passed_data, cfg] = decoding_load_data(cfg);
else
    % check that passed_data fits to cfg, otherwise load data from files
    [passed_data, cfg] = decoding_load_data(cfg, passed_data);
end

% unpack all fields from passed_data to shorten names in this function
data = passed_data.data;
mask_index = passed_data.mask_index;
sz = passed_data.dim;

%% Prepare the decoding

% Scale all data in advance if requested
if strcmpi(cfg.scale.estimation,'all')
    dispv(1,'Scaling all data, using scaling method %s',cfg.scale.method)
    data = decoding_scale_data(cfg,data);
end

% Get number of decodings for searchlight and number of ROIs for ROI (and 1 for wholebrain)
[n_decodings,decoding_subindex] = get_n_decodings(cfg,mask_index,sz);

% Initialize results vectors
n_outputs = length(cfg.results.output);
n_sets = length(unique(cfg.design.set));
n_cond = length(unique(cfg.design.label(cfg.design.train | cfg.design.test))); % all used labels
results = {};

% Set kernel method if used
use_kernel = cfg.decoding.use_kernel;

% Prepare searchlight template (if needed, sl_template will be empty for other methods)
[cfg,sl_template] = decoding_prepare_searchlight(cfg);

% Save number of conditions (e.g. to get the chancelevel later)
results.n_cond = n_cond;
% Save mask_index
results.mask_index = mask_index;
% Save all mask indices separately if several masks are provided
if isfield(passed_data,'mask_index_separate')
    results.mask_index_separate = passed_data.mask_index_separate;
end
% Save subindices if they are provided
if isfield(cfg.searchlight,'subset')
    results.decoding_subindex = decoding_subindex;
end

for i_output = 1:n_outputs
    outname = char(cfg.results.output{i_output}); % char necessary to get name of objects
    
    if strcmp(cfg.analysis, 'searchlight')
        % use number of voxels to allocate space independent of number of
        % decodings (because cfg.searchlight.subset allows to choose fewer
        % voxels, but we want in the end an image that has the same
        % dimension as the original image
        n_dim = length(mask_index);  % n_voxel = length(mask_index)
    else
        % otherwise, get as many output dimensions as decodings (no subset
        % selection possible at the moment)
        n_dim = n_decodings;
    end

    % Preallocation
    results.(outname).output = zeros(n_dim,1);

    if cfg.results.setwise
        for i_set = 1:n_sets
            results.(outname).set(i_set).output = zeros(n_dim,1);
        end
    end
    clear n_dim
end


%% PERFORM Decoding Analysis

dispv(1,'Starting decoding...')

% Save start time (for time estimate)
start_time = now;

% Preloading
msg_length = [];

% Warn if test mode
if cfg.testmode
    warningv('DECODING:testmode','TEST MODE: Only one decoding step is calculated!');
    n_decodings = 1;
end

% Report files
report_files(cfg,n_steps,inputfilenames_fid);

% General remark how final accuracy values are calculated before we start
if cfg.verbose == 1
    dispv(1, 'All samples in final estimate (e.g. accuracy) weighted equally (see README.txt)...')
elseif cfg.verbose == 2
    dispv(2, sprintf(['\n', ...
    'General remark: The final accuracy (and most other measures) for each voxel is calculated by weighting all test examples equally.\n', ...
    'This means that if e.g. one decoding step contains 2 test examples, and another contains 5, the average of all 7 will be taken.\n', ...
    'If you want to weight all decoding steps equally, please use cfg.results.setwise=1 and cfg.design.set = 1:length(cfg.design.set) and average over the resulting output images']))
end

lasttime = now; % for updating figures

% Start
for i_decoding = 1:n_decodings % e.g. voxels for searchlight (decoding_subindex in most cases is 1:n_decodings)

    curr_decoding = decoding_subindex(i_decoding); % if cfg.searchlight.subset wasn't called, then curr_decoding is identical to i_decoding

    % Display status info (i.e. how far is the analysis?)
    if verbose, [msg_length] = display_progress(cfg,i_decoding,n_decodings,start_time,msg_length); end
    % update display every 500ms
    if cfg.plot_design == 1 && (now - lasttime)*24*60*60 > .5
        drawnow; lasttime = now;
    end
    
    % Get the current maskindices (e.g. of the current searchlight or of the current ROI)
    indexindex = get_ind(cfg,mask_index,curr_decoding,sz,sl_template,passed_data);

    if isfield(cfg, 'plot_selected_voxels') && cfg.plot_selected_voxels > 0 && (cfg.plot_selected_voxels == 1 || mod(i_decoding, cfg.plot_selected_voxels) == 1 || i_decoding == n_decodings)
        if ~isfield(cfg, 'fighandles') || ~isfield(cfg.fighandles, 'plot_selected_voxels')
            cfg.fighandles.plot_selected_voxels = figure('name', 'Online ROI');
        end
        try
            % plot searchlight with brain projection
            cfg.fighandles.plot_selected_voxels = plot_selected_voxels(mask_index(indexindex), sz, data(1, :), mask_index, [], cfg.fighandles.plot_selected_voxels);
        catch
            warningv('DECODING:PlotSelectedVoxelsFailed', 'plot_selected_voxels failed');
        end
    end

    % init variables that are used to check whether the previous training
    % set equals the current decoding (used below to skip these trainings)
    previous_i_train = []; % init
    previous_trainlabels = []; % init
    previous_fs_data = []; % init
    % clear model variable from the previous decoding
    clear model;
    
    if use_kernel
        % if all decoding steps use the same data, calculating the
        % kernel only once and then passing the training and test
        % part of the kernel is in most cases faster than calculating
        % a kernel in every step. As default, a linear kernel is used
        % (@(X,Y) X*Y' ; see decoding_defaults);
        kernel = cfg.decoding.kernel.function(data(:,indexindex),data(:,indexindex));
    end

    % Loop over design columns (e.g. cross-validation runs)
    for i_step = 1:n_steps
        
        % Get indices for training
        i_train = find(cfg.design.train(:, i_step) > 0);
        % Get indices for testing
        i_test = find(cfg.design.test(:, i_step) > 0);

        % Get data for training & testing at current position
        if use_kernel
            % in each step, set the kernel-submatrix containing the
            % training entries as training data
            data_train.kernel = kernel(i_train, i_train);
            % get submatrix with kernel entries between test and train
            % examples from the kernel -- this is the way a kernel is
            % used. No leak between training data and the test data.
            data_test.kernel = kernel(i_test, i_train);
            % additionally pass original data vectors, if selected
            if cfg.decoding.kernel.pass_vectors
                data_train.vectors = data(i_train, indexindex);
                data_test.vectors = data(i_test, indexindex);
            end
        else
            % no kernel used, set the training vectors as training data
            data_train = data(i_train, indexindex);
            data_test = data(i_test, indexindex);
        end
  
        labels_train = cfg.design.label(i_train, i_step);
        labels_test = cfg.design.label(i_test, i_step);

        % Skip feature selection and training if training set & training
        % labels are identical to previous iteration (saves time)
        % never skip on first decoding step
        skip_training = i_step~=1 & isequal(previous_i_train, i_train) & isequal(previous_trainlabels, labels_train);
                
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Parameter selection (e.g. optimize C for SVM) %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if ~strcmpi(cfg.parameter_selection.method,'none') && ~skip_training
            cfg = decoding_parameter_selection(cfg,data_train,i_train);
        end

        %%%%%%%%%%%%%%%%%%%%%
        % Feature selection %
        %%%%%%%%%%%%%%%%%%%%%

        if ~strcmpi(cfg.feature_selection.method,'none')
            if ~skip_training
                % Step 1: Pack
                [fs_data, skip_feature_selection] = pack_fs_data(cfg,i_train,i_test,i_step,data,indexindex,mask_index,previous_fs_data);
                % Step 2: Perform feature selection method
                if ~skip_feature_selection
                    [fs_index,fs_results,previous_fs_data] = decoding_feature_selection(cfg,fs_data);
                end
                results.feature_selection(i_decoding).n_vox_selected(i_step) = fs_results.n_vox_selected;
                results.feature_selection(i_decoding).n_vox_steps{i_step} = fs_results.n_vox_steps;
                results.feature_selection(i_decoding).output{i_step} = fs_results.output;
                results.feature_selection(i_decoding).curr_decoding = curr_decoding;
            end
            % Step 3: Select features (unless 'useall' is selected which would be double dipping)
            if ~cfg.feature_selection.useall
                data_train = data_train(:,fs_index);
                data_test = data_test(:,fs_index);
            end
        end


        %%%%%%%%%%%%%%%%%%%%
        % PERFORM DECODING %
        %%%%%%%%%%%%%%%%%%%%

        %   TRAIN DATA    %
        %%%%%%%%%%%%%%%%%%%

        % Do scaling on all used data if requested
        % TODO: include variable set here and rename to scaling within set

        % Do scaling on training set if requested
        if ~skip_training && strcmpi(cfg.scale.estimation,'across')
            if i_decoding == 1 && i_step == 1, dispv(1,'Using scaling estimation type: %s',cfg.scale.estimation), end
            [data_train,scaleparams] = decoding_scale_data(cfg,data_train);
        end

        % Development Remark: Additional KERNEL calculation might go here, 
        % if feature selection or scaling on training data is used. Passing
        % a kernel might still be faster for certain methods/more
        % convinient if nothing needs to be changed.
        
        if skip_training
            model(i_step) = model(i_step-1);
        else
            % e.g. when software is libsvm, then:
            % model(i_step) = libsvm_train(labels_train,data_train,cfg);
            model(i_step) = cfg.decoding.fhandle_train(labels_train,data_train,cfg);
        end

        % store current training indices & training labels to check if they
        % are equal in the next decoding step
        previous_i_train = cfg.design.train(:,i_step); % update for next step
        previous_trainlabels = labels_train;

        %    TEST DATA    %
        %%%%%%%%%%%%%%%%%%%

        % TODO: introduce column scaling (mean removal, zscore, etc.)

        % Do scaling on test data if requested
        if strcmpi(cfg.scale.estimation,'across')
            data_test = decoding_scale_data(cfg,data_test,scaleparams);
        end

        % Test Estimated Model
        % e.g. when software is libsvm, then:
        % decoding_out(i_step) = libsvm_test(labels_test,data_test,cfg,model(i_step));
        decoding_out(i_step) = cfg.decoding.fhandle_test(labels_test,data_test,cfg,model(i_step));

        % TODO: decoding_out should be made extendable across runs
        % (sometimes you want to do things across runs)
        % maybe introduce another function and use all models?

    end % i_step

    %%%%%%%%%%%%%%%%%%%
    % Generate output %
    results = decoding_generate_output(cfg,results,decoding_out,i_decoding,curr_decoding,model);

end % End decoding iterations (e.g. voxel)

% done
dispv(1,'All %s steps finished successfully!',cfg.analysis)

%% Save and write results

% TODO: when results are not written, all results are still returned as
% indices, not volumes. Is that desirable?
if cfg.results.write
    % Close txt files to store filenames
    dispv(1,['Closing file to store filenames ' inputfilenames_fname])
    fclose(inputfilenames_fid);
    dispv(1,'done!')

    % Write results
    dispv(1,'Writing results to disk...')
    decoding_write_results(cfg,results)
    dispv(1,'done!')
end

% save end time
cfg.progress.endtime = datestr(now);

% Save cfg
if cfg.results.write
    cfg_fname = [cfg.results.filestart '_' cfg.results.output{1} '_cfg.mat'];
    cfg_fpath = fullfile(cfg.results.dir,cfg_fname);
    dispv(1,['Saving cfg to ' cfg_fname])
    save(cfg_fpath, 'cfg');

    % Create copy of txt files and cfg for each decoding output (e.g. 'accuracy', 'AUC', ...)
    if numel(cfg.results.output)>1
        for i_out = 2:numel(cfg.results.output)
            tmp = copyfile(inputfilenames_fname,[cfg.results.filestart '_' cfg.results.output{i_out} '_filedetails.txt']); %#ok<NASGU>
            tmp = copyfile(cfg_fname,[cfg.results.filestart '_' cfg.results.output{i_out} '_cfg.mat']); %#ok<NASGU>
        end
    end
end
    
%% plot & save design again at the end (to show that job is finished)
% Endtime shows user that job is over
try
    if cfg.plot_design
        plot_design(cfg,1); 
        if cfg.results.write
            save_fig(fullfile(cfg.results.dir, 'design'), cfg);
        end
    end
catch %#ok<*CTCH>
    warningv('DECODING:PlotDesignFailed', 'Failed to plot design')
end

%% END OF MAIN FUNCTION


%% Subfunctions


%% Pack feature selection data (moved to subfunction for better readability)
function [fs_data,skip_feature_selection] = pack_fs_data(cfg,i_train,i_test,i_step,data,indexindex,mask_index,previous_fs_data)

% Should feature selection be executed at all?
if strcmpi(cfg.feature_selection.method,'none') % Skip feature selection if method is 'none'
    fs_data = [];
    skip_feature_selection = 1;
    return
end

skip_feature_selection = 0; % init

% If requested load external data for feature selection (do only once!)
try
    fs_data.external = previous_fs_data.external;
catch
    for i = 1:length(cfg.feature_selection.external_fname)
        ranks_hdr = read_header(cfg.software,cfg.feature_selection.external_fname{i});
        if any(ranks_hdr.dim(1:3) ~= cfg.datainfo.dim)
            error('Size of external image(s) for feature selection does not match size of original images!');
        end
        ranks_image = read_image(cfg.software,ranks_hdr); % get image
        fs_data.external.ranks_image{i} = ranks_image; % add image to fs_data
    end
end

% Pack values in fs_data
fs_data.i_train = i_train;
if cfg.feature_selection.useall, fs_data.i_train = i_train | i_test; end
fs_data.labels_train = cfg.design.label(i_train, i_step);

if i_step ~= 1
    % Also skip when data which the selection is based on is identical to the previous step
    if isequal(previous_fs_data.i_train, fs_data.i_train) && isequal(previous_fs_data.labels_train, fs_data.labels_train)
        skip_feature_selection = 1;
    end
    % with the exception (when multiple external images are used the data may be identical, but the selection criteria can change)
    if strcmpi(cfg.feature_selection.method,'filter') && strcmpi(cfg.feature_selection.filter,'external')
        if length(cfg.feature_selection.external_fname)>1
        skip_feature_selection = 0;
        % if however only one external image is used (which is fulfilled by the elseif) and all data is used, then feature selection 
        % can be skipped, too (because in that case all selection steps are identical)
        elseif cfg.feature_selection.useall
            skip_feature_selection = 1;
        end
    end
end
    
if skip_feature_selection, return, end

% Continue with assigning values
fs_data.vectors_train = data(fs_data.i_train, indexindex);
fs_data.i_step = i_step;
fs_data.external.position_index = mask_index(indexindex); % absolute position of currently selected voxels in decoding (for external masks)

if cfg.feature_selection.useall == 1
    warningv('PACK_FS_DATA:Nonindependence',['Training and test data are both used for feature selection. ',...
    'Feature selection results will not be applied to main decoding, but can be used for illustrative purposes!'])
end
