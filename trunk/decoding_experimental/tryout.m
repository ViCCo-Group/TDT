% check if decoding.m is in path, otherwise abort

if isempty(which('decoding.m'))
    error('Please add TDT to the matlab path')
end

% initialize TDT & cfg
cfg = decoding_defaults;

%% Create simulated data

smooth_on = 0;
snr = 0.8;
n_runs = 6;
n_files_per_run = 8;
n_files = n_files_per_run * n_runs;

label = repmat(kron([1 -1],ones(1,n_files_per_run/2)),1,n_runs)';
chunk = kron(1:n_runs,ones(1,n_files_per_run))';

sz = [64 64 16];

[x,y,z] = ndgrid(linspace(-1,1,sz(1)),linspace(-1,1,sz(2)),linspace(-1,1,sz(3)));
mask = (x.^2+y.^2+z.^2)<=1;
mask_index = find(mask);

tdt = false(sz);
tdt(:,:,round(sz(3)/2)) = ~(double(imread('tdt.bmp'))/255);

% create signal for tdt region
signal = snr*randn(sum(tdt(:)),1);

% TODO: the solution will probably be to introduce this noise correlation
% across samples more effectively

% create correlated noise for tdt region
corrnoise = randn(sum(tdt(:)),1);

% get position where there should be noise correlation with noise in tdt region
z = round(sz(3)/4); % get slice
[x,y] = meshgrid(1:sz(1),1:sz(2));
circ = find(((x-sz(1)/2).^2+(y-sz(2)/2).^2) < 0.3*(sz(1)/2)^2);
[x,y] = ind2sub(sz(1:2),circ);
noisecorr_ind = sub2ind(sz(1:3),x,y,z*ones(size(y)));

% Create repeated regions where this noise will correlate
n_rep = ceil(length(noisecorr_ind)/sum(tdt(:)));
correlated_noise = repmat(corrnoise,1,n_rep);
correlated_noise = correlated_noise(1:length(noisecorr_ind))';

% Start with noise everywhere
data_orig = randn([sz n_files]);

% Mask noise by mask and add signal in all volumes with label 1 at position of tdt

for i_vol = 1:n_files
    cdat = data_orig(:,:,:,i_vol);
    cdat(noisecorr_ind) = cdat(noisecorr_ind)+correlated_noise;
    cdat(tdt) = cdat(tdt)+corrnoise;
    if label(i_vol)==1
        cdat(tdt) = cdat(tdt)+signal;
    end
    if smooth_on
        fprintf('Smoothing volume %i/%i\n',i_vol,n_files)
        cdat = smooth3(cdat,'gaussian',[7 7 7],2.54798);
    end
    cdat(~mask) = NaN;
    data_orig(:,:,:,i_vol) = cdat;
end

% TODO: add run-specific noise component

% Convert data to 2D matrix
data = reshape(data_orig,[prod(sz) n_files])';
data = data(:,mask_index);

%% Set parameters

cfg.analysis = 'wholebrain'; % alternatives: 'searchlight', 'wholebrain' ('ROI' does not make sense here);
cfg.searchlight.radius = 2; % set searchlight size
% Define whether you want to see the searchlight
cfg.plot_selected_voxels = 0; % all x steps, set 0 for not plotting, 1 for each step, 2 for each 2nd, etc

if strcmpi(cfg.analysis,'searchlight')
    cfg.results.output = {'accuracy_minus_chance'};
    cfg.decoding.method = 'classification_kernel';
else
    cfg.results.output = {'primal_SVM_weights_nobias'};
    cfg.decoding.method = 'classification';
end

%% Set the output directory where data will be saved
% cfg.results.dir = % e.g. 'toyresults'
cfg.results.write = 0; % no results are written to disk

%% Fill passed_data

passed_data.data = data;
passed_data.dim = sz;
passed_data.mask_index = mask_index;

[passed_data,cfg] = fill_passed_data(passed_data,cfg,label,chunk);

%% Make design

if strcmpi(cfg.analysis,'searchlight')
cfg.design = make_design_cv(cfg);
elseif strcmpi(cfg.analysis,'wholebrain')
    cfg.files.chunk = ones(size(cfg.files.chunk));
    cfg.design = make_design_alldata(cfg);
end

%% Run
results = decoding(cfg,passed_data);

%% Convert to results volume
resvol = zeros(sz);
if strcmpi(cfg.analysis,'searchlight')
    resvol(mask_index) = results.accuracy_minus_chance.output;
else
    resvol(mask_index) = results.primal_SVM_weights_nobias.output{1}{1};
end
figure
imagesc(transform_vol(resvol))