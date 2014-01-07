% function [cfg sortind, sortind_inv] = sort_design(cfg,sortind)
%
% This function is used to sort designs in a way to speed up decoding
% analyses. If training data happen to be identical in two of the many
% cross-validation iterations, then re-training of data is not necessary.
% decoding.m can recognize this and skip repeated training.
%
% Input:
%   cfg: with fields design.train, design.test, design.label and design.set
%   sortind (optional): If sorting should be done manually. This may be
%       useful e.g.to revert the sorting process later if requested.
%
% Output:
%   cfg: sorted
%   sortind: index used for sorting (if interesting)
%   sortind_inv: index necessary to invert sorting to original (if interesting)

function [cfg,sortind,sortind_inv] = sort_design(cfg,sortind)

tr = cfg.design.train;

if ~exist('sortind','var')
    
    sortind = 1:size(tr,2);
    for i = size(tr,1):-1:1
        [ignore,subind] = sort(tr(end+1-i,:));
        sortind = sortind(subind);
    end
    
end

cfg.design.train = cfg.design.train(:,sortind);
cfg.design.test  = cfg.design.test(:,sortind);
cfg.design.label = cfg.design.label(:,sortind);
cfg.design.set   = cfg.design.set(sortind);

reverse = 1:size(tr,2);
sortind_inv(sortind) = reverse;

