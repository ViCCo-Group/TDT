% function vol = tdt_mat2vol_example(results_or_filename, decoding_measure, out_hdr)
%
% Write output that is not automatically written to files.
%
% Attention: This script is more a  template that can be tailored to your 
%   specific need. You can adapt what exactly should be written from the 
%   results struct below. Modify all parts marked with "part to modify".
%
% IN
%   results_or_filename: results struct (output of decoding) or mat file
%                       containing this results struct.
%   decoding_measure: result transformation, e.g. 'accuracy_minus_chance'
% OPTIONAL
%   out_hdr: If files should be written, specify a filename (out_hdr.fname) 
%           and the rotation (hdr.mat) plus other informations that are
%           information that are needed to write the file (see 
%           "help spm_vol"). If the result contains ROIs, "_ROI%i" will be
%           appended to the filename before the extension.
% OUT
%    vol: containing the info as volume
%    written_hdrs: cell with all hdrs of the new files that were written
%
% EXAMPLE CALL
%   vol = tdt_mat2vol_example('result_file.mat', 'accuracy_minus_chance');

% Kai, 2016.04.04

function [vol, written_hdrs] = tdt_mat2vol_example(results_or_filename, decoding_measure, out_hdr)

%% Check parameters
if ~exist('decoding_measure', 'var')
    error('Please provide the decoding measure for which you like to convert to a volume')
end
    
%% Check if mat is filename and load data
if ischar(results_or_filename)
    inp_filename = results_or_filename;
    display(['Reading result from ' inp_filename]);
    inp = load(inp_filename);
    results = inp.results;
    clear inp
else % assume its the result output directly
    display(['Input seems to be no filename, assuming its the result directly']);
    results = results_or_filename;
    inp_filename = nan;
end

%% Check that mat is valid TDT mat (i.e. contains .results)
if ~isstruct(results)
    error('Input seems no valid result output. It''s not struct')
elseif ~isfield(results, 'datainfo')
    error('Input seems no valid result output. It has no field "datainfo"')
end

%% Map output to vol (part to modify: 1/2)

for roi_ind = 1:length(results.mask_index_each)
    curr_vol = nan(results.datainfo.dim); % init vol
    % put data into vol
    curr_vol(results.mask_index_each{roi_ind}) = results.(decoding_measure).output;
    vol{roi_ind} = curr_vol;
end

%% If filename and hdr are provided, write to file (part to modify: 2/2)
if exist('out_hdr', 'var') && ~isempty(out_hdr)
    for roi_ind = 1:length(vol)
        % get default cfg to write files with the toolbox
        cfg = decoding_defaults;
        if isfield(results.datainfo, 'mat')
            % check that both mats agree
            if ~isequal(out_hdr.mat, results.datainfo.mat)
                error('Rotation matrix from result data and header for output does not agree, aborting')
            end
        end
        
        curr_hdr = hdr;
        if length(vol) > 1
            % add ROI number
            [d, n, ext] = fileparts(curr_hdr.fname);
            curr_hdr.fname = [d, n, sprintf('ROI%i', roi_ind), ext];
        end
        display(['Writing image ' curr_hdr.fname]);
        new_hdr = write_image(cfg.software, hdr, vol{roi_ind});
        written_hdrs{roi_ind} = new_hdr;
    end
else
    written_hdrs = {};
end

    
%% Return vol as matrix for searchlight
if strcmp(results.analysis, 'searchlight')
    vol = vol{1};
end
