% function designs = prepare_designs_permutation(cfg,n_perms_select)
%
% This function creates designs for a number of within-subject permutations
% for a full permutation test, but importantly keeping data from different 
% decoding steps (e.g. runs) separate. The only requirement is that a 
% function was used to create the original design (e.g. make_design_cv.m). 
% If no such function was used, it is necessary to create one first to 
% reiterate the design creation steps for the permutations.
%
% For two-class classification, the labels can be used symmetrically. For
% that reason, the actual possible number of permutations may be half of
% those expected.
%
% Using multiple sets is not supported, because permutations can be
% calculated separately for them and then combined using combine_designs.
%
% INPUT:
%   cfg: configuration struct variable that was used for the original
%     decoding analysis. In fact, only the contents of cfg.files are
%     needed which can be created automatically or manually 
%     (see decoding_tutorial.m). In addition, the field
%     cfg.design.function.name is needed which contains the name of the
%     design creation function.
%   n_perms_select: Number of permutations that should be created. If 
%       n_perms_select exceeds the number of possible permutations, then 
%       the maximum number of permutations will be created. If 
%       n_perms_select is empty, the function displays the number of 
%       available permutations and the output will be empty. Can either be
%       an integer number or the string 'all', in which case all available
%       permutations will be selected.
%
% OUTPUT:
%   designs: 1xn cell matrix of permutation designs that are created by 
%       this function. These can be filled into the cfg by setting 
%       cfg.design = designs{k} where k is the index of the requested design.
%
% Martin Hebart, 2013/08/31

% TODO: randomly picking a subset of all possible designs without
% calculating all possible designs has not been implemented, yet. In case
% the number of possible designs is e.g. larger than 10^9, then they just
% cannot use this function, yet.
% TODO: also for more than two labels a symmetry might exist (e.g. when
% interchanging label 1 with label 2, and label 2 with label 3 etc.). This
% reduces the number of possible permutations, but is not implemented, yet.

function designs = prepare_designs_permutation(cfg,n_perms_select)

if length(unique(cfg.design.set)) > 1
    error('Only designs with one set variable (cfg.design.set) are allowed (see help!')
end

designs = [];
max_n_perms = 10^9; % if there are more than max_n_oerms possible combinations, only sample some of them.

% First calculate number of possible permutations
% Do this by calculating the number of possible permutations within each
% step and then multiplying them across all steps

all_steps = unique(cfg.files.step);
all_labels = unique(cfg.files.label);
n_steps = length(all_steps);
n_perms_step = zeros(1,length(all_steps));
perm_indices = cell(1,length(all_steps));

for i_step = 1:n_steps
    
    curr_step = all_steps(i_step);
    
    % Get labels of current step
    step_labels = cfg.files.label(cfg.files.step == curr_step);
    n_samples = length(step_labels);
    unique_step_labels = unique(step_labels);
    n_labels_step = length(unique_step_labels);
    
    % This function works with more labels than 2 (for which nchoosek would be used)
    n_perms_step(i_step) = number_uniqueperms(step_labels,unique_step_labels,n_labels_step);
    perm_indices{i_step} = 1:n_perms_step(i_step);
    
end

% The number of permutations is the product of all permutations
n_perms_orig = prod(n_perms_step);

% If total number of labels is 2, then divide n_perms by 2
if length(all_labels) == 2
    n_perms = n_perms_orig/2;
end

if ~exist('n_perms_select','var')
   disp(['Number of possible permutations for input data: ' num2str(n_perms)])
   return
end

% Check if number of requested permutations exceeds number of possible permutations
if isstr(n_perms_select)
    if strcmpi(n_perms_select,'all')
        n_perms_select = n_perms;
    else
        error('Unknown string variable %s entered for the number of permutations!')
    end
end


if n_perms < n_perms_select
    warningstr = sprintf('Number of requested permutations %.0f exceeds number of possible permutations %.0f. ',n_perms_select,n_perms);
    warningstr = [warningstr sprintf('Using maximum number of available permutations!')];
    warningv('PREPARE_DESIGNS_PERMUTATION:toomanyperms',warningstr);
    n_perms_select = n_perms;
