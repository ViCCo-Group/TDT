% function design = make_design_boot_cv(cfg,n_boot,n_test)
% 
% Function to generate design matrix for classification using bootstrapping 
% (without replacement) in bccn_decode. This design is helpful if it is not 
% clear how to separate training and test data or if there is unbalanced 
% data (i.e. more datapoints belonging to one class than to the other).
% In addition to bootstrapping, a leave-one-run-out procedure is applied in
% order to preserve independence of datapoints. Otherwise, spurious below 
% chance classification may occur (ask Martin H. for details). In addition,
% it naturally limits the number of necessary bootstrap samples.
%
% IN
%   cfg.files.step: a vector, one step (e.g. run) number for each file in
%       cfg.files.name
%   cfg.files.label: a vector, one label number for each file in
%       cfg.files.name
%   cfg.files.set (optional): currently only one set is possible in this 
%       function.
%   n_boot: Number of bootstrap samples to be drawn per run
%   n_test (optional): Number of samples to use as test samples. If no
%       input is provided, the maximal number of available samples will be
%       used.
%
% OUT
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

% TODO: allow multiple sets to be used

% caveat: the maximum number of available test data points are chosen
% for each run separately. E.g. in one run, it might happen that only
% one test point per sample is possible. At best only one data point should
% be chosen per run per sample. If the maximal available number is chosen,
% there will be a larger impact of some runs and a smaller of others. In a
% very bad case, this would reverse the proportions between runs (say in
% run1 more label1, in run2 more label2).
% -> We still choose maximal number of trials, because we assume the
% inequalities to be low across all runs.

function design = make_design_boot_cv(cfg,n_boot,n_test)

%% generate design matrix

design.function.name = mfilename;
design.function.ver = 'v20100613';

if ~isfield(cfg.files,'set')
    cfg.files.set = ones(size(cfg.files.label));
elseif length(unique(cfg.files.set))>1
    error(['More than one set specified in a design used in combination\n',...
        'with ''make_design_boot_cv''. Currently, using more than one \n',...
        'set is not implemented yet in this design structure. If you \n',...
        'really need it, contact the authors of the toolbox and we will \n',...
        'see what we can do.'])
end

% Make sure that input has the right orientation
if size(cfg.files.step,1) == 1
    warning('cfg.files.step has the wrong orientation. Flipping.'); %#ok<WNTAG>
    cfg.files.step = cfg.files.step';
end
if size(cfg.files.label,1) == 1
    warning('cfg.files.label has the wrong orientation. Flipping.'); %#ok<WNTAG>
    cfg.files.label = cfg.files.label';
end    
if size(cfg.files.set,1) == 1
    warning('cfg.files.set has the wrong orientation. Flipping.'); %#ok<WNTAG>
    cfg.files.set = cfg.files.set';
end    

set_numbers = unique(cfg.files.set);
n_sets = length(set_numbers);

if set_numbers >1
    error('More than one set selected. Currently only one set supported!')
end

step_numbers = unique(cfg.files.step);
n_steps = length(step_numbers);

n_files = length(cfg.files.step);

design.train = zeros(n_files, n_steps * n_boot);
design.test = zeros(n_files, n_steps * n_boot);
design.label = repmat(cfg.files.label, 1, n_steps * n_boot);
design.set = ones(1, n_steps * n_boot); % this is here only until more than one set is supported

% Calculate how many trials can maximally be used for training and
% test purposes from each run to have balanced sets

labels = unique(design.label);
samples_ind = cell(n_steps,length(labels));
samples_per_step = zeros(n_steps,length(labels));

for i_step = 1:n_steps
    step_filter = cfg.files.step == step_numbers(i_step);
    for i_label = 1:length(labels)
        samples_ind{i_step,i_label} = find(cfg.files.label == labels(i_label) & step_filter);
        samples_per_step(i_step,i_label) = length(samples_ind{i_step,i_label});
    end
end
n_choose = min(samples_per_step,[],2);

if any(n_choose<1)
    fprintf('Number of available entries per step:\n')
    disp(n_choose)
    error(['At least one step has not a single sample per category.\n',...
           'Remove this step and run function again.']);
end

% compare with n_test
if exist('n_test','var')
    if any(n_choose<n_test)
        warning(['In some steps, less test samples are available than requested.\n',...
                 'Minimum number will be %d'],min(n_choose))
        n_choose(n_choose>n_test) = n_test;
    else
        n_choose(:) = n_test;
    end
end


for i_step = 1:n_steps
    
    for i_boot = 1:n_boot

        curr_ind = (i_step-1)*n_boot + i_boot;
        
        % select a subset of entries, determined by n_choose
        all_ind = [];
        for j_step = 1:n_steps
            for i_label = 1:length(labels)
                ind = samples_ind{j_step,i_label};
                ind = ind(randperm(length(ind)));
                all_ind = [all_ind; ind(1:n_choose(j_step))]; %#ok<AGROW>
            end
        end
        
        subset_filter = zeros(length(cfg.files.label),1);
        subset_filter(all_ind) = 1;
        
        % set all training entries
        train_filter = subset_filter;
        train_filter(cfg.files.step == step_numbers(i_step)) = 0;
        design.train(logical(train_filter), curr_ind) = 1;
        
        test_filter = subset_filter;
        test_filter(cfg.files.step ~= step_numbers(i_step)) = 0;
        design.test(logical(test_filter), curr_ind) = 1;
        
    end
end


if ~isfield(cfg,'design') || ~isfield(cfg.design,'msg') || ~isfield(cfg.design.msg,mfilename)
fprintf('Design for CV decoding for %i files x %i steps created\n', n_files, n_steps)
end

design.msg.(mfilename) = 1; % set message so that output is generated only once in a decoding