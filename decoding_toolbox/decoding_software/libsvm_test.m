% function decoding_out = libsvm_test(labels_test,data_test,cfg,model)
%
% Wrapper function for libsvm. Used in combination with libsvm_train.m
%
% OUT
% decoding_out.predicted_labels: 1xn vector with predicted labels for each 
%                                test sample
%      decoding_out.true_labels: 1xn vector with true labels for each 
%                                test sample
%  decoding_out.decision_values: 1xn vector(two-class) or
%                                nxm matrix (multi-class) with decision 
%                                values for n training samples (of m
%                                pairwise classifiers) with the svm 
%                                decision values. (Not sure about m for
%                                regression, let us know if you know).
%                    NOTE: For classification & classification_kernel 
%                          (NOT for regression) the multiclass decision 
%                          values are in CANONCIAL  form, i.e. as if the 
%                          labels would have been provided to libsvm sorted.
%                          I.e. this is then NOT the output of libsvm.
%                          E.g.: columns of dv for labels [2 4 1] are
%                          1vs2 1vs4 2vs4.
%                          With LIBSVM probability output (-b 1), this
%                          field contains one probability column per
%                          class, reordered to ascending label order.
%                          For more on multiclass, see text in the header
%                          below this (i.e. type edit libsvm_test.m and 
%                          scroll down).
%            decoding_out.model: the libsvm model as from libsvm_train
%           decoding_out.opt = [];
%
% See also: libsvm_train.m
%
% Kai, 2020-06-17: Major update to canonical dv format from libsvm_test.m

% Adapted to passing kernel as .kernel

% Brief explanation of decision values and how they are used to get the
% predicted labels:
% In two-class classification, there is either a value <0 or >0, and the
% value >0 will refer to the first label. For multiple predicted labels,
% there is an nx1 vector
% In multiclass classification, there is an nxm matrix where m is the
% number of classes and n the number of predicted labels. Each row
% corresponds to the one-vs-one comparison: the first entry is label1 vs.
% label2, the second label1 vs. label 3, until label1 vs. label n, and then
% label2 vs. label 3, until label2 vs. label n, etc. If the first class is
% predicted, the value will be positive, if the second is predicted, the
% value will be negative. Now there are three predictions for one
% predicted label where all will definitely be wrong because the comparison
% doesn't contain the predicted label. One-vs-one chooses the label by
% majority vote. If there is a draw, the first label is chosen by default
% by libsvm. transres_confusion_matrix instead resolves these draws using
% decision-value strength; transres_confusion_matrix_plus_undecided reports
% them in an additional undecided column.

function decoding_out = libsvm_test(labels_test,data_test,cfg,model)

try
    switch lower(cfg.decoding.method)

        case 'classification'
            if isstruct(data_test), error('Classification wiithout kernel needs the data in vector format'), end
            test_parameters = cfg.decoding.test.classification.model_parameters;
            [predicted_labels,accuracy,decision_values] = svmpredict(labels_test,data_test,model,test_parameters); %#ok<*ASGLU>
            decision_values = sort_results(decision_values,model.Label,test_parameters);
            
        case 'classification_kernel'
            % libsvm needs labels for each input, if a kernel is given, thus we
            % add (1:size(data_test,1))' as first column to input data
            test_parameters = cfg.decoding.test.classification_kernel.model_parameters;
            [predicted_labels,accuracy,decision_values] = svmpredict(labels_test,[(1:size(data_test.kernel,1))'  data_test.kernel],model,test_parameters);
            decision_values = sort_results(decision_values,model.Label,test_parameters);

        case 'regression'
            if isstruct(data_test), error('Regression without kernel needs the data in vector format'), end
            [predicted_labels, accuracy, decision_values] = svmpredict(labels_test,data_test,model,cfg.decoding.test.regression.model_parameters);

    end

    if isempty(predicted_labels), error('libsvm''s svmpredict returned empty predictions - please check your design, whether the model was passed properly, or whether you are using the correct version of svmpredict.'), end
    
    decoding_out.predicted_labels = predicted_labels;
    decoding_out.true_labels = labels_test;
    decoding_out.decision_values = decision_values;
    decoding_out.model = model;
    decoding_out.opt = [];
    
% end of normal function

catch %#ok<CTCH>
    [e.message,e.identifier] = lasterr; %#ok<LERR> % for downward compatibility keep separate from catch
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



function decision_values = sort_results(decision_values,labelorder,test_parameters)

% With -b 1, LIBSVM returns one probability column per model label rather
% than one decision-value column per label pair. Put those columns in TDT's
% ascending label order, but do not apply the pairwise sign correction.
persistent previous_test_parameters probability_output
if isempty(previous_test_parameters) || ~isequal(test_parameters,previous_test_parameters)
    previous_test_parameters = []; %#ok<NASGU> % invalidate before rebuilding
    new_probability_output = ~isempty(regexp(test_parameters,'(^|\s)-b\s+1(\s|$)','once'));
    probability_output = new_probability_output;
    previous_test_parameters = test_parameters; % commit cache key last so interrupted rebuilds remain safe
end
if probability_output
    [~,probability_sort_vector] = sort(labelorder);
    decision_values = decision_values(:,probability_sort_vector);
    return
end

if issorted(labelorder)
    return
end

persistent previous_labelorder sort_vector sorted_sign_vector
n_label = size(labelorder,1);

if n_label == 2 % if two labels
    if labelorder(1) > labelorder(2)
        % invert decision values
        decision_values = -decision_values;
    end
    
else % if more than two labels

    % The permutation and signs depend only on model.Label, which normally
    % repeats across many calls. Cache only this mapping; decision values
    % themselves are always taken from the current svmpredict call.
    if isempty(previous_labelorder) || ~isequal(labelorder,previous_labelorder)
        % Invalidate first and commit the key last. If the user interrupts
        % rebuilding, the next call rebuilds instead of using partial data.
        previous_labelorder = []; %#ok<NASGU> % invalidate before rebuilding
        [a,b] = meshgrid(1:n_label,1:n_label);
        c = tril(true(n_label),-1); % this is our logical index selecting the lower triangular matrix
        d = [a(c) b(c)];
        e = labelorder(d);
        sign_vector = 2*double(e(:,2)>e(:,1))-1;
        [trash,sort_vector] = sortrows([min(e,[],2) max(e,[],2)]); % just sorting is not enough, they also need to be put in the correct order
        sorted_sign_vector = sign_vector(sort_vector)';
        previous_labelorder = labelorder; % commit cache key last so interrupted rebuilds remain safe
    end
    
    % OLD BUG: wrong order of changing sign and resorting columns: changed
    % sign of original column numbers but after sorting... (one step to hasty)
%     decision_values_old = bsxfun(@times,decision_values(:,sort_vector),sign_vector');
    % Select the canonical columns first and apply their matching signs in
    % the same operation. This is equivalent to the two former operations.
    decision_values = bsxfun(@times,decision_values(:,sort_vector),sorted_sign_vector); % change sign and bring columns to canonical order (e.g. 2vs1 -> 1vs2)
    
end
