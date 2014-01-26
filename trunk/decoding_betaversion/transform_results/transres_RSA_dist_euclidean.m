function output = transres_RSA_dist_euclidean(decoding_out,chancelevel,cfg,data)

% function output = transres_RSA_dist_euclidean(decoding_out,chancelevel,cfg,data)
% 
% Calculates the euclidean distance between all datapoints of the full 
% datamatrix.
%

if exist('pdist','file')
    output = {squareform(pdist(data),'euclidean')};
else
    error('Statistics toolbox needed for output transres_RSA_euclidean.')
end