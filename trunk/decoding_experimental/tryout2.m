% addpath('..\decoding_betaversion')
% decoding_defaults;
% 
% clear cfg
% 
% cfg.analysis = 'roi';
% 
% cfg.software = 'spm8';
% 
% cfg.results.dir = 'd:\temp\output_stattest01\'; 
% cfg.results.overwrite = 1;
% 
% X = version;
% if strcmp(X(1:3),'7.7')
%     base_dir = 'D:\decoding_temp';
% else
%     base_dir = 'C:\Arbeit\decoding_toolbox';
% end
% 
% beta_dir = fullfile(base_dir,'benchmark','SPM_files','full');
% 
% % display_regressor_names(beta_dir)
% 
% labelname1 = 'button left'; % e.g. 'button left';
% labelname2 = 'button right';
% 
% cfg.files.mask = {fullfile(base_dir,'benchmark\SPM_files\roi\m1_left.img');...
%                   fullfile(base_dir,'benchmark\SPM_files\roi\v1.img')};
% 
% regressor_names = design_from_spm(beta_dir);
% cfg = decoding_describe_data(cfg,{labelname1 labelname2},[1 -1],regressor_names,beta_dir);
% 
% cfg.files.chunk(cfg.files.chunk<=4) = 1;
% cfg.files.chunk(cfg.files.chunk>=5) = 2;
% 
% cfg.design = make_design_separate(cfg);
% 
% results = decoding(cfg);
% 
% cfg.design.function.name = 'make_design_separate';
% 
% cfg.permute.n_perms_select = 256;
% cfg.permute.combine = 1;
% cfg.design = make_design_permutation(cfg);
% 
% 
% 

results = decoding(cfg);


% next step: get results in statistical analysis
load('D:\temp\output99\res_cfg.mat')
cfg.stats.test = 'permutation';
cfg.stats.tail = 'right';
results = 'D:\temp\output99\res_accuracy_minus_chance.mat';
reference = spm_select('fplist','D:\temp\output99','res_accuracy_minus_chance_set.*\.mat$');

cfg.stats.output = 'accuracy_minus_chance';
cfg.stats.results.write = 2;
% cfg.stats.results.fpath = 'D:\temp\output06\stats';
cfg.stats.chancelevel = 0;

p = decoding_statistics(cfg,results,reference);

% TODO: how does everything work when no images are passed, but matrices? -> works
% TODO: add possibility to work with subindex (cfg.searchlight.subset or
% results.decoding_subindex, depending on what is available), i.e. reduce
% the mask_index to the subindex if possible
% TODO: how does everything work with ROI data?

