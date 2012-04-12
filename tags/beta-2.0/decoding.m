% function [results, cfg, passed_data] = decoding(cfg, passed_data)
% 
% Decoding Toolbox, Version: 2.0 beta, by Martin Hebart & Kai Goergen
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
% This is currently in an experimental stage, but does not work at the
% moment. However, some lines already contain code that is required for 
% that. So don't be confused by that, nor do expect that you can use
% feature selection at the moment.
%
%
% REQUIRED INPUT:
%   cfg: Structure containing all necessary configuration information
%       Required fields:
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
%                    mask minus those that are nan in the input data.
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


function [results, cfg, passed_data] = decoding(cfg, passed_data)

%% Prepare decoding analysis 

cfg = decoding_defaults(cfg); % set defaults
cfg.parameter_selection = decoding_defaults(cfg.parameter_selection);
cfg.feature_selection = decoding_defaults(cfg.feature_selection);

dispv(1,'Preparing analysis: ''%s''',cfg.analysis)

global verbose % MH: don't worry, Kai, this is the only case where global is better than passing!! ;)
verbose = cfg.verbose;

% Display version
ver = [mfilename ', Martin Hebart & Kai Goergen, v2012/03/12 2.01 beta'];
cfg.info.ver = ver;
dispv(1,ver)

% Basic checks
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

% Get number of voxels for searchlight and number of ROIs for ROI (and 1 for wholebrain)
n_decodings = get_n_decodings(cfg,mask_index);

% Initialize results vectors
n_outputs = length(cfg.results.output);
n_sets = length(unique(cfg.design.set));
n_cond = sum(unique(cfg.design.label) ~= 0);
results = {};

% Prepare searchlight template (if needed, sl_template will be empty for other methods)
[cfg,sl_template] = decoding_prepare_searchlight(cfg);

for i_output = 1:n_outputs
    outname = cfg.results.output{i_output};
    
    % Save number of conditions (e.g. to get the chancelevel later)
    results.n_cond = n_cond;
        
    % Preallocation
    results.(outname).output = zeros(n_decodings,1);
    
    if cfg.results.setwise
        for i_set = 1:n_sets
            results.(outname).set(i_set).output = zeros(n_decodings,1); %#ok
        end
    end
end


%% PERFORM Decoding Analysis

dispv(1,'Starting decoding...')

% Save start time (for time estimate)
start_time = now;

% Preloading
msg_length = [];

% Warn if test mode
if cfg.testmode
    warning('DECODING:testmode','TEST MODE: Only one decoding step is calculated!');
    n_decodings = 1;
end

% Report files
report_files(cfg,n_steps,inputfilenames_fid);

% Start
for i_decoding = 1:n_decodings % e.g. voxels for searchlight

    % Display status info (i.e. how far is the analysis?)
    if verbose, [msg_length] = display_progress(cfg,i_decoding,n_decodings,start_time,msg_length); end
    
    % Get the current maskindices (e.g. of the current searchlight or of the current ROI)
    indexindex = get_ind(cfg,mask_index,i_decoding,sz,sl_template);
    
    previous_itrain = []; % init
    
    % TODO: Get a better order of the decodings steps (i.e. sort them so
    % that the same training is used in neighbouring columns)
    
    % Loop over design columns (e.g. cross-validation runs)
    for i_step = 1:n_steps
        
        % Get indices for training
        itrain = find(cfg.design.train(:, i_step) > 0);
        % Get indices for testing
        itest = find(cfg.design.test(:, i_step) > 0);

        % Get data for training & testing at current position
        vectors_train = data(itrain, indexindex);
        vectors_test = data(itest, indexindex);
        labels_train = cfg.design.label(itrain, i_step);
        labels_test = cfg.design.label(itest, i_step);

        % Skip feature selection and training if training set is identical
        % to previous iteration (saves time)
        skip_training = isequal(previous_itrain, itrain);

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Parameter selection (e.g. optimize C for SVM) %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if ~skip_training
           cfg = decoding_parameter_selection(cfg,vectors_train,i_step); 
        end
        
        %%%%%%%%%%%%%%%%%%%%%
        % Feature selection %
        %%%%%%%%%%%%%%%%%%%%%
        
        % TODO: feature selection should give vector of selected voxels as
        % output, then vectors_test can be adjusted later on 
        % TODO: This is in an experimental stage and won't work at the
        % moment
        if ~strcmpi(cfg.feature_selection.method,'none')
            if ~skip_training
                % pack
                % TODO: for 'useall', make vectors_train = data(:,indexindex). Makes it a lot easier to code later.
                fs_data.vectors_train = vectors_train;
                fs_data.vectors_test = vectors_test;
                fs_data.labels_train = labels_train;
                fs_data.labels_test = labels_test;
                fs_data.i_step = i_step;
                fs_data.external.position_index = mask_index(indexindex); % absolute position of currently selected voxels in decoding (for external masks)
                [fs_index,fs_results,fs_data] = decoding_feature_selection(cfg,fs_data);
                if isfield(cfg.feature_selection,'useall') && cfg.feature_selection.useall
                    if i_step == 1
                    results.feature_selection(i_decoding) = fs_results;
                    end
                else
                    results.feature_selection(i_decoding).n_vox_selected(i_step) = fs_results.n_vox_selected;
                end
            end
            vectors_train = vectors_train(:,fs_index);
            vectors_test = vectors_test(:,fs_index);
        end
        
       
        %%%%%%%%%%%%%%%%%%%%
        % PERFORM DECODING %
        %%%%%%%%%%%%%%%%%%%%
        
        %   TRAIN DATA    %
        %%%%%%%%%%%%%%%%%%%
        
        % Do scaling on all used data if requested
        % TODO: include variable set here and rename to scaling within set
        
        % Do scaling on training set if requested
        if strcmpi(cfg.scale.method,'across') && ~skip_training
            if i_decoding == 1 && i_step == 1, dispv(1,'Using scaling estimation type: %s',cfg.scale.method), end
            [vectors_train,scaleparams] = scale_data(cfg,vectors_train);
        end

        % Estimate Model
        if ~skip_training
            fhandle = str2func([cfg.decoding.software '_train']); % this format allows variable input
            % e.g. when software is libsvm, then:
            % model(i_step) = libsvm_train(labels_train,vectors_train,cfg);
            model(i_step) = feval(fhandle,labels_train,vectors_train,cfg); %#ok
        else
            model(i_step) = model(i_step-1); %#ok
        end
        
        previous_itrain = cfg.design.train(:,i_step); % update for next step
        
        %    TEST DATA    %
        %%%%%%%%%%%%%%%%%%%
        
        % TODO: introduce column scaling (mean removal, zscore, etc.)
        
        % Do scaling on test data if requested
        if strcmpi(cfg.scale.method,'across')
            [vectors_test] = scale_data(cfg,vectors_test,scaleparams);
        end
        
        % Test Estimated Model
        fhandle = str2func([cfg.decoding.software '_test']); % this format allows variable input
        % e.g. when software is libsvm, then:
        % model(i_step) = libsvm_test(labels_train,vectors_train,cfg,model(i_step));
        decoding_out(i_step) = feval(fhandle,labels_test,vectors_test,cfg,model(i_step)); %#ok

        % TODO: decoding_out should be made extendable across runs 
        % (sometimes you want to do things across runs)
        % maybe introduce another function and use all models?

    end % i_step

    %%%%%%%%%%%%%%%%%%%
    % Generate output %
    results = decoding_generate_output(cfg,results,decoding_out,i_decoding,model);
    
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
decoding_write_results(cfg,results,mask_index)
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


