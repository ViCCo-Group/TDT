% function n_decodings = get_n_decodings(cfg,mask_index)
%
% Function for decoding. Determines number of times a full classification 
% is performed (e.g. number of searchlights or number of ROIs).

function n_decodings = get_n_decodings(cfg,mask_index)

if strcmpi(cfg.analysis,'searchlight')
    n_decodings = length(mask_index); % number of voxels
elseif strcmpi(cfg.analysis,'roi')
    n_decodings = numel(cfg.files.mask); % number of ROI masks
elseif strcmpi(cfg.analysis,'wholebrain')
    n_decodings = 1; % there can only be one brain
end