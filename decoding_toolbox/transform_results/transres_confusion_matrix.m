% function output = transres_confusion_matrix(decoding_out, chancelevel, varargin)
% 
% Get a matrix of how often each label has been confused by other labels.
% This function will calculate the per-class accuracy, i.e. balanced for
% the number of occurrences of each label. The output will be percentage 
% of appearance of the class, i.e. each row will sum up to 100. To change
% this, modify the commented line in the code and save under a different
% name.
%
% The output will be an NxN matrix where n is the number of unique labels.
% The columns will represent the predicted labels, whereas the rows will
% represent the true labels. The output is sorted by label number,
% from low to high.
%
% To use this transformation, use 
%
%   cfg.results.output = {'confusion_matrix'}
%
% NOTE: In multiclass settings, tied one-vs-one votes are resolved using
% the decision values. Among the tied classes, the class with the largest
% sum of absolute decision values supporting its votes is selected. Only
% if these sums are also exactly equal is the first sorted label selected.
% Rows with exact-zero margins retain LIBSVM's label because canonicalizing
% the pair order cannot preserve LIBSVM's model-order direction for zero.
% To retain ties as a separate category instead, use
%
%   cfg.results.output = {'confusion_matrix_plus_undecided'}
%
% which will create one additional 'undecided' column to the confusion 
% matrix that contains the number of all samples for which no unique
% prediction was possible.
%
% Martin, 2014-04-23
%
% See also decoding_transform_results transres_accuracy_matrix transres_accuracy_pairwise

% Update MH 2026-09-03: resolve tied multiclass votes by decision-value strength
% Update KG 2021-03-16: added confusion_matrix_plus_undecided to header
% Update MH 2017-03-15:
% Error in description: flipped columns and rows, now corrected

function output = transres_confusion_matrix(decoding_out,chancelevel,varargin)

true_labels = vertcat(decoding_out.true_labels);

