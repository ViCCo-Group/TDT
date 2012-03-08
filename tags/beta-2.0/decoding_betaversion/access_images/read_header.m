function varargout = read_header(software,varargin)

%   read_header varargin: 
%       input: name of volume (full path , 1 x n string)
%       output: header of volume

fname = [mfilename '_' lower(software)];
varargout{1} = feval(fname,varargin{:});