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
    try % if image has been loaded previously
        ranks_image = external.ranks_image{1};
    catch %#ok<CTCH> % otherwise, load image
        ranks_hdr = read_header(cfg.software,external_fname{1});
        if any(ranks_hdr.dim(1:3) ~= cfg.datainfo.dim)
            error('Size of external image(s) for feature selection does not match size of original images!');
        end
        ranks_image = read_image(cfg.software,ranks_hdr); % get image
        external.ranks_image{1} = ranks_image; % add image to fs_data
    end
% if several images    
elseif length(external_fname) > 1
    if i_step > length(external_fname)
        error('The number of external images needs to match the number of cross-validation steps!');
    end
    try % if image has been loaded previously
        ranks_image = external.ranks_image{i_step};
    catch %#ok<CTCH> % otherwise, load image
        ranks_hdr = read_header(cfg.software,external_fname{i_step});
        if any(ranks_hdr.dim(1:3) ~= cfg.datainfo.dim)
            error('Size of external image(s) for feature selection does not match size of original images!');
        end
        ranks_image = read_image(cfg.software,ranks_hdr); % get image
        external.ranks_image{i_step} = ranks_image; % add image to fs_data
    end
else
    error('Field ''cfg.feature_selection.external_fname'' was empty.')
end

curr_ranks = ranks_image(external.position_index); % use index of current searchlight position to get location information

[ind,ranks] = sort(curr_ranks,'descend');