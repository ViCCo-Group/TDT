% function decoding_write_results(cfg,results,mask_index)
%
% This is a subfunction of the decoding toolbox that saves previously
% processed data to a prespecified target location. For example, it can be
% used to write brain images in a searchlight analysis or write a mat-file
% for ROI analyses, containing a structure with fields for each ROI.
% The function can also be run separately to save previously processed data.
%
% Remark: if cfg.results.overwrite = 1 and if result files with the same 
% name exist, the result files (.hdr & .img) will be copied.
% However this is very unlikely to occur, because decoding.m checks 
% whether the result files exist already when it is starts, and aborts 
% operation already then if the result files should not be overwritten.
% Copying will only occur in the unlikely event that result files with 
% the same name are created between this initial check in decoding.m and
% when they should be saved here.

% HISTORY
% KAI, 2011/08/16
%   Added copying of result files if result files exist and
%   cfg.results.overwrite = 1

function decoding_write_results(cfg,results,mask_index)


n_outputs = length(cfg.results.output);

if strcmpi(cfg.analysis,'searchlight')
    
    try
        resultsvol_hdr = read_header(cfg.software,cfg.files.name{1}); % choose canonical hdr from first classification image
        fallback = 0; % if results cannot be written as .img, save as mat
    catch %#ok<CTCH>
        fallback = 1;
    end
    
    for i_output = 1:n_outputs
        
        %     results.(outputname).output = zeros(n_decodings,1); %#ok
        %     results.(outputname).set(i_set).output = zeros(n_decodings,1); %#ok
        
        outputname = cfg.results.output{i_output};
        
        %%%%%%%%%%%%%%%%%%%%%
        % WRITE AS MAT-FILE %
        %%%%%%%%%%%%%%%%%%%%%
        if iscell(results.(outputname).output) || isstruct(results.(outputname).output) || fallback
            
            fdir = cfg.results.dir;
            fname = fullfile(fdir,sprintf('%s.mat',cfg.results.resultsname{i_output}));
            
            if exist(fname,'file')
                if cfg.results.overwrite
                    % simply overwrite the file
                    warningv('decoding_write_results:overwrite_results', 'Resultfile %s already existed. Overwriting it (because cfg.results.overwrite = 1)',fname)
                else
                    % dont overwrite file, copy it
                    [old_results_path, old_results_file, dummy_ending] = fileparts(fname);
                    old_fname = fullfile(old_results_path, old_results_file);
                    backup_fname = fullfile(old_results_path, [old_results_file, '_old_before_', datestr(now, 'yyyymmddTHHMMSS')]);
                    warningv('decoding_write_results:overwrite_results', 'Resultfile %s already existed. Copying old files %s to %s (because cfg.results.overwrite = 0)', fname, old_fname, backup_fname);
                    
                    fext = '.mat';
                    source = [old_fname, fext];
                    target = [backup_fname, fext];
                    dispv(1, 'Copying %s to %s', source, target)
                    r = copyfile(source, target);
                end
            end
            
            dispv(1,'Saving %s results to %s', cfg.decoding.method, fname)
            
            output = results.(outputname).output; %#ok<NASGU>
            resultdim = cfg.datainfo.dim; %#ok<NASGU>
            
            save(fname,'output','mask_index','resultdim')
            
            results.(outputname).(outputname).fname = fname;
            
            % Save set results (should each set be saved separately?)
            if cfg.results.setwise
                n_sets = length(results.(outputname).set);
                for i_set = 1:n_sets
                    fname = fullfile(fdir,sprintf('%s_set%i.mat', cfg.results.resultsname{i_output}, results.(outputname).set(i_set).set_id));
                    dispv(2,'Saving results for set %i to %s', i_set, fname)
                    output = results.(outputname).set(i_set).output; %#ok<NASGU>
                    
                    save(fname,'output','mask_index','resultdim')

                    results.(outputname).set(i_set).fname = fname;
                end
            end
            
        %%%%%%%%%%%%%%%%%%%%%
        % WRITE AS IMG-FILE %
        %%%%%%%%%%%%%%%%%%%%%
        else
            
            % Save overall results and save to returning variable
            
            % TODO: how to make it possible to write only sets? Maybe input
            % variable with three inputs: save only sets, save only overall, or
            % save both
            
            fname = sprintf('%s.img',cfg.results.resultsname{i_output});
            resultsvol_hdr.fname = fullfile(cfg.results.dir,fname);
            resultsvol_hdr.descrip = sprintf('%s decoding map',outputname);
            resultsvol = zeros(resultsvol_hdr.dim(1:3)); % prepare results volume
            resultsvol(mask_index) = results.(outputname).output;
            
            if exist(resultsvol_hdr.fname,'file')
                if cfg.results.overwrite
                    % simply overwrite the file
                    warning('decoding_write_results:overwrite_results', 'Resultfile %s already existed. Overwriting it (because cfg.results.overwrite = 1)',resultsvol_hdr.fname)
                else
                    % dont overwrite file, copy it
                    [old_results_path, old_results_file, dummy_fext] = fileparts(resultsvol_hdr.fname);
                    old_fname = fullfile(old_results_path, old_results_file);
                    backup_fname = fullfile(old_results_path, [old_results_file, '_old_before_', datestr(now, 'yyyymmddTHHMMSS')]);
                    warning('decoding_write_results:overwrite_results', 'Resultfile %s already existed. Copying old files %s to %s (because cfg.results.overwrite = 0)',resultsvol_hdr.fname, old_fname, backup_fname);
                    
                    for fext = {'.hdr', '.img'}
                        source = [old_fname, fext{1}];
                        target = [backup_fname, fext{1}];
                        dispv(1, 'Copying %s to %s', source, target)
                        r = copyfile(source, target);
                    end
                end
            end
            
            dispv(1,'Saving %s results to %s', cfg.decoding.method, resultsvol_hdr.fname)
            
            write_image(cfg.software,resultsvol_hdr,resultsvol);
                        
            results.(outputname).(outputname).fname = resultsvol_hdr.fname;
            
            % Save set results (should each set be saved separately?)
            if cfg.results.setwise
                n_sets = length(results.(outputname).set);
                for i_set = 1:n_sets
                    fname = sprintf('%s_set%i.img', cfg.results.resultsname{i_output}, results.(outputname).set(i_set).set_id);
                    resultsvol_hdr.fname = fullfile(cfg.results.dir,fname);
                    resultsvol_hdr.descrip = sprintf('%s decoding map of set %i',outputname,i_set);
                    resultsvol_set = zeros(resultsvol_hdr.dim(1:3)); % prepare results volume
                    resultsvol_set(mask_index) = results.(outputname).set(i_set).output;
                    dispv(2,'Saving results for set %i to %s', i_set, resultsvol_hdr.fname)
                    write_image(cfg.software,resultsvol_hdr,resultsvol_set);
                    results.(outputname).set(i_set).fname = resultsvol_hdr.fname;
                end
            end
        end
    end