persistent previous_true_labels labels true_label_map n_true previous_test_parameters non_probability_output
% The true labels and their row membership do not change between
% searchlights/ROIs. Cache them instead of rebuilding them on every call.
if isempty(previous_true_labels) || ~isequal(true_labels,previous_true_labels)
    labels = uniqueq(true_labels);
    true_label_map = bsxfun(@eq,true_labels,labels');
    n_true = sum(true_label_map,1);
    previous_true_labels = true_labels;
end
n_labels = size(labels,1);

% The correction is specific to non-probability LIBSVM classification.
% Calls without cfg are kept for direct use of this transformation; their
% decision-value and model compatibility is checked below before any change.
resolve_vote_ties = true;
if ~isempty(varargin) && isstruct(varargin{1}) && isfield(varargin{1},'decoding')
    cfg = varargin{1};
    resolve_vote_ties = isfield(cfg.decoding,'software') && strcmpi(cfg.decoding.software,'libsvm') && isfield(cfg.decoding,'method') && any(strcmpi(cfg.decoding.method,{'classification','classification_kernel'}));
    if resolve_vote_ties && isfield(cfg.decoding,'test') && isfield(cfg.decoding.test,cfg.decoding.method) && isfield(cfg.decoding.test.(cfg.decoding.method),'model_parameters')
        test_parameters = cfg.decoding.test.(cfg.decoding.method).model_parameters;
        if isempty(non_probability_output) || ~isequal(test_parameters,previous_test_parameters)
            non_probability_output = isempty(regexp(test_parameters,'(^|\s)-b\s+1(\s|$)','once'));
            previous_test_parameters = test_parameters;
        end
        resolve_vote_ties = non_probability_output;
    else
        resolve_vote_ties = false;
    end
end
if resolve_vote_ties
    predicted_labels = resolve_multiclass_vote_ties(decoding_out,labels);
else
    predicted_labels = vertcat(decoding_out.predicted_labels);
end

output = zeros(n_labels); % init

for i_label = 1:n_labels
    labelfilt = true_label_map(:,i_label);
    curr_predicted_labels = predicted_labels(labelfilt);
    for j_label = 1:n_labels
        output(i_label,j_label) = 100 * (1/n_true(i_label)) * sum(curr_predicted_labels==labels(j_label)); % deactivate me if you want raw results
        % output(i_label,j_label) = sum(curr_predicted_labels==labels(j_label)); % activate me if you want raw results
    end
end
output = {output};


function predicted_labels = resolve_multiclass_vote_ties(decoding_out,labels)

predicted_labels = vertcat(decoding_out.predicted_labels);
n_labels = length(labels);
if n_labels < 3
    return
end

n_pairwise = n_labels * (n_labels - 1) / 2;
persistent previous_n_labels first_class_map second_class_map pair_incidence base_votes vote_change code_weights tie_lookup tied_label_lookup tie_bitmask_lookup

% Build the pair-to-class maps once per number of labels. They convert the
% signs of LIBSVM's pairwise decision values into votes and vote strengths.
if isempty(previous_n_labels) || previous_n_labels~=n_labels
    first_class = zeros(n_pairwise,1);
    second_class = zeros(n_pairwise,1);
    i_pair = 0;
    for i_first = 1:n_labels-1
        for i_second = i_first+1:n_labels
            i_pair = i_pair+1;
            first_class(i_pair) = i_first;
            second_class(i_pair) = i_second;
        end
    end
    pair_ind = (1:n_pairwise)';
    first_class_map = full(sparse(pair_ind,first_class,1,n_pairwise,n_labels));
    second_class_map = full(sparse(pair_ind,second_class,1,n_pairwise,n_labels));
    pair_incidence = first_class_map+second_class_map;
    base_votes = sum(second_class_map,1);
    vote_change = first_class_map-second_class_map;

    % Four to six labels have at most 32768 possible vote patterns. A
    % complete lookup is faster than rebuilding votes for every prediction
    % and remains small enough to keep per MATLAB worker.
    if n_labels>=4 && n_labels<=6
        n_vote_patterns = 2^n_pairwise;
        all_first_wins = false(n_vote_patterns,n_pairwise);
        for i_pair = 1:n_pairwise
            all_first_wins(:,i_pair) = bitget((0:n_vote_patterns-1)',i_pair);
        end
        all_votes = bsxfun(@plus,double(all_first_wins)*vote_change,base_votes);
        all_max_votes = max(all_votes,[],2);
        tied_label_lookup = bsxfun(@eq,all_votes,all_max_votes);
        tie_lookup = sum(tied_label_lookup,2)>1;
        code_weights = 2.^(0:n_pairwise-1)';

    % Seven labels already have 2097152 patterns. Store the tied classes as
    % one uint8 bitmask per pattern (~2 MB) instead of a logical matrix.
    elseif n_labels==7
        n_vote_patterns = 2^n_pairwise;
        vote_pattern = uint32((0:n_vote_patterns-1)');
        all_votes = zeros(n_vote_patterns,n_labels,'uint8');
        for i_pair = 1:n_pairwise
            first_wins = logical(bitget(vote_pattern,i_pair));
            all_votes(:,first_class(i_pair)) = all_votes(:,first_class(i_pair))+uint8(first_wins);
            all_votes(:,second_class(i_pair)) = all_votes(:,second_class(i_pair))+uint8(~first_wins);
        end
        all_max_votes = max(all_votes,[],2);
        tied_label_lookup = bsxfun(@eq,all_votes,all_max_votes);
        tie_lookup = sum(tied_label_lookup,2)>1;
        tie_bitmask_lookup = zeros(n_vote_patterns,1,'uint8');
        for i_label = 1:n_labels
            tie_bitmask_lookup(tie_lookup & tied_label_lookup(:,i_label)) = tie_bitmask_lookup(tie_lookup & tied_label_lookup(:,i_label))+bitshift(uint8(1),i_label-1);
        end
        tie_lookup = [];
        tied_label_lookup = [];
        code_weights = 2.^(0:n_pairwise-1)';
    end
    previous_n_labels = n_labels;
end

% Only LIBSVM OVO margins have exactly one column per label pair. Also
% require the model labels to match, preventing probability output and
% similarly shaped output from another classifier from being reinterpreted.
valid_step = true(1,length(decoding_out));
column_predictions = true;
for i_step = 1:length(decoding_out)
    n_predictions = numel(decoding_out(i_step).predicted_labels);
    column_predictions = column_predictions && size(decoding_out(i_step).predicted_labels,2)==1;
    if ~isfield(decoding_out(i_step),'decision_values')
        valid_step(i_step) = false;
        continue
    end
    decision_values = decoding_out(i_step).decision_values;
    valid_step(i_step) = isnumeric(decision_values) && size(decision_values,1)==n_predictions && size(decision_values,2)==n_pairwise;
    if valid_step(i_step) && isfield(decoding_out(i_step),'model') && isstruct(decoding_out(i_step).model) && isfield(decoding_out(i_step).model,'Label')
        valid_step(i_step) = isequal(sort(decoding_out(i_step).model.Label(:)),labels(:));
    else
        valid_step(i_step) = false;
    end
end

% Combining steps is faster for the common 3-4 class case. With more
% classes, the larger matrix multiplication is slower in MATLAB R2021b.
if n_labels<=4 && all(valid_step) && column_predictions
    decision_values = vertcat(decoding_out.decision_values);
    predicted_labels = resolve_ties(predicted_labels,decision_values,labels,pair_incidence,vote_change,code_weights,tie_lookup,tied_label_lookup,tie_bitmask_lookup);
else
    for i_step = find(valid_step)
        decoding_out(i_step).predicted_labels = resolve_ties(decoding_out(i_step).predicted_labels,decoding_out(i_step).decision_values,labels,pair_incidence,vote_change,code_weights,tie_lookup,tied_label_lookup,tie_bitmask_lookup);
    end
    predicted_labels = vertcat(decoding_out.predicted_labels);
end


function predicted_labels = resolve_ties(predicted_labels,decision_values,labels,pair_incidence,vote_change,code_weights,tie_lookup,tied_label_lookup,tie_bitmask_lookup)

n_labels = length(labels);
if n_labels==3
    % A three-class vote tie can only be the 1-1-1 cycle. Testing that
    % pattern directly is faster than creating votes or indexing a lookup.
    first_wins = decision_values>0;
    tied_predictions = find(first_wins(:,1)==first_wins(:,3) & first_wins(:,1)~=first_wins(:,2));
elseif n_labels<=6
    % Treat the decision-value signs as bits and look up whether their vote
    % pattern ties. This measured fastest for four to six labels.
    first_wins = decision_values>0;
    vote_code = 1+double(first_wins)*code_weights;
    tied_predictions = find(tie_lookup(vote_code));
elseif n_labels==7
    % Use the same sign code, but retrieve the compact tied-class bitmask.
    first_wins = decision_values>0;
    vote_code = 1+double(first_wins)*code_weights;
    tie_bitmask = tie_bitmask_lookup(vote_code);
    tied_predictions = find(tie_bitmask);
else
    % Eight labels would require 2^28 lookup entries, so lookup tables stop
    % being practical. For these sizes MATLAB's JIT-compiled pair loops
    % measured faster than multiplying increasingly wide mapping matrices.
    n_predictions = size(decision_values,1);
    votes = zeros(n_predictions,n_labels);
    vote_strength = zeros(n_predictions,n_labels);
    i_pair = 0;
    for first_label = 1:n_labels-1
        for second_label = first_label+1:n_labels
            i_pair = i_pair+1;
            curr_decision_values = decision_values(:,i_pair);
            first_wins_curr = curr_decision_values>0;
            second_wins_curr = ~first_wins_curr;
            votes(:,first_label) = votes(:,first_label)+first_wins_curr;
            votes(:,second_label) = votes(:,second_label)+second_wins_curr;
            vote_strength(:,first_label) = vote_strength(:,first_label)+first_wins_curr.*abs(curr_decision_values);
            vote_strength(:,second_label) = vote_strength(:,second_label)+second_wins_curr.*abs(curr_decision_values);
        end
    end
    max_votes = max(votes,[],2);
    tied_predictions = find(sum(bsxfun(@eq,votes,max_votes),2)>1);
end

% Canonicalizing pair order loses LIBSVM's model-order direction for exact
% zero margins, so retain LIBSVM's original prediction for those rare rows.
valid_ties = decision_values(tied_predictions,:);
tied_predictions = tied_predictions(all(isfinite(valid_ties) & valid_ties~=0,2));

if isempty(tied_predictions)
    return
end

if n_labels==3
    % The closed form below adds only the margins that voted for each class.
    % It is the fastest measured implementation for the common 3-class case.
    tie_decision_values = decision_values(tied_predictions,:);
    tie_first_wins = first_wins(tied_predictions,:);
    abs_tie_decision_values = abs(tie_decision_values);
    vote_strength = [abs_tie_decision_values(:,1).*tie_first_wins(:,1)+abs_tie_decision_values(:,2).*tie_first_wins(:,2),abs_tie_decision_values(:,1).*~tie_first_wins(:,1)+abs_tie_decision_values(:,3).*tie_first_wins(:,3),abs_tie_decision_values(:,2).*~tie_first_wins(:,2)+abs_tie_decision_values(:,3).*~tie_first_wins(:,3)];
elseif n_labels<=7
    % For tied rows only, calculate each class's total absolute margin
    % support. This identity avoids a second loop over all label pairs.
    tie_decision_values = decision_values(tied_predictions,:);
    abs_tie_decision_values = abs(tie_decision_values);
    vote_strength = .5*(abs_tie_decision_values*pair_incidence+tie_decision_values*vote_change);
else
    vote_strength = vote_strength(tied_predictions,:);
end

% Exclude classes that did not share the maximum vote count, then select
% the greatest decision-value support. MATLAB's max supplies the stable
% first-sorted-label fallback if strengths are exactly equal.
if n_labels==3
    tied_labels = true(length(tied_predictions),3);
elseif n_labels<=6
    tied_labels = tied_label_lookup(vote_code(tied_predictions),:);
elseif n_labels==7
    tied_labels = false(length(tied_predictions),n_labels);
    for i_label = 1:n_labels
        tied_labels(:,i_label) = bitget(tie_bitmask(tied_predictions),i_label);
    end
else
    tied_labels = bsxfun(@eq,votes(tied_predictions,:),max_votes(tied_predictions));
end
vote_strength(~tied_labels) = -Inf;
[~,strongest_vote] = max(vote_strength,[],2);
predicted_labels(tied_predictions) = labels(strongest_vote);
