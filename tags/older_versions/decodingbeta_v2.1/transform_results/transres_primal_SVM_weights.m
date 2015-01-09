% output = transres_primal_SVM_weights(decoding_out, chancelevel, cfg, model)
% 
% Calculates the weights in source space (primal problem), if a linear SVM 
% was used (otherwise no weights can be calculated for the primal problem).
%
% To use it, use
%
%   cfg.results.output = {'primal_SVM_weights'}
%
% OUTPUT
%   struct array for each output.weights(step), containing for each step
%   
%     .w: weights for each primal dimension
%     .b: bias
%     .model: full dual model (as saved by libSVM)

% If you want to draw the lines separating hyperplane & the margins, use
%
% w = weights.w; w0 = weights.b;
% a = -w(1)/w(2);
% b = -w0/w(2);
% 
% % plot hyperplane
% x = [0, 1];
% y = a*x + b;
% hold all
% plot(x, y);
% 
% % upper boundary
% b_up = -(w0+1)/w(2);
% y = a*x + b_up;
% plot(x, y);
% 
% % lower boundary
% b_lo = -(w0-1)/w(2);
% y = a*x + b_lo;
% plot(x, y); 
% hold off

% Kai, 2012-03-12

function output = transres_primal_SVM_weights(decoding_out, chancelevel, cfg, model)

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
    case 'regression'
        libsvm_options = cfg.decoding.train.regression.model_parameters;
end
% find '-t 0' in the current options (parameter for linear svm)
if isempty(findstr(libsvm_options, '-t 0'))
    error('Calculating linear weights for the primal problem does not make sense, because the classifier is not linear')
end

    
% get the size of the current primal source space
[nSVs, primal_dim] = size(model(1).SVs);

% init a matrix that contains orthogonal + 1 entries
X = [eye(primal_dim); ones(1, primal_dim)];
% generate labels (values are unimportant, we are interested in decision_values only)
labels = ones(size(X, 1), 1);
    
% "reverse-engineer" the model for each step
for i_model = 1:length(model)

    m = model(i_model);
    
    % get the predictions from this model
    switch lower(cfg.decoding.method)
        case 'classification'
            [predicted, acc, decision_values] = svmpredict(labels,X,m,cfg.decoding.test.classification.model_parameters);
        case 'regression'
            [predicted, acc, decision_values] = svmpredict(labels,X,m,cfg.decoding.test.regression.model_parameters);
    end
        
    % calculate w and b
    %  using
    % Y = w' X + b --> Y = [wb]' [X1] --> Y / [X1] = [wb]'
    % mit X = eye(size(...))

    wb = decision_values' / [X, ones(size(decision_values))]';

    w = wb(1:end-1);
    b = wb(end);

    weights.w = w;
    weights.b = b;
    weights.model = m; % also save the model
    
    output.weights{i_model} = weights;
    
end
