function checked = check_software_spm25(varargin)

% SPM25 retains the public image-access API used by the SPM12 adapter.
checked = check_software_spm12(varargin{:});
