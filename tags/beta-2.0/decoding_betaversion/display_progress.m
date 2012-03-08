%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Display progress (how far is the analysis?)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [msg_length] = display_progress(cfg,cnt,n_decodings,start_time,msg_length)

if cnt == 1
    fprintf('\nStarting time: %s',datestr(start_time));
end

if n_decodings > 50
    display_values = [1 2 5 10 25 50 100 500 n_decodings]; % display progress of these voxels
else
    display_values = 1:n_decodings;
end

if any(display_values == cnt) || mod(cnt,1000) == 0

    if isfield(cfg, 'sn')
        message = sprintf('Subject: %02d %s: %d/%d', cfg.sn, cfg.analysis, cnt, n_decodings);
    else
        message = sprintf('%s: %d/%d', cfg.analysis, cnt, n_decodings);
    end
    
    % delete old message and state time
    if ~isempty(msg_length)
        fprintf(repmat('\b', 1, msg_length + 2)); % delete old text
    end
    % add estimated time to go
    p = cnt / n_decodings * 100;
    el_time = now - start_time;
    el_time_str = datestr(el_time, 'dd HH:MM:SS');
    est_time = (el_time / p) * 100;
    est_time_left = est_time - el_time;
    est_time_left_str = datestr(est_time_left, 'dd HH:MM:SS');
    est_finish = start_time + est_time;
    est_finish_str = datestr(est_finish, 'yyyy/mm/dd HH:MM:SS');
    message = [message ', time running: ' el_time_str ', time to go: ' est_time_left_str ', finish: ' est_finish_str];
    msg_length = length(message);

    % print message
    fprintf(['\n' message '\n'])
end