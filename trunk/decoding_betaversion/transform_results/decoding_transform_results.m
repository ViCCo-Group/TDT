function output = decoding_transform_results(method,decoding_out,chancelevel)

% TODO: split this function up to ease the process of adding new functions

if strcmpi(method, 'accuracy')
    predicted_labels =  vertcat(decoding_out.predicted_labels);
    true_labels = vertcat(decoding_out.true_labels);
    
    output = 100 * mean(predicted_labels == true_labels);
    output = output - chancelevel; % subtract chancelevel from all output entries
    
elseif strcmpi(method, 'sensitivity') % where the first label is correct
    predicted_labels =  vertcat(decoding_out.predicted_labels);
    true_labels = vertcat(decoding_out.true_labels);
    
    labels = unique(true_labels);
    if length(labels) > 2
        error('Too many labels for sensitivity measure! Check input labels.')
    end
    labelfilt = true_labels == labels(1); % use first label (only works with two labels)
    output = 100 * mean(predicted_labels(labelfilt) == true_labels(labelfilt));
    output = output - chancelevel; % subtract chancelevel from all output entries
    
elseif strcmpi(method, 'specificity') % where the other label is correct
    predicted_labels =  vertcat(decoding_out.predicted_labels);
    true_labels = vertcat(decoding_out.true_labels);
    
    labels = unique(true_labels);
    if length(labels) > 2
        error('Too many labels for sensitivity measure! Check input labels.')
    end
    labelfilt = true_labels == labels(end); % use last label (only works with two labels)
    output = 100 * mean(predicted_labels(labelfilt) == true_labels(labelfilt));
    output = output - chancelevel; % subtract chancelevel from all output entries
    
elseif strcmpi(method, 'dprime')
    predicted_labels =  vertcat(decoding_out.predicted_labels);
    true_labels = vertcat(decoding_out.true_labels);
    
    output = dprimestats(true_labels,predicted_labels);
    
elseif strcmpi(method, 'loglikelihood')
    predicted_labels =  vertcat(decoding_out.predicted_labels);
    true_labels = vertcat(decoding_out.true_labels);
    
    [dprime,output] = dprimestats(true_labels,predicted_labels);
    
elseif strcmpi(method, 'AUC')
    decision_values = vertcat(decoding_out.decision_values);
    true_labels = vertcat(decoding_out.true_labels);
    
    labels = unique(true_labels);
    output = AUCstats(decision_values,true_labels,labels,0);
    output = 100*output - chancelevel; % center around 0 and express in percent
    
elseif strcmpi(method, 'corr')
       
    n_steps = length(decoding_out);
    output_sep = zeros(1,n_steps);
    for i_step = 1:n_steps
       output_sep(i_step) = correl(decoding_out(i_step).predicted_labels,decoding_out(i_step).true_labels);
    end
    output = tanh(mean(atanh(output_sep))); % z-transform and back to average correlation
    
elseif strcmpi(method, 'zcorr')

    n_steps = length(decoding_out);
    output_sep = zeros(1,n_steps);
    for i_step = 1:n_steps
       output_sep(i_step) = correl(decoding_out(i_step).predicted_labels,decoding_out(i_step).true_labels);
    end
    output = mean(atanh(output_sep)); % z-transform
    
else % all other methods
    
    fhandle = str2func(method);
    output = feval(fhandle,decoding_out,chancelevel);
    % e.g. if method = 'yourmethod', this calls:
    %  output = yourmethod(decoding_out,chancelevel);
    
end





%% Possibly use this function (replace unique by unique )
% % 30% faster than unique for the small arrays used here
% function vect_out = unique_labels(vect_in)
% 
% vect_in = vect_in(:);
% vect_sorted = sort(vect_in);
% vect_sorted_diff = diff(vect_sorted);
% vect_sorted_ind = [true; vect_sorted_diff ~=0];
% vect_out = vect_sorted(vect_sorted_ind);
