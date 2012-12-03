function decoding_out = newton_test(labels_test,vectors_test,cfg,model)

switch lower(cfg.decoding.method)

    case 'classification'
        predicted_labels = nsvm_test(labels_test,vectors_test,model);
    case 'regression'
        predicted_labels = nsvm_test(labels_test,vectors_test,model);
        
end

decoding_out.predicted_labels = predicted_labels;
decoding_out.true_labels = labels_test;
decoding_out.decision_values = nan;