function test_step1_regressions

toolbox_dir = fileparts(fileparts(mfilename('fullpath')));
workspace_dir = fileparts(toolbox_dir);
fake_spm26_dir = fullfile(workspace_dir,'test_fixtures','fake_spm26');
spm25_dir = '/Applications/spm25';

addpath(toolbox_dir)

%% SPM25 is detected and dispatched through its image-access adapters
assert(exist(fullfile(spm25_dir,'spm.m'),'file')==2,'The local SPM25 installation required for this regression test was not found.')
addpath(spm25_dir,'-begin')
clear spm check_software check_software_spm12 check_software_spm25 check_software_spm26
cfg = decoding_defaults;
assert(strcmpi(cfg.software,'SPM25'),'decoding_defaults did not detect the local SPM25 installation.')
check_software('SPM25');

%% SPM26 can be detected and dispatched without a local installation
addpath(fake_spm26_dir,'-begin')
clear spm check_software check_software_spm12 check_software_spm25 check_software_spm26
check_software('SPM26');
rmpath(fake_spm26_dir)
clear spm check_software check_software_spm12 check_software_spm25 check_software_spm26

test_dir = tempname;
mkdir(test_dir)
cleanup = onCleanup(@()cleanup_test_dir(test_dir));

data = reshape(single(1:8),[2 2 2]);
hdr.fname = fullfile(test_dir,'spm25_adapter_test.nii');
hdr.dim = size(data);
hdr.dt = [16 0];
hdr.mat = eye(4);
hdr.pinfo = [1; 0; 0];
hdr.descrip = 'TDT SPM25 adapter regression test';

written_hdr = write_image_spm25(hdr,data);
listed = cellstr(get_filenames_spm25(test_dir,'*.nii'));
assert(isequal(listed,{hdr.fname}),'SPM25 filename dispatch returned the wrong file.')
listed_one_argument = cellstr(get_filenames_spm25(fullfile(test_dir,'*.nii')));
listed_regexp = cellstr(get_filenames_spm25(test_dir,'REGEXP:^spm25_.*\.nii$'));
assert(isequal(listed_one_argument,{hdr.fname}),'SPM25 one-argument filename dispatch failed.')
assert(isequal(listed_regexp,{hdr.fname}),'SPM25 regular-expression filename dispatch failed.')

read_hdr = read_header_spm25(hdr.fname);
read_data = read_image_spm25(read_hdr);
sampled = read_voxels_spm25(read_hdr,[1 1 1; 2 2 2]);
assert(isequal(single(read_data),data),'SPM25 image adapter changed the image values.')
assert(isequal(sampled(:),double([1; 8])),'SPM25 voxel adapter returned wrong values.')
assert(strcmp(written_hdr.fname,hdr.fname),'SPM25 write adapter returned the wrong header.')

% SPM26 delegates the same public image-access API.
spm26_hdr = hdr;
spm26_hdr.fname = fullfile(test_dir,'spm26_adapter_test.nii');
written_spm26_hdr = write_image_spm26(spm26_hdr,data);
listed_spm26 = cellstr(get_filenames_spm26(test_dir,'spm26_*.nii'));
read_spm26_hdr = read_header_spm26(spm26_hdr.fname);
read_spm26_data = read_image_spm26(read_spm26_hdr);
sampled_spm26 = read_voxels_spm26(read_spm26_hdr,[1 1 1; 2 2 2]);
assert(isequal(listed_spm26,{spm26_hdr.fname}),'SPM26 filename adapter returned the wrong file.')
assert(isequal(single(read_spm26_data),data),'SPM26 image adapter changed the image values.')
assert(isequal(sampled_spm26(:),double([1; 8])),'SPM26 voxel adapter returned wrong values.')
assert(strcmp(written_spm26_hdr.fname,spm26_hdr.fname),'SPM26 write adapter returned the wrong header.')

%% Multiclass confusion matrices resolve vote ties by decision-value strength
decoding_out.predicted_labels = [1; 1; 1];
decoding_out.true_labels = [1; 2; 3];
decoding_out.decision_values = repmat([1 -4 2],3,1); % cyclic vote; class 3 has strongest support
decoding_out.model.Label = [1; 2; 3];

