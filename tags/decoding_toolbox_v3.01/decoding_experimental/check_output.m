function check_output(cfg)

% after this function has been tested, it can go into decoding_basic_checks
% and possibly even replace check_libsvm, because it is more general
% (but possibly not)

outputs = cfg.results.output;
use_kernel = ~isempty(strfind(cfg.decoding.method, '_kernel'));
n_vox_simu = 500;
n_samples = size(cfg.design.train,1);
data_simu = [ones(floor(n_samples/2),n_vox_simu); -ones(ceil(n_samples/2),n_vox_simu)];

if use_kernel
    kernel_simu = cfg.decoding.kernel.function(data_simu,data_simu);
end

for i_step = 1:length(cfg.design.set)

    n_labels = length(uniqueq(cfg.design.label(cfg.design.train(:,i_step)&cfg.design.test(:,i_step))));
    chancelevel = 100/n_labels;
    i_train = logical(cfg.design.train(:,i_step));
    curr_labels_train = cfg.design.label(i_train);
    curr_labels_test = cfg.design.label(logical(cfg.design.test(:,i_step)));
    
if ~use_kernel
    model = cfg.decoding.fhandle_train(curr_labels_train, data_simu(i_train,:), cfg);
else % when using kernel
    curr_kernel_simu.kernel = kernel_simu(i_train,i_train);
    model = cfg.decoding.fhandle_train(curr_labels_train, curr_kernel_simu, cfg);
end


    decoding_out(i_step).predicted_labels = curr_labels_test;
    decoding_out(i_step).true_labels = curr_labels_test;
    decoding_out(i_step).decision_values = curr_labels_test;
    decoding_out(i_step).model = model;
end

for i_output = 1:length(outputs)
    try
        output = decoding_transform_results(outputs{i_output},decoding_out,chancelevel,cfg,data_simu);
    catch
        error('Could not write output ''%s''. Either method does not exist or data is incompatible. Please check!',outputs{i_output})
    end
end