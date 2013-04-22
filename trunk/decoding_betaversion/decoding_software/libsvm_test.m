function decoding_out = libsvm_test(labels_test,vectors_test,i_train,i_test,cfg,model,kernel)

switch lower(cfg.decoding.method)

    case 'classification'
        [predicted_labels accuracy decision_values] = svmpredict(labels_test,vectors_test,model,cfg.decoding.test.classification.model_parameters);
        
    case 'classification_kernel'
        [predicted_labels accuracy decision_values] = svmpredict(labels_test,[(1:length(i_test))' kernel(i_test,i_train)],model,cfg.decoding.test.classification_kernel.model_parameters);
        
    case 'regression'
        [predicted_labels accuracy decision_values] = svmpredict(labels_test,vectors_test,model,cfg.decoding.test.regression.model_parameters);
        
end

decoding_out.predicted_labels = predicted_labels;
decoding_out.true_labels = labels_test;
decoding_out.decision_values = decision_values;