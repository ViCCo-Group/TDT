function [all_same,diff_vol,diff_ind] = compare_volumes(fnames,writeout)

% Function to compare multiple volumes. Should be provided as list of file 
% names. If writeout == 1, then write difference image to pwd, but only if
% there really is a difference!
% If nargout == 2, then also the indices are provided where there is a
% difference in the images.

if exist('writeout','var')
    warning('Nothing is written yet, the function doesn''t support this yet')
end

all_same = 0;
diff_vol = [];
diff_ind = [];

fnames = char(fnames); % if necessary convert from cell to char

hdr = spm_vol(fnames);

for i = 1:length(hdr)
vol{i} = spm_read_vols(hdr(i));
end

if isequal(vol{:})
    disp('All images are the same!')
    if exist('writeout','var') && (writeout ~= 0 || nargout>1)
        disp('No additional output is returned or written, because there is no difference')
    end
    all_same = 1;
    return
end

disp('Images are different. Check output!')

V = zeros([size(vol{1}) length(vol)]);
for i = 1:length(hdr)
    V(:,:,:,i) = vol{i};
    vol{i} = []; % to free memory
end

% Find where they are different: get list of pairs
diff_vol = sum(abs(diff(V,1,4)),4);
diff_ind = find(diff_vol);