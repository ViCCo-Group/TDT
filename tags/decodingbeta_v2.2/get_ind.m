% function indexindex = get_ind(cfg,mask_index,i_decodingstep,sz,sl_template)
%
% Subfunction for decoding.m
% This function gets the indices for the current step of the decoding
% analysis (i.e. the current searchlight for searchlight decoding or the
% current ROI for ROI decoding).
%
% Martin Hebart, 2011/06/13

% TODO comment: At current, we need to load ROI masks again here, because
% they may overlap and there is no easy way to assign indices. It may
% however be possible to overcome this problem in the mask definition.
% Since we can assume that masks don't overlap a lot, we could load all
% data for all masks, i.e. that some data would be loaded twice. Then we
% would pass mask indices for each ROI. This should be done in a future
% release.

% HISTORY
% KAI, 11/07/01
%   wrap-around correction and cfg.searchlight.wrap_control added

function indexindex = get_ind(cfg,mask_index,i_decodingstep,sz,sl_template)

if strcmpi(cfg.analysis,'searchlight')
    % Get the current searchlight position as index
    position_index = sl_template.index + mask_index(i_decodingstep); % position_index gives the position of searchlight in the data

    if cfg.searchlight.wrap_control
        % Get the current searchlight position as coordinates
        xpos = sl_template.M.X(mask_index(i_decodingstep));
        ypos = sl_template.M.Y(mask_index(i_decodingstep));
        zpos = sl_template.M.Z(mask_index(i_decodingstep));

        % Check for wraparound
        position_filter = ...
            sl_template.dx + xpos > 0 & ...  % distance to 0 in all dimensions
            sl_template.dy + ypos > 0 & ...
            sl_template.dz + zpos > 0 & ...
            sl_template.dx + xpos <= sz(1) & ...  % distance to xyz dimensions
            sl_template.dy + ypos <= sz(2) & ...
            sl_template.dz + zpos <= sz(3);

        position_index = position_index(position_filter);
    end

%     [position_index,indexindex] = intersect(mask_index,position_index);
    indexindex0 = ismembc2(position_index,mask_index); % much faster than intersect
    indexindex = indexindex0(indexindex0 > 0); % indexindex give these indices relative to the indices of the mask

elseif strcmpi(cfg.analysis,'ROI')

    % as noted above, not very efficient to load masks again, but better
    % readability (and probably doesn't matter much, because most of the
    % time only a few ROIs are loaded)

    mask_names = cfg.files.mask;

    if ischar(mask_names) % to deal with different types of input
        mask_names = num2cell(mask_names,2);
    end

    fname = mask_names{i_decodingstep};
    hdr = spm_vol(fname); % get headers of mask
    mask = spm_read_vols(hdr); % get mask
    
    % Select indices that relate to the ROI within mask_indices
    [c,indexindex] = intersect(mask_index,find(mask));
    
    if isempty(indexindex)
        error('There is no overlap between mask %s and the decoding data, check position of mask!',fname)
    end
        
elseif strcmpi(cfg.analysis,'wholebrain')

    indexindex = 1:length(mask_index);

end