% function prevalence_savedata_to_images(outputfilename, mask, gamma0, at, vol)
%
% Helper function to save data from the prevalence analysis to an image. 
% Will create
%   _gamma0.nii
%   _mask.nii
%   _typical.nii
%
% IN
%   outputfilename: Filename with full path to be put before the three
%       images.
%   mask: Volume with true where data should be written to. Will be written
%       to _mask.nii.
%   gamma0: The value(s) for gamma0 (the prevalence map). Either as many as 
%       true values in  the mask, or 1 value, then all true values will be 
%       the same, e.g. in ROI analyses or wholebrain; written to gamma0.nii
%   at: Same as above but values of the "typical map"; written to 
%       _typical.nii
%   vol: should contain a 4x4 transformation/rotation matrix. 
%
% Kai, 2016/07/25 (adapted from Carstens original function)

function prevalence_savedata_to_images(outputfilename, mask, gamma0, at, vol)
display(['Saving gamma0.nii, typical.nii, and mask.nii images for ' outputfilename])
data = nan(size(mask));
data(mask) = gamma0;
saveMRImage(data, [outputfilename '_gamma0.nii'], vol.mat, 'prevalence map')
data = nan(size(mask));
data(mask) = at;
saveMRImage(data, [outputfilename '_typical.nii'], vol.mat, 'typical map')
saveMRImage(uint8(mask), [outputfilename '_mask.nii'], vol.mat, 'prevalence map mask')
% stored mask values end up to be 1.00000005913898 instead of 1 - why?