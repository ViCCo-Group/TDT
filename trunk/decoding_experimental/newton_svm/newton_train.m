function model = newton_train(labels_train,vectors_train,cfg)

% display newton SVM information
persistent alreadyVisited
if isempty(alreadyVisited)
    alreadyVisited = true; % prevent that this message is shown a second time
    display(sprintf(['-------\n' ...
        'NEWTON_SVM: TODO: ADD AUTHOR, COPYRIGHT, ETC INFORMATION HERE!\n' ...
        '-------']))
end

% call training
switch lower(cfg.decoding.method)

    case 'classification'
        model = nsvm_train(labels_train,vectors_train);
        if isempty(model), error('svmtrain returned an empty model - please check that svmtrain is working properly'), end
    case 'regression'
        model = nsvm_train(labels_train,vectors_train);
        if isempty(model), error('svmtrain returned an empty model - please check that svmtrain is working properly'), end
    otherwise
        error('Unknown decoding method %s for cfg.decoding.software = %s',...
            cfg.decoding.method, cfg.decoding.software)
end