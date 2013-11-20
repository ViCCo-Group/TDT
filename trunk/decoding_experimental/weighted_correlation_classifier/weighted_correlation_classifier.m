% [predicted_labels decision_values not_unique] = weighted_correlation_classifier(labels_test,vectors_test,model)
%
% This function performs a weighted comparision for each test vector using
% the correlation to all training vectors. In detail, it does:
%
%   1. Calculate the correlation between all training & test vectors
%   2. Performs a Fisher-z-transform or the correlation values
%   3. Averages the z-transformed values for each class
%   4. Takes the "vote" of all vectors, i.e. check which class average is
%      larger.
%
%   As decision value, the difference between the two classes is returned.
%
% Possible alternative 1 (TODO, not implemented yet):
%   Instead of calculating all correlations, calculate the average vector
%   for each training class first, and then do the correlation of this
%   average vector to all test vectors (should be faster).
%
% Possible alternative 2 (TODO, not implemented yet):
%   Analogue to above: Calculate the average vector each test class first,
%   and then do the correlation of this average vector to all average
%   training vectors (should be even faster).
%
%
% IN
%   labels_test: n_test x 1 vector with test labels
%   vectors_test: n_test x n_dim matrix with test vectors
%   model: struct with
%       model.labels_train: n_train x 1 vector with training labels
%       model.vecotrs_train: n_train x n_dim vector with training vectors
%
% OUT
%   predicted_labels: n_test x 1 vector with predicted labels. If two
%       classes have equal maximal correlation values, the first of theses
%       classes is taken. (Labels are sorted using sort).
%   decision_value: n_test x n_unique_labels with average Fisher z
%       tranformed correlation values for each class
%   not_unique: n_test x 1 logical vector, having 1 for each test pattern
%       for which there is no unique class decision, because multiple
%       classes have equal average correlation values.
%
% See also: correlation_classifier.m (Haxby-style)

function [predicted_labels decision_values not_unique] = weighted_correlation_classifier(labels_test,vectors_test,model)

vectors_train = model.vectors_train;
labels_train = model.labels_train;


% check how many test classes we have
unique_test_labels = sort(unique(labels_test));
n_unique_test_labels = size(unique_test_labels,1);
if n_unique_test_labels == 1
    warningv('Correlation_classifier:only_1_testlabel', 'Only 1 unique testlabel is present, testing to which class the mean is more similar');
end

% check how many training classes we have
unique_train_labels = sort(unique(labels_train));
n_unique_train_labels = size(unique_train_labels,1);
if n_unique_train_labels == 1
    error('Correlation_classifier:only_1_trainlabel', 'Only 1 unique trainlabel is present, classification with only 1 label not possible');
end

% check how many classes we have in training and test
labels = sort(unique([labels_test; labels_train]));
n_labels = size(labels,1);
if n_labels > 2, error('Correlation classifier cannot yet deal with more than two labels at a time.\n Run all pairs separately.'), end

% create mean training and test vectors (TODO, if wanted)
% train = cell(n_labels,1);
% test = cell(n_labels,1);
% for i_label = 1:n_labels
%     % TODO: possibly replace mean by % sum(...,1)/sum(labels_train==i_label) to gain speed
%     train{i_label} = mean(vectors_train(labels_train==labels(i_label),:),1);
%     test{i_label} = mean(vectors_test(labels_test==labels(i_label),:),1);
% end

% check that number of voxels is > 2
if size(vectors_train, 2) <= 2 % if less than two voxels are present, a correlation is not possible

    warning('CORRELATION_CLASSIFIER:LESSTHAN2VOXLS','Searchlight or ROI with <= 2 voxels (may happen at borders of mask). Setting value to NaN!')

    decision_values = nan(length(labels_test), length(unique_train_labels));
    predicted_labels = nan(length(labels_test), 1);
    not_unique = nan(length(labels_test), 1);

else % normal case in which more than one voxel is present

    corrmat = corr(vectors_train', vectors_test');
    % returns n_vec_train x n_vec_test correlation matrix

    % force finite values for later z-transformation
    if any(abs(corrmat(:)) > (1 - 1.0e-15))  % taking 1.0e-15 because abs does not work perfectly for -1.0

        warningv('WEIGHTED_CORRELATION_CLASSIFIER:ZCORRINF','Correlations of +1 or -1 found. Correcting to +/-0.99999 to avoid infinity for z-transformed correlations!')
        corrmat(corrmat > (1 - 1.0e-15)) =  0.99999; % forces finite values
        corrmat(corrmat <-(1 - 1.0e-15)) = -0.99999; % forces finite values
    end

    % translate to Fisher's z transformed values
    zcorr = atanh(corrmat);

    class_vote = zeros(length(labels_test), length(unique_train_labels));
    % get average zcorr for each class for each test pattern
    for u_train_label_ind = 1:length(unique_train_labels)
        curr_label = unique_train_labels(u_train_label_ind);
        class_vote(:, u_train_label_ind) = mean(zcorr(labels_train==curr_label, :), 1); % get mean z-correlation for each pattern for each class
    end
    
    % get the maximum in each row -- this is the class each pattern "voted"
    % for (i.e. had the highest correlation with the current target pattern)
    [max_val, max_ind] = max(class_vote, [], 2);
    
    % translate max_ind back to predicted class
    predicted_labels = unique_train_labels(max_ind);
    
    % What to do if two classes are equally likely, i.e. get equally strong votes?
    not_unique = sum(class_vote - repmat(max_val, 1, size(class_vote, 2))==0, 2)>1;
    
    if any(not_unique)
        warningv('WEIGHTED_CORRELATION:Not_Unique_classes', 'Some test patterns get equal max correlation values from different classes -- putting them into the first class. Check out.not_unique')
    end
        
    % finally, save average z-correlation from class_vote as decision value
    decision_values = class_vote;
end