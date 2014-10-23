% Now resize ROIs
Porig = spm_select('fplist','roi','.*\.img$');

bb = [-61 -73 -30; 68 95 87]; % minimal representation that captures all voxels

resize_img(Porig,[3 3 3],bb,1);

P = spm_select('fplist','roi','^r.*\.img$');

for i = 1:size(P,1)
    movefile(P(i,:),Porig(i,:));
    x = deblank(P(i,:));
    xorig = deblank(Porig(i,:));
    movefile([x(1:end-3) 'hdr'],[xorig(1:end-3) 'hdr'])
end