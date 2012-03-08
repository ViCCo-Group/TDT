%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Get searchlight template %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [cfg,sl_template] = decoding_prepare_searchlight(cfg,hdr)

% This function computes a reference sphere around zero to use in the 
% definition of searchlights.
% Output sl_template is a struct containing x,y,z displacement for each
% sl_template.index voxel relative to the center of the searchlight (may be
% necessary in get_ind.m)
% Output sl_template.index will give the indices of the searchlight template

% When non-isotropic voxels are used, then the searchlight in real space is
% not spherical, but stretched along the longer dimension. The code below 
% can correct for this by squeezing the searchlight in voxel space. This 
% leads to less voxels in a searchlight, but the appropriate volume.

if ~strcmpi(cfg.analysis,'searchlight')
    sl_template.index = [];
    return
end

% Get voxel dimensions (may become necessary for later correction)
voxdims = abs(sqrt(sum(hdr.mat(1:3,1:3).^2))); % get voxel dimensions from volume header in mm
% Reduce rounding error
voxdims = round(voxdims*1e5)/1e5;

sz = hdr.dim(1:3);
[M.X M.Y M.Z] = ndgrid(1:sz(1),1:sz(2),1:sz(3)); % meshgrid in 3D

if cfg.searchlight.spherical
    proportions = voxdims./min(voxdims); % this gets the voxel proportions
else
    proportions = [1 1 1];
end

if strcmpi(cfg.searchlight.unit,'voxels')
    radius = cfg.searchlight.radius;
elseif strcmpi(cfg.searchlight.unit,'mm')
    radius = cfg.searchlight.radius / min(voxdims); % this converts radius from mm to voxels
end

% This calculates the searchlight indices as a template that will be
% shifted around the volume; it is done in all eight corners of the volume
% and later summed up to prevent problems with a very large searchlight radius
ct = 0;
sl_template.index = cell(1,8);
for i_x = [1 sz(1)]
   for i_y = [1 sz(2)]
       for i_z = [1 sz(3)]
           ct = ct+1;
           ref_vox = [i_x i_y i_z]; % reference voxel location
                      
           % change the matrix for other proportions (used for searchlight template indices)
           Mp.X = proportions(1) * (M.X - ref_vox(1));
           Mp.Y = proportions(2) * (M.Y - ref_vox(2));
           Mp.Z = proportions(3) * (M.Z - ref_vox(3));
           
           sl_sphere_squared = (Mp.X.^2 + Mp.Y.^2 + Mp.Z.^2);
           
           %get searchlight index
           distance_filter = sl_sphere_squared < radius^2;
           sl_template.index{ct} = find(distance_filter);
           % move to position 0
           sl_template.index{ct} = sl_template.index{ct} - sub2ind(sz,ref_vox(1),ref_vox(2),ref_vox(3));
           % save positions of searchlights
           displacement_temp(ct).x = M.X(distance_filter) - ref_vox(1); %#ok<AGROW>
           displacement_temp(ct).y = M.Y(distance_filter) - ref_vox(2); %#ok<AGROW>
           displacement_temp(ct).z = M.Z(distance_filter) - ref_vox(3); %#ok<AGROW>
       end
   end
end

% get searchlight template index for all above
[sl_template.index,unique_indices] = unique(vertcat(sl_template.index{:}));

% only keep position of voxel inside sl_template.index
sl_template.dx = vertcat(displacement_temp(:).x);
sl_template.dx = sl_template.dx(unique_indices);
sl_template.dy = vertcat(displacement_temp(:).y);
sl_template.dy = sl_template.dy(unique_indices);
sl_template.dz = vertcat(displacement_temp(:).z);
sl_template.dz = sl_template.dz(unique_indices);

sl_template.M = M;
cfg.voxdims = voxdims;