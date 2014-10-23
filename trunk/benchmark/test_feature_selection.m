% Artificial data

n_vox = 200;
n_samples = 20;
snr = 0.5;
labels = [ones(n_samples/2,1); -ones(n_samples/2,1)];

noise = randn(n_samples,n_vox);

signal = [snr*ones(n_samples/2,n_vox); -snr*ones(n_samples/2,n_vox)]; % first create signal in all voxels
signal(:,n_vox/2+1:n_vox) = 0; % then remove it in half

signal(:,15) = 5*signal(:,15); % then for the 15th voxel enhance signal (should give higher weight)

data = signal+noise;

cfg = decoding_defaults;
cfg.feature_selection = decoding_defaults(cfg.feature_selection);
% cfg.feature_selection.feature_selection = decoding_defaults(cfg.feature_selection.feature_selection);

cfg.files.label = labels;
cfg.files.set = ones(n_samples,1);
cfg.files.chunk = [1:n_samples/2 1:n_samples/2]';
cfg.files.mask = {''};
cfg.files.name = repmat('temp.img',n_samples,1);

cfg.design = make_design_cv(cfg);

% cfg.feature_selection.feature_selection.method = 'filter';
% cfg.feature_selection.feature_selection.filter = 'F';
% cfg.feature_selection.feature_selection.n_vox = [60:70:200];
% cfg.feature_selection.method = 'embedded';
% cfg.feature_selection.embedded = 'RFE';
% cfg.feature_selection.n_vox = [1 10:60];
% cfg.feature_selection.nested_n_vox = 0.001:0.001:1;

cfg.feature_selection.method = 'embedded';
cfg.feature_selection.embedded = 'RFE';
cfg.feature_selection.n_vox = 'automatic';
cfg.feature_selection.nested_n_vox = 'automatic';
cfg.feature_selection.optimization_criterion = 'select_peak';


fs_data.labels_train = labels;
fs_data.i_step = 1;
fs_data.i_train = find(cfg.design.train(:,1));
fs_data.vectors_train = data;

[cfg, n_files, n_steps] = decoding_basic_checks(cfg,2);

[fs_index,fs_results,fs_data] = decoding_feature_selection(cfg,fs_data);