function model = newton_train(labels_train,data_train,cfg)

switch lower(cfg.decoding.method)

    case 'classification'
        model = nsvm_train(labels_train,data_train,-1);
        if isempty(model), error('nsvm_train returned an empty model - please check that nsvm_train is working properly'), end
        
    case 'classification_kernel'
        error('nsvm_train doesn''t work with passed kernels at the moment - please use libsvm or another method instead.')
        
    case 'regression'
        error('nsvm_train cannot be used for a regression analysis - please use libsvm or another method instead.')
        
    otherwise
        error('Unknown decoding method %s for cfg.decoding.software = %s',...
            cfg.decoding.method, cfg.decoding.software)
end