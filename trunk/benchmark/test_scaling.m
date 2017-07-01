n_vox = 200;
n_samples = 20;
snr = 0.5;
labels = [ones(n_samples/2,1); -ones(n_samples/2,1)];

noise = randn(n_samples,n_vox);

signal = [snr*ones(n_samples/2,n_vox); -snr*ones(n_samples/2,n_vox)]; % first create signal in all voxels
data = signal+noise;
data(:,[n_vox/2-9:n_vox/2 n_vox-9:n_vox]) = data(:,[n_vox/2-9:n_vox/2 n_vox-9:n_vox]) + 8*randn(n_samples,20); % then remove it in half

decoding_scale_dat