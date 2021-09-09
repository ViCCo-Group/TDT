% test_tdt_different_designs_different_outputs
%
% testing that different output create expected outputs on simple data
% for different szenarios that went wrong in the past. Assertions will fail
% and throw errors.
%
% You should be able to run the function without getting any errors.
%   
% Tested outputs:
%   cfg.results.output = {'accuracy', 'accuracy_minus_chance',
%       'accuracy_matrix', 'accuracy_matrix_minus_chance', 
%       'accuracy_pairwise', 'accuracy_pairwise_minus_chance', 
%       'confusion_matrix'};
% Szenarios include design_separate, design_cv, unbalanced data, labels not
% in increasing order. Uses very simple SAA (Goergen et al) constructed 
% data in passed_data.
%
% Based on a bugreport from Simon.
%
% Simon & Kai, 2020-06-17


function test_tdt_different_designs_different_outputs

disp('Testing if different outputs give the expected results for different settings in which they havent')

clear
nrun = 3;
ntrials = 4;

%% Create labels and chunks

label = repmat(1:ntrials,1,nrun)';
chunk = sort(repmat(1:nrun,1,ntrials))';

% Do decoding
[results,cfg,passed_data] = saa_decoding_chunk_label(chunk, label);
disp('Results original (increasing labels in chunk)')

%% Create labels and chunks, randomly shuffle within run

label = repmat(1:ntrials,1,nrun)';
chunk = sort(repmat(1:nrun,1,ntrials))';

% different ways to sort 
% sort_index = randperm(numel(label));
% sort_index = numel(label):-1:1;                                           % all reversed
% sort_index = []; for i = 1:8, sort_index = [sort_index, [8:-1:1]+8*(i-1)]; end         % all chunks reversed individually
sort_index = []; for i = 1:nrun, sort_index = [sort_index, randperm(ntrials)+ntrials*(i-1)]; end      %#ok<AGROW> % each chunk randomized individually, simulates loading scheme in analysis script
label_sorted = label(sort_index);
chunk_sorted = chunk(sort_index);

% Do decoding
[results,cfg,passed] = saa_decoding_chunk_label(chunk_sorted, label_sorted);
disp('Results sorted (randomized labels within chunk)')

%% Create labels and chunks, decreasing labels in run

label = repmat(ntrials:-1:1,1,nrun)'
chunk = sort(repmat(1:nrun,1,ntrials))'

% Do decoding
[results,cfg,passed_data] = saa_decoding_chunk_label(chunk, label);
disp('Results original (decreasing labels in run)')

%% Create labels and chunks, unbalanced number of trials but kind of sorted

label = repmat(1:ntrials,1,nrun)'
chunk = sort(repmat(1:nrun,1,ntrials))'

% add extra trials to the last chunk to get imbalanced data
label(end+1:end+2) = 1:2;
chunk(end+1:end+2) = chunk(end);

unbalanced = 'ok';

% Do decoding
[results,cfg,passed_data] = saa_decoding_chunk_label(chunk, label, unbalanced);
disp('Results unbalanced number of trials but kind of sorted')

%% unbalance data, order of first labels not as usual

% unsorted
label = [2 1 4  1 2 4 4]'; %  2 3 3 3 1 1]'
chunk = [1 1 1  2 2 2 2]'; %  3 3 3 3 3 3]'

unbalanced = 'ok'

% Do decoding
[results,cfg,passed_data] = saa_decoding_chunk_label(chunk, label, unbalanced);
disp('unbalance data, order of first labels not as usual')

%% End of tests
disp('All tests successful - yeah!')

%% Helper function

function [results,cfg,passed_data] = saa_decoding_chunk_label(chunk, label, unbalanced, cfg)

if ~exist('cfg', 'var')
    cfg = [];
else
    warning('using the following cfg as startpoint')
    display(cfg)
end
cfg = decoding_defaults(cfg);
cfg.analysis = 'ROI';
cfg.plot_selected_voxels = 0;
cfg.plot_design = 0;

