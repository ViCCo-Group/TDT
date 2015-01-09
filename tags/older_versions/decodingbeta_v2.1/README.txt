=======
GENERAL
=======

The Decoding toolbox has been created for classification of structural and 
functional brain images. It is currently optimized for SPM2, SPM5, and 
SPM8, but can also be extended to other brain image analysis tools.

To get started quick, type
> help decoding_example
in your Matlab command window.

If you want a tutorial or create your own decoding script, 
edit the decoding_tutorial.m

For more details on all currently available options, type
> help decoding
or
> help decoding_defaults
and for feature_selection
< help decoding_feature_selection

Please report any bugs to
martin.hebart@bccn-berlin.de or
kai.goergen@bccn-berlin.de

=========================
Advantages of the toolbox
=========================

The advantages of it are:

1. SIMPLICITY: It is very easy to use. Just try out the decoding_example 
on your SPM.mat using leave-one-run out crossvalidation. 
It is one line of code.

2. GENERALITY: It is quite general purpose (you can do searchlight 
decoding, whole brain decoding or ROI decoding with it). In the current 
beta version we implemented SVM classification with libsvm, SV regression 
with libsvm and pattern similarity analysis using voxel pattern 
correlations. It is general purpose in the classifiers that can be used 
and includes feature selection.

3. FLEXIBILITY: It has a well-defined modular structure and can easily be 
set up for all sorts of classification designs. In addition, it can easily 
be extended by your own algorithm.

4. READABILITY: You should be able to easily read and adjust the code. 
Although sometimes you have to dig for subfunctions if you want to hack 
the toolbox, this structure makes adjustments a lot easier. Everything is 
commented well which should make it easy to find what you want to edit. 
The transparency makes it valuable for programmers who want to adjust the 
code to their needs.

5. SPEED: It is comparably fast (considering that it uses mainly 
uncompiled code) and uses custom-made functions to speed up processing 
(for example running many F-tests in feature selection in matrix format).

=======================================
Functionality of the toolbox and basics
=======================================

Typically, in brain image analyses you would like to know whether some 
regional brain activity pattern is significantly activated. In brain 
image classification you are searching for significant information about 
the classified samples. For that reason we optimized the toolbox for users 
who have a group of subjects and would later want to test whether 
significant information is conveyed in the patterns of brain activity. 
As input, you typically have a number of brain images belonging to several 
categories which you would like to classify. As output you get for each 
subject one or several classification volumes (for searchlight analyses) 
or individual values (e.g. mean cross-validation accuracy in ROIs). In a 
second step be tested easily using your brain image analysis toolbox (e.g. 
second-level analysis in SPM) or simple statistics (e.g. a one-sample 
t-test in Matlab). For simplicity, we set chance to 0 and set all other 
values around 0 (i.e. for 2 classes and chance level of 50%, values range 
from -50 to 50).

================
Compiling libsvm
================

Some people experience problems with the mex-files of libsvm. If your 
problem is that a module was not found, try downloading missing dll that 
your mex file depends on here:
http://www.mathworks.de/support/solutions/en/data/1-2RQL4L/index.html

Alternatively, you may want to use your own compilation or a later version 
of libsvm, so you can follow these 6 steps. 

1. Download libsvm from
http://www.csie.ntu.edu.tw/~cjlin/libsvm/#download

2. Unzip libsvm and navigate to the folder "Matlab".

3. Make the following adjustments:

a) Open svmpredict.c in Matlab and find and delete (or
comment by using // ) the following code:

if(svm_type==NU_SVR || svm_type==EPSILON_SVR)
    {
        mexPrintf("Mean squared error = %g (regression)\n",error/total);
        mexPrintf("Squared correlation coefficient = %g (regression)\n",
            ((total*sumpt-sump*sumt)*(total*sumpt-sump*sumt))/
            ((total*sumpp-sump*sump)*(total*sumtt-sumt*sumt))
            );
    }
    else
  mexPrintf("Accuracy = %g%% (%d/%d) (classification)\n",
      (double)correct/total*100,correct,total);


b) This shep is not necessary when option -q is activated, but you should 
do this anyway: Open SVM.cpp in the path below the folder "Matlab" and 
look for

#if 1
static void info(const char *fmt,...)

and replace the 1 by 0.

4. Rename or delete all compiled mex files. Also make sure that no other 
path contains any mex-files with the same name by typing in the Matlab 
command window

> which svmtrain
and
> which svmpredict

There should be no listing.

5. If you use 32bit, then remove all -largeArrayDims from file make.m in 
the folder "Matlab". For both 32bit and 64bit, then just type "make".
If you get only warnings, but no error, then everything went well. 
Run your code using the compiled mex-files and see if everything worked.

6. Troubleshooting: If you still have problems, you may need to try a 
different compiler (see below). If that still doesn't work, then you 
should in the meantime try a different decoding software (e.g. 
correlation_classifier).

Compiler:
a) Linux users: get the latest version of gcc.
b) Windows users: get the appropriate compiler for your version of Matlab 
(check the Mathworks website). Then set the installation path manually to 
Matlab using
c) Mac users: install the gcc compiler by downloading and installing 
Xcode (need to register).

> mex -setup