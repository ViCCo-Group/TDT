% function design = make_design_boot(cfg,n_boot,balance_test,n_train)
% 
% Function to generate design matrix for classification using bootstrapping 
% in the decoding toolbox. This design is helpful if it is not clear how 
% to separate training and test data (e.g. which pair should be left out) 
% or if there is unbalanced data (i.e. more datapoints belonging to one 
% class than to the other). For each cross-validation iteration, a subset 
% of samples are drawn (without replacement). The only limitation is that
% at least one label per group has to be present in the test data.
% This function is useful only if there is only one decoding step, i.e. if
% data does not consist of several chunks of data (as is the case with e.g.
% leave-one-run-out). For example, if you classify across different groups
% of subjects and want to make sure that training data stays balanced, this
% function might be useful.
% 
% If you have more than one step, use make_design_boot_cv.
%
% INPUT
%   cfg.files.step: a vector, one step (e.g. run) number for each file in
%       cfg.files.name
%   cfg.files.label: a vector, one label number for each file in
%       cfg.files.name
%   cfg.files.set (optional): currently only one set is possible in this 
%       function.
%   n_boot: Number of bootstrap samples to be drawn
%   balance_test (optional): Set to 1 if also the test data should be 
%       balanced. This might make sense if you want all runs to contribute 
%       equally to the decoding results or both labels equally. Otherwise 0.
%   n_train (optional): Number of samples per condition to use as training 
%       samples. If no input is provided, the maximal number of available 
%       samples will be used (recommended).
%
% OUTPUT
%   design.label: matrix with one column for each CV step, containing a
%       label for each image used for decoding (a replication of the vector
%       cfg.files.label across CV steps)
%   design.train: binary matrix with one column for each CV step, containing
%       a 1 for each image used for training in this CV step and 0 for all
%       images not used
%   design.test: same as in design.train, but this time for all test images
%   design.set: 1xn vector, describing the set number of each CV step.
%   design.function: Information about function used to create design
%
%

% Martin 2013/09/08

% TODO: allow multiple sets to be used

function design = make_design_boot(cfg,n_boot,balance_test,n_train)

%% generate design matrix

design.function.name = mfilename;
design.function.ver = 'v20130908';

if ~exist('balance_test','var'), balance_test = 0; end

% Internal function to check prerequisites (see bottom)
cfg = basic_checks(cfg);

n_files = length(cfg.files.step);

% Set labels and set
design.label = repmat(cfg.files.label, 1, n_boot);
design.set = ones(1, n_boot); % this is here only until more than one set is supported

% Init train and test
design.train = zeros(n_files, n_boot);
design.test = zeros(n_files, n_boot);

% Calculate how many trials can maximally be used for training and
% test purposes to have a balance
all_labels = unique(cfg.files.label);
n_labels = size(all_labels,1);
for i_label = 1:n_labels
    label_count(i_label) = sum(cfg.files.label == all_labels(i_label));
end
max_n_labels_train = min(label_count) - 1;

if exist('n_train','var')
    if n_train > max_n_labels_train
        error(['More training labels selected than training labels available. ',...
               'Maximum available number of training labels is %.0f'],min(label_count)-1)    
    else
        max_n_labels_train = n_train;
    end
end

n_test = min(label_count) - max_n_labels_train;

% Loop over labels and get index for each label
for i_label = 1:n_labels
    all_ind{i_label} = find(cfg.files.label == all_labels(i_label));
end

counter = 0;
% Now create bootstrap samples
for i_boot = 1:n_boot
    
    counter = counter+1;
    
    for i_label = 1:n_labels
        % shuffle the indices
        all_ind{i_label} = all_ind{i_label}(randperm(length(all_ind{i_label}))); %#ok<*AGROW>
        % select the maximum available number as train index
        train_ind{i_label} = all_ind{i_label}(1:max_n_labels_train);
        if balance_test
            % select last few indices as test index
            test_ind{i_label} = all_ind{i_label}(end-n_test+1:end);
        else
            % select all remaining indices as test index
            test_ind{i_label} = all_ind{i_label}(max_n_labels_train+1:end);
        end
    end

    % now combine training indices of all labels and test indices of all labels
    train_ind_all = vertcat(train_ind{:});
    test_ind_all = vertcat(test_ind{:});
    
    design.train(train_ind_all,i_boot) = 1;
    design.test(test_ind_all,i_boot) = 1;
end
    
    
msg = 'Design for CV decoding for %i files x %i steps created\n';
if check_verbosity(msg,1)
    dispv(1, msg, n_files, counter)
end



function cfg = basic_checks(cfg)

if ~isfield(cfg.files,'set')
    cfg.files.set = ones(size(cfg.files.label));
elseif length(unique(cfg.files.set))>1
    error(['More than one set specified in a design used in combination\n',...
        'with ''make_design_boot_cv''. Currently, using more than one \n',...
        'set is not implemented yet in this design structure. If you \n',...
        'really need it, you can create two separate designs first, \n',...
        'combine them using combine_designs and manually introducing \n',...
        'set number afterwards.'])
end

if unique(cfg.files.step) > 1
    error(['cfg.files.step contains more than one entry. This function is ',...
           'designed for one entry only. Use one step number only, '...
           'use make_design_boot_cv instead or create your design manually.'])
end

% Make sure that input has the right orientation
if size(cfg.files.step,1) == 1
    warningv('MAKE_DESIGN:ORIENTATION_STEP','cfg.files.step has the wrong orientation. Flipping.');
    cfg.files.step = cfg.files.step';
end
if size(cfg.files.label,1) == 1
    warningv('MAKE_DESIGN:ORIENTATION_LABEL','cfg.files.label has the wrong orientation. Flipping.');
    cfg.files.label = cfg.files.label';
end    
if size(cfg.files.set,1) == 1
    warningv('MAKE_DESIGN:ORIENTATION_SET','cfg.files.set has the wrong orientation. Flipping.');
    cfg.files.set = cfg.files.set';
end    

set_numbers = unique(cfg.files.set);
n_sets = length(set_numbers);

if n_sets >1
    error('More than one set selected. Currently only one set supported!')
end