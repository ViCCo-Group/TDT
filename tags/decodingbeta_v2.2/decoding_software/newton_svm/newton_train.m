function model = newton_train(labels_train,vectors_train,cfg)

% display newton SVM information
persistent alreadyVisited
if isempty(alreadyVisited)
    alreadyVisited = true; % prevent that this message is shown a second time
    display(char({'-------'
        'The sourcecode for NSVM Newton Support Vector Machine has been downloaded from http://research.cs.wisc.edu/dmi/svm/nsvm'
        ''
        'Authors:'
        'Glenn Fung'
        'Olvi L. Mangasarian'
        ''
        'Copyright:'
        'The software is free for academic use. For commercial use, please contact Olvi Mangasarian (olvi@cs.wisc.edu).'
        ''
        'See also newton_svm/newton_copyright.txt'
        '-------'}))
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