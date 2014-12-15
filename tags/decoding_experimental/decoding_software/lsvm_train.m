function model = lsvm_train(labels_train,data_train,cfg)

if isstruct(data_train), error('This method requires training vectors in data_train directly. Probably a kernel was passed method is use. This method does not support kernel methods'), end
if ischar(cfg.decoding.train.classification.model_parameters, error('Pass model parameters as struct, not as char. Type ''pegasos_train'' to see details on passing'); end

switch lower(cfg.decoding.method)

    case 'classification'
        w = pegasos_train(data_train',labels_train',cfg.decoding.train.classification.model_parameters);
        model.w = w(1:end-1); model.b = w(end);
        if isempty(model), error('pegasos_train returned an empty model - please check that pegasos_train is working properly'), end
        
    case 'classification_kernel'
        % Develop: If you implement this, adapt error at the beginning
        error('pegasos_train doesn''t work with passed kernels at the moment - please use libsvm or another method instead.')
        
    case 'regression'
        error('pegasos_train cannot be used for a regression analysis - please use libsvm or another method instead.')
        
    otherwise
        error('Unknown decoding method %s for cfg.decoding.software = %s',...
            cfg.decoding.method, cfg.decoding.software)
end