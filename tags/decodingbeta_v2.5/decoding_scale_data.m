% function [data,scaleparams] = decoding_scale_data(cfg,data,scaleparams)
%
% Function to perform data scaling on training or on test data.
%
% The function currently supports only row scaling, i.e. scaling
% across samples. To preserve independence of training and test data, one
% approach is to perform scaling on training data and later apply
% these parameters to test data (estimation = 'across').
%
% However, in general there is no reason to assume that a simple scaling of 
% data can carry any category-specific information from training to test 
% set, so scaling can be performed using all data samples, which is more 
% stable (recommended; estimation = 'all').
%
%
% Input variables:
%    cfg                 : struct containing configuration information
%    cfg.scale.method    : 'z', 'min0max1', 'none'. Defines type of scaling.
%    cfg.scale.estimation: 'all', 'across' or 'none'. When all is selected,
%                          all data is scaled, and when across is selected, 
%                          data is scaled for training separately than for 
%                          testing (slower).
%    [cfg.scale.cutoff]  : optional input for outlier reduction, 1x2 vector
%                         ([lower bound upper bound])
%    data                : contains samples to be scaled
%    [scaleparams]       : possibly needed for action 'test', generated from
%                         action 'train'
%
% Output:
%    data         : samples on which scaling had been performed
%    [scaleparams]: when needed scaling parameters for action 'test'
%
% Martin H. 2010/05/12

% restructured Martin H. 2010/07/25
% TODO: introduce column scaling (would need to change position of scaling
% function)

function [data,scaleparams] = decoding_scale_data(cfg,data,scaleparams)

% if no scaling is wanted, return to invoking function
if strcmp(cfg.scale.method,'none')
    scaleparams = []; % do nothing
    return
end

% Set scaling parameters
if ~exist('scaleparams','var') || isempty(scaleparams)
    switch lower(cfg.scale.method)
        case 'min0max1'
            scaleparams.samples_min = min(data,[],1);
            scaleparams.samples_max = max(data,[],1);
        case 'z'
            scaleparams.samples_mean = mean(data);
            scaleparams.samples_std = std(data);
            scaleparams.samples_std(scaleparams.samples_std==0) = 1; % prevents divide by 0, if no std exists
        otherwise
            error(['Unknown scaling method ' cfg.scale.method ', please check'])
    end
end

% Scale data
if exist('bsxfun','builtin') % New method for Matlab 7.4+ (fast)
    
    switch lower(cfg.scale.method)
        case 'min0max1'
            data = bsxfun(@minus, data, scaleparams.samples_min);
            data = bsxfun(@rdivide, data, scaleparams.samples_max - scaleparams.samples_min);
        case 'z'
            data = bsxfun(@minus, data, scaleparams.samples_mean);
            data = bsxfun(@rdivide, data, scaleparams.samples_std);
    end
    
else % Old method for < Matlab 7.4 (slow)
    
    switch lower(cfg.scale.method)
        case 'min0max1'
            minmat = repmat(scaleparams.samples_min,size(data,1),1);
            maxmat = repmat(scaleparams.samples_max,size(data,1),1);
            data = (data - minmat)./(maxmat - minmat);
        case 'z'
            meanmat = repmat(scaleparams.samples_mean,size(data,1),1);
            stdmat = repmat(scaleparams.samples_std,size(data,1),1);
            data = (data - meanmat) ./ stdmat;
    end
    
end

% Remove outliers (default cutoff: [-Inf Inf])
data(data<cfg.scale.cutoff(1)) = cfg.scale.cutoff(1);
data(data>cfg.scale.cutoff(2)) = cfg.scale.cutoff(2);