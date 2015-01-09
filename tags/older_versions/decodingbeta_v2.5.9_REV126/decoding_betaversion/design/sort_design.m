% function cfg = sort_design(cfg)
%
% This function is used to sort designs in a way to speed up decoding
% analyses. If training data happen to be identical in two of the many
% cross-validation iterations, then re-training of data is not necessary.
% decoding.m can recognize this and skip repeated training.

function cfg = sort_design(cfg)

tr = cfg.design.train;
sortind = 1:size(tr,2);
for i = size(tr,1):-1:1
    [ignore,subind] = sort(tr(end+1-i,:));
    sortind = sortind(subind);
end

cfg.design.train = cfg.design.train(:,sortind);
cfg.design.test  = cfg.design.test(:,sortind);
cfg.design.label = cfg.design.label(:,sortind);
cfg.design.set   = cfg.design.set(sortind);



