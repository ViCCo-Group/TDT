function model = libsvm_train(labels_train,vectors_train,i_train,cfg,kernel)

switch lower(cfg.decoding.method)

    case 'classification'
        model = svmtrain(labels_train,vectors_train,cfg.decoding.train.classification.model_parameters);
        if isempty(model), error('svmtrain returned an empty model - please check that svmtrain is working properly'), end
        
    case 'classification_kernel'
        model = svmtrain(labels_train,[(1:length(i_train))' kernel(i_train,i_train)],cfg.decoding.train.classification_kernel.model_parameters);
        if isempty(model), error('svmtrain returned an empty model - please check that svmtrain is working properly'), end
        
    case 'regression'
        model = svmtrain(labels_train,vectors_train,cfg.decoding.train.regression.model_parameters);
        if isempty(model), error('svmtrain returned an empty model - please check that svmtrain is working properly'), end
        
    otherwise
        error('Unknown decoding method %s for cfg.decoding.software = %s',...
            cfg.decoding.method, cfg.decoding.software)
end