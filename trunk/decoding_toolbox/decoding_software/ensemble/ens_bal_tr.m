% function model = ens_bal_tr(labels_train,data_train,cfg)
%
% This is using an ensemble classification approach to balance training
% data. The idea is to create a number of models based on balanced,
% randomly subsampled data. These models are then all evaluated generating
% a decision value for each sample and each model. The decision values are
% then averaged in a sort of weighted majority vote and used for final
% classification. This turns out to be superior to repeated subsampling and
% averaging classification results.
%
% INPUT (n = n_samples, p = n_features):
%   labels_train: nx1 vector of training labels
%   data_train:   pxn matrix of training data or struct with field kernel with nxn kernel matrix
%   cfg: typical cfg struct variable with specific fields (example assumes 'classification')
%           .cfg.decoding.train.classification.model_parameters.software: chosen classifier (example: 'libsvm')
%           .cfg.decoding.train.classification.model_parameters.model_parameters: usual model parameters of chosen classier
%           .cfg.decoding.train.classification.model_parameters.n_iter: how often to randomly subsample (example: 100)
%           .sigma: passed pre-calculated covariance matrix (ignores field
%               .shrinkage
%
% OUTPUT:
%   model: struct variable with the following fields:
%           .model: which again is a struct with size n_iter
%
% 2015/11/04 Martin Hebart

function model = ens_bal_tr(labels_train,data_train,cfg)

try
    param = cfg.decoding.train.(cfg.decoding.method).model_parameters;
    n_iter = param.n_iter;
    classifier = str2func([param.software '_train']);
    modelparam = param.model_parameters;
    
    % overwrite cfg internally for actual classifier
    cfg.decoding.train.(cfg.decoding.method).model_parameters = modelparam;
    
catch %#ok<CTCH>
    disp('Probably one of this was missing and caused the error below:')
    disp(['Required fields for ens_bal_tr (assuming classification): \n',...
        'cfg.decoding.train.classification.model_parameters.n_iter\n',...
        'cfg.decoding.train.classification.model_parameters.software\n',...
        'cfg.decoding.train.classification.model_parameters.model_parameters\n'])
    rethrow(lasterror) %#ok<LERR>
end
    

% Get unique labels and number of labels
ulabels = uniqueq(labels_train);
n_ulabels = length(ulabels);

% Select index to select all labels
n_labels_sub = zeros(n_ulabels,1);
ulabel_ind = cell(n_ulabels,1);
for i_label = 1:length(ulabels)
    ulabel_ind{i_label} = find(labels_train==ulabels(i_label));
    n_labels_sub(i_label) = length(ulabel_ind{i_label});
end

subset_size = min(n_labels_sub);

% Create random index for each label n_iter times (faster)
randmat = cell(n_ulabels,1);
for i_label = n_ulabels
    if n_labels_sub(i_label) == subset_size
       continue 
    end
    [~, randmat{i_label}] = sort(rand(n_iter,n_labels_sub(i_label)),2);
    % sort randmat so we can skip repetitions (TODO: may use persistent variable to run this only once)
    randmat{i_label} = randmat{i_label}(:,1:subset_size);
    randmat{i_label} = sortrows(sort(randmat{i_label},2))';
end

% Create index for later selection of subset of data
ct = 0;
% ind = zeros(n_ulabels*subset_size,n_iter);
for i_label = 1:length(ulabels)
    % Skip iterations where nothing needs to be removed
    if n_labels_sub(i_label) == subset_size
        ind(ct+(1:subset_size),:) = ulabel_ind{i_label}(:,ones(1,n_iter));
        ct = ct+subset_size;
        continue
    end
    ind(ct+(1:subset_size),:) = ulabel_ind{i_label}(randmat{i_label});
    ct = ct+subset_size;
end

% Remove duplicated iterations (ens_bal_te deals with missing entries)
iter_ind = 1:n_iter;
iter_ind([false ~any(diff(ind')')]) = [];

for i_iter = iter_ind
    
    curr_ind = ind(:,i_iter);

    if cfg.decoding.use_kernel
        curr_data_train.kernel = data_train.kernel(curr_ind,curr_ind);
    else
        curr_data_train = data_train(curr_ind,:);
    end
    curr_labels_train = labels_train(curr_ind);
    model.model(i_iter) = classifier(curr_labels_train,curr_data_train,cfg);

end


