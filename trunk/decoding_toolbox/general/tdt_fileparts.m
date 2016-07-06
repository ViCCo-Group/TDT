function [fpath,fname,suffix,fext] = tdt_fileparts(fullfname)

% This function is like fileparts, but with a third output suffix which is
% important for AFNI (e.g. +orig). If no + exists in the filename, suffix
% will be empty.

% Martin Hebart 16/07/06

[fpath,fname_,fext] = fileparts(fullfname);

tmp = strsplit(fname_,'+');
switch length(tmp)
    case 1
        fname = fname_;
        suffix = '';
    case 2
        fname = tmp{1};
        suffix = ['+' tmp{2}];
    otherwise
        ind = strfind(fname_,'+');
        fname = fname_(1:(ind(end)-1));
        suffix = ['+' tmp{end}];
end