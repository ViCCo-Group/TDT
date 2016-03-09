% Comparison between new weight extraction function that can extract
% weights from one multiclass classification and the old weight function
% that needed binary comparisons, both tested with and without TDT
%
% Kai, 9.3.16

%% Get random data
labels = repmat(1:10,1,10)';
data = randn(100,300);

% shift all data to provoke a bias
% data = data + 10;

% add an effect for class 10 in the last voxel
% data(labels == 10, :) = data(labels == 10, :) + 1;
%% Multiclass classification
% do multiclass classification without TDT
m = svmtrain(labels,data,'-s 0 -t 0 -q');

% set the minimum number of parameters needed for the new function to pass
% the model result to the new transres function to get the weights without
% TDT
cfg = [];
cfg.decoding.method = 'classification';
cfg.decoding.train.classification.model_parameters = '-s 0 -t 0 -q';
cfg.decoding.software = 'libsvm';

cfg.feature_transformation.method='none';
cfg.feature_selection.method='none';
cfg.scale.method='none';

decoding_out.model = m;

% get the weights without TDT
weights_new = transres_SVM_weights(decoding_out, nan, cfg);
weights_plusbias_new = transres_SVM_weights_plusbias(decoding_out, nan, cfg);

%% Check that the result is the same as when using a loop with single classification with the old weight functions

weights = [];
weights_plusbias = [];

ct = 0;
for i_label = 1:10
    for j_label = i_label+1:10
        ct = ct+1;
        ind = labels==i_label | labels==j_label;
        m = svmtrain(labels(ind),data(ind,:),'-s 0 -t 0 -q');
        
        decoding_out = [];
        decoding_out.model = m;
        
        curr_weights = transres_SVM_weights_old(decoding_out, nan, cfg);
        weights(:,ct) = curr_weights{1}{1};
        curr_weights = transres_SVM_weights_plusbias_old(decoding_out, nan, cfg);
        weights_plusbias.w(:,ct) = curr_weights{1}{1}.w;
        weights_plusbias.b(:,ct) = curr_weights{1}{1}.b;
    end
end

%% Check how well new multiclass and old calculation from binary classes agree

display('Without TDT: Check how well new multiclass (without TDT) and old calculation from pairwise comparison (without TDT) agree')
weightdiff = weights - weights_new{1}{1};
min_max_weight = [min(weights(:)) max(weights(:))]
max_abs_weightdiff = max(abs(weightdiff(:)))

weight_plusbias_w_diff = weights_plusbias.w - weights_plusbias_new{1}{1}.w;
min_max_weight_plusbias_w = [min(weights_plusbias.w(:)) max(weights_plusbias.w(:))]
max_abs_weight_plusbias_w_diff = max(abs(weight_plusbias_w_diff(:)))

weight_plusbias_b_diff = weights_plusbias.b - weights_plusbias_new{1}{1}.b;
min_max_weight_plusbias_b = [min(weights_plusbias.b(:)) max(weights_plusbias.b(:))]
max_abs_weight_plusbias_b_diff = max(abs(weight_plusbias_b_diff(:)))

%% Keep cfg
cfg_org = cfg;

%% Do the same processing with TDT using pass_data multiclass

% add what we need to run TDT
cfg = decoding_defaults(cfg_org);

cfg.results.write = 0; % no results are written to disk
cfg.analysis = 'wholebrain';
cfg.results.output = {'SVM_weights', 'SVM_weights_plusbias'};

