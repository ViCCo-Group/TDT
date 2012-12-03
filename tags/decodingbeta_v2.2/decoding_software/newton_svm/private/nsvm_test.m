function [p corr] = nsvm_test(dd,AA,model)

    % dd: labels
    % AA: test data vector
    % model: result of training

    p=sign(AA*model.w-model.gamma);
    corr=length(find(p==dd))/size(AA,1)*100;

end