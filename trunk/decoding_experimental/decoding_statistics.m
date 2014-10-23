% function [p,stat] = decoding_statistics(cfg,results)
%
% Calculates statistical results of a given analysis at the decoding level.
% For example, if decoding was done within subject, the statistics is
% returned within subject, too. If decoding was done between subject, the
% statistics reflects between subjects results. For group-level random
% effects analyses, please use decoding_statistics2.
%
% Please note that tests assuming independence of samples are not valid for
% cross-validated designs. An error will be thrown in case any such tests
% are tried to be used on cross-validated results. If your results are
% truly independent (i.e. test samples are always treated separately), we
% recommend binomial testing. For cross-validated results, we recommend
% permutation testing (may be time consuming!). Please contact us if you
% need additional methods implemented (such as chi2 for comparing
% accuracies).
%
% IMPORTANT REMARK: If a '_minus_chance' method had been used (e.g. 
%   accuracy_minus_chance), then internally, chancelevel is added again to
%   the results. If you add a new method, please take this into account.
%
% INPUT:
%   cfg: structure with at least the following fields:
%       stats: struct containing parameters for statistical analysis
%       fields:
%           test:
%               'binomial':    Runs a binomial test
%               'permutation': Runs a permutation test
%           tail:
%               'left':        Left-sided test
%               'right':       Right-sided test
%               'both':        Two-sided test
%   
%   results: entry from .mat-file that has been generated from the main
%       decoding analysis. For example, for res_AUC.mat,
%       the corresponding entries may be found in
%       results.AUC.output and results.AUC.chancelevel
%
%
%   OUTPUT:
%
%   p: p-value of all inputs
%   results: adjusted results file containing p-value and other
%      statistical results
%
% EXAMPLE:
%   After having finished a decoding analysis:
%       load res_cfg.mat
%       load res_accuracy_minus_chance.mat
%       cfg.stats.test = 'binomial';
%       cfg.stats.tail = 'right';
%       cfg.stats.output = 'accuracy_minus_chance';
%       p = decoding_statistics(cfg,results,chancelevel);
%
% See also: decoding_statistics2

% 14/07/29 Martin Hebart

% Important:
% TODO: introduce possibility to pass img-files, too
% TODO: introduce possibility to write images as statistical images
% TODO: introduce possibility to return z-value as stat, too

% Less important:
% TODO: introduce check that binomial test is only executed when cfg
%   contains no cv method (i.e. test for independence of samples in
%   decoding design!)
% TODO: implement multiple sets

function [p,results] = decoding_statistics(cfg,results)

addpath('statistics') % TODO: remove me when no longer experimental

% use decoding_subindex for reporting p-values (i.e. only those, where
% subindex exists)

% Really important: use only subindex later!!

warningv('decoding_statistics:beta',...
    ['This function is a recent addition to the toolbox. Running in beta mode...',...
     'Please report any errors that you do not understand immediately or any bugs to the developers.'])

cfg = basic_checks(cfg,results);


fname = cfg.stats.output;
tail = cfg.stats.tail;
output = results.(fname).output;
try
    chancelevel = results(fname).chancelevel;
catch %#ok<CTCH>
    error('At the moment, decoding_statistics can only be used with data that has a chancelevel field provided (here in results.%s)',fname)
end

% check if any of these methods had been used to generate results
fields_to_check = {'accuracy',...
                   'accuracy_minus_chance',...
                   'sensitivity',...
                   'sensitivity_minus_chance',...
                   'specificity',...
                   'specificity_minus_chance',...
                   'balanced_accuracy',...
                   'balanced_accuracy_minus_chance',...
                   'AUC',...
                   'AUC_minus_chance'};

check = 0;
if exist('cellfun','builtin')
    check = any(cellfun(@any,strfind(fields_to_check,fname)));
else
    for i = 1:length(fields_to_check)
        if strfind(fields_to_check{i},fname)
            check = 1;
            break
        end
    end
end               

% recreate original results between 0 and 1 if required
if strfind(fname,'_minus_chance')
    output = output + chancelevel;
end

if check
    output = output/100;
end
    
######Continue here (check if everything works with binomial, and then pass all results from permutation results
    ##This means rather than passing a results-matrix, it should also be possible to pass files



switch lower(cfg.stats.test)
    
    case 'binomial'

        if isfield(cfg,'design') && isfield(cfg.design,'test')
            n_test = sum(cfg.design.test(:)); % this is how many samples have been used for testing the classifier
        else
            error('Need cfg.design.test to calculate number of samples used for testing the decoding.')
        end
        
        % convert accuracy_minus_chance to n_correct
        n_correct = output * n_test;
        % eliminate rounding errors
        n_correct = round(10^6*n_correct)*10^-6;
        
        p = stats_binomial(n_correct,n_test,chancelevel/100,tail);
        
    case 'permutation'
        
        p = stats_permutation(results,reference,tail);
        
    otherwise
        error('Unknown method %s for cfg.stats.test',cfg.stats.test)
        % TODO: implement passing method with function handle
end




%% Run basic checks
%--------------------------------------
function cfg = basic_checks(cfg,results)

if ~isfield(cfg,'stats')
    error('Nonexistent field ''stats'' in cfg. Please specify (see help decoding_statistics)')
end

if ~isfield(cfg.stats,'output')
    if isfield(results,'accuracy_minus_chance')
        warning('DECODING_STATISTICS:nofieldoutput',...
            ['Non-existent field cfg.stats.output. It was detected that results contained ',...
             'the field ''accuracy_minus_chance''. Using this field!! In the future, ',...
             'please specify cfg.stats.output!'])
         cfg.stats.output = 'accuracy_minus_chance';
    else
        error('Non-existent field cfg.stats.output. Please specify the output you would like to use for generating statistics.')
    end
end

fname = cfg.stats.output;

if ~isnumeric(results(fname).output)
    error('Data type of input variable results must be numeric. Class was %s',class(results))
end
    
if ~isfield(cfg.stats,'tail')
    error('Nonexistent field cfg.stats.tail. For accuracies and similar measures, use cfg.stats.tail = ''right''');
end

if isfield(cfg,'design')
    % If multiple sets exist, currently throw an error (cannot deal with this yet)
    if length(uniqueq(cfg.design.set)) > 1
        error(['Cannot deal with multiple sets, yet. If you want to average across sets anyway, please set ',...
               'cfg.design.set(:) = 1; before running this function'])
    end
    % Check goes over design variable and tests if binomial test is appropriate
    % check if test data is at some point also used as training data
    if strcmpi(cfg.stats.test,'binomial') && isfield(cfg.design,'train') && isfield(cfg.design,'test')
        if any( any(cfg.design.train,2) & any(cfg.design.test,2) )
            warning('DECODING_STATISTICS:wrongtest',...
                ['Test data is in some iterations also used as training data. ',... 
                 'This violates the distributional assumption of binomial testing! ',...
                 'Please use another test (e.g. cfg.stats. permutation testing).'])
        end
    end
end