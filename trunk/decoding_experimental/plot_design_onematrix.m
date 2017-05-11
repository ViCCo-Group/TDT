% function figure_handle = plot_design_onematrix(cfg,visible_on,max_n_fnames)
%
% Works like plot_design, but plots everything in one plot.
% Value is indicated by hue from three palettes from colorbrew.
% Color scheme: 
%   strong colors: Training data
%   light colors: Test data
%   PINK: In both training and test (value not provided)
%   
% If the figure handle should be reused, use as
%   cfg.fighandles.plot_design = plot_design_onematrix(cfg)
%
% This function plots your current design (analog to display_design.m).
%
% The output is informative, because you can see your decoding design at a glance.
%
% If you like and/or know how to design nice figures in Matlab, feel free
% to improve the design.
%
% Some optional input:   
%   visible_on: 1: show figure, 0: do not show figure (default: 1)
%   max_n_fnames: number of maximal displayed file names (default: 16)
%   cfg.fighandles.plot_design: Figure handle to which design
%       will be plotted to (default: new figure)
%
% See also: plot_design, display_design.m

% Kai, adapted from plot_design, 17-05-11


function figure_handle = plot_design_onematrix(cfg,visible_on,max_n_fnames)
drawnow; % fixes a display problem with plot_selected_voxels
if ~exist('visible_on','var')
    visible_on = 1;
end

if ischar(cfg.files.name)
    cfg.files.name = num2cell(cfg.files.name,2);
    warningv('BASIC_CHECKS:FileNamesStringNotCell','File names provided as string, not as cell matrix. Converting to cell...')
end

%% define color range
alternative = 2;

if alternative == 0 % old orange black standard
    max_color = [.7, .5, .2]; % RGB values for the max color -- min color is black at the moment
elseif alternative == 1 % whoohoo, can be ugly
    colors = jet(64);
    max_color = colors(1,:);
elseif alternative == 2
    % colors from colorbrewer
%     % train: dark (blue to green from colorbrewer)
%     max_color_train = [44,162,95]/256;
%     min_color_train = [43,140,190]/256;
%     % test: light (blue to green from colorbrewer)
%     max_color_test = [153,216,201]/256;
%     min_color_test = [166,189,219]/256;

    % Old orange and black    
    % train: dark (old orange and new green)
    max_color_train = [.7, .5, .2];
    min_color_train = [0, .3, .3];
    % test: light (same colors but lighter)
    max_color_test = (max_color_train + 1) / 2; % same color but lighter
    min_color_test = (min_color_train + 1) / 2; % same color but lighter

    % conflict (both in train and in test): pink
    max_color_both = [221,28,119]/256;
    min_color_both = [221,28,119]/256;
else 
    error('Unkown value %i for alternative, please check', alternative)
end

background_color = [.5, .5, .5];



%% define position of subplots
% we use a 4x4 grid and specify the number of all positions that should be
% used
if alternative < 2
    pos.train = [5, 6, 9, 10];
    pos.test = [7, 8, 11, 12];
else
    % we just need one plot
    pos.train = [6, 7, 10, 11];
end
    
% Text is positioned using a 4x4 grid
pos.text = [1:4];
% to create a bit more space for text and legend, we add extra space by
% using a 8x4 grid
pos.legend = [29:31];

%% get min and max label for later scaling

min_label = min(cfg.design.label(:));
max_label = max(cfg.design.label(:));

%% create figure

figure_position = get(0,'defaultFigurePosition');
figure_position = round(figure_position .* [1 1 1.3 1] + [0 -0.4*figure_position(2) 0 +0.4*figure_position(2)] ); % increase width by 30% and height by 40%
if isfield(cfg, 'fighandles') && isfield(cfg.fighandles, 'plot_design')
    % try to reuse the old figure handel
    try
        figure(cfg.fighandles.plot_design)
        figure_handle = cfg.fighandles.plot_design; % return currrent handle
    catch %#ok<CTCH>
        % if the user already closed the figure, open a new one
        warning('Could not use specified figure handle, creating a new figure')
        % Remark: Same as in else-part above, please keep in synch
        if visible_on
            figure_handle = figure('name', 'Decoding Design','visible','on', 'Position', figure_position);
        else
            % TODO: problem with visible off: when opening .fig, figure remains
            % invisible
            figure_handle = figure('name', 'Decoding Design','visible','off', 'Position', figure_position);
        end
    end
    
    %     warning('Ignoring visible_on at the moment') % MH: deactivated this
    %     warning, because it would come always. What does it mean?
