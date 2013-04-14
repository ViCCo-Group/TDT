% function table = print_design(cfg)
%   or
% function table = print_design(cfg.design)
%
% Prints the design matrices (train, test & label) in a nice(r) form.
%
% For a graphical representation, see  plot_design.m
%
% See also: plot_design.m

% Potential improvements
%
% - Multiple blocks for long designs (e.g. after 20 steps)

function table = print_design(cfg)

%% check if input is design subfield
if ~isfield(cfg, 'design') && isfield(cfg, 'files')
    % save design in cfg.design for this function
    cfg.design = cfg;
end


%% print the design in a readable form
nrows = length(cfg.files.name);

% data
if size(cfg.files.name, 1) == 1
    % flip
    cfg.files.name = cfg.files.name';
end

% reduce file name length
fnames = char(cfg.files.name);
n_files = size(fnames,1);
n_str = size(fnames,2);
for i_str = 1:n_str
    str = strmatch(fnames(1,1:i_str),fnames(2:end,:));
    if length(str) ~= n_files-1
        n_match = i_str-1;
        break
    end
end
filestart = fnames(1,1:n_match); % common file start
if length(filestart) > 15
    filerest = [repmat('...', size(fnames, 1), 1), fnames(:, n_match+1:end)]; % get not common part + initial '...'
    fnames = filerest;
else
	% keep fnames as they are (not cutted)
end

% get first column (filenames + header) as string
% filename_str = char([{'files.name'}; {'---'}; cfg.files.name; {'---'}; {'design.set'}]);
filename_str = char([{'files.name'}; {'---'}; fnames; {'---'}; {'design.set'}]);

% set
if isfield(cfg.design, 'set')
    set_str = char([{num2str(cfg.design.set)}]);
else
    set_str = '';
end
    
train_str = char([{'design.train'}; {''}; {num2str(cfg.design.train)}; {''}; set_str]);
test_str = char([{'design.test'}; {''}; {num2str(cfg.design.test)}; {''}; set_str]);
label_str = char([{'design.label'}; {''}; {num2str(cfg.design.label)}; {''}; set_str]);

% tabs
tabs = repmat(sprintf('\t'), size(filename_str, 1),1); % prepare tabs for hdr + data

% table
table = [filename_str, tabs, train_str, tabs, test_str, tabs, label_str]; 

% add common part
if exist('filerest', 'var')
    table = char([{'DECODING DESIGN'}; {'File start: '}; {['  ' filestart]}; {table}]);
end

% print if not returned
if nargout < 1
    disp(table)
end