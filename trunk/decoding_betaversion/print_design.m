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
tabs = repmat(sprintf('\t'), nrows+1,1); % prepare tabs for hdr + data

% data
filename_str = char([{'files.name'}, cfg.files.name]);

train_str = char([{'design.train'}; {num2str(cfg.design.train)}]);
test_str = char([{'design.test'}; {num2str(cfg.design.test)}]);
label_str = char([{'design.label'}; {num2str(cfg.design.label)}]);

% table
table = [filename_str, tabs, train_str, tabs, test_str, tabs, label_str]; 