cfg.results.output = {'accuracy', 'accuracy_minus_chance', 'accuracy_matrix', 'accuracy_matrix_minus_chance', 'accuracy_pairwise', 'accuracy_pairwise_minus_chance', 'confusion_matrix'};
disp('Checking: ')
display(cfg.results.output')

% for bug tracking: CHECK if the following solves your bug (should not be
% the case - if so, check which persistent variables cause the error)
% clear all persistent functions that might be used
% for cind = 1:length(cfg.results.output)
%     evalstr = ['clear transres_' cfg.results.output{cind}]
%     eval(evalstr)
% end

cfg.decoding.method = 'classification_kernel';
cfg.results.write = 0;

%%% default
clear passed_data results
passed_data.data = [label chunk];
passed_data.dim = [2 1 1];
[passed_data,cfg] = fill_passed_data(passed_data,cfg,label,chunk);
% cfg.design = make_design_cv(cfg);
cfg.design = make_design_separate(cfg);
if exist('unbalanced', 'var')
    cfg.design.unbalanced_data = unbalanced;    
end
% cfg.fighandles.plot_design = plot_design(cfg);
[results,cfg,passed_data] = decoding(cfg,passed_data);

% disp('Test that labels and chunks correspond between input and used, and that both correspond to data (visually)')
assert(isequal(passed_data.data, [label chunk]), 'passed_data was not as expected. Check if the assignment above changed from what is tested, or otherwise why it changes during processing')
assert(isequal([cfg.files.label(:) cfg.files.chunk(:)], [label(:) chunk(:)]), 'cfg.files.label or cfg.files.chunk are not as expected. Check if the assignment above changed from what is tested, or otherwise why it changes during processing')

% display([label cfg.files.label chunk cfg.files.chunk passed_data.data])
assert(abs(results.accuracy.output)-100 < 1e-12, 'accuracy should be 100 in this simple setting but isnt'); % sometimes small inaccuracies, order e-14
cfg.results.output = cfg.results.output(~strcmp(cfg.results.output, 'accuracy'));  % remove from list

assert(abs(results.accuracy_minus_chance.output + results.accuracy_minus_chance.chancelevel)-100 < 1e-12, 'accuracy_minus_chance.output + accuracy_minus_chance.chancelevel should sum up to 100 in this simple setting but dont')
cfg.results.output = cfg.results.output(~strcmp(cfg.results.output, 'accuracy_minus_chance'));  % remove from list

assert(abs(results.accuracy_pairwise.output)-100 < 1e-12, 'accuracy_pairwise: should be 100')
cfg.results.output = cfg.results.output(~strcmp(cfg.results.output, 'accuracy_pairwise'));  % remove from list

assert(abs(results.accuracy_pairwise_minus_chance.output)-50 < 1e-12, 'accuracy_pairwise_minus_chance: should be 50 in this simple setting, pairwise (chance 1/2) accuracy minus chance max')
cfg.results.output = cfg.results.output(~strcmp(cfg.results.output, 'accuracy_pairwise_minus_chance'));  % remove from list

fieldname = 'accuracy_matrix';
display(results.(fieldname).output{1});
output = results.(fieldname).output{1};
assert(all(isnan(diag(output))), ['The diagonal of ' fieldname '  should be nan but is not, please check']);
expectedval = 100;
assert(all(output(~eye(size(output)))-expectedval < 1e-12), [fieldname ': should be %i in this simple setting for all entries but is not, please check '], expectedval);
cfg.results.output = cfg.results.output(~strcmp(cfg.results.output, fieldname));  % remove from list

fieldname = 'accuracy_matrix_minus_chance';
display(results.(fieldname).output{1});
output = results.(fieldname).output{1};
assert(all(isnan(diag(output))), ['The diagonal of ' fieldname '  should be nan but is not, please check']);
expectedval = 50;
assert(all(output(~eye(size(output)))-expectedval < 1e-12), [fieldname ': should be %i in this simple setting for all entries but is not, please check '], expectedval);
cfg.results.output = cfg.results.output(~strcmp(cfg.results.output, fieldname));  % remove from list

fieldname = 'confusion_matrix';
display(results.(fieldname).output{1});
output = results.(fieldname).output{1};
expectedval = 100;
assert(all(diag(output)-expectedval < 1e-12), ['The diagonal of ' fieldname '  should be %i in this simple setting but is not, please check'], expectedval);
expectedval = 0;
assert(all(output(~eye(size(output)))-expectedval < 1e-12), [fieldname ': should be %i in this simple setting for all entries but is not, please check '], expectedval);
cfg.results.output = cfg.results.output(~strcmp(cfg.results.output, fieldname));  % remove from list

% report remaining entries
display(cfg.results.output)
assert(isempty(cfg.results.output), 'Some entries in cfg.results.output were calculated but not tested. Please check. Remaining values: see above')