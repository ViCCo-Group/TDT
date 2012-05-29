% function design = make_design_cv(cfg)
%
%
% Function to generate design matrix for cross validation using the
% decoding toolbox. This function uses a "leave one run out" cross
% validation method.
%
% IN
%   cfg.files.step: a vector, one step (e.g. run) number for each file in
%       cfg.files.name
%   cfg.files.label: a vector, one label number for each file in
%       cfg.files.name
%   cfg.files.set (optional): a vector, one set number for each file in
%       cfg.files.name. This variable is used to run several different
%       decodings at once. This might be useful e.g. if they overlap. 
%       
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
%
%
% EXAMPLE:
%
% >> cfg.files
% ans = 
%      name: {12x1 cell}
%      step: [12x1 double]
%      label: [12x1 double]
%      set:  [12x1 double]
%
% >> [cfg.files.step, cfg.files.label cfg.files.set]
% ans =
%      1     1     1
%      2     1     1
%      3     1     1
%      4     1     1
%      5     1     1
%      6     1     1
%      1     2     1
%      2     2     1
%      3     2     1
%      4     2     1
%      5     2     1
%      6     2     1
%
% >> cfg.design = make_design_cv(cfg);
% >> cfg.design
% 
% ans = 
% 
%     train: [12x6 double]
%      test: [12x6 double]
%     label: [12x6 double]
%       set: [1x6 double]
% 
% >> cfg.design.train
% ans =
%      0     1     1     1     1     1
%      1     0     1     1     1     1
%      1     1     0     1     1     1
%      1     1     1     0     1     1
%      1     1     1     1     0     1
%      1     1     1     1     1     0
%      0     1     1     1     1     1
%      1     0     1     1     1     1
%      1     1     0     1     1     1
%      1     1     1     0     1     1
%      1     1     1     1     0     1
%      1     1     1     1     1     0
%
% >> cfg.design.test
% ans =
%      1     0     0     0     0     0
%      0     1     0     0     0     0
%      0     0     1     0     0     0
%      0     0     0     1     0     0
%      0     0     0     0     1     0
%      0     0     0     0     0     1
%      1     0     0     0     0     0
%      0     1     0     0     0     0
%      0     0     1     0     0     0
%      0     0     0     1     0     0
%      0     0     0     0     1     0
%      0     0     0     0     0     1
%
% >> cfg.design.label
% ans =
%      1     1     1     1     1     1
%      1     1     1     1     1     1
%      1     1     1     1     1     1
%      1     1     1     1     1     1
%      1     1     1     1     1     1
%      1     1     1     1     1     1
%      2     2     2     2     2     2
%      2     2     2     2     2     2
%      2     2     2     2     2     2
%      2     2     2     2     2     2
%      2     2     2     2     2     2
%      2     2     2     2     2     2
%
% >> cfg.design.set
% ans =
%      1     1     1     1     1     1
% ------------------------------------
% By: Kai Goergen & Martin Hebart, 2010/06/13

% History:
% - introduced sets variable MH: 11-06-13
% - Changed fieldname cfg.cond to cfg.label, output of train and test
%   to be binary and label names to be separately provided (more general
%   purpose) MH: 10-08-01
% - MH: Made more general to allow steps that don't go from 1:n to be
%   cross-validated



function design = make_design_cv(cfg)

%% generate design matrix (CV)

design.info.ver = [mfilename ' Martin H., v20100802'];

if ~isfield(cfg.files,'set') || isempty(cfg.files.set)
    cfg.files.set = ones(size(cfg.files.label));
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

n_files = length(cfg.files.step);

% design.train = zeros(n_files, n_steps);
% design.test = zeros(n_files, n_steps);
% design.label = repmat(cfg.files.label, 1, n_steps);

counter = 0;
design.label = [];
design.set = [];
design.train(n_files,1) = 0; % sets size along x dimension
design.test(n_files,1) = 0;

for i_set = 1:n_sets

    set_filter = cfg.files.set == i_set;
    
    step_numbers = unique(cfg.files.step(set_filter));
    n_steps = length(step_numbers);
    
    for i_step = 1:n_steps
        
        counter = counter + 1;
        
        % set all training entries
        train_filter = cfg.files.step(set_filter) ~= step_numbers(i_step);
        design.train(train_filter, counter) = 1;
        
        % set all test entries
        test_filter = cfg.files.step(set_filter) == step_numbers(i_step);
        design.test(test_filter, counter) = 1;
    end
    
    design.label = [design.label repmat(cfg.files.label(set_filter), 1, n_steps)];
    design.set = [design.set repmat(i_set,1,n_steps)];
    
end



if ~isfield(cfg,'design') || ~isfield(cfg.design,'msg') || ~isfield(cfg.design.msg,mfilename)
fprintf('Design for CV decoding for %i files x %i steps created\n', n_files, counter)
end

design.msg.(mfilename) = 1; % set message so that output is generated only once