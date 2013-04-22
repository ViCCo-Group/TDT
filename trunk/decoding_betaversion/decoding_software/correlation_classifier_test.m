function decoding_out = correlation_classifier_test(labels_test,vectors_test,i_train,i_test,cfg,model,kernel) %#ok

switch lower(cfg.decoding.method)
    
    case 'classification'
        [predicted_labels decision_values] =  correlation_classifier(labels_test,vectors_test,model);
        
    case 'classification_kernel'
        error('correlation_classifier_test doesn''t work with passed kernels at the moment - please use libsvm or another method instead.')
        
    case 'regression'
        error('correlation_classifier_test cannot be used for a regression analysis - please use libsvm or another method instead.')
        
end

decoding_out.predicted_labels = predicted_labels;
decoding_out.true_labels = labels_test; % TODO: this doesn't work with correlation, because labels_train are also part of true_labels
decoding_out.decision_values = decision_values;