% setup for passed data
cfg.files.label = labels;
cfg.files.chunk = ones(size(cfg.files.label)); % no chunks
cfg.files.name = cellstr(strcat('cl', num2str(cfg.files.label, '%02i'), 'ck', num2str(cfg.files.chunk, '%02i'), '#', num2str([1:length(cfg.files.label)]', '%03i')));
cfg.files.mask = ''; % need no name for a mask but make sure the field is there

%% Setup passed data for multiclass
passed_data = [];
passed_data.data = data;
passed_data.mask_index = 1:size(data, 2); % use all voxels
passed_data.files = cfg.files;
passed_data.hdr = ''; % we don't need a header, because we don't write img-files as output (but mat-files)
passed_data.dim = [size(data, 2), 1, 1];

% Set the analysis that should be performed
cfg.design = make_design_alldata(cfg);

[results, cfg] = decoding(cfg, passed_data);

%% compare with multiclass result from top

display('Multiclass with vs without TDT: Check how well new multiclass without vs. with TDT agree ')

mc_weights_new = results.SVM_weights.output{1}{1};
mc_weights_plus_bias_w_new = results.SVM_weights_plusbias.output{1}{1}.w;
mc_weights_plus_bias_b_new = results.SVM_weights_plusbias.output{1}{1}.b;

weightdiff = mc_weights_new - weights_new{1}{1};
min_max_weight = [min(mc_weights_new(:)) max(mc_weights_new(:))]
max_abs_weightdiff = max(abs(weightdiff(:)))

weight_plusbias_w_diff = mc_weights_plus_bias_w_new - weights_plusbias_new{1}{1}.w;
min_max_weight_plusbias_w = [min(mc_weights_plus_bias_w_new(:)) max(mc_weights_plus_bias_w_new(:))]
max_abs_weight_plusbias_w_diff = max(abs(weight_plusbias_w_diff(:)))

weight_plusbias_b_diff = mc_weights_plus_bias_b_new - weights_plusbias_new{1}{1}.b;
min_max_weight_plusbias_b = [min(mc_weights_plus_bias_b_new(:)) max(mc_weights_plus_bias_b_new(:))]
max_abs_weight_plusbias_b_diff = max(abs(weight_plusbias_b_diff(:)))

%% Do the same for with TDT all pairwise, use  new and old measures

% add what we need to run TDT

bc_weights = [];
bc_weights_plusbias.w = [];
bc_weights_plusbias.b = [];

bc_weights_new = [];
bc_weights_plusbias_new.w = [];
bc_weights_plusbias_new.b = [];

ct = 0;

profile on

for i_label = 1:10
    for j_label = i_label+1:10
        display(sprintf('binary classifications, i=%i, j=%i', i_label, j_label));
        
        ct = ct+1;
        ind = labels==i_label | labels==j_label; % index for all data and labels that we use in the current decoding
        
        cfg = decoding_defaults(cfg_org);
        
        cfg.plot_design = 0; % dont show design
        
        cfg.results.write = 0; % no results are written to disk
        cfg.analysis = 'wholebrain';
        cfg.results.output = {'SVM_weights_old', 'SVM_weights_plusbias_old', 'SVM_weights', 'SVM_weights_plusbias'};
        
        % setup cfg for passed data
        cfg.files.label = labels(ind);
        cfg.files.chunk = ones(size(cfg.files.label)); % no chunks
        cfg.files.name = cellstr(strcat('cl', num2str(cfg.files.label, '%02i'), 'ck', num2str(cfg.files.chunk, '%02i'), '#', num2str([1:length(cfg.files.label)]', '%03i')));
        cfg.files.mask = ''; % need no name for a mask but make sure the field is there
        
        % Setup passed data
        passed_data = [];
        passed_data.data = data(ind, :);
        passed_data.mask_index = 1:size(data, 2); % use all voxels
        passed_data.files = cfg.files;
        passed_data.hdr = ''; % we don't need a header, because we don't write img-files as output (but mat-files)
        passed_data.dim = [size(data, 2), 1, 1];
        
        % Set the analysis that should be performed
        cfg.design = make_design_alldata(cfg);
        
        [results, cfg] = decoding(cfg, passed_data);
        
        % save results of this loop
        
        bc_weights(:,ct) = results.SVM_weights_old.output{1}{1};
        
        bc_weights_plusbias.w(:,ct) = results.SVM_weights_plusbias_old.output{1}{1}.w;
        bc_weights_plusbias.b(:,ct) = results.SVM_weights_plusbias_old.output{1}{1}.b;
        
        bc_weights_new(:,ct) = results.SVM_weights.output{1}{1};
        
        bc_weights_plusbias_new.w(:,ct) = results.SVM_weights_plusbias.output{1}{1}.w;
        bc_weights_plusbias_new.b(:,ct) = results.SVM_weights_plusbias.output{1}{1}.b;
        
    end
end

profile view

%% Check that they all do what they should

display('Pariwise binary with TDT: Check how well new function and the old function agree on the same pairwise binary classification with TDT')

weightdiff = bc_weights - bc_weights_new;
min_max_weight = [min(bc_weights_new(:)) max(bc_weights_new(:))]
max_abs_weightdiff = max(abs(weightdiff(:)))

weight_plusbias_w_diff = bc_weights_plusbias.w - bc_weights_plusbias_new.w;
min_max_weight_plusbias_w = [min(bc_weights_plusbias_new.w(:)) max(bc_weights_plusbias_new.w(:))]
max_abs_weight_plusbias_w_diff = max(abs(weight_plusbias_w_diff(:)))

weight_plusbias_b_diff = bc_weights_plusbias.b - bc_weights_plusbias_new.b;
min_max_weight_plusbias_b = [min(bc_weights_plusbias_new.b(:)) max(bc_weights_plusbias_new.b(:))]
max_abs_weight_plusbias_b_diff = max(abs(weight_plusbias_b_diff(:)))

display('Pariwise binary with TDT: Check how well new function (that also works for multiclass) agrees WITH TDT to old function (that just worked for single comparison) for pairwise binary classification WITHOUT TDT')
weightdiff = weights_new{1}{1} - bc_weights_new;
min_max_weight = [min(bc_weights_new(:)) max(bc_weights_new(:))]
max_abs_weightdiff = max(abs(weightdiff(:)))

weight_plusbias_w_diff = weights_plusbias_new{1}{1}.w - bc_weights_plusbias_new.w;
min_max_weight_plusbias_w = [min(bc_weights_plusbias_new.w(:)) max(bc_weights_plusbias_new.w(:))]
max_abs_weight_plusbias_w_diff = max(abs(weight_plusbias_w_diff(:)))

weight_plusbias_b_diff = weights_plusbias_new{1}{1}.b - bc_weights_plusbias_new.b;
min_max_weight_plusbias_b = [min(bc_weights_plusbias_new.b(:)) max(bc_weights_plusbias_new.b(:))]
max_abs_weight_plusbias_b_diff = max(abs(weight_plusbias_b_diff(:)))

display('All done')