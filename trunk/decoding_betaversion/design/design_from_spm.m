% function regressor_names = design_from_spm(spm_folder)
% 
% This function will extract the relevant information for the current
% decoding from a SPM design matrix.
%
% INPUT:
% spm_folder: The folder where the design matrix is stored as SPM.mat.
%   Alternatively, the matrix can also be stored in a *_SPM.mat file (e.g.
%   to reduce the filesize when data is passed on to someone else).
%
% OUTPUT:
% regressor_names: a 2-by-n cell matrix where the first row refers to the
% names of the regressors and the second row represents the experimental
% run of those regressors. If more than one basis function exists in the
% design matrix (e.g. as is the case for FIR designs), each regressor name 
% will be extended by a string ' bin 1' to ' bin m' where m refers to the 
% number of basis functions.
%
% by Martin Hebart & Kai Görgen, 2012/03/01 

% History:
% 2012/03/09, Kai
%   Also *_SPM.mat files will be used (if no SPM.mat is found)
% 2012/03/01, Martin: v1

function regressor_names = design_from_spm(spm_folder)

spm_file = fullfile(spm_folder,'SPM.mat');
regressor_file = fullfile(spm_folder,'regressor_names.mat');

if ~exist(spm_file,'file')
    % check if *_SPM.mat exists, if so, take this
    otherSPM = dir(fullfile(spm_folder, '*_SPM.mat'));
    if length(otherSPM) == 1
        dispv(1, 'design_from_spm: Could not find SPM.mat in %s, but found %s instead.',spm_folder,otherSPM.name);
        spm_file = fullfile(spm_folder, otherSPM.name);
    elseif length(otherSPM) > 1
        error('Could not find a SPM.mat in %s, but multiple other *_SPM.mat files. Please make sure that only one such file exists.',spm_folder);
    else    
        error('No SPM.mat or *_SPM.mat could be found in %s',spm_folder);
    end
end

% Check for existence of regressor_names
if exist(regressor_file,'file')
    % Check also if date of regressor names is younger than that of SPM.mat
    d = dir(spm_file);
    spm_date = d.datenum;
    d = dir(regressor_file);
    regressor_date = d.datenum;
    if regressor_date>spm_date
        load(regressor_file)
        return; % no need to recompute regressor names
    end
end


load(spm_file)

regressors = SPM.xX.name;

% Alternatively, it is possible to extract names from SPM.Sess.U and
% SPM.Sess.C. However, this might become difficult (e.g. for FIR bf) and 
% may be more error prone than the solution below.

% Row 1: regressor names, row 2: run numbers
regressor_names = cell(2,length(regressors));
% Number of basis function (e.g. for HRF all are 1, for FIR from 1 to n)
bf_numbers = zeros(1,length(regressors)); 

for i = 1:length(regressors)
    
    % TODO: if session number is not provided in one run, then throw out an
    % error message (if val happens to be NaN)
    
    %== Get run number from regressors ==
    
    % Normally, all regressors start with the session number (e.g. Sn(1) )
    str1 = 'Sn(';
    exp = '(\d+)';
    str2 = ')';
    str1 = regexptranslate('escape',str1);
    str2 = regexptranslate('escape',str2);
    ind1 = regexp(regressors{i},[str1 exp str2],'tokenExtents');
    ind1 = unique(cell2mat(ind1));
      
    val = regressors{i}(ind1);
    regressor_names{2,i} = str2double(val);
    
    %== Get basis function number from regressors ==
    
    % Most regressors terminate with the basis function (e.g. *bf(1) )
    str3 = '*bf(';
    exp = '(\d+)';
    str4 = ')';
    str3 = regexptranslate('escape',str3);
    str4 = regexptranslate('escape',str4);
    ind2 = regexp(regressors{i},[str3 exp str4],'tokenExtents');
    ind2 = unique(cell2mat(ind2));
    
    val = regressors{i}(ind2);
    bf_numbers(i) = str2double(val);
    
    %== Get regressor name from regressors with indices ==
    
    ind_start = ind1(end) + 3; % based on str1/str2 above
    
    if isempty(ind2)
        ind_end = length(regressors{i});
    else
        ind_end = ind2(1) - 5; % based on str3/str4 above
    end
    
    regressor_names{1,i} = regressors{i}(ind_start:ind_end);
    
end

% Check if all basis functions are the same, if not include string 'bin 1' etc. after each name
bf = bf_numbers(~isnan(bf_numbers));
unique_bf = unique(bf);
if length(unique_bf) > 1
    for i = 1:length(regressors)
        if ~isnan(bf_numbers(i))
            regressor_names{1,i} = [regressor_names{1,i} ' bin ' num2str(bf_numbers(i))];
        end
    end
end


save(regressor_file,'regressor_names')