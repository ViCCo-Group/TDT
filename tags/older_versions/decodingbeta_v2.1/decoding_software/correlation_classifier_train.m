function model = correlation_classifier_train(labels_train,vectors_train,cfg)

switch lower(cfg.decoding.method)
    
    case 'classification'
        % essentially, this is the model
        model.vectors_train = vectors_train;
        model.labels_train = labels_train;
        
    otherwise
        error('Unknown decoding method %s for cfg.decoding.software = %s',...
            cfg.decoding.method, cfg.decoding.software)
end