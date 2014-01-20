% function design = make_design_xclass_cv(cfg)
%
%
% Function to generate design matrix for cross classification using the
% decoding toolbox. This function uses leave-one-run-out crossvalidation,
% but keeps training and test data separate. In that way,
% crossclassification is done with independent runs.
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
%   cfg.files.twoway: 1 or 0 (optional input). If 1, then two-way cross 
%       classification is carried out (i.e. training on 1 and testing 2 as 
%       well as training on 2 and testing on 1).
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
%   design.function: Information about function used to create design
%
%
% EXAMPLE:
%
% >> cfg.files
% ans = 
%      name:   {24x1 cell}
%      step:   [24x1 double]
%      label:  [24x1 double]
%      set:    [24x1 double]
%      xclass: [24x1 double]
%      twoway: 0
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
%     train: [24x6 double]
%      test: [24x6 double]
%     label: [24x6 double]
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
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%
% >> cfg.design.test
% ans =
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
%      0     0     0     0     0     0
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
% By: Martin Hebart, 2011/09/05



function design = make_design_xclass_cv(cfg)

%% generate design matrix (CV)

design.function.name = mfilename;
design.function.ver = 'v20110905';

if ~isfield(cfg.files,'set') || isempty(cfg.files.set)
    cfg.files.set = ones(size(cfg.files.label));
end

if ~isfield(cfg.files,'twoway')
    cfg.files.twoway = 0;
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
if size(cfg.files.xclass,1) == 1
    warningv('MAKE_DESIGN:ORIENTATION_XCLASS','cfg.files.xclass has the wrong orientation. Flipping.');
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
design.train(n_files,1) = 0; % sets size along x-dimension
design.test(n_files,1) = 0;

n_twoway = 1;
if cfg.files.twoway, n_twoway = 2; end

for i_twoway = 1:n_twoway
    
    if i_twoway == 2
        xclass_numbers = [xclass_numbers(2) xclass_numbers(1)];
    end
    
    for i_set = 1:n_sets
        
        set_filter = cfg.files.set == i_set;
        
        step_numbers = unique(cfg.files.step(set_filter));
        n_steps = length(step_numbers);
        
        for i_step = 1:n_steps
            
            counter = counter + 1;
            
            % set all training entries
            train_filter = cfg.files.step ~= step_numbers(i_step) & cfg.files.xclass == xclass_numbers(1) & set_filter;
            design.train(train_filter, counter) = 1;
            
            % set all test entries
            test_filter = cfg.files.step == step_numbers(i_step) & cfg.files.xclass == xclass_numbers(2) & set_filter;
            design.test(test_filter, counter) = 1;
        end
        
        design.label = [design.label repmat(cfg.files.label, 1, n_steps)];
        design.set = [design.set repmat(i_set,1,n_steps)];
        
    end
    
end

msg = 'Design for CV and cross classification decoding for %i files x %i steps created\n';
if check_verbosity(msg,1)
    dispv(1, msg, n_files, counter)
end