else
    % Remark: Same as in catch-part above, please keep in synch
    if visible_on
        figure_handle = figure('name', 'Decoding Design','visible','on', 'Position', figure_position);
    else
        % TODO: problem with visible off: when opening .fig, figure remains
        % invisible
        figure_handle = figure('name', 'Decoding Design','visible','off', 'Position', figure_position);
    end
end


%% create a row with the set information to add to figure

row_length = size(cfg.design.train, 2);
% get set_row
if ~isfield(cfg.design, 'set')
    warning('cfg.design.set does not exist, adding an empty line')
    set_row(1, 1:row_length) = 0;
elseif length(cfg.design.set) == 1
    set_row(1, 1:row_length) = cfg.design.set;
elseif length(cfg.design.set) > row_length
    warning('Set vector is longer than train design matrix, this is strange')
    set_row(1, 1:row_length) = cfg.design.set(1:row_length);
elseif length(cfg.design.set) < size(cfg.design.train, 2)
    warning('Set vector is shorter than train design matrix but not 1, this is strange. Filling with 0s')
    set_row(1, row_length) = 0;
    set_row(1, 1:length(cfg.design.set)) = cfg.design.set;
else
    set_row(1, 1:row_length) = cfg.design.set;
end

% normalize set values for plotting
set_row = set_row - min(set_row) + 1;
set_row = set_row / max(set_row);

% create a 3d version for RGB plotting
set_row(:, :, 2) = set_row;
set_row(:, :, 3) = 0; % setting 3rd value 0 for better contrast

%% get x-axis description
% first row: decoding step [set x]

% Don't display everything if it is too much to display
n_ind = size(cfg.design.train,2);
max_n_ind = 30;
if n_ind > max_n_ind
    % In that case, showing them evenly spaced
    show_ind = round(linspace(1,n_ind,max_n_ind));
    show_ind = unique(show_ind);
else
    show_ind = 1:n_ind;
end

for x_ind = 1:n_ind
    
    if any(show_ind==x_ind)
        if isfield(cfg.design, 'set')
            xstr{x_ind} = sprintf('%i[%i]', x_ind, cfg.design.set(x_ind)); %#ok<*AGROW>
        else
            xstr{x_ind} = sprintf('%i', x_ind);
        end
    else
        xstr{x_ind} = '';
    end
end



%% create train design (incl. labels)

if alternative == 0 % original version
    clear show_train
    for rgb = 1:3
        currcol = cfg.design.train;
        currcol(cfg.design.train == 0) = background_color(rgb);
        currcol(cfg.design.train == 1) = (cfg.design.label(cfg.design.train == 1)-min_label)./(max_label-min_label).*max_color(rgb);
        show_train(:, :, rgb) = currcol;
    end
    
elseif alternative == 1 % ugly version
    selectind = cfg.design.train == 1;
    colorselect = (cfg.design.label(selectind) - min_label)./(max_label-min_label);
    colorselect = ceil((size(colors,1)-1) * colorselect) + 1;
    show_train_rgb = selectind;
    show_train = repmat(selectind,[1 1 3]);
    
    for rgb = 1:3
        show_train_rgb(selectind) = colors(colorselect,rgb);
        show_train(:,:,rgb) = show_train_rgb;
    end
    
elseif alternative == 2 % three color version
    % create training and test in one go

    for rgb = 1:3
        currcol = zeros(size(cfg.design.train)); % init, only to get size
        
        % background
        currcol(cfg.design.train == 0 & cfg.design.test == 0) = background_color(rgb);
        % training
        selectind = cfg.design.train == 1;        
        h = (cfg.design.label(selectind) - min_label)./(max_label-min_label);
        currcol(cfg.design.train == 1) = min_color_train(rgb) * (1-h) + max_color_train(rgb) * h;
        % test
        selectind = cfg.design.test == 1;        
        h = (cfg.design.label(selectind) - min_label)./(max_label-min_label);
        currcol(cfg.design.test == 1) = min_color_test(rgb) * (1-h) + max_color_test(rgb) * h;
        % both (overwrites values from before)
        selectind = (cfg.design.train == 1 & cfg.design.test == 1);
        h = (cfg.design.label(selectind) - min_label)./(max_label-min_label);
        currcol(cfg.design.train == 1 & cfg.design.test == 1) = min_color_both(rgb) * (1-h) + max_color_both(rgb) * h;
        
        show_train(:, :, rgb) = currcol;
    end

