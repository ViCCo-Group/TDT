function results = decoding_generate_output(cfg,results,decoding_out,i_decoding,model)

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
    if ~isfield(results.(outname),'chancelevel')
        results.(outname).chancelevel = 0;
    end

    output = decoding_transform_results(outname,decoding_out,results.(outname).chancelevel,cfg,model);

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
        results.(outname).output(i_decoding) = output;
    end

    results.(outname).output(i_decoding) = output;

    if cfg.results.setwise
        for i_set = 1:n_sets
            current_set = unique_sets(i_set);
            output = decoding_transform_results(outname,decoding_out(cfg.design.set == current_set),results.(outname).chancelevel,cfg,model);

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
                results.(outname).set(i_set).output(i_decoding) = output;
            end

            results.(outname).set(i_set).output(i_decoding) = output;
            results.(outname).set(i_set).set_id = current_set;
        end
    end
end