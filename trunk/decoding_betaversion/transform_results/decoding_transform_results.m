% function output = decoding_transform_results(method,decoding_out,chancelevel,cfg,model)
%
% This function caculates a lot of different result measures defined by
% METHOD.
%
% It also calls external transres_XX functions that implement other
% methods, e.g. "trans_model_parameters" if method = 'model_parameter'.
%
% METHODS IMPLEMENTED HERE:
% accuracy: decoding accuracy
% accuracy_minus_chance: decoding accuracy minus chance level (useful for 
%   SPM 2nd level)
% sensitivity: accuracy of first label
% sensitivity_minus_chance: sensitivity minus chance level
% specificity: accuracy of second label
% specificity_minus_chance: specificity minus chance level
% dprime: z(hit rate) - z(false alarm rate)
% loglikelihood: measure of bias to one label: -1/2*(zHIT_rate^2 - zFA_rate^2)
% AUC: Area under the ROC (Receiver Operator Characteristics) Curve
% AUC_minus_chance: like AUC, but minus chance level(useful for SPM 2nd level)
% corr: Correlation
% zcorr: Fisher-z-transformed correlation (necessary for averaging correlations)
%
% The function also allows adding new result transformation functions by 
% calling
%
%   output = transres_METHOD(decoding_out,chancelevel);
%
% where METHOD will be replaced by the provided method name.
% E.g., if you want to write your own result transformation function
% "yourmethod", the method shall be named "transres_yourmethod", take
% decoding_out and chancelevel as input, and provide your desired output
% measure as output.
%
% IN
%   method: desired method name as string (s. above)
%   decoding_out: struct with result from last decoding step
%   cfg: the standard decoding cfg struct that was used for the last
%        decoding
%   model: the model that was used for the last decoding
%
% OUT
%   output: can be either a single number or a struct ({}) that can contain
%       any type of data. For nomal application, output contains the fields
%           output.predicted_labels
%           output.true_labels
%       which are both 1 x n_step double vectors containing the predicted
%       and the true labels, so that these can be compared. However, in
%       principle output contains whatever the decoding method puts out
%       (e.g. if you write your own method).

% TODO: Remove chancelevel here as explicit input, should be returned by 
% each method (also for each decoding step separately).

function output = decoding_transform_results(method,decoding_out,chancelevel,cfg,model)

if strcmpi(method, 'accuracy') || strcmpi(method, 'accuracy_minus_chance')
    predicted_labels =  vertcat(decoding_out.predicted_labels);
    true_labels = vertcat(decoding_out.true_labels);
    
    output = 100 * sum(predicted_labels == true_labels)/size(predicted_labels,1); % calculate mean (faster than Matlab function)
    
    if strcmpi(method, 'accuracy_minus_chance')
        output = output - chancelevel; % subtract chancelevel from all output entries
    end
    
elseif strcmpi(method, 'sensitivity') || strcmpi(method, 'sensitivity_minus_chance') % where the first label is correct
    predicted_labels =  vertcat(decoding_out.predicted_labels);
    true_labels = vertcat(decoding_out.true_labels);
    
    labels = unique(true_labels);
    if length(labels) > 2
        error('Too many labels for sensitivity measure! Check input labels.')
    end
    labelfilt = true_labels == labels(1); % use first label (only works with two labels)
    output = 100 * mean(predicted_labels(labelfilt) == true_labels(labelfilt));
    
    if strcmpi(method, 'sensitivity_minus_chance')
        output = output - chancelevel; % subtract chancelevel from all output entries
    end
    
elseif strcmpi(method, 'specificity') || strcmpi(method, 'specificity_minus_chance') % where the other label is correct
    predicted_labels =  vertcat(decoding_out.predicted_labels);
    true_labels = vertcat(decoding_out.true_labels);
    
    labels = unique(true_labels);
    if length(labels) > 2
        error('Too many labels for sensitivity measure! Check input labels.')
    end
    labelfilt = true_labels == labels(end); % use last label (only works with two labels)
    output = 100 * mean(predicted_labels(labelfilt) == true_labels(labelfilt));
    if strcmpi(method, 'specificity_minus_chance')
        output = output - chancelevel; % subtract chancelevel from all output entries
    end
    
elseif strcmpi(method, 'dprime')
    predicted_labels =  vertcat(decoding_out.predicted_labels);
    true_labels = vertcat(decoding_out.true_labels);
    
    output = dprimestats(true_labels,predicted_labels);
    
elseif strcmpi(method, 'loglikelihood')
    predicted_labels =  vertcat(decoding_out.predicted_labels);
    true_labels = vertcat(decoding_out.true_labels);
    
    [dprime,output] = dprimestats(true_labels,predicted_labels);
    
elseif strcmpi(method, 'AUC') || strcmpi(method, 'AUC_minus_chance')
    decision_values = vertcat(decoding_out.decision_values);
    true_labels = vertcat(decoding_out.true_labels);
    
    labels = unique(true_labels);
    output = AUCstats(decision_values,true_labels,labels,0);
    if strcmpi(method, 'AUC_minus_chance')
        output = 100*output - chancelevel; % center around 0 and express in percent
    end
    
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
    
    fhandle = str2func(['transres_' method]);
    output = feval(fhandle,decoding_out,chancelevel,cfg,model);
    % e.g. if method = 'yourmethod', this calls:
    %  output = transres_yourmethod(decoding_out,chancelevel,cfg,model);
    
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
