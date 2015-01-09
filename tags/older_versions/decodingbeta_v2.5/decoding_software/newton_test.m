function decoding_out = newton_test(labels_test,data_test,cfg,model)

switch lower(cfg.decoding.method)

    case 'classification'
        predicted_labels = nsvm_test(labels_test,data_test,model);
    case 'classification_kernel'
        error('nsvm_test doesn''t work with passed kernels at the moment - please use libsvm or another method instead (or edit nsvm so that it takes kernels and send it to the development team ;).')        
    case 'regression'
        error('nsvm_test cannot be used for a regression analysis - please use libsvm or another method instead.')
        
end

decoding_out.predicted_labels = predicted_labels;
decoding_out.true_labels = labels_test;
decoding_out.decision_values = nan;