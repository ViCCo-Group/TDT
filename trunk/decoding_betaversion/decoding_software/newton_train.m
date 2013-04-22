function model = newton_train(labels_train,vectors_train,cfg)

switch lower(cfg.decoding.method)

    case 'classification'
        model = nsvm_train(labels_train,vectors_train);
        if isempty(model), error('nsvm_train returned an empty model - please check that nsvm_train is working properly'), end
    case 'regression'
        model = nsvm_train(labels_train,vectors_train);
        if isempty(model), error('nsvm_train returned an empty model - please check that nsvm_train is working properly'), end
    otherwise
        error('Unknown decoding method %s for cfg.decoding.software = %s',...
            cfg.decoding.method, cfg.decoding.software)
end