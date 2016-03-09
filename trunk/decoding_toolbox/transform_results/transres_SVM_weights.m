% output = transres_SVM_weights(decoding_out, chancelevel, cfg, varargin)
% 
% Calculates the weights in source space (primal problem), if a linear SVM 
% was used (otherwise no weights can be calculated for the primal problem).
% Use this function if you only want to plot weights and do not more
% calculations, because then the decoding toolbox can automate this for
% you. If you need the bias term for calculations, use
% transres_SVM_weights_plusbias.
%
% To use it, use
%
%   cfg.results.output = {'SVM_weights'}
%
% OUTPUT
%   1x1 cell array of cell arrays for each output(step), with the weights
%   for each primal dimension as n_weightsx1 numeric output.
%   % for multiclass the output is a n_weights x n_comparisons matrix with
%   a column for each pair of comparisons (for 3 classes: class 1 vs. 2,
%   1 vs. 3, 2 vs. 3)
%   
% Martin, 2014-01-15
%
% See also transres_SVM_weights_plusbias, transres_SVM_pattern

% UPDATE Martin 2016-03-08: included case of multiclass classification (a
%                           lot faster than many pairwise classifications)

function output = transres_SVM_weights(decoding_out, chancelevel, cfg, varargin)

%% check that input data has not been changed without the user knowing it
check_datatrans(mfilename, cfg); 

%% check that the model was a linear SVM 
% only works for libSVM for the moment
if ~strcmpi(cfg.decoding.software,'libsvm')
    error('Can''t get primal weights for anything except libsvm at the moment');
end
% check that we indeed use a linear SVM
% get the current libSVM parameters
switch lower(cfg.decoding.method)
    case 'classification'
        libsvm_options = cfg.decoding.train.classification.model_parameters;
    case 'classification_kernel'
        error('Weights cannot be returned for cfg.decoding.method = ''classification_kernel'', please use cfg.decoding.method = ''classification''!');
    case 'regression'
        libsvm_options = cfg.decoding.train.regression.model_parameters;
end
% find '-t 0' in the current options (parameter for linear svm)
if isempty(strfind(libsvm_options, '-t 0'))
    error('Calculating linear weights for the primal problem does not make sense, because the classifier is not linear')
end

% Unpack model
model = [decoding_out.model];

%% implementation from libsvm website
% see http://www.csie.ntu.edu.tw/~cjlin/libsvm/faq.html#f804

n_models = length(model);
output{1} = cell(n_models,1);
for i_model = 1:n_models
    m = model(i_model);
    ulabel = uniqueq(m.Label);
    n_label = length(ulabel);
    
    if strcmpi(cfg.decoding.method, 'classification')
        
        if n_label == 2
            % simple case for binary classification
            weights = m.SVs' * m.sv_coef;
            output{1}{i_model} = weights;
            
        else
            % more complex case for multiclass classification, see abve for instructions
            % (coding this efficiently was not easy, feel free to improve):
            % http://www.csie.ntu.edu.tw/~cjlin/libsvm/faq.html#f804
            
            % we need to know which rows of SVs and of sv_coef belong to which
            % label, this is determined by the number of support vectors per label
            csum = cumsum(m.nSV);
            % the following provides us with a range for each
            rangeind = [[1; csum(1:end-1)+1] csum];
            
            % we get the relevant subscripts and convert them to indices, it
            % will give us the indices that signal the same pair, e.g. the indices
            % for (1,2) and (2,1) or for (31,5) and (5,31) -> the missing
            % diagonal would make this difficult for indexing
            [a,b] = meshgrid(1:n_label,1:n_label);
            c = tril(true(n_label),-1); % this is our logical index selecting the lower triangular matrix
            d = [a(c) b(c)];
            % This line is like ind2sub, but leaves out the diagonals to get indices
            ind = d(:,[2 1]) + (d-1)*n_label - [d(:,1) d(:,2)-1];
            
            % we assign all entries of sv_coef an index that we use to find relevant entries later
            mask = zeros(size(m.sv_coef,1),1);
            for i_label = 1:n_label
                mask(rangeind(i_label,1):rangeind(i_label,2)) = (i_label-1)*(n_label-1)+1;
            end
            mask = bsxfun(@plus,mask,0:n_label-2);
            
            % init
            weights = zeros(size(m.SVs,2),nchoosek(n_label,2));
            ct = 0;
            
            m.SVs = full(m.SVs); % this speeds everything up
            for i_label = 1:n_label
                for j_label = i_label+1:n_label
                    ct = ct+1; % increase counter
                    % index needs to be sorted, should always be the case if entered this way (I checked it)
                    rind = [rangeind(i_label,1):rangeind(i_label,2) rangeind(j_label,1):rangeind(j_label,2)];
                    % need to index separately to maintain order
                    coef = [m.sv_coef(mask==ind(ct,1)); m.sv_coef(mask==ind(ct,2))];
                    % carry out calculation as done on libsvm website
                    weights(:,ct) = m.SVs(rind,:)'*coef;
                end
            end
            
            output{1}{i_model} = weights;
            
        end
        
    else
       error('Method %s not implemented for cfg.decoding.method = %s.',mfilename,cfg.decoding.method)
    end
end

% %% old version
% The old version works for smaller problems, but not for e.g. wholebrain
% decoding. So I replaced it by a one that should always work. It might
% become interested trying it for linear kernels.
% % get the size of the current primal source space
% [nSVs, primal_dim] = size(model(1).SVs);
% 
% % init a matrix that contains orthogonal + 1 entries
% X = [eye(primal_dim); ones(1, primal_dim)];
% % generate labels (values are unimportant, we are interested in decision_values only)
% labels = ones(size(X, 1), 1);
%     
% % "reverse-engineer" the model for each step
% for i_model = 1:length(model)
% 
%     m = model(i_model);
%     
%     % get the predictions from this model
%     switch lower(cfg.decoding.method)
%         case 'classification'
%             [predicted, acc, decision_values] = svmpredict(labels,X,m,cfg.decoding.test.classification.model_parameters);
%         case 'regression'
%             [predicted, acc, decision_values] = svmpredict(labels,X,m,cfg.decoding.test.regression.model_parameters);
%     end
%         
%     % calculate w and b
%     %  using
%     % Y = w' X + b --> Y = [wb]' [X1] --> Y / [X1] = [wb]'
%     % mit X = eye(size(...))
% 
%     wb = decision_values' / [X, ones(size(decision_values))]';
% 
%     w = wb(1:end-1);
%     b = wb(end);
% 
%     weights.w = w;
%     weights.b = b;
%     
%     output.weights{i_model} = weights;
%     
% end