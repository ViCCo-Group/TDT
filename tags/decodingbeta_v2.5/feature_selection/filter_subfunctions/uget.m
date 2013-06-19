% function [ranks,ind] = uget(labels_train,vectors_train)
%
% Feature selection subfunction using Mann-Whitney U-test (also called 
% Wilcoxon Rank Sum Test)

function [ranks,ind] = uget(labels_train,vectors_train)

train_index = find(labels_train == 1);
[r_all,curr_rank] = sort(vectors_train,1);

n1 = size(vectors_train,1)/2;
n2 = n1;

ind = ismember(curr_rank,train_index);

r1 = zeros(1,size(vectors_train,2));
r2 = zeros(1,size(vectors_train,2));

for i = 1:size(vectors_train,2)
    r1(i) = sum(find(ind(:,i)));
    r2(i) = sum(find(ind(:,i)==0));
end

u1 = r1 - n1*(n1+1)/2;
u2 = r2 - n2*(n2+1)/2;

u = min([u1;u2]); % the smaller u, the better (expected value: (n1+n2)/2 )

[ind,ranks] = sort(u,'ascend');