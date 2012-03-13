% function table = print_design(cfg)
%
% Prints the design matrices (train, test & label) in a nice(r) form.
%
% Potential improvements
%
% - Add common file parts (as we use it for logfiles)
% - Multiple blocks for long designs (e.g. after 20 steps)

function table = print_design(cfg)

%% print the design in a readable form
nrows = length(cfg.files.name);

% data
filename_str = char([{'files.name'}, {'---'}, cfg.files.name, {'---'}, {'design.set'}]);

% set
set_str = char([{num2str(cfg.design.set)}]);

train_str = char([{'design.train'}; {''}; {num2str(cfg.design.train)}; {''}; set_str]);
test_str = char([{'design.test'}; {''}; {num2str(cfg.design.test)}; {''}; set_str]);
label_str = char([{'design.label'}; {''}; {num2str(cfg.design.label)}; {''}; set_str]);

% tabs
tabs = repmat(sprintf('\t'), size(filename_str, 1),1); % prepare tabs for hdr + data

% table
table = [filename_str, tabs, train_str, tabs, test_str, tabs, label_str]; 

if nargout < 1
    display(table);
end