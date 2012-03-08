% function [AUC, zAUC, p] = AUCstats(decision_values, true_labels, labels, plot_on)
% computes the area unter the curve (AUC) and the corresponding z-value
% zAUC for the n-by-1 vector of decision values, corresponding n-by-1
% vector of true labels. The order of assigned labels is given by the
% variable "labels. If plot_on = 1, then the ROC curve is plotted.
%
% AUC - Area under the ROC curve (between 0 and 1), chance = 0.5
% zAUC - corresponding z-statistic for the AUC
% p - Significance value of zAUC

% by Thorsten Kahnt
% adjusted and debugged: 2010 Martin Hebart

function [AUC, zAUC, p] = AUCstats(decision_values, true_labels, labels, plot_on)

if ~exist('plot_on','var')
    plot_on = 0;
end

if numel(labels)~=2
    error('Number of labels must be 2.')
end

n1 = sum(true_labels==labels(1));
n2 = sum(true_labels==labels(2));

% identify thresholds
thresholds = unique(decision_values);
n_thresholds = length(thresholds);

% compute ROC

sensitivity = zeros(n_thresholds,1);
specificity = zeros(n_thresholds,1);
for i = 1:n_thresholds
    res = decision_values >= thresholds(i);
    sensitivity(i) = sum(true_labels == labels(1) & res == 1)/n1;
    specificity(i) = sum(true_labels == labels(2) & res == 0)/n2;
end

% compute the area under the "curve"
AUC = -trapz(1-specificity, sensitivity);

% given you want to see the ROC
if plot_on
    figure;
    fpr = 1-specificity;
    plot(fpr,sensitivity); hold on
    title(sprintf('AUC = %1.2f', AUC)); xlabel('false positive rate'); ylabel('hit rate')
    plot([0,1], [0,1], 'k')
end

% Mann-Whitney-Wilcoxon rank sum test for AUC according to:
% Cortes, C. & Mohri, M. (2004). Confidence intervals for the area under the ROC curve. Advances in neural information processing systems.
% see also: McClish, D.K. (1987). Comparing the Areas under More Than Two Independent ROC Curves. Med Decis Making. 7:149
% for more precise AUC statistics, use bootstrap sampling
if nargout > 1
    q1 = AUC/(2-AUC);
    q2 = 2*AUC^2/(1+AUC);
    vAUC = (AUC*(1-AUC)+(n1-1)*(q1-AUC^2)+(n2-1)*(q2-AUC^2)) / (n1*n2); % variance of estimated AUC
    zAUC = (AUC-0.5)/sqrt(vAUC);
end
if nargout > 2
    p = (1-normcdf(abs(zAUC),0,1))*2;
end
