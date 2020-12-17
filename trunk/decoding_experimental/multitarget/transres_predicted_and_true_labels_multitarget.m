% function output = transres_predicted_labels_multitarget(decoding_out, chancelevel, varargin)
%
% Return both predicted and true labels in a multitarget setting. The
% function creates a struct output.model{} (one entry per target) with
% fields 'predicted_labels' and 'true labels'. This facilitates easy
% comparison of predicted and true labels.
%
% OUT
% 'predicted_labels' and 'true_labels' are returned as nx1 vectors where n
% is the number of files used for decoding. This allows for cases where the
% number of prediction varies between CV folds.
%
% To use this transformation, use
%
%   cfg.results.output = {'predicted_labels_multitarget'};
%
% Kai Görgen & Simon Weber, 2020-12-10

function output = transres_predicted_labels_multitarget(decoding_out, chancelevel, varargin)

n_models = length(decoding_out(1).output);
output = struct;

for model_ind = 1:n_models
    curr_predicted_labels = [];
    curr_true_labels = [];
    
    for cv_ind = 1:length(decoding_out)
        assert(n_models == length(decoding_out(cv_ind).output), 'Different number of models per cv step, no idea why. Please check')
        curr_input = decoding_out(cv_ind).output{model_ind};
        % assert that at least one dimension is 1
        assert(any(size(curr_input.predicted_labels)==1), 'curr_input.predicted_labels is not a vector. Please check')
        assert(any(size(curr_input.true_labels)==1), 'curr_input.true_labels is not a vector. Please check')
        curr_predicted_labels = [curr_predicted_labels; curr_input.predicted_labels(:)];
        curr_true_labels = [curr_true_labels; curr_input.true_labels(:)];
    end
    
    output.model{model_ind}.predicted_labels = curr_predicted_labels;
    output.model{model_ind}.true_labels = curr_true_labels;
end