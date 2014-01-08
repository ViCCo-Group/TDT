% function decoding_out = libsvm_test(labels_test,data_test,cfg,model)
%
% Wrapper function for libsvm.
%
% See libsvm_train.m for details.

% Adapted to passing kernel as .kernel

function decoding_out = libsvm_test(labels_test,data_test,cfg,model)

try
    switch lower(cfg.decoding.method)

        case 'classification'
            if isstruct(data_test), error('Classification wiithout kernel needs the data in vector format'), end
            [predicted_labels accuracy decision_values] = svmpredict(labels_test,data_test,model,cfg.decoding.test.classification.model_parameters);
        
        case 'classification_kernel'
            % libsvm needs labels for each input, if a kernel is given, thus we
            % add (1:size(data_test,1))' as first column to input data
            [predicted_labels accuracy decision_values] = svmpredict(labels_test,[(1:size(data_test.kernel,1))'  data_test.kernel],model,cfg.decoding.test.classification_kernel.model_parameters);

        case 'regression'
            if isstruct(data_test), error('Regression without kernel needs the data in vector format'), end
            [predicted_labels accuracy decision_values] = svmpredict(labels_test,data_test,model,cfg.decoding.test.regression.model_parameters);

    end

    if isempty(predicted_labels), error('svmtest returned empty predictions - please check that svmtest is working properly'), end
    
    decoding_out.predicted_labels = predicted_labels;
    decoding_out.true_labels = labels_test;
    decoding_out.decision_values = decision_values;
    
% end of normal function

catch %#ok<CTCH>
    [e.message,e.identifier] = lasterr; % for downward compatibility keep separate from catch
    if strcmp(e.identifier, 'MATLAB:nonStrucReference') && ~isfield(data_test, 'kernel')
        error('Using Kernel method, but data was not passed as data_test.kernel. More infos below this error')
        %           You most likely
        %             (a) passed data as vectors, OR
        %             (b) passed the kernel in the old format (not as data.kernel).
        %           Right?
        %           If (a), use a non-kernel method, or calculate the kernel with
        %           your test-data and pass it as data.kernel (I have no idea
        %           though how you can get the trainingdata easily).
    else
        rethrow(e)
    end
end
