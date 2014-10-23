% This reduces the file size of the original "full" to the file size we use
% for the benchmark

fpath = 'full';

Porig = spm_select('fplist',fpath,'^beta.*\.img');

bb = [-61 -73 -30; 68 95 87]; % minimal representation that captures all voxels

resize_img(Porig,[3 3 3],bb,0);

P = spm_select('fplist',fpath,'^rbeta.*\.img');

V = spm_vol(P);
Y = spm_read_vols(V);

mask = sum(abs(Y),4);
mask(mask==0) = NaN;
mask(~isnan(mask)) = 1;

hdr = V(1);
[hdrpath hdrname hdrext] = fileparts(hdr.fname);
hdr.fname = [hdrpath filesep 'rmask.img'];
spm_write_vol(hdr,mask);

for i = 1:size(Y,4)
    Y(:,:,:,i) = Y(:,:,:,i).*mask; % makes all other values NaN
    spm_write_vol(V(i),Y(:,:,:,i));
    movefile(P(i,:),Porig(i,:));
    x = deblank(P(i,:));
    xorig = deblank(Porig(i,:));
    movefile([x(1:end-3) 'hdr'],[xorig(1:end-3) 'hdr'])
end

movefile(hdr.fname,strrep(hdr.fname,'rmask.img','mask.img'))
movefile(strrep(hdr.fname,'rmask.img','rmask.hdr'),strrep(hdr.fname,'rmask.img','mask.hdr'))

f = spm_select('fplist',fpath,'(ResMS|RPV)\.(img|hdr)');
for i = 1:size(f,1)
    delete(f(i,:))
end