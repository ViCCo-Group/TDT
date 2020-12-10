function output = transres_predicted_labels_multitarget(decoding_out, chancelevel, varargin)

% what we get
% decoding_out(cv_step_ind).output{model_ind}
% with
%     predicted_labels: [2×1 double]
%          true_labels: [2×1 double]
%      decision_values: [2×1 double]
%                model: [1×1 struct]
%                  opt: []

n_models = length(decoding_out(1).output);
output = cell(1,1);

for cv_ind = 1:length(decoding_out)
    curr_output = [];
    for model_ind = 1:n_models
        assert(n_models == length(decoding_out(cv_ind).output), 'Different number of models per cv step, no idea why. Please check')
        curr_input = decoding_out(cv_ind).output{model_ind};
        curr_output(model_ind, :) = curr_input.predicted_labels;
    end
    output{1} = [output{1}; curr_output];
end

% ways to output
% output = 5 % if only one number should be returned (creates one SL map)
% output = {whatever_else} % put output in one cell