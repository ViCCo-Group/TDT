function select_ind = select_peak(n_vox,all_results)

% This function selects the index of n_vox which is the largest (same as max), 
% but if several peaks exist it picks the most stable. The function has a 
% tendency to select values at the extremes which is slightly corrected 
% by switching a correction on. A major drawback is the slow speed.

% step one: check for maximum
select_ind = find(all_results == max(all_results));
n_select_ind = length(select_ind);
if n_select_ind ~= 1 % if more than one maximum
    n_vox_interp = min(n_vox):max(n_vox);
	% interpolate missing values in between
    if exist('interp1q','file') % if signal processing toolbox exists
        all_results_interp = interp1q(n_vox',all_results',n_vox_interp');
    else % otherwise
        all_results_interp = interp1dec(n_vox,all_results,n_vox_interp);
    end
    
    % update select ind
    select_ind_interp = find(all_results_interp == max(all_results_interp));
    n_select_ind_interp = length(select_ind_interp);

    if all(diff(select_ind_interp)==1) % if all maxima in one cluster
        % pick center (most stable)
        select_ind_interp = select_ind_interp(round(n_select_ind_interp/2));
    else % run smoothing and pick unique maximum
        wid = round(length(n_vox_interp)/2);
        if wid < 3, wid = 3; end
        sigma = 1; % TODO: is this a reasonable value?
        gausskernel = exp(-linspace(-wid/2,wid/2,wid) .^ 2 / (2 * sigma ^ 2))';
        gausskernel = gausskernel/sum(gausskernel);
        all_results_interp_x = [linspace(mean(all_results_interp),all_results_interp(1),wid)'; all_results_interp; linspace(all_results_interp(end),mean(all_results_interp),wid)'];
        
        all_results_interp_sm = conv2(all_results_interp_x,gausskernel,'same');
        all_results_interp_sm = all_results_interp_sm(wid+1:end-wid);
        % step five: select absolute peak
        [ignore,select_ind_interp] = max(all_results_interp_sm);
    end
    % step six: use nearest neighbor to original value of n_vox
    v = abs(n_vox - n_vox_interp(select_ind_interp));
    k = find(v == min(v));
    if any(ismember(select_ind,k))
        k = intersect(select_ind,k);
    end
    select_ind = k(end);
        
%     figure, plot(n_vox,all_results,'x'); hold all; plot(n_vox_interp,all_results_interp); 
%     plot(n_vox_selected,all_results(select_ind),'o')
%     if exist('all_results_interp_sm','var')
%         plot(n_vox_interp,all_results_interp_sm); 
%     end
%     pause
%     close
    
end