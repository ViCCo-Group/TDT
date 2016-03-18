%% init
cfg = decoding_defaults;
cfg.analysis = 'wholebrain';

%% Set filesnames
inputdir = 'a_directory'

images_train1 = {'t1_1';  't1_2'};
images_train2 = {'t2_1';  't2_2'};

images_validate = {'v1';  'v2'};

cfg.files.name =  strcat(inputdir, '\', [images_train1; images_train2; images_validate], '.img')
% and the other two fields if you use a make_design function (e.g. make_design_cv)

%% Define what to do with these files
% all should be trained and tested in one go
cfg.files.chunk = ones(size(cfg.files.name));

% 
cfg.design.label = [1*ones(size(images_train1)); % train 1 gets label 1
                   2*ones(size(images_train2)); % train 2 gets label 2
                   3*ones(size(images_validate)); % validation gets label 3 (actually does not matter)
                   ];
% Use train 1 and 2 for training
cfg.design.train = [1*ones(size(images_train1)); % train 1 gets label 1
                    1*ones(size(images_train2)); % train 2 gets label 2
                    0*ones(size(images_validate)); % validation gets label 3 (actually does not matter)
                   ];

% use validation for test               
cfg.design.test = [0*ones(size(images_train1)); % train 1 gets label 1
                    0*ones(size(images_train2)); % train 2 gets label 2
                    1*ones(size(images_validate)); % validation gets label 3 (actually does not matter)
                   ];

% plot to check if as desired
plot_design(cfg);

%% Specify to return prediction for each input image
cfg.results.output = 'predicted_label';

%% If you want you can return also the model and then use libsvm_predict directly
% See demo2_simpletoydata.m and use:
%
% cfg.decoding.method = 'classification'; 
% cfg.results.output = 'model_parameters';
%
% Make sure to mask the images by the same brainmask/ROI that you also used
% when calculating classifier.

%% do decoding
result = decoding(cfg);

% the output will now be the predicted label for each decoding