resolved = transres_confusion_matrix(decoding_out,100/3);
explicit = transres_confusion_matrix_plus_undecided(decoding_out,100/3);

assert(all(resolved{1}(:,3)==100),'The multiclass vote tie was not assigned to the class with strongest decision-value support.')
assert(all(explicit{1}(:,end)==100),'Tied votes were not reported as undecided.')

row_out = decoding_out;
row_out.predicted_labels = row_out.predicted_labels';
row_out.true_labels = row_out.true_labels';
row_result = transres_confusion_matrix(row_out,100/3);
assert(all(row_result{1}(:,3)==100),'Row-vector predictions are no longer handled correctly.')

relabeled_out = decoding_out;
relabeled_out.predicted_labels = [10; 10; 10];
relabeled_out.true_labels = [-2; 7; 10];
relabeled_out.model.Label = [10; -2; 7];
relabeled = transres_confusion_matrix(relabeled_out,100/3);
assert(all(relabeled{1}(:,3)==100),'Decision-value tie resolution changed when non-consecutive labels were reordered.')

four_class_out.predicted_labels = 2*ones(4,1);
four_class_out.true_labels = (1:4)';
four_class_out.decision_values = repmat([-1 -1 -5 1 -4 1],4,1); % votes [0 2 2 2], class 4 has strongest support
four_class_out.model.Label = (1:4)';
four_class = transres_confusion_matrix(four_class_out,25);
assert(all(four_class{1}(:,4)==100),'A four-class tie excluding the first model label was not resolved correctly.')

mismatched_model = decoding_out;
mismatched_model.model.Label = [1; 2; 4];
mismatched = transres_confusion_matrix(mismatched_model,100/3);
assert(all(mismatched{1}(:,1)==100),'Incompatible model labels should retain the original predictions.')

decoding_out.decision_values = repmat([1 -1 1],3,1); % exact strength tie
exact_tie = transres_confusion_matrix(decoding_out,100/3);
assert(all(exact_tie{1}(:,1)==100),'An exact decision-value-strength tie did not use the first sorted label.')

zero_out = decoding_out;
zero_out.predicted_labels = 2*ones(3,1);
zero_out.decision_values = repmat([1 0 1],3,1);
zero_out.model.Label = [2; 1; 3];
zero_result = transres_confusion_matrix(zero_out,100/3);
assert(all(zero_result{1}(:,2)==100),'Rows with exact-zero canonical margins should retain LIBSVM''s original prediction.')

probability_out = decoding_out;
probability_out.predicted_labels = 2*ones(3,1);
probability_out.decision_values = repmat([.4 0 .6],3,1);
probability_cfg.decoding.software = 'libsvm';
probability_cfg.decoding.method = 'classification';
probability_cfg.decoding.test.classification.model_parameters = '-q -b 1';
probability_result = transres_confusion_matrix(probability_out,100/3,probability_cfg);
assert(all(probability_result{1}(:,2)==100),'LIBSVM probability output should not be interpreted as pairwise decision values.')

other_classifier_out = rmfield(decoding_out,'model');
other_classifier_out.predicted_labels = 2*ones(3,1);
other_classifier_result = transres_confusion_matrix(other_classifier_out,100/3);
assert(all(other_classifier_result{1}(:,2)==100),'Decision values without compatible model labels should retain the classifier predictions.')

binary_out.predicted_labels = [1; 2];
binary_out.true_labels = [1; 2];
binary_out.decision_values = [1; -1];
binary = transres_confusion_matrix(binary_out,50);
assert(isequal(binary{1},100*eye(2)),'Binary confusion-matrix behavior changed unexpectedly.')

