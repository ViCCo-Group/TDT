cfg = decoding_defaults;
cfg.decoding.method = 'classification';



% first, show that weights are the same whether using one pair or multiple
data = randn(100,300);
labels = repmat([-1 -2 -3 -4 -5],1,20)';


currdata = [data(labels==-3,:); data(labels==-1,:)];
currlabels = [labels(labels==-3); labels(labels==-1)];

m = svmtrain(currlabels,currdata,'-s 0 -t 0 -q');
decoding_out.model = m;

cfg.design.train = ones(40,1);
cfg.design.label = labels(currind);

tmp = transres_SVM_pattern_old(decoding_out,[],cfg, currdata);
w13 = tmp{1}{1};

% now with multiple
m = svmtrain(labels,data,'-s 0 -t 0 -q -h 0');
decoding_out.model = m;

cfg.design.train = ones(100,1);
cfg.design.label = labels;

tmp = transres_SVM_pattern(decoding_out,[],cfg,data);
w = tmp{1}{1};

fprintf('Max error: %d\n',max(abs(w(:,end-1)-w13)))

%% looking good, now redo with different order of labels
labels_inv = labels(end:-1:1);
data_inv = data(end:-1:1,:);

currind = labels_inv==-1|labels_inv==-3;

currdata = data_inv(currind,:);
currlabels = labels_inv(currind);

m = svmtrain(currlabels,currdata,'-s 0 -t 0 -q');
decoding_out.model = m;

cfg.design.train = ones(40,1);
cfg.design.label = currlabels;

tmp = transres_SVM_pattern(decoding_out,[],cfg,currdata);
w13_inv = tmp{1}{1};

fprintf('Max error: %d\n',max(abs(w13-w13_inv)))

%% and with inverted labels

m = svmtrain(labels_inv,data_inv,'-s 0 -t 0 -q');
decoding_out.model = m;

cfg.design.train = ones(100,1);
cfg.design.label = labels_inv;

tmp = transres_SVM_pattern(decoding_out,[],cfg,data_inv);
w_inv = tmp{1}{1};

fprintf('Max error: %d\n',max(abs(w(:)-w_inv(:))));

%% Now that we have managed that they fit again, try the same with reordered multiple labels

order = bsxfun(@plus,[1 4 3 2 5]',0:5:95);
labels_inv2 = labels(order(:));
data_inv2 = data(order(:),:);

m = svmtrain(labels_inv2,data_inv2,'-s 0 -t 0 -h 0 -q');
decoding_out.model = m;

cfg.design.label = labels_inv2;

tmp = transres_SVM_pattern(decoding_out,[],cfg,data_inv2);
w_inv2 = tmp{1}{1};

fprintf('Max error: %d\n',max(abs(w_inv2(:)-w(:))))


%% Now use transres function with one pair without the kernel method

currind = labels==-1|labels==-3;

currdata = data(currind,:);
currlabels = labels(currind);

m = svmtrain(currlabels,currdata,'-s 0 -t 0 -q');
decoding_out.model = m;

cfg.design.train = ones(size(currlabels));
cfg.design.label = currlabels;
cfg.decoding.method = 'classification';
tmp = transres_SVM_pattern(decoding_out,0,cfg,currdata);
w13k = tmp{1}{1};

fprintf('Max error: %d\n',max(abs(w13(:)-w13k(:))))


%% Now use transres function with multiple classes

kernel = data*data';
mk = svmtrain(labels,[(1:size(kernel,1))' kernel],'-s 0 -t 4 -q');
decoding_out.model = mk;
cfg.decoding.method = 'classification_kernel';
cfg.design.train = ones(size(labels));
cfg.design.label = labels;
tmp = transres_SVM_pattern(decoding_out,0,cfg,data);
wk = tmp{1}{1};

fprintf('Max error: %d\n',max(abs(w(:)-wk(:))))