function decoding_out = weighted_correlation_classifier_test(labels_test,data_test,cfg,model)

if isstruct(data_test), error('This method requires training vectors in data_test directly. Probably a kernel was passed method is use. This method does not support kernel methods'), end

switch lower(cfg.decoding.method)
    
    case 'classification'
        [predicted_labels decision_values not_unique] = weighted_distance_classifier(labels_test,data_test,model,cfg.decoding.pdist_distance);
        
    case 'classification_kernel'
        % Develop: If you implement this, adapt error at the beginning
        error('correlation_classifier_test doesn''t work with passed kernels at the moment - please use libsvm or another method instead.')
        
    case 'regression'
        error('correlation_classifier_test cannot be used for a regression analysis - please use libsvm or another method instead.')
        
end

decoding_out.predicted_labels = predicted_labels;
decoding_out.true_labels = labels_test;
decoding_out.decision_values = decision_values;
decoding_out.not_unique = not_unique; % shows which classes multiple equal max decision values from different classes

