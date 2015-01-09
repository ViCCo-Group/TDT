% function r = correl(x,y)
% 
% Custom made correlation function, faster than Matlab versions, but less 
% general (e.g. only for 1D x and y)

function r = correl(x,y)

sx = size(x);
sy = size(y);

if sx(2) ~= 1
    x = x';
    sx(1) = sx(2);
end

if sy(2) ~= 1
    y = y';
    sy(1) = sy(2);
end

x0 = x - sum(x,1)/sx(1); % here sum is faster than mean
y0 = y - sum(y,1)/sy(1);
r = (x0./norm(x0))' * (y0./norm(y0));