% function plot_design(cfg)
%
% This function plots your current design (analog to print_design.m).
%
% It works, but at the moment the output is somewhat ugly.
%
% If you like and/or know how to design nice figures in matlab, feel free
% to improve the design.
%
% See also: print_design.m

% Kai, 13-01-24


function plot_design(cfg)

%% define colours
max_color = [.7, .5, .2]; % RGB values for the max color -- min color is black at the moment
background_color = [.5, .5, .5];

%% get min and max label for later scaling

min_label = min(cfg.design.label(:));
max_label = max(cfg.design.label(:));

%% show train design (incl. labels)
clear show_train
for rgb = 1:3
    currcol = cfg.design.train;
    currcol(cfg.design.train == 0) = background_color(rgb);
    currcol(cfg.design.train == 1) = (cfg.design.label(cfg.design.train == 1)-min_label)./(max_label-min_label).*max_color(rgb);
    show_train(:, :, rgb) = currcol;
end
    
figure('name', 'Decoding Design')
subplot(2,2,1)
image(show_train)
title('Training Data')

%% add filenames

% compress filenames
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

set(gca,'YTickLabel', fnames)
xlabel('Training Data - Step number')

%% same for test
clear show_test
for rgb = 1:3
    currcol = cfg.design.train;
    currcol(cfg.design.test == 0) = background_color(rgb);
    currcol(cfg.design.test == 1) = (cfg.design.label(cfg.design.test == 1)-min_label)./(max_label-min_label).*max_color(rgb);
    show_test(:, :, rgb) = currcol;
end
    
subplot(2,2,2)
image(show_test)
title('Test Data')
set(gca, 'YTick', 1:size(cfg.files.name, 1))
set(gca,'YTickLabel', cfg.files.name)
xlabel('Test Data - Step number')

%% if a description is available, also add this on the right

if isfield(cfg.files, 'description')
    % move yaxis to the right
    set(gca, 'YAxisLocation', 'right');
    set(gca, 'YTick', 1:size(cfg.files.description, 1))
    set(gca,'YTickLabel', cfg.files.description);
else
    % switch yaxis off
end

%% add legend (this is still ugly)

clear show_legend
unique_labels = sort(unique(cfg.design.label(:)))';
for rgb = 1:3
    currcol = (unique_labels-min_label)./(max_label-min_label).*max_color(rgb);
    currcol(end+1) = background_color(rgb);
    show_legend(:, :, rgb) = currcol;
end
    
subplot(2,2,3)
image(show_legend)
xlabel('Unique label values (NOT necessary linearly scaled)')
set(gca, 'ytick', [])
set(gca, 'XTick', 1:length(unique_labels)+1)
set(gca, 'XTickLabel', [sprintf('%i|', unique_labels) 'unused'])


subplot(2,2,2)
title('color <-> values')

