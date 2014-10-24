clear cfg

cfg.software = 'spm8';

cfg.results.dir = 'd:\temp\output_stattest01\'; 

beta_dir = 'C:\Arbeit\decoding_toolbox\benchmark\SPM_files\full';

display_regressor_names(beta_dir)

labelname1 = 'button left'; % e.g. 'button left';
labelname2 = 'button right';

cfg.files.mask = {'C:\Arbeit\decoding_toolbox\benchmark\SPM_files\roi\m1_left.img';...
                  'C:\Arbeit\decoding_toolbox\benchmark\SPM_files\roi\v1.img'};

regressor_names = design_from_spm(beta_dir);
cfg = decoding_describe_data(cfg,{labelname1 labelname2},[1 -1],regressor_names,beta_dir);

cfg.files.chunk(cfg.files.chunk<=4) = 1;
cfg.files.chunk(cfg.files.chunk>=5) = 2;

cfg.design = make_design_separate(cfg);