% function results = decoding_generate_output(cfg,results,decoding_out,i_decoding,curr_decoding,model)
% 
% This function calls all decoding_transform_results for all entries in
% cfg.results.output and saves the returning outputs at results.(outname).
%
% It also handles initialization of output fields if they are not single
% numerical values.
% 
% Try to see it as a black box and ignore it, as far as possible. Look at
%
%   decoding_transform_results 
%
% instead.
%
% Kai, 2013/04/19


function results = decoding_generate_output(cfg,results,decoding_out,i_decoding,curr_decoding,model)

n_outputs = length(cfg.results.output);

if cfg.results.setwise
    unique_sets = unique(cfg.design.set(:));
    n_sets = length(unique_sets);
else
    n_sets = 1;
end


for i_output = 1:n_outputs

    outname = cfg.results.output{i_output};

    % in case chance-level is not provided (which should only happen for
    % parameter selection or feature selection where it doesn't really matter
    
    % TODO: Find some way to get the chancelevel back for each measure
    %   Question: Do we have everything here that we need for this?
%     if ~isfield(results.(outname),'chancelevel')
%         results.(outname).chancelevel = 0;
%     end

    chancelevel = 1/results.n_cond * 100; % chancelevel in percent    

    if strcmpi(outname, 'accuracy') || strcmpi(outname, 'accuracy_minus_chance') || ...
            strcmpi(outname, 'sensitivity') || strcmpi(outname, 'specificity') || ...
            strcmpi(outname, 'AUC') || strcmpi(outname, 'AUC_minus_chance')
        results.(outname).chancelevel = chancelevel;
    else
        % dont save it as chancelevel 
        % TODO: Should we change TRANSRES_ functions so that they can also 
%             return an (optional) chancelevels if asked?
    end
    
    output = decoding_transform_results(outname,decoding_out,chancelevel,cfg,model);

    % This is a lazy initialization (Martin would call it workaround) for
    % the case in which the output has more than one element (e.g. weights
    % of classifier)
    if iscell(output) && i_decoding == 1
        results.(outname).output = cell(size(results.(outname).output));
    end

    % Lazy initialization, if a struct is returned
    % Create a struct array
    if isstruct(output) && i_decoding == 1
        results.(outname) = rmfield(results.(outname), 'output');
        results.(outname).output(curr_decoding) = output;
    end

    results.(outname).output(curr_decoding) = output;

    if cfg.results.setwise
        for i_set = 1:n_sets
            current_set = unique_sets(i_set);
            output = decoding_transform_results(outname,decoding_out(cfg.design.set == current_set),chancelevel,cfg,model);

            % This is a lazy initialization (Martin would call it workaround) for
            % the case in which the output has more than one element (e.g. weights
            % of classifier)
            if iscell(output) && i_decoding == 1
                results.(outname).set(i_set).output = cell(size(results.(outname).output));
            end

            % Lazy initialization, if a struct is returned
            % Create a struct array
            if isstruct(output) && i_decoding == 1 && i_set == 1
                % reinit set
                results.(outname) = rmfield(results.(outname), 'set');
                results.(outname).set(i_set).output(curr_decoding) = output;
            end

            results.(outname).set(i_set).output(curr_decoding) = output;
            results.(outname).set(i_set).set_id = current_set;
        end
    end
end