elseif strcmpi(cfg.analysis,'ROI') || strcmpi(cfg.analysis,'wholebrain')

    for i_output = 1:n_outputs

        % TODO: add input roinames to cfg to be able to apply names later.

        outputname = cfg.results.output{i_output};

        % Save overall results and save to returning variable
        fname = sprintf('%s.mat',cfg.results.resultsname{i_output});
        resultsmat_fname = fullfile(cfg.results.dir,fname);
        resultsmat = results.(outputname).output; %#ok<NASGU>
        dispv(1,'Saving %s results to %s', cfg.decoding.method, resultsmat_fname)
        save(resultsmat_fname,'resultsmat')

        results.(outputname).fname = resultsmat_fname;

        % Save set results (should each set be saved separately?)
        if cfg.results.setwise
            n_sets = length(results.(outputname).set);
            for i_set = 1:n_sets
                fname = sprintf('%s_set%i.mat', cfg.results.resultsname{i_output}, results.(outputname).set(i_set).set_id);
                resultsmat_fname = fullfile(cfg.results.dir,fname);
                resultsmat_set = results.(outputname).set(i_set).output; %#ok<NASGU>
                dispv(2,'Saving results for set %i to %s', i_set, resultsmat_fname)
                save(resultsmat_fname,'resultsmat_set');
                results.(outputname).set(i_set).fname = resultsmat_fname;
            end
        end

    end

end
