function model = correlation_classifier_train(labels_train,vectors_train,i_train,cfg,kernel) %#ok

switch lower(cfg.decoding.method)
    
    case 'classification'
        % essentially, this is the model
        model.vectors_train = vectors_train;
        model.labels_train = labels_train;
        
    case 'classification_kernel'
        % the kernel would be some similarity that is shared in the cross-validation steps, but this method is not implemented, yet
        error('correlation_classifier_train doesn''t work with passed kernels at the moment - please use libsvm or another method instead.')
        
    case 'regression'
        error('correlation_classifier_train cannot be used for a regression analysis - please use libsvm or another method instead.')
        
    otherwise
        error('Unknown decoding method %s for cfg.decoding.software = %s',...
            cfg.decoding.method, cfg.decoding.software)
end