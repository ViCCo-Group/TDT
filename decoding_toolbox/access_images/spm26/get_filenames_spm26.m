function varargout = get_filenames_spm26(varargin)

% SPM26 retains the public image-access API used by the SPM12 adapter.
[varargout{1:nargout}] = get_filenames_spm12(varargin{:});
