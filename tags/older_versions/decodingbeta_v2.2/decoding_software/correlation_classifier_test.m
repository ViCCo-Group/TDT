function decoding_out = correlation_classifier_test(labels_test,vectors_test,cfg,model)

switch lower(cfg.decoding.method)
    
    case 'classification'
        [predicted_labels decision_values] =  correlation_classifier(labels_test,vectors_test,model);
        
end

decoding_out.predicted_labels = predicted_labels;
decoding_out.true_labels = labels_test; % TODO: this doesn't work with correlation, because labels_train are also part of true_labels
decoding_out.decision_values = decision_values;

