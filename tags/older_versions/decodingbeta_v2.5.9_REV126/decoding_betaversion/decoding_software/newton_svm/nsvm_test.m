function [p corr dv] = nsvm_test(dd,AA,model)

    % dd: labels
    % AA: test data vector
    % model: result of training
    
    dv = AA*model.w-model.gamma;
    p=sign(dv);
    corr=length(find(p==dd))/size(AA,1)*100;

end