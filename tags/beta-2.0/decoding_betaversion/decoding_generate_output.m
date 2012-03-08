function results = decoding_generate_output(cfg,results,decoding_out,i_decoding)

n_outputs = length(cfg.results.output);

if cfg.results.setwise
    n_sets = unique(cfg.design.set(:));
else
    n_sets = 1;
end


for i_output = 1:n_outputs
    
    outname = cfg.results.output{i_output};
    
    % in case chance-level is not provided (which should only happen for
    % parameter selection or feature selection where it doesn't really matter
    if ~isfield(results(i_output),'chancelevel')
        results(i_output).chancelevel = 0;
    end
    
    output = decoding_transform_results(outname,decoding_out,results(i_output).chancelevel);
    
    % This is a lazy initialization (Martin would call it workaround) for 
    % the case in which the output has more than one element (e.g. weights
    % of classifier)
    if iscell(output) && i_decoding == 1
        results(i_output).output = cell(size(results(i_output).output));
    end
        
    results(i_output).output(i_decoding) = output;
        
    if cfg.results.setwise
        for i_set = 1:n_sets
            output = decoding_transform_results(outname,decoding_out(set_ind(i_set)));
            results(i_output).set(i_set).output(i_decoding) = output;
        end
    end
end