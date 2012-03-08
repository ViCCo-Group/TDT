function varargout = write_image(software,varargin)

%   write_image varargin:
%       inputs: header, volume (X x Y x Z)
%       output: written header (normally not needed)

fname = [mfilename '_' lower(software)];
varargout{1} = feval(fname,varargin{:});