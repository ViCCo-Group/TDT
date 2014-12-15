function [p,stat] = decoding_statistics2


% TODO: when using images, check that they all come from the same space
% TODO: next introduce maybe paired t-test or F-test
% TODO: make function that creates a csv-file from results data (but when searchlight too many columns)?


% start off by creating a t-test script

% TODO: make format that allows multiple entries at the same time

n = size(values,1); % TODO: make format the same as the decoding analysis (samples x features, i.e. it should be samples x searchlights)

switch lower(stat2.test)
    
    
    case 't'

        df = n-1;

        m = sum(values)/n;

        se = (sum((values-m).^2)/(n*df))^0.5; % really fast calculation of standard error (on my computer 3x faster than std/(sqrt(n))
        t = m/se;

        % if tcdf doesn't exist, use our custom t_cdf function (a little slower and
        % precision only up till 1e-12, but doesn't require statistics toolbox)
        if exist('tcdf','file')
            hstat = @tcdf;
        else
            hstat = @t_cdf;
        end

        p = hstat(t,df);


    case 'f'
        
        

