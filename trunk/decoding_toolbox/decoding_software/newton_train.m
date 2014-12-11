function model = newton_train(labels_train,data_train,cfg)

if isstruct(data_train), error('This method requires training vectors in data_train directly. Probably a kernel was passed method is use. This method does not support kernel methods'), end

switch lower(cfg.decoding.method)

    case 'classification'
        % newtonsvm assumes only -1 and 1 as label, verifying that's true
        if ~all(labels_train == -1 | labels_train == 1)
            error('Newtonsvm takes only -1 and 1 as label, but other labels are present in training set. Aborting')
        end
        % train newton svm
        try
            model = nsvm_train(labels_train,data_train,cfg.decoding.train.newton_nu);
        catch e
            % check if no nu has been defined
            if strcmp('Reference to non-existent field ''newton_nu''.', e.message)
                error('Newton-SVM is used as decoding software, but no nu-parameter is provided in cfg.decoding.train.newton_nu. Please provide nu (e.g. cfg.decoding.train.newton_nu = 0; see nsvm_train.m for details)');
            else
                rethrow e
            end
        end
        if isempty(model), error('nsvm_train returned an empty model - please check that nsvm_train is working properly'), end
        
    case 'classification_kernel'
        % Develop: If you implement this, adapt error at the beginning
        error('nsvm_train doesn''t work with passed kernels at the moment - please use libsvm or another method instead.')
        
    case 'regression'
        error('nsvm_train cannot be used for a regression analysis - please use libsvm or another method instead.')
        
    otherwise
        error('Unknown decoding method %s for cfg.decoding.software = %s',...
            cfg.decoding.method, cfg.decoding.software)
end