%% Cached LIBSVM canonicalization matches the previous uncached calculation
libsvm_dir = fullfile(toolbox_dir,'decoding_software','libsvm3.17','matlab');
addpath(libsvm_dir,'-begin')
svm_cfg = decoding_defaults;
svm_cfg.decoding.method = 'classification';
train_labels = [3; 1; 2; 3; 1; 2];
train_data = [3 0; 0 1; -2 -2; 2.5 .1; .1 1.5; -1.5 -2.5];
svm_model = libsvm_train(train_labels,train_data,svm_cfg);
[raw_predictions,~,raw_decision_values] = svmpredict(train_labels,train_data,svm_model,'-q');
sorted_once = libsvm_test(train_labels,train_data,svm_cfg,svm_model);
sorted_twice = libsvm_test(train_labels,train_data,svm_cfg,svm_model);
expected_decision_values = canonical_decision_values(raw_decision_values,svm_model.Label);
assert(isequal(sorted_once.decision_values,expected_decision_values),'LIBSVM decision values were not put in canonical label order.')
assert(isequal(sorted_twice.decision_values,expected_decision_values),'Cached LIBSVM canonicalization changed the decision values.')
assert(isequal(sorted_once.predicted_labels,raw_predictions),'Canonicalizing decision values changed LIBSVM''s predicted labels.')
assert(isequal(sorted_once.model,svm_model),'libsvm_test changed the trained model.')

% A different model label order must invalidate the single-entry cache.
reorder = [3 1 2 6 4 5];
train_labels_reordered = train_labels(reorder);
train_data_reordered = train_data(reorder,:);
svm_model_reordered = libsvm_train(train_labels_reordered,train_data_reordered,svm_cfg);
[raw_predictions_reordered,~,raw_decision_values_reordered] = svmpredict(train_labels_reordered,train_data_reordered,svm_model_reordered,'-q');
sorted_reordered = libsvm_test(train_labels_reordered,train_data_reordered,svm_cfg,svm_model_reordered);
expected_reordered = canonical_decision_values(raw_decision_values_reordered,svm_model_reordered.Label);
assert(isequal(sorted_reordered.decision_values,expected_reordered),'Changing model.Label did not rebuild the LIBSVM canonicalization mapping.')
assert(isequal(sorted_reordered.predicted_labels,raw_predictions_reordered),'Cache invalidation changed LIBSVM''s predicted labels.')
sorted_first_again = libsvm_test(train_labels,train_data,svm_cfg,svm_model);
assert(isequal(sorted_first_again.decision_values,expected_decision_values),'Returning to an earlier model.Label reused the wrong cached mapping.')

