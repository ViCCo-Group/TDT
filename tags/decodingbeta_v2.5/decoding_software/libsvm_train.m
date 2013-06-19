function model = libsvm_train(labels_train,data_train,cfg)

switch lower(cfg.decoding.method)

    case 'classification'
        model = svmtrain(labels_train,data_train,cfg.decoding.train.classification.model_parameters);
        if isempty(model), error('svmtrain returned an empty model - please check that svmtrain is working properly'), end
        
    case 'classification_kernel'
        % libsvm needs labels for each input, if a kernel is given, thus we
        % add (1:size(data_train,1))' as first column to input data
        model = svmtrain(labels_train,[(1:size(data_train,1))' data_train],cfg.decoding.train.classification_kernel.model_parameters);
        if isempty(model), error('svmtrain returned an empty model - please check that svmtrain is working properly'), end
        
    case 'regression'
        model = svmtrain(labels_train,data_train,cfg.decoding.train.regression.model_parameters);
        if isempty(model), error('svmtrain returned an empty model - please check that svmtrain is working properly'), end
        
    otherwise
        error('Unknown decoding method %s for cfg.decoding.software = %s',...
            cfg.decoding.method, cfg.decoding.software)
end