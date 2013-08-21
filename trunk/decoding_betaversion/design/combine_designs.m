% function ocfg = combine_designs(cfg1,cfg2)
% 
% Version 12-4-2013, Dan Birman
%
% Function to combine two design matrices.
%
% IN
%   cfg1: A config with design matrix, see usage.
%   cfg2: A second config with it's own design matrix. None of the values
%       except for the files and design are used from cfg2.
%
% OUT
%   ocfg: A single config with a combined design matrix. Will contain all
%       of the files of the two combined configs.
%
% EXAMPLE:
%
% First set up your cfg with whatever settings you want. Then setup:
%
% regressor_names = design_from_spm(beta_dir);
% 
% Now build up your two (or more) configs that you want to combine.
%
% cfg1 = decoding_describe_data(cfg,{ll ln},[-1 1],regressor_names,beta_dir);
% cfg2 = decoding_describe_data(cfg,{lr ln},[-1 1],regressor_names,beta_dir);
% 
% cfg1.design = make_design_cv(cfg1);
% cfg2.design = make_design_cv(cfg2);
% 
% cfg = combine_designs(cfg1,cfg2);
% 
% Let's take a look at cfg1 and cfg2:
%
% cfg1:
%
% files.name	design.train    	design.test     	design.label     
% ---       	                	                	                 
% ...06.img 	0  1  1         	1  0  0          	-1 -1 -1         
% ...14.img 	1  0  1         	0  1  0          	-1 -1 -1         
% ...22.img 	1  1  0         	0  0  1         	-1 -1 -1         
% ...08.img 	0  1  1          	1  0  0          	 1  1  1          
% ...16.img 	1  0  1         	0  1  0          	 1  1  1          
% ...24.img 	1  1  0         	0  0  1          	 1  1  1         
% ---       	                	                	                 
% design.set	1  1  1          	1  1  1         	 1  1  1          
%
% cfg2:
%
% files.name	design.train    	design.test     	design.label     
% ---       	                	                	                 
% ...07.img 	0  1  1         	1  0  0          	-1 -1 -1         
% ...15.img 	1  0  1          	0  1  0          	-1 -1 -1         
% ...23.img 	1  1  0         	0  0  1         	-1 -1 -1         
% ...08.img 	0  1  1          	1  0  0          	 1  1  1                
% ...16.img 	1  0  1          	0  1  0          	 1  1  1         
% ...24.img 	1  1  0          	0  0  1          	 1  1  1          
% ---       	                	                	                 
% design.set	1  1  1         	1  1  1              1  1  1          
%
% Note that the first three images are not the same for design 2 as for
% design 1. Combine_designs will take this into account. Also note that
% otherwise the designs are identical.
%
% Now let's take a look at the combined design:
%
% ocfg:
%
% files.name	design.train         design.test           design.label                       
% ---       	                     
% ...06.img 	0  1  1  0  0  0      1  0  0  0  0  0     -1 -1 -1  0  0  0 
% ...14.img 	1  0  1  0  0  0      0  1  0  0  0  0     -1 -1 -1  0  0  0 
% ...22.img 	1  1  0  0  0  0      0  0  1  0  0  0     -1 -1 -1  0  0  0 
% ...08.img 	0  1  1  0  1  1      1  0  0  1  0  0      1  1  1  1  1  1 
% ...16.img 	1  0  1  1  0  1      0  1  0  0  1  0      1  1  1  1  1  1 
% ...24.img 	1  1  0  1  1  0      0  0  1  0  0  1      1  1  1  1  1  1 
% ...07.img 	0  0  0  0  1  1      0  0  0  1  0  0      0  0  0 -1 -1 -1 
% ...15.img 	0  0  0  1  0  1      0  0  0  0  1  0      0  0  0 -1 -1 -1 
% ...23.img 	0  0  0  1  1  0      0  0  0  0  0  1      0  0  0 -1 -1 -1 
% ---       	                                  	                                  	                                   
% design.set	1  1  1 2  2  2      1  1  1  2  2  2      1  1  1  2  2  2 
%
% We see clearly the same patterns of training/testing appear. As well as
% now the correct files are zeroed out (unused by the decoding toolbox) in
% the different sets.
% 
% Finally, note that the sets are averaged in the output unless you use the
% cfg.results.setwise = 1 option (by default as of 12-4-2013 the option is
% 0).