end

% show train design
ah_train = subplot(4, 4, pos.train);
image([show_train; set_row]);
if alternative == 2
    title('Training & Test Matrix')
    if size(show_train, 2) < 30
        axis equal
    end
    axis tight
else
    title('Training Data')
end

%% add filenames

% compress filenames
% data
if size(cfg.files.name, 1) == 1
    % flip
    cfg.files.name = cfg.files.name';
end

% reduce file name length
fnames = cfg.files.name;
fnames_char = char(fnames);
n_str = size(fnames_char,2); % maximum string length
n_match = n_str;
for i_str = 1:n_str
    match = strncmp(fnames{1},fnames(2:end),i_str);
    if ~all(match)
        n_match = i_str-1;
        break
    end
end
filestart = fnames_char(1,1:n_match); % common file start
if length(filestart) > 15
    filerest = [repmat('...', size(fnames_char, 1), 1), fnames_char(:, n_match+1:end)]; % get not common part + initial '...'
    fnames_char = filerest;
else
    % keep fnames_char as they are (not cut)
end

% convert to cellstr, much easier to handle
fnames_cstr = cellstr(fnames_char);
clear fnames_char; % to avoid anyone uses it below

% Do not show all file names if too many
n_fnames = size(fnames_cstr,1);
if ~exist('max_n_fnames', 'var')
    max_n_fnames = 16;
end

% if n_fnames > max_n_fnames
% In that case, showing them evenly spaced
% Find smallest integer stepsize so that maximally (default: 16) names are shown
stepsize = ceil(n_fnames/max_n_fnames);
fnames_shown = 1:stepsize:n_fnames; % indices for all names that are shown

% fnames_not_shown = setdiff(1:n_fnames,fnames_shown(:));
% 
% fnames_cstr(fnames_not_shown) = {''};

%% add set as last row + stepsize info

% add set as last row and make sure it's shown
if stepsize>1
    fnames_cstr(end+1) = {sprintf('Showing 1 of %i names; Set', stepsize)};
else
    fnames_cstr(end+1) = {'Set'};
end
fnames_shown(end+1) = length(fnames_cstr);

% show
set(gca,'YTick', fnames_shown)
set(gca,'YTickLabel', fnames_cstr(fnames_shown));
try
    set(gca,'TickLabelInterpreter','none'); % for matlab 2014++
end

%% set xaxis training
set(gca,'XTick', 1:length(xstr))
set(gca,'XTickLabel', xstr)
try, set(gca,'XTickLabelRotation', 60); end
xlabel('Step [Set] nr')

%% same for testset
if alternative ~= 2 % skip, because only 1 plot for alternative 2
    
    if alternative == 0

        clear show_test
        for rgb = 1:3
            currcol = cfg.design.train;
            currcol(cfg.design.test == 0) = background_color(rgb);
            currcol(cfg.design.test == 1) = (cfg.design.label(cfg.design.test == 1)-min_label)./(max_label-min_label).*max_color(rgb);
            show_test(:, :, rgb) = currcol;
        end

    elseif alternative == 1
        selectind = cfg.design.test == 1;
        colorselect = (cfg.design.label(selectind) - min_label)./(max_label-min_label);
        colorselect = ceil((size(colors,1)-1) * colorselect) + 1;
        show_test_rgb = selectind;
        show_test = repmat(selectind,[1 1 3]);

        for rgb = 1:3
            show_test_rgb(selectind) = colors(colorselect,rgb);
            show_test(:,:,rgb) = show_test_rgb;
        end
    end

    ah_test = subplot(4, 4, pos.test);
    % link to train axis
    try linkaxes([ah_train, ah_test]), catch, warning('Failed to link train and test axis'), end
    image([show_test; set_row])
    title('Test Data')
end

    
% add file description on the right if available, else the number
if alternative == 2
    warning('Cant display description of files at the moment')
