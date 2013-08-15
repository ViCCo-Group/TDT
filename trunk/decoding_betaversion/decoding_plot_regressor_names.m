% function decoding_plot_regressor_names(spm_folder)
%
% This function gives you an overview over the possible regressor names
% that can be used as labels for a decoding analysis. This is helpful if
% you don't want to look inside the SPM.mat (e.g. with the SPM GUI) or do 
% not have the regressor names created in the spm folder, yet.
%
% INPUT:
% spm_folder: The folder where the design matrix is stored as SPM.mat.
%   Alternatively, the matrix can also be stored in a *_SPM.mat file (e.g.
%   if you want to reduce the filesize when data is passed on to someone else).
%
% If you want the regressor names as output, use the function
% get_design_from_spm.m

function decoding_plot_regressor_names(spm_folder)

cfg = decoding_defaults;
addpath(fullfile(cfg.toolbox_path,'design'))
regressor_names = design_from_spm(spm_folder,0);

[all_names,b] = unique(regressor_names(1,:),'first');
[tmp,bb] = sort(b); % to get the original order
all_names = all_names(bb); % use index to keep the order
all_runs = unique([regressor_names{2,:}]);

n_names = length(all_names);
n_runs = length(all_runs);

all_names_char = char(all_names);

fprintf('\nNumber of different regressors: %.0f\n',n_names)
fprintf('Number of runs: %.0f\n',n_runs)
fprintf('Regressor names (and run numbers where regressor occurs):\n')
for i_name = 1:n_names
    ind = strcmp(regressor_names(1,:),all_names{i_name});
    curr_runs = [regressor_names{2,ind}];
    if all(diff(curr_runs)==1)
        fprintf('%s (%.0f:%.0f)\n',all_names_char(i_name,:),curr_runs(1),curr_runs(end))
    else
        fprintf('%s (%s)\n',all_names_char(i_name,:),num2str(curr_runs));
    end
end

