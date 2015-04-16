% function dist = euclidean(X)
% 
% A function to calculate the Euclidean distance between multiple vectors.
% Usually faster than squareform(pdist(X,'euclidean')). No checks included
% in order to keep speed high.
%
% 2015/04/14 Martin Hebart


function dist = euclidean(X)


ssq = sum(X.*X,2); % faster than diag(x'*x)

if exist('bsxfun','builtin')
    dist = sqrt(max(bsxfun(@plus,ssq,ssq')-2*(X*X'),0));
else
    sz = size(X,1);
    dist = sqrt(max(repmat(ssq,[1 sz]) + repmat(ssq',[sz 1]) - 2*(X*X'),0));
end