w = randn(1,300);

fx = repmat(1:5,1,20)';

data_train = bsxfun(@plus,w,fx) + randn(100,300);


labels_train = repmat(1:5,1,20)';

data_test = bsxfun(@plus,w,fx) + randn(100,300);


labels_test = repmat(1:5,1,20)';

% data_train = 1e16*data_train;
% data_test = 1e16*data_test;

%% calculate by hand first

d1train = mean(data_train(labels_train==1,:));
d2train = mean(data_train(labels_train==3,:));
d1test = mean(data_test(labels_test==1,:));
d2test = mean(data_test(labels_test==3,:));

r = corr([d1test' d2test'],[d1train' d2train']);
z = atanh(r);

dvmanual = z(:,1)-z(:,2);


m.data_train = [d1train; d2train];
m.labels_train = [1;2];
[pl,dv] = correlation_classifier([1 2]',[d1test; d2test],m);

fprintf('Error: %d\n',max(abs(dv(:))-abs(dvmanual(:))))

%% Now all five labels

m.data_train = data_train;
m.labels_train = labels_train;

[pl,dv] = correlation_classifier(labels_test,data_test,m);
