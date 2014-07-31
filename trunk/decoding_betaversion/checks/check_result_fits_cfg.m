function success = check_result_fits_cfg(results, cfg)

% init success as failed
success = 0;

% check analysis type
if ~isequal(results.analysis, cfg.analysis)
    error('results.analysis=%s not equal cfg.analysis=%s', results.analysis, cfg.analysis)
end

% check datainfo (input data dimensions and voxel size)
if ~isequal(results.datainfo, cfg.datainfo)
    disp(results.datainfo)
    disp(cfg.datainfo)
    error('results.datainfo not equal cfg.datainfo, see details above')
end


% return success
success = 1; % everything worked, so it's successful