%% Subfunctions

%%%%%%%%%%%%%%%%%%%%%
% Run basic checks  %
%%%%%%%%%%%%%%%%%%%%%
function [cfg, n_files, n_steps] = basic_checks(cfg,output_arguments)

% Display image access software that is used
dispv(1, 'Image access with: %s',cfg.software);

cfg = check_software(cfg);

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
            warning('Some fields for design matrix were missing. Design was created anew, using the method %s.',cfg.design.function) %#ok<WNTAG>
        end
        fhandle = str2func(cfg.design);
        cfg.design = feval(fhandle,cfg);
    else % throw error if no method has been passed and design incomplete
        error('Design is missing or incomplete. Either create design in advance or pass method to create design (see ''help decoding'')');
    end
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

% TODO: introduce check that cfg.scale.estimation = 'all' only for balanced
% data (otherwise, results may be biased in favor of one hypothesis,
% reducing decoding accuracies)

if ~strcmpi(cfg.feature_selection.method,'none')
    warning('Feature selection has not been fully debugged. Running in test mode!') %#ok<WNTAG>
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

if strcmpi(cfg.scale.method,'none') && ~strcmpi(cfg.scale.estimation,'none')
    warning(['Scaling method is ''none'', but estimation type is ''' cfg.scale.estimation ''', changing type to ''none''']) %#ok
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

if ischar(cfg.files.name), cfg.files.name = num2cell(cfg.files.name); end
if length(cfg.files.name) ~= length(unique(cfg.files.name))
    warning('Double filename entries in cfg.files.name. No guarantee, that training and test sets are independent!!!') %#ok
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
                    warning('Resultfile %s already existed. Overwriting...',output_fname) %#ok
                end
            end
            
            % Check if it is possible to write
            temp = fopen(output_fname, 'w');
            fclose(temp);
            delete(output_fname);
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
    itrain = find(cfg.design.train(:, i_step) > 0);
    % Get indices for testing
    itest = find(cfg.design.test(:, i_step) > 0);
    
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
    
    for curr_itrain = itrain'
        text = sprintf('  File Train %i: %s%s', cfg.design.label(curr_itrain, i_step), cont, cfg.files.name{curr_itrain}(n_match+1:end));
        dispv(2, '%s', text)
        fprintf(inputfilenames_fid, '%s\n', text);
    end
    fprintf(inputfilenames_fid, '\n');
    
    
    for curr_itest = itest'
        text = sprintf('  File Test %i: %s%s', cfg.design.label(curr_itest, i_step), cont, cfg.files.name{curr_itest}(n_match+1:end));
        dispv(2, '%s', text)
        fprintf(inputfilenames_fid, '%s\n', text);
    end
    fprintf(inputfilenames_fid, '\n');
    
end