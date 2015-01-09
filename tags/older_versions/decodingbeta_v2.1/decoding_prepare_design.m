% function cfg = decoding_prepare_design(cfg,labelnames,labels,regressor_names,beta_dir,xclass)
% 
% This functions creates the link between the file names of regressors
% (e.g. beta_0001.img) and its corresponding label name (e.g. button press),
% label number (e.g. -1 or 1) and decoding step number (e.g. run 1). These 
% inputs are needed to create a design matrix with all make_design functions.
%
% INPUT:
%   cfg: configuration file (see decoding.m)
%   labelnames: 1xn cell array, containing all label names used in the SPM
%       design matrix. These are the regressor names that are entered in the
%       first-level analysis and which should serve as basis of the decoding.
%   regressor_names: A file location where all regressor names are stored.
%       This file is created by the function design_from_spm.
%   beta_dir: Directory where images are stored that are used for decoding
%       (e.g. beta_0001.img)
%   xclass (optional): Useful for simple cross classification. Assigns 
%       separate numbers to each label. The cross classification will go from 
%       class 1 to class 2. For classification, an example could look like this:
%       labelnames = {'yourtraininglabel1','yourtraininglabel2','yourtestlabel1','yourtestlabel2'};
%       labels = [1 -1 1 -1];
%       xclass = [1 1 2 2];
%
% by Martin Hebart 11/06/12

% MH: added cross classification and help file: 11/09/05

function cfg = decoding_prepare_design(cfg,labelnames,labels,regressor_names,beta_dir,xclass)

cfg = decoding_defaults(cfg);

cfg.files.name = [];
cfg.files.step = [];
cfg.files.label = [];
cfg.files.set = [];
cfg.files.xclass = [];

if length(labelnames) ~= length(labels)
    error('Label names have to be of equal size than label numbers!')
end

if beta_dir(end) == filesep % prevents some stupid spm_select bug
    beta_dir = beta_dir(1:end-1);
    if beta_dir(end) == ':' % also because of spm_select bug
        error('At current, results cannot be saved in basic directories such as C:\')
    end
end
beta_names = get_filenames(cfg.software,beta_dir,'beta*.img');
if isempty(beta_names)
    error('No img-files starting with ''beta'' found in %s',beta_dir)
end

n_inputs = length(labelnames);

for i_input = 1:n_inputs
    label_index = strcmp(regressor_names(1,:),labelnames{i_input});
    if ~any(label_index)
        error('Could not find any file associated with label ''%s''. Check input label names (case sensitive!)!',labelnames{i_input})
    end
    cfg.files.name = [cfg.files.name; beta_names(label_index,:)];
    cfg.files.step = [cfg.files.step cell2mat(regressor_names(2,label_index))];
    cfg.files.label = [cfg.files.label repmat(labels(i_input),1,sum(label_index))];
    if exist('xclass','var')
        cfg.files.xclass = [cfg.files.xclass repmat(xclass(i_input),1,sum(label_index))];
    end
end

if ischar(cfg.files.name), cfg.files.name = num2cell(cfg.files.name,2); end
cfg.files.step = cfg.files.step';
cfg.files.label = cfg.files.label';
cfg.files.set = cfg.files.set';
cfg.files.xclass = cfg.files.xclass';
    


