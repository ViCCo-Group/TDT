function varargout = get_filenames(software,varargin)

%   get_filenames varargin:
%       inputs: file path (1 x n string), possible filenames with wildcards (e.g. *.img or rf*.img)
%       output: filenames as n x m char array (n = number of files)

fname = [mfilename '_' lower(software)];
varargout{1} = feval(fname,varargin{:});