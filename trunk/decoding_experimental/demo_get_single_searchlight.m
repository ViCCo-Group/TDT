%% open figure for later drawing
fighdl = figure;

sl_centers = 1:100:[64*64*32];

for i_decodingstep = sl_centers

    %% prepare searchlight
    cfg.analysis = 'searchlight';
    cfg.searchlight.wrap_control = 1;
    cfg.searchlight.radius = 5;

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

    drawnow
    
    % display total number of voxels
    n_vox = length(indexindex);
    display(['nvox=' num2str(n_vox)])

end