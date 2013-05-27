% function plot_design(cfg,visible_on)
%
% This function plots your current design (analog to display_design.m).
%
% The output is informative, because you can see your decoding design at a glance.
%
% If you like and/or know how to design nice figures in Matlab, feel free
% to improve the design.
%
% Some possible input:
%   cfg.fighandles.plot_design (optional): Figure handle to which design
%       will be plotted to
%
% See also: display_design.m

% Kai, 13-01-24

% TODO: In contrast to display_design, plot_design(cfg.design) does not work at
% the moment.

function figure_handle = plot_design(cfg,visible_on)

if ~exist('visible_on','var')
    visible_on = 1;
end

%% define colours
max_color = [.7, .5, .2]; % RGB values for the max color -- min color is black at the moment
background_color = [.5, .5, .5];

%% define position of subplots
% we use a 4x4 grid and specify the number of all positions that should be
% used
pos.train = [5, 6, 9, 10];
pos.test = [7, 8, 11, 12];
% Text is positioned using a 4x4 grid
pos.text = [1:4];
% to create a bit more space for text and legend, we add extra space by
% using a 8x4 grid
pos.legend = [29];

%% get min and max label for later scaling

min_label = min(cfg.design.label(:));
max_label = max(cfg.design.label(:));

%% create figure

if isfield(cfg, 'fighandles') && isfield(cfg.fighandles, 'plot_design')
    figure(cfg.fighandles.plot_design)
    warning('Ignoring visible_on at the moment')
else
    if visible_on
        figure_handle = figure('name', 'Decoding Design','visible','on');
    else
        % TODO: problem with visible off: when opening .fig, figure remains
        % invisible
        figure_handle = figure('name', 'Decoding Design','visible','off');
    end
end

%% show train design (incl. labels)
clear show_train
for rgb = 1:3
    currcol = cfg.design.train;
    currcol(cfg.design.train == 0) = background_color(rgb);
    currcol(cfg.design.train == 1) = (cfg.design.label(cfg.design.train == 1)-min_label)./(max_label-min_label).*max_color(rgb);
    show_train(:, :, rgb) = currcol;
end
    
subplot(4, 4, pos.train)
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
	% keep fnames as they are (not cut)
end

set(gca,'YTick', 1:size(fnames,1))
set(gca,'YTickLabel', fnames)
xlabel('Training Data - Step number')

%% same for testset
clear show_test
for rgb = 1:3
    currcol = cfg.design.train;
    currcol(cfg.design.test == 0) = background_color(rgb);
    currcol(cfg.design.test == 1) = (cfg.design.label(cfg.design.test == 1)-min_label)./(max_label-min_label).*max_color(rgb);
    show_test(:, :, rgb) = currcol;
end
    
subplot(4, 4, pos.test)
image(show_test)
title('Test Data')

set(gca, 'YTick', 1:size(cfg.files.name, 1))
xlabel('Test Data - Step number')

% add file description on the left if available
if isfield(cfg.files, 'descr')
    set(gca,'yaxislocation','right')
    set(gca, 'YTick', 1:size(cfg.files.name, 1))
    set(gca,'YTickLabel', cfg.files.descr)
end

%% if a description is available, also add this on the right

if isfield(cfg.files, 'description')
    % move yaxis to the right
    set(gca, 'YAxisLocation', 'right')
    if size(cfg.files.description, 1) == 1
        cfg.files.description = cfg.files.description';
    end
    
    set(gca, 'YTick', 1:size(cfg.files.description, 1))
    set(gca,'YTickLabel', cfg.files.description);
else
    % switch yaxis off
end

%% add legend (this is still ugly)

clear show_legends
unique_labels = sort(unique(cfg.design.label(:)))';
for rgb = 1:3
    currcol = (unique_labels-min_label)./(max_label-min_label).*max_color(rgb);
    currcol(end+1) = background_color(rgb);
    show_legend(:, :, rgb) = currcol;
end
    
subplot(8, 4, pos.legend)
image(show_legend)
title({'Unique label values'; '(NOT necessary linearly scaled)'})
set(gca, 'ytick', [])
set(gca, 'XTick', 1:length(unique_labels)+1)
set(gca, 'XTickLabel', [sprintf('%i|', unique_labels) 'unused'])

%% add remaining text
subplot(4, 4, pos.text);

text_maxlength = 100; % number of characters

% common file start
outtext = {'TDT - Decoding details'};
if ~isempty(filestart)
    outtext_mrow = ['Filestart: ' filestart];
    while ~isempty(outtext_mrow)
        outtext{end+1} = outtext_mrow(1:min(text_maxlength, end));
        outtext_mrow(1:min(text_maxlength, end)) = [];
    end
end

% result dir
if isfield(cfg.results, 'dir')
    outtext_mrow = ['Results: ' cfg.results.dir];
    while ~isempty(outtext_mrow)
        outtext{end+1} = outtext_mrow(1:min(text_maxlength, end));
        outtext_mrow(1:min(text_maxlength, end)) = [];
    end
else
    outtext{end+1} = ['Results: not written to file'];
end

% start & endtime, if available
if isfield(cfg, 'progress') && isfield(cfg.progress, 'starttime')
    outtext{end+1} = ['Start: ' cfg.progress.starttime];
    if isfield(cfg, 'progress') && isfield(cfg.progress, 'endtime')
        outtext{end} = [outtext{end} ', End: ' cfg.progress.endtime];
    else
        outtext{end} = [outtext{end} ', End: No endtime'];
    end
else
    outtext{end+1} = ['Start/Endtime not available'];
end

axis off

text(0,.5,outtext, 'Interpreter', 'none', 'BackgroundColor',[.7 .9 .7]);

%% make sure it shows up
drawnow;
