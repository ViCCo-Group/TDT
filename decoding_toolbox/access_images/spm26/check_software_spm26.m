function checked = check_software_spm26(varargin)

% SPM26 retains the public image-access API used by the SPM12 adapter.
checked = check_software_spm12(varargin{:});
