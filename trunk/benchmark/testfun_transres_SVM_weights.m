cfg = decoding_defaults;
cfg.decoding.method = 'classification';

% first, show that weights are the same whether using one pair or multiple
data = randn(100,300);
labels = repmat([5 4 3 2 1],1,20)';

currdata = [data(labels==3,:); data(labels==1,:)];
currlabels = [labels(labels==3); labels(labels==1)];

m = svmtrain(currlabels,currdata,'-s 0 -t 0 -q');
decoding_out.model = m;

tmp = transres_SVM_weights(decoding_out,[],cfg);
w13 = tmp{1}{1};

% now with multiple
m = svmtrain(labels,data,'-s 0 -t 0 -q -h 0');
decoding_out.model = m;

tmp = transres_SVM_weights(decoding_out,[],cfg);
w = tmp{1}{1};

fprintf('Max error: %d\n',max(abs(w(:,2)-w13)))

%% looking good, now redo with different order of labels
labels_inv = labels(end:-1:1);
data_inv = data(end:-1:1,:);

currdata = [data_inv(labels_inv==3,:); data_inv(labels_inv==1,:)];
currlabels = [labels_inv(labels_inv==3); labels_inv(labels_inv==1)];

m = svmtrain(currlabels,currdata,'-s 0 -t 0 -q');
decoding_out.model = m;

cfg.decoding.method = 'classification';
tmp = transres_SVM_weights(decoding_out,[],cfg);
w13_inv = tmp{1}{1};

fprintf('Max error: %d\n',max(abs(w13-w13_inv)))

%% and with inverted labels

m = svmtrain(labels_inv,data_inv,'-s 0 -t 0 -q');
decoding_out.model = m;
cfg.decoding.method = 'classification';

tmp = transres_SVM_weights(decoding_out,[],cfg);
w_inv = tmp{1}{1};

fprintf('Max error: %d\n',max(abs(w(:)-w_inv(:))));

%% Now that we have managed that they fit again, try the same with reordered multiple labels

order = bsxfun(@plus,[1 4 3 2 5]',0:5:95);
labels_inv2 = labels(order(:));
data_inv2 = data(order(:),:);

cfg.decoding.method = 'classification';
m = svmtrain(labels_inv2,data_inv2,'-s 0 -t 0 -h 0 -q');
decoding_out.model = m;

tmp = transres_SVM_weights(decoding_out,[],cfg);
w_inv2 = tmp{1}{1};

fprintf('Max error: %d\n',max(abs(w_inv2(:)-w(:))))

%% Now compare the weights with the kernel method

currdata = [data(labels==3,:); data(labels==1,:)];
currlabels = [labels(labels==3); labels(labels==1)];

cfg.decoding.method = 'classification';
m = svmtrain(currlabels,currdata,'-s 0 -t 0 -q');
decoding_out.model = m;

tmp = transres_SVM_weights(decoding_out,[],cfg);
w13 = tmp{1}{1};

kernel = currdata*currdata';
cfg.decoding.method = 'classification_kernel';
mk = svmtrain(currlabels,[(1:size(kernel,1))' kernel],'-s 0 -t 4 -q');

w13k = (mk.sv_coef'*currdata(mk.sv_indices,:))';
if find(currlabels==max(currlabels),1,'first') == 1 % if order is reversed
    w13k = -w13k;
end

fprintf('Max error: %d\n',max(abs(w13k(:)-w13(:))))

%% Now use transres function with one pair

currdata = [data(labels==3,:); data(labels==1,:)];
currlabels = [labels(labels==3); labels(labels==1)];

cfg.design.train = ones(size(currlabels));
cfg.decoding.method = 'classification_kernel';
tmp = transres_SVM_weights(decoding_out,0,cfg,currdata);
w13k2 = tmp{1}{1};

fprintf('Max error: %d\n',max(abs(w13k(:)-w13k2(:))))


%% Now use transres function with multiple classes

kernel = data*data';
mk = svmtrain(labels,[(1:size(kernel,1))' kernel],'-s 0 -t 4 -q');
decoding_out.model = mk;
cfg.design.train = ones(size(labels));
tmp = transres_SVM_weights(decoding_out,0,cfg,data);
wk = tmp{1}{1};

fprintf('Max error: %d\n',max(abs(w(:)-wk(:))))