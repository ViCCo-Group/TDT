% function plot_selected_voxels(position_index,sz,brain_data,mask_index,boarder_images)
%
% This function plots a given voxelselection (e.g. searchlight, ROI), and
% can in addition show a 2d projection of an image.
%
% Example usages:
%   plot_selected_voxels(position_index,sz)
%       Plot currently selected voxels only (no background image)
%   plot_selected_voxels(position_index,sz,brain_data,mask_index)
%       Plot searchlight + background
%   plot_selected_voxels(...,boarder_images)    
%       Additionally select how the 2d boarder image should look like
%       
%
% PARAMETER
%   position_index: vector 1xn with indices of voxels in sz space
%   sz: 1x3 vector: dimensions of original images
% OPTIONAL (to add background image)
%   brain_data: 1xBD vector with values of an input image 
%       (e.g. the first brain image), serves as background
%   mask_index: 1xBD vector specifying the position of each value in 
%       brain_data in the sz-dimensional space
%   borader_image: specify type of background image. Possible value:
%       'projection', 'slices', 'projection+slices' (default)
%
% Martin Hebart, Kai Görgen, 2013/04/14      

% Possible IMPROVEMENTS:
% Speed-Up - Ideas: 
%   - only update the SL, i.e. remove voxels that are not there any longer, 
%       and add voxels that are new
%   - do not draw projections over and over, but only once
%       but of course plot searchlight
%   -- somewhere on the way there: save projections

function plot_selected_voxels(position_index,sz,brain_data,mask_index,boarder_images)

% check that the correct arguments are provided
if exist('brain_data', 'var')
    if ~exist('mask_index', 'var')
        error('brain_data is provided, but mask_index not. Both arguments must be provided')
    end
end

%%
% position_index: indices of all voxel positions
% sz: size of volume (optional)

vertex_matrix = [0 0 0
1 0 0
1 1 0
0 1 0
0 0 1
1 0 1
1 1 1
0 1 1];
faces_matrix = [1 2 6 5
2 3 7 6
3 4 8 7
4 1 5 8
1 2 3 4
5 6 7 8];

n_vox = length(position_index);

large_vertex_matrix = zeros(n_vox* size(vertex_matrix,1), size(vertex_matrix,2));
large_faces_matrix = zeros(n_vox * size(faces_matrix,1), size(faces_matrix,2));

[px,py,pz] = ind2sub(sz,position_index);

for i = 1:n_vox
    xpos = (i-1)*8 + (1:8);
%     large_vertex_matrix(xpos,:) = bsxfun(@plus,vertex_matrix,[M.X(position_index(i)) M.Y(position_index(i)) M.Z(position_index(i))]);
    large_vertex_matrix(xpos,:) = bsxfun(@plus,vertex_matrix,[px(i) py(i) pz(i)]);    
    xpos = (i-1)*6 + (1:6);
    large_faces_matrix(xpos,:) = faces_matrix + (i-1)*8;
end

clf
h = patch('Vertices',large_vertex_matrix,'Faces',large_faces_matrix,...
'FaceVertexCData',ones(8*length(position_index),1) * [.9 .2 .4],'FaceColor','interp',...
'EdgeColor',[0.2 0.2 0.2]);
axis([0 sz(1) 0 sz(2) 0 sz(3)])

%% Plot brain on x,y,z plane, if provided

if exist('brain_data', 'var')
    if ~exist('mask_index', 'var')
        error('brain_data is provided, but mask_index not. Both arguments must be provided')
    end
    
    % replace possible nans by 0
    brain_data(isnan(brain_data)) = 0;

    % normalize gray values for plotting
    brain_data = (brain_data-min(brain_data(:)))/(max(brain_data(:))-min(brain_data(:)));

    % put brain into a full volume (at the moment, we only have the masked
    % brain)
    brain = zeros(sz);
    brain(mask_index) = brain_data*0.9+0.1; % *.9 + .1 serves to differentiate between inmask and outmask voxels

    % % TODO:
    % % - only project outer voxels 
    %

    if ~exist('boarder_image', 'var')
        boarder_images = 'projection+slices'; % choose if you want to project slice (e.g. the middle) or the projection
    end
    % check that value is valid
    if ~(strcmp(boarder_images, 'projection') || strcmp(boarder_images, 'projection+slices') || strcmp(boarder_images, 'slices'))
        error('Unkown projection method for boarder_images, please check')
    end

    if strcmp(boarder_images, 'projection') || strcmp(boarder_images, 'projection+slices')
        z_projection = sum(brain, 3)';
        x_projection = squeeze(sum(brain, 2))';
        y_projection = squeeze(sum(brain, 1))';   
        
        % normalize colours between 0 / 1
        min_value = min([z_projection(:); x_projection(:); y_projection(:)]);
        max_value = max([z_projection(:); x_projection(:); y_projection(:)]);
        z_projection = (z_projection-min_value)/(max_value-min_value);
        x_projection = (x_projection-min_value)/(max_value-min_value);
        y_projection = (y_projection-min_value)/(max_value-min_value);

        z_background = z_projection;
        x_background = x_projection;
        y_background = y_projection;
    end

    if strcmp(boarder_images, 'slices') || strcmp(boarder_images, 'projection+slices')
        z_slice = brain(:,:,round(sz(3)/2))';
        x_slice = squeeze(brain(:,round(sz(2)/2),:))';
        y_slice = squeeze(brain(round(sz(1)/2),:,:))';
        % no normalization needed, is already normalized above
    end


    if strcmp(boarder_images, 'projection+slices')
        z_background(z_slice>0) = z_slice(z_slice>0);
        x_background(x_slice>0) = x_slice(x_slice>0);
        y_background(y_slice>0) = y_slice(y_slice>0);
    elseif strcmp(boarder_images, 'slices')
        z_background = z_slice;
        x_background = x_slice;
        y_background = y_slice;
    end

    % add projection of searchlight onto image
    sl_3d = zeros(size(brain));
    sl_3d(position_index) = 1;
    % add projection to slices
    z_sl_projection = sum(sl_3d, 3) > 0;
    z_background(z_sl_projection') = 1;
    x_sl_projection = squeeze(sum(sl_3d, 2) > 0);
    x_background(x_sl_projection') = 1;
    y_sl_projection = squeeze(sum(sl_3d, 1) > 0);
    y_background(y_sl_projection') = 1;

    % x and y are flipped
    [x,y] = meshgrid(1:sz(1),1:sz(2));
    surface(x,y,zeros(size(x)),z_background);
    colormap('gray')
    % shading flat
    [x,z] = meshgrid(1:sz(1),1:sz(3));
    surface(sz(2)*ones(size(x)),x,z,y_background);
    colormap('gray')
    % shading flat
    [y,z] = meshgrid(1:sz(2),1:sz(3));
    surface(y,sz(1)*ones(size(y)),z,x_background);
    colormap('gray')
    % shading flat
end

%% draw image
drawnow
