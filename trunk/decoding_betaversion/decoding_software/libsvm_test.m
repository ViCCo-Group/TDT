function decoding_out = libsvm_test(labels_test,data_test,cfg,model)

switch lower(cfg.decoding.method)

    case 'classification'
        [predicted_labels accuracy decision_values] = svmpredict(labels_test,data_test,model,cfg.decoding.test.classification.model_parameters);
        
    case 'classification_kernel'
        % libsvm needs labels for each input, if a kernel is given, thus we
        % add (1:size(data_test,1))' as first column to input data
        [predicted_labels accuracy decision_values] = svmpredict(labels_test,[(1:size(data_test,1))'  data_test],model,cfg.decoding.test.classification_kernel.model_parameters);
        
    case 'regression'
        [predicted_labels accuracy decision_values] = svmpredict(labels_test,data_test,model,cfg.decoding.test.regression.model_parameters);
        
end

decoding_out.predicted_labels = predicted_labels;
decoding_out.true_labels = labels_test;
decoding_out.decision_values = decision_values;