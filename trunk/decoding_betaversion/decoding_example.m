% function results = decoding_example(decoding_type,labelname1,labelname2,beta_dir,output_dir,radius)
%
% This is a general function for two class classification, using a linear 
% SVM as implemented in the libsvm software, with accuracy images (for
% searchlight) or variables (for ROI or wholebrain) as output. All 
% variables that are not specified in the input will be set automatically 
% in the function. An SPM.mat containing the label names as regressor names
% must also exist.
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
%   the searchlight (in voxels).

function results = decoding_example(decoding_type,labelname1,labelname2,beta_dir,output_dir,radius)

cfg = decoding_defaults;

cfg.testmode = 0;
cfg.analysis = decoding_type;
cfg.decoding.train.classification.model_parameters = '-s 0 -t 0 -c 1 -b 0 -q'; % linear classification
try
    cfg.software = spm('ver');
catch % else try out spm8
    cfg.software = 'SPM8';
end

if exist('output_dir','var')
    cfg.results.dir = output_dir;
else
    cfg.results.write = 0;
end


switch lower(decoding_type)
    
    case 'searchlight'
        
        if ~exist('radius','var')
           warning('Variable ''radius'' wasn''t specified. Using default value %d',cfg.searchlight.radius); %#ok<WNTAG>
        else
            cfg.searchlight.radius = radius;
        end
        cfg.searchlight.unit = 'voxels';
        
        % Use mask in beta dir (e.g. SPM mask) as brain mask
        cfg.files.mask = fullfile(beta_dir,'mask.img');
        
%         cfg.plot_selected_voxels = 100; % activate to plot searchlights
        
    case 'roi'
        
        [fnames,fpath] = uigetfile('*.img; *.nii', 'Select your ROI masks', 'Multiselect', 'on');
        
        if ~iscell(fnames)
            if fnames ~= 0
                cfg.files.mask = fullfile(fpath,fnames);
            else
                error('No file was selected')
            end
        else
            if ~strcmp(fpath(1,end),filesep), fpath = [fpath filesep]; end
            cfg.files.mask = [repmat(fpath,2,1) vertcat(char(fnames{:}))];
        end
        
        cfg.plot_selected_voxels = 1;
        
    case 'wholebrain'
        
        % Use mask in beta dir (e.g. SPM mask) as brain mask
        cfg.files.mask = fullfile(beta_dir,'mask.img');
                
end

if exist('output_dir','var')
    cfg.results.dir = output_dir;
end

% get regressor names
regressor_names = design_from_spm(beta_dir);

% extract regressors with labelname1 and labelname2, including run number
% make sure that labels 1 and 2 are uniquely assigned
cfg = decoding_describe_data(cfg,{labelname1 labelname2},[-1 1],regressor_names,beta_dir);

% assign these values to the standard matrix and create the matrix
cfg.design = make_design_cv(cfg);

% cfg.results.output = {'AUC_minus_chance'}; % activate for alternative output

% run results = decoding(cfg)
results = decoding(cfg);