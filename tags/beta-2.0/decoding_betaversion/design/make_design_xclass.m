% function design = make_design_xclass(cfg)
%
%
% Function to generate design matrix for cross classification using the
% decoding toolbox. This function uses all training data and all test data,
% without crossvalidation.
%
% IN
%   cfg.files.step: a vector, one step (e.g. run) number for each file in
%       cfg.files.name
%   cfg.files.label: a vector, one label number for each file in
%       cfg.files.name
%   cfg.files.set: a vector, one set number for each file in
%       cfg.files.name.
%   cfg.files.xclass: a vector, one number for each file in
%       cfg.files.name. This variable is used to distinguish training
%       and test data. Cross classification is performed from the lower to
%       the higher number (e.g. from 1 to 2).
%       
%
% OUT
%   design.label: matrix with one column for each decoding step, containing a
%       label for each image used for decoding (a replication of the vector
%       cfg.files.label across decoding steps)
%   design.train: binary matrix with one column for each decoding step, containing
%       a 1 for each image used for training in this decoding step and 0 for all
%       images not used
%   design.test: same as in design.train, but this time for all test images
%   design.set: 1xn vector, describing the set number.
%
%
% EXAMPLE:
%
% >> cfg.files
% ans = 
%      name: {24x1 cell}
%      step: [24x1 double]
%      label: [24x1 double]
%      set:  [24x1 double]
%
% >> [cfg.files.step, cfg.files.label cfg.files.xclass]
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
%      1     1     2
%      2     1     2
%      3     1     2
%      4     1     2
%      5     1     2
%      6     1     2
%      1     2     2
%      2     2     2
%      3     2     2
%      4     2     2
%      5     2     2
%      6     2     2
%
% >> cfg.design = make_design_cv(cfg);
% >> cfg.design
% 
% ans = 
% 
%     train: [24x1 double]
%      test: [24x1 double]
%     label: [24x1 double]
%       set: [24x1 double]
% 
% >> cfg.design.train
% ans =
%      1
%      1
%      1
%      1
%      1
%      1
%      1
%      1
%      1
%      1
%      1
%      1
%      0
%      0
%      0
%      0
%      0
%      0
%      0
%      0
%      0
%      0
%      0
%      0
%
% >> cfg.design.test
% ans =
%      0
%      0
%      0
%      0
%      0
%      0
%      0
%      0
%      0
%      0
%      0
%      0
%      1
%      1
%      1
%      1
%      1
%      1
%      1
%      1
%      1
%      1
%      1
%      1
%
% >> cfg.design.label
% ans =
%      1
%      1
%      1
%      1
%      1
%      1
%      2
%      2
%      2
%      2
%      2
%      2
%      1
%      1
%      1
%      1
%      1
%      1
%      2
%      2
%      2
%      2
%      2
%      2
%
% >> cfg.design.set
% ans =
%      1
% ------------------------------------
% By: Martin Hebart, 2011/09/05



function design = make_design_xclass(cfg)

%% generate design matrix

design.info.ver = [mfilename ' Martin H., v20110905'];

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
if size(cfg.files.xclass,1) == 1
    warning('cfg.files.xclass has the wrong orientation. Flipping.'); %#ok<WNTAG>
    cfg.files.xclass = cfg.files.xclass';
end 

set_numbers = unique(cfg.files.set);
xclass_numbers = unique(cfg.files.xclass);

n_sets = length(set_numbers);
n_xclass = length(xclass_numbers);
if n_xclass ~= 2
    error('Wrong number of labels in cfg.files.xclass. Cross classification needs exactly one training and one test set.')
end

n_files = length(cfg.files.step);

counter = 0;
design.label = [];
design.set = [];
design.train(n_files,1) = 0; % sets size along x dimension
design.test(n_files,1) = 0;

for i_set = 1:n_sets

    set_filter = cfg.files.set == i_set;

    counter = counter + 1;

    % set all training entries
    train_filter = set_filter & cfg.files.xclass == xclass_numbers(1);
    design.train(train_filter, counter) = 1;
    
    % set all test entries
    test_filter = set_filter & cfg.files.xclass == xclass_numbers(2);
    design.test(test_filter, counter) = 1;

    design.label = [design.label repmat(cfg.files.label(set_filter), 1, counter)];
    design.set = [design.set repmat(i_set,1,counter)];

end

if ~isfield(cfg,'design') || ~isfield(cfg.design,'msg') || ~isfield(cfg.design.msg,mfilename)
fprintf('Design for cross classification decoding for %i files x %i steps created\n', n_files, counter)
end

design.msg.(mfilename) = 1; % set message so that output is generated only once