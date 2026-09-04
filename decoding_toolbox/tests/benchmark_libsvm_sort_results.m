function timings = benchmark_libsvm_sort_results

rng(3)
n_labels_all = [3 4 6 10 12];
n_predictions = 60;
n_repetitions = 5;
test_parameters = '-q';
baseline_seconds = zeros(size(n_labels_all));
optimized_seconds = zeros(size(n_labels_all));

for i_test = 1:length(n_labels_all)
    n_labels = n_labels_all(i_test);
    n_pairwise = n_labels*(n_labels-1)/2;
    label_order = randperm(n_labels)';
    if issorted(label_order)
        label_order([1 2]) = label_order([2 1]);
    end
    decision_values = randn(n_predictions,n_pairwise);
    baseline_call = @()baseline_sort_results(decision_values,label_order);
    optimized_call = @()cached_sort_results(decision_values,label_order,test_parameters);
    assert(isequal(baseline_call(),optimized_call()),'Cached result differs for %i labels',n_labels)

    baseline_repeat = zeros(1,n_repetitions);
    optimized_repeat = zeros(1,n_repetitions);
    for i_repetition = 1:n_repetitions
        baseline_repeat(i_repetition) = timeit(baseline_call);
        optimized_repeat(i_repetition) = timeit(optimized_call);
    end
    baseline_seconds(i_test) = median(baseline_repeat);
    optimized_seconds(i_test) = median(optimized_repeat);
end

baseline_microseconds = 1e6*baseline_seconds;
optimized_microseconds = 1e6*optimized_seconds;
speedup_percent = 100*(baseline_seconds-optimized_seconds)./baseline_seconds;
seconds_saved = 800000*(baseline_seconds-optimized_seconds);
timings = table(n_labels_all',baseline_microseconds',optimized_microseconds',speedup_percent',seconds_saved','VariableNames',{'Labels','BaselineUs','OptimizedUs','SpeedupPercent','SecondsSaved800k'});
disp(timings)


function decision_values = baseline_sort_results(decision_values,label_order)

n_labels = size(label_order,1);
[a,b] = meshgrid(1:n_labels,1:n_labels);
keep = tril(true(n_labels),-1);
pairs = [a(keep) b(keep)];
pair_labels = label_order(pairs);
sign_vector = 2*double(pair_labels(:,2)>pair_labels(:,1))-1;
[~,sort_vector] = sortrows([min(pair_labels,[],2) max(pair_labels,[],2)]);
decision_values = bsxfun(@times,decision_values,sign_vector');
decision_values = decision_values(:,sort_vector);


function decision_values = cached_sort_results(decision_values,label_order,test_parameters)

persistent previous_test_parameters probability_output
if isempty(previous_test_parameters) || ~isequal(test_parameters,previous_test_parameters)
    previous_test_parameters = [];
    new_probability_output = ~isempty(regexp(test_parameters,'(^|\s)-b\s+1(\s|$)','once'));
    probability_output = new_probability_output;
    previous_test_parameters = test_parameters;
end
if probability_output
    [~,probability_sort_vector] = sort(label_order);
    decision_values = decision_values(:,probability_sort_vector);
    return
end

persistent previous_label_order sort_vector sorted_sign_vector
if isempty(previous_label_order) || ~isequal(label_order,previous_label_order)
    previous_label_order = [];
    n_labels = size(label_order,1);
    [a,b] = meshgrid(1:n_labels,1:n_labels);
    keep = tril(true(n_labels),-1);
    pairs = [a(keep) b(keep)];
    pair_labels = label_order(pairs);
    sign_vector = 2*double(pair_labels(:,2)>pair_labels(:,1))-1;
    [~,sort_vector] = sortrows([min(pair_labels,[],2) max(pair_labels,[],2)]);
    sorted_sign_vector = sign_vector(sort_vector)';
    previous_label_order = label_order;
end
decision_values = bsxfun(@times,decision_values(:,sort_vector),sorted_sign_vector);
