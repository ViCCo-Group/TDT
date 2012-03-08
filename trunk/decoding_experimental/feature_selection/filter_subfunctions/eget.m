% function [ranks,ind,external] = eget(cfg,external,i_step)

% Feature selection subfunction using external ranking scheme. For example,
% features can be weighted based on an independent localizer run and the
% according t-values. As another example, an F-test can be applied to each
% training set independently, in that way selecting features independently,
% but optimized for voxels which are maximally activated.

function [ranks,ind,external] = eget(cfg,external,i_step)

% TODO: introduce checks that wrong input will generate appropriate error
% messages

if ~isfield(cfg.feature_selection,'external_fname')
    error('Field ''external_fname'' was not provided for cfg.feature_selection.')
end
external_fname = cfg.feature_selection.external_fname;
if ischar(external_fname)
    external_fname = num2cell(external_fname,2);
end

% if only one image
if length(external_fname) == 1 
    if isfield(external,'ranks_image')
        ranks_image = external.ranks_image{1};
    else
        ranks_hdr = spm_vol(external_fname{1}); % get hdr
        % TODO: introduce check if correct space
        ranks_image = spm_read_vols(ranks_hdr); % get image
        external.ranks_image{1} = ranks_image; % add image to fs_data
    end
% if several images    
elseif length(external_fname) > 1 % TODO: may not work properly
    if isfield(external,'ranks_image')
        ranks_image = external.ranks_image{i_step};
    else
        ranks_hdr = spm_vol(external_fname{i_step}); % get hdr
        % TODO: check if correct space
        ranks_image = spm_read_vols(ranks_hdr); % get image
        external.ranks_image{i_step} = ranks_image; % add image to fs_data
    end
else
    error('Field ''cfg.feature_selection.external_fname'' was empty.')
end

curr_ranks = ranks_image(external.position_index); % use index of current searchlight position to get location information

[ind,ranks] = sort(curr_ranks,'descend');