function kernel = decoding_setup_kernel(data,cfg)

% the kernel function in the linear case is
% kernel_function = @(X,Y) X*Y';
kernel_function = cfg.decoding.kernel.function;
kernel = kernel_function(data,data);