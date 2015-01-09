% function results = decoding_example_compare(decoding_type,labelname1,labelname2,beta_dir,output_dir,radius)
%
% This function is very similar to the new decoding_example, but works with
% the old function generic_searchlight. This has the advantage that it can
% be used to compare results and facilitate debugging where necessary.
%
% This is a general function for two class classification, using a linear 
% SVM as implemented in the libsvm software, with accuracy images (for
% searchlight) or variables (for ROI or wholebrain) as output. All 
% variables that are not specified in the input will be set automatically 
% in the function. An SPM.mat containing the label names as regressor names
% also has to exist.
%
% INPUT:
% decoding_type: determines decoding method ('searchlight','ROI', or 'wholebrain')
% labelname1: name of first label (e.g. 'button left')
% labelname2: name of second label (e.g. 'button right')
% beta_dir: Folder where beta images are stored. An SPM.mat with these
%   beta names has to exist in this folder to make use of this function.
%
% OPTIONAL:
% output_dir: Where results should be saved (if they should be saved at all)  
% radius: for decoding_type 'searchlight', you may specify the radius of
%   the searchlight.

function results = decoding_example_compare(decoding_type,labelname1,labelname2,beta_dir,output_dir,radius)

cfg = decoding_defaults;
cfg.radius = cfg.searchlight.radius;
cfg.unit = cfg.searchlight.unit;
cfg.spherical = cfg.searchlight.spherical;

cfg.analysis = decoding_type;

if exist('output_dir','var')
    cfg.results.dir = output_dir;
else
    cfg.results.write = 0;
end


switch lower(decoding_type)
    
    case 'searchlight'
        % TODO: remove below when defaults exist
        if ~exist('radius','var')
           warning('Variable ''radius'' wasn''t specified. Using default of 4 voxels'); %#ok<WNTAG>
           cfg.radius = 4;
        else
            cfg.radius = radius;
        end
        cfg.unit = 'voxels';
        
    case 'roi'
        error('method roi not specified in generic_searchlight')
    case 'wholebrain'     
        error('method wholebrain not specified in generic_searchlight')
end

if exist('output_dir','var')
    cfg.results.dir = output_dir;
end

% get regressor names
regressor_names = design_from_spm(beta_dir);

% extract regressors with labelname1 and labelname2, including run number
% make sure that labels 1 and 2 are uniquely assigned

labelname1_index = strcmp(regressor_names(1,:),labelname1);
labelname2_index = strcmp(regressor_names(1,:),labelname2);

if beta_dir(end) == filesep % prevents some stupid spm_select bug
    beta_dir = beta_dir(1:end-1);
    if beta_dir(end) == ':' % also because of spm_select bug
        error('At current, results cannot be saved in basic directories such as C:\')
    end
end
beta_names = spm_select('FPlist',beta_dir,'^beta_.*\img');

cfg.files.name = [beta_names(labelname1_index,:); beta_names(labelname2_index,:)];
if ischar(cfg.files.name), cfg.files.name = num2cell(cfg.files.name,2); end
cfg.files.step = [cell2mat(regressor_names(2,labelname1_index)) cell2mat(regressor_names(2,labelname2_index))]';
cfg.files.label = [repmat(-1,1,sum(labelname1_index)) repmat(1,1,sum(labelname2_index))]';

% assign these values to the standard matrix and create the matrix
cfg.design = make_design_cv(cfg);

% Use SPM mask as brain mask
cfg.files.mask = fullfile(beta_dir,'mask.img');

% run results
addpath('C:\Users\Martin\Desktop\generic_svm_current\generic_decoding_update')

cfg.radius = 12;
cfg.unit = 'mm';
cfg.spherical  = 1;

results = generic_searchlight(cfg);