% The precomputed-kernel classification path uses the same canonicalizer.
kernel_cfg = svm_cfg;
kernel_cfg.decoding.method = 'classification_kernel';
kernel_data.kernel = train_data*train_data';
kernel_model = libsvm_train(train_labels,kernel_data,kernel_cfg);
[kernel_predictions,~,kernel_decision_values] = svmpredict(train_labels,[(1:length(train_labels))' kernel_data.kernel],kernel_model,'-q');
kernel_sorted = libsvm_test(train_labels,kernel_data,kernel_cfg,kernel_model);
kernel_expected = canonical_decision_values(kernel_decision_values,kernel_model.Label);
assert(isequal(kernel_sorted.decision_values,kernel_expected),'Kernel LIBSVM decision values were not put in canonical label order.')
assert(isequal(kernel_sorted.predicted_labels,kernel_predictions),'Canonicalizing kernel decision values changed LIBSVM''s predicted labels.')

% Probability output has one column per class, not one per pair. It must be
% reordered by model label without the decision-value sign correction.
probability_cfg = svm_cfg;
probability_cfg.decoding.train.classification.model_parameters = '-s 0 -t 0 -c 1 -b 1 -q';
probability_cfg.decoding.test.classification.model_parameters = '-b 1 -q';

three_probability_model = libsvm_train(train_labels,train_data,probability_cfg);
[three_probability_predictions,~,three_raw_probabilities] = svmpredict(train_labels,train_data,three_probability_model,'-b 1 -q');
three_probability_sorted = libsvm_test(train_labels,train_data,probability_cfg,three_probability_model);
[~,three_probability_sort_vector] = sort(three_probability_model.Label);
three_expected_probabilities = three_raw_probabilities(:,three_probability_sort_vector);
assert(isequal(three_probability_sorted.decision_values,three_expected_probabilities),'Three-class LIBSVM probabilities were not put in canonical label order.')
assert(isequal(three_probability_sorted.predicted_labels,three_probability_predictions),'Canonicalizing three-class probabilities changed LIBSVM''s predicted labels.')

probability_labels = [4; 2; 1; 3; 4; 2; 1; 3];
probability_data = [4 0; 2 0; 1 0; 3 0; 4 .1; 2 .1; 1 .1; 3 .1];
probability_model = libsvm_train(probability_labels,probability_data,probability_cfg);
[probability_predictions,~,raw_probabilities] = svmpredict(probability_labels,probability_data,probability_model,'-b 1 -q');
probability_sorted = libsvm_test(probability_labels,probability_data,probability_cfg,probability_model);
[~,probability_sort_vector] = sort(probability_model.Label);
expected_probabilities = raw_probabilities(:,probability_sort_vector);
assert(isequal(probability_sorted.decision_values,expected_probabilities),'LIBSVM probabilities were not put in canonical label order.')
assert(all(probability_sorted.decision_values(:)>=0 & probability_sorted.decision_values(:)<=1),'LIBSVM probabilities were changed into invalid values.')
assert(all(abs(sum(probability_sorted.decision_values,2)-1)<1e-12),'LIBSVM probability rows no longer sum to one.')
assert(isequal(probability_sorted.predicted_labels,probability_predictions),'Canonicalizing probabilities changed LIBSVM''s predicted labels.')

probability_kernel_cfg = probability_cfg;
probability_kernel_cfg.decoding.method = 'classification_kernel';
probability_kernel_cfg.decoding.train.classification_kernel.model_parameters = '-s 0 -t 4 -c 1 -b 1 -q';
probability_kernel_cfg.decoding.test.classification_kernel.model_parameters = '-b 1 -q';
probability_kernel_data.kernel = probability_data*probability_data';
probability_kernel_model = libsvm_train(probability_labels,probability_kernel_data,probability_kernel_cfg);
[probability_kernel_predictions,~,raw_kernel_probabilities] = svmpredict(probability_labels,[(1:length(probability_labels))' probability_kernel_data.kernel],probability_kernel_model,'-b 1 -q');
probability_kernel_sorted = libsvm_test(probability_labels,probability_kernel_data,probability_kernel_cfg,probability_kernel_model);
[~,probability_kernel_sort_vector] = sort(probability_kernel_model.Label);
expected_kernel_probabilities = raw_kernel_probabilities(:,probability_kernel_sort_vector);
assert(isequal(probability_kernel_sorted.decision_values,expected_kernel_probabilities),'Kernel LIBSVM probabilities were not put in canonical label order.')
assert(isequal(probability_kernel_sorted.predicted_labels,probability_kernel_predictions),'Canonicalizing kernel probabilities changed LIBSVM''s predicted labels.')

% Clearing the core function simulates a fresh MATLAB function state.
clear libsvm_test
sorted_after_clear = libsvm_test(train_labels,train_data,svm_cfg,svm_model);
assert(isequal(sorted_after_clear.decision_values,expected_decision_values),'Clearing libsvm_test changed decision-value canonicalization.')
rmpath(libsvm_dir)

fprintf('All Step 1 regression tests passed.\n')


function cleanup_test_dir(test_dir)

if exist(test_dir,'dir')
    rmdir(test_dir,'s')
end


function decision_values = canonical_decision_values(decision_values,label_order)

if issorted(label_order)
    return
end

n_labels = size(label_order,1);
if n_labels==2
    decision_values = -decision_values;
    return
end

[first_class,second_class] = meshgrid(1:n_labels,1:n_labels);
keep = tril(true(n_labels),-1);
pairs = [first_class(keep) second_class(keep)];
pair_labels = label_order(pairs);
sign_vector = 2*double(pair_labels(:,2)>pair_labels(:,1))-1;
[~,sort_vector] = sortrows([min(pair_labels,[],2) max(pair_labels,[],2)]);
decision_values = bsxfun(@times,decision_values,sign_vector');
decision_values = decision_values(:,sort_vector);
