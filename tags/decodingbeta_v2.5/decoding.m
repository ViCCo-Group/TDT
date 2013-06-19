% function [results, cfg, passed_data] = decoding(cfg, passed_data)
%
% Decoding Toolbox, Version: 2.5 beta, by Martin Hebart & Kai Goergen
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
% REMARK: We are currently working on implementing FEATURE SELECTION.
% This is currently in an experimental stage.
%
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
%   cfg.searchlight.spherical: should the searchlight be spherical in real
%       space or in voxel space (for real space, spherical = 1) [default = 0]
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
%   cfg.results.overwrite: Should existing results be overwritten [default = 0]
%   cfg.results.setwise: Should results of each set be returned separately [default = 0]
%   cfg.results.filestart: Manually define start of output filename [default: 'res']
%   cfg.sn: Provide subject number for status messages
%   cfg.verbose: How much output should be printed to the screen
%       (0 = minimum, 1 = normal, 2 = all) [default = 1]
%   cfg.testmode: Test mode, only the first decoding step (e.g. the first
%       searchlight) will be calculated
%
% Explanation of important variables:
%   n_steps: Number of decoding steps, e.g. cross-validation steps.
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
%                    mask minus those that are NaN in the input data.
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


% TODO: add check to basic checks that chosen software can perform
%   classification, regression or correlation (see also next)
% TODO: better: check that current software can deliver the requested
%   output

% HISTORY
% 2013-04-23 Kai
%   Rewrote Kernel related stuff
% 2013-04-22 Martin
%   Added possibility to use kernels
% 2013-04-16 Kai
%   Added cfg.files in help description
%
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
global reports % and this is the second only case...
verbose = cfg.verbose;
reports = []; % init

% Display version
ver = [mfilename ', Martin Hebart & Kai Goergen, v2013/06/19 2.5 beta'];
cfg.info.ver = ver;
dispv(1,ver)

%% try show design to user and save to result dir
% plot design if required
try
    if cfg.plot_design == 1 % plot + save fig, save hdl
        cfg.fighandles.plot_design = plot_design(cfg); save_fig(fullfile(cfg.results.dir, 'design'), cfg); drawnow;
    elseif cfg.plot_design == 2 % only save fig, plot invisible, dont save hdl
        fighdl = plot_design(cfg, 0); save_fig(fullfile(cfg.results.dir, 'design'), cfg); close(fighdl); clear fighdl
    end
catch
    warningv('DECODING:PlotDesignFailed', 'Failed to plot design')
end
% show design as text
try display_design(cfg); catch, warningv('DECODING:PrintDesignFailed', 'Failed to print design to screen'), end

%% Basic checks
[cfg, n_files, n_steps] = basic_checks(cfg,nargout);

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
    outname = cfg.results.output{i_output};
    
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

% Check if kernel method is used
use_kernel = ~isempty(strfind(cfg.decoding.method, '_kernel'));
cfg.decoding.use_kernel = use_kernel;
if use_kernel
    dispv(1, 'Using a "_kernel" decoding method.')
    dispv(2, sprintf('\nThis means that the kernel is only calculated once for each voxel/ROI,\nand then a submatrix of the kernel is passed to training and test methods \ninstead of the data. This might increase speed, but does not allow all\nparameters to be selected'))
else
    dispv(2, 'Using normal method')    
end

lasttime = now; % for updating figures

