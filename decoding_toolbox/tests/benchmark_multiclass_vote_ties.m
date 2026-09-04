function timings = benchmark_multiclass_vote_ties

toolbox_dir = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(toolbox_dir))
rng(1)

n_labels_all = [3 4 5 6 7 8 10 12];
n_steps = 4;
n_predictions_min = 60;
n_repetitions = 7;
cfg.decoding.software = 'libsvm';
cfg.decoding.method = 'classification';
cfg.decoding.test.classification.model_parameters = '-q';
baseline_seconds = zeros(size(n_labels_all));
optimized_seconds = zeros(size(n_labels_all));
initialization_seconds = zeros(size(n_labels_all));

for i_test = 1:length(n_labels_all)
    n_labels = n_labels_all(i_test);
    n_predictions = n_labels*ceil(n_predictions_min/n_labels);
    n_pairwise = n_labels*(n_labels-1)/2;
    labels = (1:n_labels)';

    decoding_out = repmat(struct('predicted_labels',[],'true_labels',[],'decision_values',[],'model',[]),1,n_steps);
    for i_step = 1:n_steps
        decoding_out(i_step).true_labels = repmat(labels,n_predictions/n_labels,1);
        decoding_out(i_step).decision_values = randn(n_predictions,n_pairwise);
        decoding_out(i_step).model.Label = labels;
        decoding_out(i_step).model.SVs = [];
        decoding_out(i_step).model.sv_coef = [];
        decoding_out(i_step).predicted_labels = libsvm_predictions(decoding_out(i_step).decision_values,labels);
    end

    baseline_call = @()baseline_confusion_matrix(decoding_out,cfg);
    optimized_call = @()transres_confusion_matrix(decoding_out,100/n_labels,cfg);
    baseline_result = baseline_call();
    initialization_start = tic;
    optimized_result = optimized_call();
    initialization_seconds(i_test) = toc(initialization_start);
    assert(isequaln(baseline_result,optimized_result{1}),'Optimized result differs from baseline for %i labels',n_labels)

    baseline_repeat = zeros(1,n_repetitions);
    optimized_repeat = zeros(1,n_repetitions);
    for i_repetition = 1:n_repetitions
        if mod(i_repetition,2)
            baseline_repeat(i_repetition) = timeit(baseline_call);
            optimized_repeat(i_repetition) = timeit(optimized_call);
        else
            optimized_repeat(i_repetition) = timeit(optimized_call);
            baseline_repeat(i_repetition) = timeit(baseline_call);
        end
    end
    baseline_seconds(i_test) = median(baseline_repeat);
    optimized_seconds(i_test) = median(optimized_repeat);
end

baseline_microseconds = 1e6*baseline_seconds;
optimized_microseconds = 1e6*optimized_seconds;
speedup_percent = 100*(baseline_seconds-optimized_seconds)./baseline_seconds;
baseline_minutes = 800000*baseline_seconds/60;
optimized_minutes = 800000*optimized_seconds/60;
minutes_saved = baseline_minutes-optimized_minutes;
timings = table(n_labels_all',1000*initialization_seconds',baseline_microseconds',optimized_microseconds',speedup_percent',baseline_minutes',optimized_minutes',minutes_saved','VariableNames',{'Labels','FirstCallMs','BaselineUs','OptimizedUs','SpeedupPercent','BaselineMin800k','OptimizedMin800k','MinutesSaved'});
disp(timings)


function predicted_labels = libsvm_predictions(decision_values,labels)

n_labels = length(labels);
n_predictions = size(decision_values,1);
votes = zeros(n_predictions,n_labels);
i_pair = 0;
for first_label = 1:n_labels-1
    for second_label = first_label+1:n_labels
        i_pair = i_pair+1;
        first_wins = decision_values(:,i_pair)>0;
        votes(:,first_label) = votes(:,first_label)+first_wins;
        votes(:,second_label) = votes(:,second_label)+~first_wins;
    end
end
[~,winner] = max(votes,[],2);
predicted_labels = labels(winner);


function output = baseline_confusion_matrix(decoding_out,cfg) %#ok<INUSD>

true_labels = vertcat(decoding_out.true_labels);
labels = uniqueq(true_labels);
predicted_labels = baseline_resolve_ties(decoding_out,labels);
n_labels = length(labels);
output = zeros(n_labels);

for i_label = 1:n_labels
    labelfilt = true_labels==labels(i_label);
    curr_predicted_labels = predicted_labels(labelfilt);
    curr_n_true = sum(labelfilt);
    for j_label = 1:n_labels
        output(i_label,j_label) = 100*(1/curr_n_true)*sum(curr_predicted_labels==labels(j_label));
    end
end


function predicted_labels = baseline_resolve_ties(decoding_out,labels)

n_labels = length(labels);
for i_step = 1:length(decoding_out)
    decision_values = decoding_out(i_step).decision_values;
    n_predictions = size(decision_values,1);
    votes = zeros(n_predictions,n_labels);
    vote_strength = zeros(n_predictions,n_labels);
    i_pair = 0;

    for first_label = 1:n_labels-1
        for second_label = first_label+1:n_labels
            i_pair = i_pair+1;
            curr_decision_values = decision_values(:,i_pair);
            first_wins = curr_decision_values>0;
            second_wins = ~first_wins;
            votes(:,first_label) = votes(:,first_label)+first_wins;
            votes(:,second_label) = votes(:,second_label)+second_wins;
            vote_strength(:,first_label) = vote_strength(:,first_label)+first_wins.*abs(curr_decision_values);
            vote_strength(:,second_label) = vote_strength(:,second_label)+second_wins.*abs(curr_decision_values);
        end
    end

    max_votes = max(votes,[],2);
    tied_predictions = find(sum(bsxfun(@eq,votes,max_votes),2)>1 & all(isfinite(decision_values),2));
    for i_tie = 1:length(tied_predictions)
        i_prediction = tied_predictions(i_tie);
        tied_labels = find(votes(i_prediction,:)==max_votes(i_prediction));
        [~,strongest_vote] = max(vote_strength(i_prediction,tied_labels));
        decoding_out(i_step).predicted_labels(i_prediction) = labels(tied_labels(strongest_vote));
    end
end

predicted_labels = vertcat(decoding_out.predicted_labels);
