% Demo how to get individual searchlights (just in case you want)
% 
% CHANGE .dim + sz and sl_centers to your dimensions
% 
% sl_center is the index in the 3d image where the searchlight is centered.
%
% You could get a formula for this with meshgrid (if you want to avoid
% thinking) or run the searchlights as is currently implemeted and wait.
% 
% Suggestions: check what happens for 
%   cfg.searchlight.wrap_control = 0
%
% Enjoy

% Kai, 14/09/15

%% open figure for later drawing
fighdl = figure;

sl_centers = 1:100:[64*64*32];

for i_decodingstep = sl_centers

    %% prepare searchlight
    cfg.analysis = 'searchlight';
    cfg.searchlight.wrap_control = 1;
    cfg.searchlight.radius = 3;

    cfg.datainfo.dim = [64, 64, 32]; % DIMENSIONS of original data

    cfg.searchlight.unit = 'voxels';
    cfg.searchlight.spherical = 0;

    [cfg,sl_template] = decoding_prepare_searchlight(cfg);

    %% get searchlight indices
    mask_index = 1:[64*64*32]; % 
%     i_decodingstep = 20000;
    sz = [64, 64, 32]; % DIMENSION of the original image

    indexindex = get_ind(cfg,mask_index,i_decodingstep,sz,sl_template);

    %% plot
    plot_selected_voxels(indexindex,sz, '', '', '', fighdl)
    
    % display total number of voxels
    n_vox = length(indexindex);
    display(['nvox=' num2str(n_vox)])

end