% Start
for i_decoding = 1:n_decodings % e.g. voxels for searchlight (decoding_subindex in most cases is 1:n_decodings)

    curr_decoding = decoding_subindex(i_decoding);

    % Display status info (i.e. how far is the analysis?)
    if verbose, [msg_length] = display_progress(cfg,i_decoding,n_decodings,start_time,msg_length); end
    % update display every 500ms
    if cfg.plot_design == 1 && (now - lasttime)*24*60*60 > .5
        drawnow; lasttime = now;
    end
    
    % Get the current maskindices (e.g. of the current searchlight or of the current ROI)
    indexindex = get_ind(cfg,mask_index,curr_decoding,sz,sl_template);

    if isfield(cfg, 'plot_selected_voxels') && cfg.plot_selected_voxels > 0 && (cfg.plot_selected_voxels == 1 || mod(i_decoding, cfg.plot_selected_voxels) == 1 || i_decoding == n_decodings)
        if ~isfield(cfg, 'fighandles') || ~isfield(cfg.fighandles, 'plot_selected_voxels')
            cfg.fighandles.plot_selected_voxels = figure('name', 'Online ROI');
        end
        try
            % plot searchlight with brain projection
            plot_selected_voxels(mask_index(indexindex), sz, data(1, :), mask_index, [], cfg.fighandles.plot_selected_voxels);
        catch
            warningv('DECODING:PlotSelectedVoxelsFailed', 'plot_selected_voxels failed');
        end
    end

    % init variables that are used to check whether the previous training
    % set equals the current decoding (used below to skip these trainings)
    previous_i_train = []; % init
    previous_trainlabels = []; % init
    % clear model variable from the previous decoding
    clear model;
    
    if use_kernel
        % if all decoding steps use the same data, calculating the
        % kernel only once and then passing the training and test
        % part of the kernel is in most cases faster than calculating
        % a kernel in every step. As default, a linear kernel used
        % (@(X,Y) X*Y' ; see decoding_defaults);
        kernel = cfg.decoding.kernel.function(data(:,indexindex),data(:,indexindex));
    end
    
    % TODO: Get a better order of the decodings steps (i.e. reorder the
    % decoding step index i_step so that the same training is used in
    % successive steps)

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
            data_train = kernel(i_train, i_train);
            % get submatrix with kernel entries between test and train
            % examples from the kernel -- this is the way that a kernel is
            % used. No leak between training data and the test data.
            data_test = kernel(i_test, i_train);
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

        % TODO: feature selection should give vector of selected voxels as
        % output, then vectors_test can be adjusted later on
        if ~strcmpi(cfg.feature_selection.method,'none')
            if ~skip_training
                % pack
                if cfg.feature_selection.useall
                    fs_data.i_train = find(cfg.design.train(:, i_step) > 0 | cfg.design.test(:, i_step) > 0);
                else
                    fs_data.i_train = i_train;
                end
                fs_data.vectors_train = data(fs_data.i_train, indexindex);
                fs_data.labels_train = cfg.design.label(i_train, i_step);
                fs_data.i_step = i_step;
                fs_data.external.position_index = mask_index(indexindex); % absolute position of currently selected voxels in decoding (for external masks)
                [fs_index,fs_results,fs_data] = decoding_feature_selection(cfg,fs_data);
                if isfield(cfg.feature_selection,'useall') && cfg.feature_selection.useall
                    if i_step == 1
                        fs_results.curr_decoding = curr_decoding;
                        results.feature_selection(i_decoding) = fs_results;
                    end
                else
                    results.feature_selection(i_decoding).n_vox_selected(i_step) = fs_results.n_vox_selected;
                    results.feature_selection(i_decoding).curr_decoding = curr_decoding;
                end
            end
            data_train = data_train(:,fs_index);
            data_test = data_test(:,fs_index);
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

        if skip_training
            model(i_step) = model(i_step-1);
        else
            % e.g. when software is libsvm, then:
%             model(i_step) = libsvm_train(labels_train,data_train,cfg);
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
            if use_kernel, error('Cant use scaling method ''across'' for "_kernel" methods. It does not make sense, because a kernel must be calculated in this case in every step anyway (this is what the normal methods do)'), end
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
if ~cfg.results.write
    return
end

% Close txt files to store filenames
dispv(1,['Closing file to store filenames ' inputfilenames_fname])
fclose(inputfilenames_fid);
dispv(1,'done!')

% Write results
dispv(1,'Writing results to disk...')
decoding_write_results(cfg,results)
dispv(1,'done!')

% Save cfg
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

cfg.progress.endtime = datestr(now);

%% plot & save design again at the end (to show that job is finished
% Endtime shows user that job is over
try
    if cfg.plot_design
        plot_design(cfg,1); save_fig(fullfile(cfg.results.dir, 'design'), cfg);
    end
catch %#ok<*CTCH>
    warningv('DECODING:PlotDesignFailed', 'Failed to plot design')
end

%% Subfunctions

%%%%%%%%%%%%%%%%%%%%%
% Run basic checks  %
%%%%%%%%%%%%%%%%%%%%%
function [cfg, n_files, n_steps] = basic_checks(cfg,output_arguments)

% Display image access software that is used
dispv(1, 'Image access with: %s',cfg.software);

% File check here not necessary anymore.
% Moved the check to when a file function is used for the first time.
% - Kai
% check_software(cfg);

% TODO: make sure that the chosen program can perform
% the chosen algorithm (e.g. can libsvm perform SVR)

% check if design exists, and create if it doesn't
field_names = {'label','train','test','set'};
missing = [1 1 1 1];
for i_field = 1:length(field_names)
    if isfield(cfg.design,field_names{i_field})
        missing(i_field) = 0;
    end
end

if any(missing) % if only some or no fields for a design exist
    if isfield(cfg.design,'function') % create design with passed method
        if ~all(missing) % throw warning if some fields exist, but others not
            warningv('BASIC_CHECKS:MissingFieldsInDesignReplaced','Some fields for design matrix were missing. Design was created anew, using the method %s.',cfg.design.function)
        end
        fhandle = str2func(cfg.design);
        cfg.design = feval(fhandle,cfg);
    else % throw error if no method has been passed and design incomplete
        error('Design is missing or incomplete. Either create design in advance or pass method to create design (see ''help decoding'')');
    end
end

% Set function handle for classifier here (saves time to do only once)
if ~isfield(cfg.decoding,'fhandle_train') && ~isfield(cfg.decoding,'fhandle_test')
        cfg.decoding.fhandle_train = str2func([cfg.decoding.software '_train']); % this format allows variable input
        cfg.decoding.fhandle_test = str2func([cfg.decoding.software '_test']); % this format allows variable input
else
    % Run quick test that method is the same for both:
    if ~strcmpi(func2str(cfg.decoding.fhandle_train),[cfg.decoding.software '_train']) || ...
       ~strcmpi(func2str(cfg.decoding.fhandle_test),[cfg.decoding.software '_test'])
       error('Mismatch between cfg.decoding.software and cfg.decoding.fhandle_train / cfg.decoding.fhandle_test. Must match!') 
    end
end

% Set function handle for classifier in parameter_selection
if ~strcmpi(cfg.parameter_selection.method,'none') && (~isfield(cfg.parameter_selection.decoding,'fhandle_train') || ~isfield(cfg.parameter_selection.decoding,'fhandle_test'))
    cfg.parameter_selection.decoding.fhandle_train = str2func([cfg.parameter_selection.decoding.software '_train']); % this format allows variable input
    cfg.parameter_selection.decoding.fhandle_test = str2func([cfg.parameter_selection.decoding.software '_test']); % this format allows variable input
end

% Set function handle for classifier in feature_selection
if ~strcmpi(cfg.feature_selection.method,'none') && (~isfield(cfg.feature_selection.decoding,'fhandle_train') || ~isfield(cfg.feature_selection.decoding,'fhandle_test'))
    cfg.feature_selection.decoding.fhandle_train = str2func([cfg.feature_selection.decoding.software '_train']); % this format allows variable input
    cfg.feature_selection.decoding.fhandle_test = str2func([cfg.feature_selection.decoding.software '_test']); % this format allows variable input
end

% try the most simple decoding possible (only if libsvm is used)
if strcmpi(cfg.decoding.software,'libsvm')
    [working, libsvm_path] = check_libsvm(cfg);
    if ~working
        error('libsvm does not seem to work with the current parameters (Path: %s)', libsvm_path)
    else
        dispv(2, 'Checked that libsvm works with the current parameters')
        dispv(2, 'Using libsvm in: %s', libsvm_path)
    end
end

% Using a precomputed kernel doesn't work for scaling across
if ~isempty(strfind(cfg.decoding.method, '_kernel')) && strcmpi(cfg.scale.estimation,'across')
    error('Decoding method %s cannot be used together with scaling method %s',cfg.decoding.method,cfg.scale.estimation);
end

% Using feature selection in the main function with a kernel method doesn't make sense
if ~isempty(strfind(cfg.decoding.method, '_kernel')) && ~strcmpi(cfg.feature_selection.method,'none')
    newmethod = strrep(cfg.decoding.method,'_kernel','');
    str = sprintf(['Use of feature selection and decoding method ''%s'' in the main function makes processing slower. ',...
                   'Method is now reverted to ''%s''.'],cfg.decoding.method,newmethod);
    warningv('BASIC_CHECKS:KernelAndFeatureSelection',str)
    cfg.decoding.method = newmethod;
end

if ~strcmpi(cfg.feature_selection.method,'none')
    warningv('BASIC_CHECKS:FeatureSelectionIsTestmode','Feature selection has not been fully debugged. Running in test mode!')
end

[n_files, n_steps] = size(cfg.design.train);

dispv(1,'Performing %i decoding steps for %i files', n_steps, n_files)

% check that number of files = number of rows in cfg.design
if n_files ~= size(cfg.design.train, 1)
    error('Number of files in cfg.files (%i) does not correspond to number of rows in cfg.design.train', n_files, size(cfg.design.train, 1))
end

if n_files ~= size(cfg.design.test, 1)
    error('Number of files in cfg.files (%i) does not correspond to number of rows in cfg.design.test', n_files, size(cfg.design.train, 1))
end

if ~isequal(size(cfg.design.train), size(cfg.design.test))
    error('Size mismatch: ~isequal(size(cfg.design.train), size(cfg.design.test))')
end

problem = 0;
for i_step = 1:n_steps
    curr_train = cfg.design.train(:,i_step);
    curr_test = cfg.design.test(:,i_step);
    curr_label = cfg.design.label(:,i_step);
    if length(unique(curr_label(logical(curr_train)))) == 1
        error('Training data in decoding step %i contains only one label, but needs at least two.',i_step)
    end
    if length(unique(curr_label(logical(curr_test)))) == 1
        problem = problem+1;
    end
end
if problem && n_steps == 1
    warningv('BASIC_CHECKS:TestDataOnlyOneLabel',...
        ['Test data in %i steps contains only one label and there is only ',...
         'one decoding step. This might be a problem when using correlation, ',...
         'AUC, sensitivity, specificity and similar measures!'],problem)
end
    
if strcmpi(cfg.scale.method,'none') && ~strcmpi(cfg.scale.estimation,'none')
    warningv('BASIC_CHECKS:DisagreeingScalingMethodAndEstimation',['Scaling method is ''none'', but estimation type is ''' cfg.scale.estimation ''', changing type to ''none'''])
end

if ischar(cfg.results.output)
    cfg.results.output = num2cell(cfg.results.output,2);
end

% check if masks exist, and maybe correct it. Otherwise set it to "auto"

if isfield(cfg.files, 'mask')
    if ischar(cfg.files.mask)
        cfg.files.mask = num2cell(cfg.files.mask,2);
    end
else % mask does not exist, set it to auto
    dispv(1, 'No mask file detected, using all voxels')
    cfg.files.mask = {'all voxels'}; % will generate a mask later (using all voxels)
end

results_out_flag = output_arguments >= 1; % flag showing whether the results are returned from the function

if cfg.results.write == 0 && ~results_out_flag
    error('''Write results'' set to 0, but results are not returned either. Change ''write results'' to 1 or return results as output')
end

if strcmpi(cfg.parameter_selection.method,'none') && isfield(cfg.parameter_selection,'parameters')
    error('Field ''cfg.parameter_selection.parameters'' exists, but ''cfg.parameter_selection.method = ''none''!')
end

% Checking for independence of training and test data
if any(cfg.design.train(:) ~= 0 & cfg.design.test(:) ~=0)
    disp('Positions of Entries in Training- & Testset:')
    disp(cfg.design.train ~= 0 & cfg.design.test ~= 0)
    error('Trainingset & Testset are not independent! Some entries from the training set are also used in the testset! Please check!')
else
    dispv(2,'  Check for double entries in Training- & Testset: No double entries found.')
end

% Check if training data is balanced (test data does not matter)
check_imbalance(cfg);

if ischar(cfg.files.name)
    cfg.files.name = num2cell(cfg.files.name,2);
    warningv('BASIC_CHECKS:FileNamesStringNotCell','File names provided as string, not as cell matrix. Converting to cell...')
end

if length(cfg.files.name) ~= length(unique(cfg.files.name))
    warningv('BASIC_CHECKS:DoubleFilenameEntries','Double filename entries in cfg.files.name. No guarantee, that training and test sets are independent!!!')
else
    dispv(2,'  Check for double names in cfg.files.name: No double entries found.')
end

if ~strcmpi(cfg.scale.method,'none') && numel(cfg.scale.cutoff) ~= 2
    error('Wrong number of entries for field ''cfg.scale.cutoff''.')
end

if length(unique(cfg.design.set)) == 1
    cfg.results.setwise = 0;
end


if cfg.results.write

    dir_output = cfg.results.dir; % results directory
    if ~exist(dir_output, 'dir'), mkdir(dir_output); end

    n_outputs = length(cfg.results.output);
    if ~isfield(cfg.results,'resultsname')
        for i_output = 1:n_outputs
            outputname = cfg.results.output{i_output};
            cfg.results.resultsname(i_output) = { sprintf('%s_%s',cfg.results.filestart,outputname) };
        end
    end

    for i_output = 1:n_outputs

        % TODO: should we also introduce this check for each set if sets
        % are written?

        % Check if it is ok to overwrite existing files

        for ext = {'.img','.hdr'}
            output_fname = [fullfile(dir_output,cfg.results.resultsname{i_output}) ext{1}];
            if exist(output_fname,'file')
                if ~cfg.results.overwrite
                    error(['Resultfile %s already exists. Change filename or ',...
                        'set cfg.results.overwrite = 1'],output_fname)
                else
                    warningv('BASIC_CHECKS:OverwritingExistingResultsfile',sprintf('Resultfile %s already existed. Overwriting...',output_fname))
                end
            end

            % Check if it is possible to write
            temp = fopen(output_fname, 'w');
            fclose(temp);
            delete(output_fname);
        end
    end
end


%% CHECK subfunctions

% Check for unbalanced training data
function check_imbalance(cfg)
dispv(2, 'Checking for imbalances in cfg.design.train')
for decoding_step = 1:size(cfg.design.train, 2)
    curr_labels = cfg.design.label(:, decoding_step);
    curr_training_labels = curr_labels(cfg.design.train(:, decoding_step) == 1);
    unique_labels = unique(curr_training_labels);
    n_each_label = zeros(length(unique_labels),1);
    for label_ind = 1:length(unique_labels)
        n_each_label(label_ind) = sum(curr_training_labels == unique_labels(label_ind));
    end
    if any(diff(n_each_label) ~= 0)
        message_str = sprintf('Unbalanced training data detected in cfg.design.train(:, %i).', decoding_step);
        if isfield(cfg.design, 'unbalanced_data') && strcmp(cfg.design.unbalanced_data, 'ok')
            warningv('DECODING:CheckUnbalancedDataOk', [message_str, ' You decided this is ok, because cfg.design.unbalanced_data = ''ok''']);
        else
            error('DECODING:CheckUnbalancedDataOk', [message_str, ' If this is ok, set cfg.design.unbalanced_data = ''ok'''])
        end
    end
end

%% REPORT USED FILES

% This function prints file names for a certain decoding to the screen and
% writes them to a given file if requested

function report_files(cfg,n_steps,inputfilenames_fid)

if ~cfg.results.write
    inputfilenames_fid = ''; % this will prevent writing
end

% Find common string in all files to print this only once
fnames = char(cfg.files.name);
n_files = size(fnames,1);
n_str = size(fnames,2);
for i_str = 1:n_str
    str = strmatch(fnames(1,1:i_str),fnames(2:end,:));
    if length(str) ~= n_files-1
        n_match = i_str-1;
        break
    end
end
filestart = fnames(1,1:n_match);

for i_step = 1:n_steps

    % Get indices for training
    i_train = find(cfg.design.train(:, i_step) > 0);
    % Get indices for testing
    i_test = find(cfg.design.test(:, i_step) > 0);

    if isfield(cfg, 'sn')
        text = sprintf('Subject %i, Decoding Nr %i', cfg.sn, i_step);
    else
        text = sprintf('Decoding Nr %i', i_step);
    end
    dispv(2, '%s', text)
    fprintf(inputfilenames_fid, '%s\n', text);

    if n_match > 0
        cont = '...';
        text = sprintf('  File Start: %s%s\n', filestart, cont);
        dispv(2, '%s', text)
        fprintf(inputfilenames_fid, '%s\n', text);
    else
        cont = '';
    end

    for curr_i_train = i_train'
        text = sprintf('  File Train %i: %s%s', cfg.design.label(curr_i_train, i_step), cont, cfg.files.name{curr_i_train}(n_match+1:end));
        dispv(2, '%s', text)
        fprintf(inputfilenames_fid, '%s\n', text);
    end
    fprintf(inputfilenames_fid, '\n');


    for curr_i_test = i_test'
        text = sprintf('  File Test %i: %s%s', cfg.design.label(curr_i_test, i_step), cont, cfg.files.name{curr_i_test}(n_match+1:end));
        dispv(2, '%s', text)
        fprintf(inputfilenames_fid, '%s\n', text);
    end
    fprintf(inputfilenames_fid, '\n');

end