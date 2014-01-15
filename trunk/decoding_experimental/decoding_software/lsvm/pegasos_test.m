function [predicted_labels accuracy decision_values] = pegasos_test(labels_test,data_test,model)

decision_values = data_test'*model.w + model.b;
predicted_labels = sign(decision_values);
accuracy = double(predicted_labels==labels_test);