else
    if isfield(cfg.files, 'descr')
        descr_and_set = cfg.files.descr;
        descr_and_set(end+1) = {''}; % entry for the set row

        set(gca,'yaxislocation','right')
        set(gca, 'YTick', fnames_shown); % 1:length(descr_and_set))

        set(gca,'YTickLabel', descr_and_set(fnames_shown));
        try
            set(gca,'TickLabelInterpreter','none'); % for matlab 2014++
        end
    else
        % add number of each file
        set(gca,'yaxislocation','right')
        set(gca, 'YTick', fnames_shown(1:end-1)); % show simply the number of each, except the set (the last entry)
    end
end
%% set xaxis test
if alternative < 2
    xlabel('Step [Set] nr')
    set(gca,'XTick', 1:length(xstr))
    set(gca,'XTickLabel', xstr)
    try, set(gca,'XTickLabelRotation', 60); end
end
    
%% add legend (this is still ugly)

clear show_legends
unique_labels = sort(unique(cfg.design.label(:)))'; % labels are numbers

if alternative == 0 % old standard
    
    for rgb = 1:3
        currcol = (unique_labels-min_label)./(max_label-min_label).*max_color(rgb);
        currcol(end+1) = background_color(rgb);
        show_legend(:, :, rgb) = currcol;
    end
    
elseif alternative == 1 % ulgy
    colorselect = (unique_labels-min_label)./(max_label-min_label);
    colorselect = ceil((size(colors,1)-1) * colorselect) + 1;
    show_legend = zeros(1,size(colorselect,2),3);
    
    for rgb = 1:3
        show_legend_rgb = colors(colorselect,rgb);
        show_legend(1,:,rgb) = show_legend_rgb;
    end
    show_legend(:,end+1,:) = background_color;
    
elseif alternative == 2
    show_legend = [];
    nuql = length(unique_labels);
    for rgb = 1:3
        h = (unique_labels-min_label)./(max_label-min_label); % value between 0 and 1
        show_legend(1, 1:nuql, rgb) = min_color_train(rgb) .* (1-h) + max_color_train(rgb) .* h;
        show_legend(2, 1:nuql, rgb) = min_color_test(rgb) .* (1-h) + max_color_test(rgb) .* h;
        if any(cfg.design.train == 1 & cfg.design.test == 1)
            show_legend(3, 1:nuql, rgb) = min_color_both(rgb) .* (1-h) + max_color_both(rgb) .* h;
        end
        show_legend(1:end, nuql+1, rgb) = background_color(rgb);
    end
    

end

subplot(8, 4, pos.legend)
image(show_legend)
if alternative < 2
    set(gca, 'YTick', [0.75, 1.25])
    set(gca, 'YAxisLocation', 'right')
    set(gca,'YTickLabel', {'Unique label values'; '(maybe not linearly scaled)'});
else
    set(gca, 'YTick', 1:3)
    set(gca, 'YAxisLocation', 'right')
    if any(cfg.design.train == 1 & cfg.design.test == 1)
        set(gca,'YTickLabel', {'Train', 'Test', '!!!BOTH!!!'});
    else
        set(gca,'YTickLabel', {'Train', 'Test'});
    end
    xlabel({'Unique label values (maybe not linearly scaled)'})
    if size(show_legend, 2) < 30
        axis equal
    end
    axis tight
end
% set(gca, 'ytick', [])

% only show some if too many unique labels
ul_stepsize = ceil(length(unique_labels)/10); 
ul_xticks = [1:ul_stepsize:length(unique_labels), length(unique_labels)+1];
ul_xtick_labels = [num2cell(unique_labels), {'unused'}];
    
set(gca, 'XTick', ul_xticks);
set(gca, 'XTickLabel', ul_xtick_labels(ul_xticks))

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
if isfield(cfg,'results') && isfield(cfg.results, 'write') && ~cfg.results.write
    outtext{end+1} = ['Results: results will not be written (cfg.results.write = 0)'];
elseif isfield(cfg,'results') && isfield(cfg.results, 'dir')
    outtext_mrow = ['Results: ' cfg.results.dir];
    while ~isempty(outtext_mrow)
        outtext{end+1} = outtext_mrow(1:min(text_maxlength, end));
        outtext_mrow(1:min(text_maxlength, end)) = [];
    end
else
    outtext{end+1} = ['Results: directory not defined'];
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