end


if n_perms <= max_n_perms

% Now get all possible permutations within each step
step_perms = cell(1,n_steps);
for i_step = 1:n_steps
    
    curr_step = all_steps(i_step);
    step_labels = cfg.files.label(cfg.files.step == curr_step);
    step_perms{i_step} = uniqueperms(step_labels);
    
end

% Now combine permutations across steps
all_perms = zeros(n_perms_orig,length(cfg.files.label));

% Get row indices of all combinations using ndgrid
all_ind = cell(1,length(perm_indices)); 
[all_ind{:}] = ndgrid(perm_indices{:});
for i_step = 1:length(all_ind)
    all_ind{i_step} = all_ind{i_step}(:);
end
% rows are permutations, columns are steps
all_ind = cell2mat(all_ind);

% Now fill all_perms by picking the appropriate row (in a for-loop)
ct = 0;
for i_step = 1:n_steps
    curr_row_ind = all_ind(:,i_step);
    curr_row = step_perms{i_step}(curr_row_ind,:);
    row_length = size(curr_row,2);
    all_perms(:,ct+1:ct+row_length) = curr_row;
    ct = ct+row_length;
end

% If two labels, then remove symmetry
if length(all_labels) == 2
    
    original = all_perms;
    inverted = zeros(size(original));
    inverted(original==all_labels(1)) = all_labels(2);
    inverted(original==all_labels(2)) = all_labels(1);
    
    remove_ind = [];
    for i_iter = 1:size(all_perms,1)
        if any(remove_ind==i_iter)
            continue
        end
        remove_ind = [remove_ind find(all(repmat(original(i_iter,:),size(all_perms,1),1)==inverted,2))]; %#ok<AGROW>
    end
    
    all_perms(remove_ind,:) = [];
    
    
end

% Flip all_perms
all_perms = all_perms';

else % in case that number of permutations is very large, calculate only a random subset

    errorstr = sprintf('Number of permutations is too large to be calculated fully. ');
    errorstr = [errorstr sprintf('Calculating a subset has not been implemented, yet! ')];
    errorstr = [errorstr sprintf('If you believe your memory permits, increase the ')];
    errorstr = [errorstr sprintf('number of maximal permutations in the beginning of this function!')];
    error(errorstr)
    
end

% Pick requested subset of number of permutations (if all are selected,
% this is also fine)
pick_ind = 1:n_perms;
if n_perms_select < n_perms
    pick_ind = pick_ind(randperm(length(pick_ind)));
    pick_ind = pick_ind(1:n_perms_select);
    pick_ind = sort(pick_ind);
end

% Finally, fill designs (only need to change the label variable)
fhandle = str2func(cfg.design.function.name);
for i_perm = 1:n_perms_select
    cfg.files.label = all_perms(:,pick_ind(i_perm));
    designs{i_perm} = feval(fhandle,cfg);
end
    
function output = number_uniqueperms(step_labels,unique_step_labels,n_labels)

n_samples_per_label = zeros(1,n_labels);
for i_label = 1:n_labels
    n_samples_per_label(i_label) = sum(step_labels == unique_step_labels(i_label));
end
n_samples_per_label = sort(n_samples_per_label);

% Updated this from Ged Ridgway's uperms function to prevent overflow
output = prod(n_samples_per_label(end)+1:sum(n_samples_per_label)) / prod(factorial(n_samples_per_label(1:end-1)));

function output = uniqueperms(input)
    
    input = input(:);
    input_length = length(input);
    
    unique_input = unique(input);
    number_unique = length(unique_input);
    
    if isempty(input)
        output = [];
    elseif number_unique == 1
        output = input';
    elseif input_length == number_unique
        output = perms(input);
    else
        output = cell(number_unique,1);
        for i = 1:number_unique
            v = input;
            ind = find(v == unique_input(i),1,'first');
            v(ind) = [];
            temp = uniqueperms(v);
            output{i} = [repmat(unique_input(i),size(temp,1),1) temp];
        end
        output = cell2mat(output);
    end
    







