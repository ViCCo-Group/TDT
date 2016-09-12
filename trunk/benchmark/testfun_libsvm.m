w = randn(1,300);

fx = repmat(1:5,1,20)';

data_train = bsxfun(@plus,w,fx) + randn(100,300);


labels_train = repmat(1:5,1,20)';

data_test = bsxfun(@plus,w,fx) + randn(100,300);


labels_test = repmat(1:5,1,20)';

% data_train = 1e16*data_train;
% data_test = 1e16*data_test;

%% Now try classification alone

cfg.decoding.method = 'classification';
cfg.decoding.train.classification.model_parameters = '-s 0 -t 0 -c 1 -q';
cfg.decoding.test.classification.model_parameters = '-q';

model = libsvm_train(labels_train,data_train,cfg);
pl = libsvm_test(labels_test,data_test,cfg,model);

%% Now get labels 1 vs 3

model = libsvm_train(labels_train(labels_train==1|labels_train==3),data_train(labels_train==1|labels_train==3,:),cfg);
pl2 = libsvm_test(labels_test(labels_test==1|labels_test==3),data_test(labels_test==1|labels_test==3,:),cfg,model);

% Compare dvs
fprintf('Error: %d\n',max(abs(pl2.decision_values - pl.decision_values(labels_test==1|labels_test==3,2)))) % column 2 because 1 vs 3

%% Now reverse labels and try again

ltr = [labels_train(labels_train==3); labels_train(labels_train==1)];
dtr = [data_train(labels_train==3,:); data_train(labels_train==1,:)];
model = libsvm_train(ltr,dtr,cfg);
pl3 = libsvm_test(labels_test(labels_test==1|labels_test==3),data_test(labels_test==1|labels_test==3,:),cfg,model);

fprintf('Error: %d\n',max(abs(pl3.decision_values - pl.decision_values(labels_test==1|labels_test==3,2)))) % column 2 because 1 vs 3

%% I guess we need to re-order the labels and invert them depending on where they are in the order (using the same approach as we used for the weights)

order = bsxfun(@plus,[1 4 3 2 5]',0:5:95);
labels_train_inv = labels_train(order(:));
data_train_inv = data_train(order(:),:);

model = libsvm_train(labels_train_inv,data_train_inv,cfg);

pl4 = libsvm_test(labels_test,data_test,cfg,model);

fprintf('Max error: %d\n',max(abs(pl4.decision_values(:)-pl.decision_values(:))))