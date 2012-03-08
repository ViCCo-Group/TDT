% function [ranks,ind] = wget(labels_train,vectors_train)
% 
% Feature selection subfunction using weights from SVM

function [ranks,ind] = wget(labels_train,vectors_train)

model = svmtrain(labels_train,vectors_train,'-s 0 -t 0 -b 0');

w = model.SVs' * model.sv_coef; 
w = abs(w) .* std(vectors_train,0,1)'; % if unscaled data is used, w scales inversely with the std of each feature

[ind,ranks] = sort(w,'descend');