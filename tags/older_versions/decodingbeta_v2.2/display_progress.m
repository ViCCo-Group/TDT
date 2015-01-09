%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Display progress (how far is the analysis?)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [msg_length] = display_progress(cfg,cnt,n_decodings,startval,endval,start_time,msg_length)

if cnt == startval
    fprintf('\nStarting time: %s',datestr(start_time));
end

if n_decodings > 50
    display_values = (startval-1) + [1 2 5 10 15 20 30 40 50 100 200 300 400 500 n_decodings]; % display progress of these voxels
else
    display_values = 1:n_decodings;
end

if any(display_values == cnt) || mod(cnt,1000) == 0

    if isfield(cfg, 'sn')
        message = sprintf('Subject: %02d %s: %d/%d', cfg.sn, cfg.analysis, cnt, endval);
    else
        message = sprintf('%s: %d/%d', cfg.analysis, cnt, endval);
    end
    
    % delete old message and state time
    if ~isempty(msg_length)
        fprintf(repmat('\b', 1, msg_length + 2)); % delete old text
    end
    % add estimated time to go
    p = (cnt-startval+1) / n_decodings * 100;
    el_time = now - start_time;
    el_time_str = datestr(el_time, 'dd HH:MM:SS');
    if str2double(el_time_str(1:2)) == 0, el_time_str = el_time_str(4:end); end
    est_time = (el_time / p) * 100;
    est_time_left = est_time - el_time;
    est_time_left_str = datestr(est_time_left, 'dd HH:MM:SS');
    if str2double(est_time_left_str(1:2)) == 0, est_time_left_str = est_time_left_str(4:end); end    
    est_finish = start_time + est_time;
    est_finish_str = datestr(est_finish, 'yyyy/mm/dd HH:MM:SS');
    message = [message ', time to go: ' est_time_left_str ', time running: ' el_time_str ', finish: ' est_finish_str];
    msg_length = length(message);

    % print message
    fprintf(['\n' message '\n'])
end