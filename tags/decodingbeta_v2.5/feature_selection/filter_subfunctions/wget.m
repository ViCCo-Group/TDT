% function [ranks,ind] = wget(labels_train,vectors_train,cfg)
% 
% Feature selection subfunction using weights from SVM

function [ranks,ind] = wget(labels_train,vectors_train,cfg)

model = svmtrain(labels_train,vectors_train,cfg.feature_selection.decoding.train.classification.model_parameters);

w = model.SVs' * model.sv_coef; 
w = abs(w) .* std(vectors_train,0,1)'; % if unscaled data is used, w scales inversely with the std of each feature

[ind,ranks] = sort(w,'descend');