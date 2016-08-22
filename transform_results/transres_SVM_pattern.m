% output = transres_SVM_pattern(decoding_out, chancelevel, cfg, data)
% 
% Calculates the pattern according to Haufe et al (2014), Neuroimage. This
% is done by first getting the weights in source space (primal problem), if
% a linear SVM was used (otherwise no weights can be calculated for the
% primal problem). The bias term is not needed for this.
% To use it, use
%
%   cfg.results.output = {'SVM_pattern'}
%
% Caution: This function uses cfg.design, so it needs a design and assumes
% you are in the main analysis (and not in e.g. feature_selection). It
% further assumes that all input models are related to their decoding step.
%
% OUTPUT
%   1x1 cell array of cell arrays for each output(step), with the pattern
%   as a n_featuresx1 numeric output. For multiclass, 
%   
% Martin, 2014-01-15

% History
% 2016-03-08: Added multiclass capabilities

function output = transres_SVM_pattern(decoding_out, chancelevel, cfg, data)

%% check that input data has not been changed without the user knowing it
check_datatrans(mfilename, cfg); 

%% check that the model was a linear SVM 
% only works for libSVM for the moment
if ~strcmpi('libsvm', cfg.decoding.software)
    error('Can''t get primal weights for anything except libSVM at the moment');
end
% check that we indeed use a linear SVM
% get the current libSVM parameters
switch lower(cfg.decoding.method)
    case 'classification'
        libsvm_options = cfg.decoding.train.classification.model_parameters;
    case 'classification_kernel'
        error('Pattern cannot be returned for cfg.decoding.method = ''classification_kernel'', please use cfg.decoding.method = ''classification''!');
    case 'regression'
        libsvm_options = cfg.decoding.train.regression.model_parameters;
end
% find '-t 0' in the current options (parameter for linear svm)
if isempty(strfind(libsvm_options, '-t 0'))
    error('Calculating linear weights for the primal problem does not make sense, because the classifier is not linear')
end

% Unpack model
model = [decoding_out.model];

%% Get weights (implementation from libsvm website)
% see http://www.csie.ntu.edu.tw/~cjlin/libsvm/faq.html#f804

n_models = length(model);
output{1} = cell(n_models,1);
for i_model = 1:n_models
    m = model(i_model);
    ulabel = uniqueq(m.Label);
    n_label = length(ulabel);
    
    if strcmpi(cfg.decoding.method, 'classification')
        
        % get weights first
        
        if n_label == 2
            
            weights = m.SVs' * m.sv_coef;
            
        else
            % for extensively commented code, see transres_SVM_weights
            csum = cumsum(m.nSV);
            rangeind = [[1; csum(1:end-1)+1] csum];
            [a,b] = meshgrid(1:n_label,1:n_label);
            c = tril(true(n_label),-1);
            d = [a(c) b(c)];
            ind = d(:,[2 1]) + (d-1)*n_label - [d(:,1) d(:,2)-1];
            mask = zeros(size(m.sv_coef,1),1);
            for i_label = 1:n_label
                mask(rangeind(i_label,1):rangeind(i_label,2)) = (i_label-1)*(n_label-1)+1;
            end
            mask = bsxfun(@plus,mask,0:n_label-2);
            weights = zeros(size(m.SVs,2),n_label*(n_label-1)/2);
            ct = 0;
            m.SVs = full(m.SVs);
            for i_label = 1:n_label
                for j_label = i_label+1:n_label
                    ct = ct+1;
                    rind = [rangeind(i_label,1):rangeind(i_label,2) rangeind(j_label,1):rangeind(j_label,2)];
                    coef = [m.sv_coef(mask==ind(ct,1)); m.sv_coef(mask==ind(ct,2))];
                    weights(:,ct) = m.SVs(rind,:)'*coef;
                end
            end
        end
        
        %% Get pattern
        
        % Get all relevant data and corresponding labels (check if correct)
        select_ind = cfg.design.train(:, i_model) > 0;
        all_data_train = data(select_ind, :);
        all_labels = cfg.design.label(select_ind, i_model);
        [n_samples n_dim] = size(all_data_train);
        
        pattern = zeros(size(weights));
        ct = 0;
        for i_label = 1:n_label
            for j_label = i_label+1:n_label
                ct = ct+1;
                % we need correct order for label_ind
                label_ind = [find(all_labels == m.Label(i_label)) find(all_labels == m.Label(j_label))];
                data_train = all_data_train(label_ind,:);
                
                if n_dim^2<10^7 % if pattern doesn't have a very large number of voxels
                    pattern(:,ct) = cov(data_train)*weights(:,ct) / cov(weights(:,ct)'*data_train'); % like cov(X)*W * inv(W'*X')
                else % else do row by row (not much slower, even if we chunk it no dramatic speed-up)
                    warningv('TRANSRES_SVM_PATTERN:pattern_calculation_slow','Pattern is very large, so its estimation will be very slow (up to minutes)!')
                    scale_param = cov(weights(:,ct)'*data_train');
                    pattern_unscaled = zeros(n_dim,1);
                    for i = 1:n_dim % remove mean columnwise
                        data_train(:,i) = data_train(:,i) - mean(data_train(:,i));
                    end
                    fprintf(repmat(' ',1,20))
                    backstr = repmat('\b',1,20);
                    for i = 1:n_dim % now calculate columnwise
                        if i == 1 || ~mod(i,round(n_dim/50)) || i == n_dim
                            fprintf([backstr '%03.0f percent finished'],100*i/n_dim)
                        end
                        data_cov = (data_train(:,i)'*data_train)/(n_samples-1);
                        pattern_unscaled(i,1) = data_cov * weights(:,ct);
                    end
                    fprintf('\ndone.\n')
                    pattern(:,ct) = pattern_unscaled / scale_param; % like cov(X)*W * inv(W'*X')
                end
            end
        end
        
        
        output{1}{i_model} = pattern;
        
    else
        error('Method %s not implemented for cfg.decoding.method = %s.',mfilename,cfg.decoding.method)
    end
end