% TODO: introduce possibility to combine more than two designs

function ocfg = combine_designs( cfg1, cfg2 )

warningv('COMBINE_DESIGNS:IgnoreCfg2','Ignores all the values in cfg2 except for cfg2.files and cfg2.design');

if ~length(cfg1.files.name)==length(cfg2.files.name)
    warningv('COMBINE_DESIGNS:FileCountsDifferent','File counts are not the same, some files will only appear in one set. WARNING: THIS HAS NEVER BEEN TESTED!!!!');
end

ocfg = cfg1;

for si = 1:length(cfg2.design.set) % si == set index
    os_l = length(ocfg.design.set)+1;
    ocfg.design.set = [ocfg.design.set max(cfg1.design.set)+1];

    % Find the index in ocfg of each file in cfg2. This means that
    % idx_o_c2(CFG2-IDX) = OCFG-IDX;
    idx_ocfg_of_cfg2 = zeros(1,length(cfg2.files.name));
    used_idx_cfg2 = zeros(1,length(cfg2.files.name));
    for fidx2 = 1:length(cfg2.files.name) % file index in 2
        % for each file in design 2, check it's index in ocfg
        fname = cfg2.files.name{fidx2};
        fidxo = find(strcmp(ocfg.files.name,fname));
        if ~isempty(fidxo)
            % we did find this file, copy it's index
            idx_ocfg_of_cfg2(fidx2) = fidxo;
            used_idx_cfg2(fidx2) = 1;
        end
    end
    
    % We want to copy all the data for those files that are already in
    % cfg1. This means we should use sim_ind_map(sim_ind_mask).
    for fi2 = 1:length(cfg2.files.name) % again, file index in 2
        if used_idx_cfg2(fi2)
            % This index in CFG2 was used, so let's copy
            % We want to add to the O-IDX
            o_ind = idx_ocfg_of_cfg2(fi2);
            % Copy the relevant data:
            ocfg.design.label(o_ind,os_l) = cfg2.design.label(fi2,si);
            ocfg.design.train(o_ind,os_l) = cfg2.design.train(fi2,si);
            ocfg.design.test(o_ind,os_l) = cfg2.design.test(fi2,si);   
        end
    end
    
    if any(used_idx_cfg2==0)
        warningv('COMBINE_DESIGNS:AutoConcat','At least one file exists in cfg2 but not ocfg. Concatenating to end...');
    
        % the next set of code copies any missing files into ocfg from
        % cfg2. This only happens once per run.
        z_inds = find(used_idx_cfg2==0);
        for z_ind = z_inds % Real position in cfg2 of this unused file
            clen = length(ocfg.design.label);
            ocfg.design.label(clen+1,os_l) = cfg2.design.label(z_ind,si);
            ocfg.design.train(clen+1,os_l) = cfg2.design.train(z_ind,si);
            ocfg.design.test(clen+1,os_l) = cfg2.design.test(z_ind,si);
            ocfg.files.name{clen+1} = cfg2.files.name{z_ind};
            ocfg.files.step(clen+1) = cfg2.files.step(z_ind);
            ocfg.files.label(clen+1) = cfg2.files.label(z_ind);
            if ~isempty(ocfg.files.xclass)
                ocfg.files.xclass(clen+1) = cfg2.files.xclass(z_ind);
            end
            ocfg.files.descr{clen+1} = cfg2.files.descr{z_ind};
        end
    end

end

