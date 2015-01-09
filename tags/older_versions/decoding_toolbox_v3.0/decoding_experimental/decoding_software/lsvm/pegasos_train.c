/*

Train binary Linear SVM with Pegasos algorithm

MIN_w lambda/2 |w|^2 + 1/N SUM_i LOSS(w, X(:,i), y(i))
where LOSS(w,x,y) = MAX(0, 1 - y w'x) is the hinge loss 


Usage
------

w = pegasos_train(X , y , [options] );


Inputs
-------

X                              Input data (d x N) in single/double format. 
y                              Binary label (1 x N) where y_i ={-1,1}, i=1,...,N in single/double format.
options 
        lambda                 Regularizer (default lambda = 1/N).
        B                      Bias term (default B = 1.0).
        nbite                  Number of iteration (default nbite = 20*N).
		reguperiod             Period regularization (default reguperiod = 10).
		seed                   Seed number for internal random generator (default random seed according to time) 

If compiled with the "OMP" compilation flag
        num_threads            Number of threads. If num_threads = -1, num_threads = number of core  (default num_threads = -1)

Outputs
-------

w                              Model weights vector ((d + (B != 0)) x 1) in single/double format

To compile
----------


mex  -g -output pegasos_train.dll pegasos_train.c "C:\Program Files\MATLAB\R2009b\extern\lib\win32\microsoft\libmwblas.lib"

mex  -f mexopts_intel10.bat -output pegasos_train.dll pegasos_train.c

If compiled with BLAS option, linked with BLAS lib

mex  -DBLAS -f mexopts_intel10.bat -output pegasos_train.dll pegasos_train.c "C:\Program Files\MATLAB\R2009b\extern\lib\win32\microsoft\libmwblas.lib"

mex  -DBLAS -f mexopts_intel10.bat -output pegasos_train.dll pegasos_train.c "C:\Program Files\Intel\Compiler\11.1\065\mkl\ia32\lib\mkl_core.lib" "C:\Program Files\Intel\Compiler\11.1\065\mkl\ia32\lib\mkl_intel_c.lib" "C:\Program Files\Intel\Compiler\11.1\065\mkl\ia32\lib\mkl_intel_thread.lib" "C:\Program Files\Intel\Compiler\11.1\065\lib\ia32\libiomp5md.lib"


If compiled with OMP option, OMP support

mex -v -DOMP -f mexopts_intel10.bat -output pegasos_train.dll pegasos_train.c "C:\Program Files\Intel\Compiler\11.1\065\mkl\ia32\lib\mkl_core.lib" "C:\Program Files\Intel\Compiler\11.1\065\mkl\ia32\lib\mkl_intel_c.lib" "C:\Program Files\Intel\Compiler\11.1\065\mkl\ia32\lib\mkl_intel_thread.lib" "C:\Program Files\Intel\Compiler\11.1\065\lib\ia32\libiomp5md.lib"

If compiled with BLAS & OMP options

mex  -DBLAS -DOMP -f mexopts_intel10.bat -output pegasos_train.dll pegasos_train.c "C:\Program Files\Intel\Compiler\11.1\065\mkl\ia32\lib\mkl_core.lib" "C:\Program Files\Intel\Compiler\11.1\065\mkl\ia32\lib\mkl_intel_c.lib" "C:\Program Files\Intel\Compiler\11.1\065\mkl\ia32\lib\mkl_intel_thread.lib" "C:\Program Files\Intel\Compiler\11.1\065\lib\ia32\libiomp5md.lib"


Example 1
---------

d                    = 10240;
N                    = 4485;
C                    = 1;

X                    = rand(d , N);
y                    = double(rand(1,N)>0.5);
y(y==0)              = -1;

options.lambda       = 1/(C*N);
options.B            = 1;
options.nbite        = 30*N;
options.reguperiod   = 10;
options.seed         = 1234543;


w                    = pegasos_train(X , y  , options);
b                    = w(d+1);
w                    = w(1:d);


fX                   = w'*X+b*ones(1,N);

plot(1:N,fX);



Example 2
---------

d                    = 10240;
N                    = 4485;
C                    = 1;

X                    = rand(d , N , 'single');
y                    = single(rand(1,N)>0.5);
y(y==0)              = -1;

options.lambda       = 1/(C*N);
options.B            = 1;
options.nbite        = 30*N;
options.reguperiod   = 10;
options.seed         = 1234543;


w                    = pegasos_train(X , y  , options);
b                    = w(d+1);
w                    = w(1:d);


fX                   = w'*X+b*ones(1,N);

plot(1:N,fX);





Author : Sébastien PARIS : sebastien.paris@lsis.org
-------  Date : 09/23/2010

References [1] S. Shalev-Shwartz, Y. Singer, and N. Srebro. "Pegasos: Primal estimated sub-GrAdient SOlver for SVM."
               In Proc. ICML, 2007.

           [2] http://www.vlfeat.org/

*/

#include <time.h>
#include <math.h>
#include <mex.h>

#ifdef OMP
 #include <omp.h>
#endif


#define PI 3.14159265358979323846
#define EPSILON_D 2.220446049250313e-16
#ifndef max
    #define max(a,b) (a >= b ? a : b)
    #define min(a,b) (a <= b ? a : b)
#endif

#ifndef MAX_THREADS
#define MAX_THREADS 64
#endif


#if defined(__OS2__)  || defined(__WINDOWS__) || defined(WIN32) || defined(_MSC_VER)
#define BLASCALL(f) f
#else
#define BLASCALL(f) f ##_
#endif


#define SHR3   ( jsr ^= (jsr<<17), jsr ^= (jsr>>13), jsr ^= (jsr<<5) )
#define randint SHR3
#define rand() (0.5 + (signed)randint*2.328306e-10)

#ifdef __x86_64__
    typedef int UL;
#else
    typedef unsigned long UL;
#endif

static UL jsrseed = 31340134 , jsr;

struct opts
{
    double         lambda;
	double         B;
	int            nbite;
	int            reguperiod;
	UL             seed;
#ifdef OMP 
    int            num_threads;
#endif
};

/*-------------------------------------------------------------------------------------------------------------- */
/* Function prototypes */
#ifdef BLAS
extern double BLASCALL(sdot)(int *, double *, int *, double *, int *);
extern double BLASCALL(ddot)(int *, double *, int *, double *, int *);
#endif
void spegasos_train(float * , float * , int  , int   , struct opts , float * );
void dpegasos_train(double * , double * , int  , int   , struct opts , double * );
void randini(UL);
/*-------------------------------------------------------------------------------------------------------------- */
#ifdef MATLAB_MEX_FILE
void mexFunction( int nlhs, mxArray *plhs[] , int nrhs, const mxArray *prhs[] )
{  
	float *sX , *sy;
	double *dX , *dy;
	int    d , N , issingle = 0;
	float  *sw;
	double *dw;
#ifdef OMP 
	struct opts options = {0.01 , 1.0 , 100 , 10 , (UL)NULL , -1};
#else
	struct opts options = {0.01 , 1.0 , 100 , 10 , (UL)NULL};
#endif
	mxArray *mxtemp;
	double *tmp , temp;
	int tempint;
	UL templint;

	if (nrhs < 1) 
	{
		mexPrintf(
			"\n"
			"\n"
			"Train binary Linear SVM with Pegasos algorithm\n"
			"\n"
			"MIN_w lambda/2 |w|^2 + 1/N SUM_i LOSS(w, X(:,i), y(i))\n"
			"where LOSS(w,x,y) = MAX(0, 1 - y w'x) is the hinge loss \n"
			"\n"
			"\n"
			"\n"
			"Usage\n"
			"------\n"
			"\n"
			"\n"
			"w = pegasos_train(X , y , [options] );\n"
			"\n"
			"\n"
			"\n"
			"Inputs\n"
			"-------\n"
			"\n"
			"X                              Input data (d x N) in single/double format. \n"
			"y                              Binary label vector (1 x N) where y_i ={-1,1}, i=1,...,N in single/double format.\n"
			"options \n"
			"        lambda                 Regularizer (default lambda = 1/N). \n"
			"        B                      Bias term (default B   = 0.0).\n"
			"        nbite                  Number of iteration (default nbite = 20*N).\n"
			"        max_ite                Maximum number of iteration (default max_ite = 1000).\n"
			"        reguperiod             Period regularization (default reguperiod = 10).\n"
			"        seed                   Seed number for internal random generator (default random seed according to time)\n"
#ifdef OMP
			"        num_threads            Number of threads. If num_threads = -1, num_threads = number of core  (default num_threads = -1)\n"
#endif
			"\n"
			"\n"
			"Outputs\n"
			"-------\n"
			"\n"
			"\n"
			"w                              Model weights vector ((d + (biasmult != 0)) x 1) in single/double format.\n"
			"\n"
			"\n"
			);
		return;
	}

	/* Input 1  */

	if(mxIsSingle(prhs[0]))
	{
		sX       = (float *)mxGetData(prhs[0]);
		issingle = 1;
	}
	else
	{
		dX       = (double *)mxGetData(prhs[0]);
	}

	d            = mxGetM(prhs[0]);
	N            = mxGetN(prhs[0]);

	/* Input 2  */

	if(mxIsSingle(prhs[1]))
	{
		sy       = (float *)mxGetData(prhs[1]);
	}
	else
	{
		dy       = (double *)mxGetData(prhs[1]);
	}

	if(mxGetN(prhs[1]) != N)
	{
		mexErrMsgTxt("y must be (1 x N) \n");
	}

	/* Input 3  */

	if ((nrhs > 2) && !mxIsEmpty(prhs[2]) )
	{
		mxtemp                            = mxGetField(prhs[2] , 0 , "lambda");
		if(mxtemp != NULL)
		{
			tmp                           = mxGetPr(mxtemp);
			temp                          = tmp[0];
			if( (temp < 0.0) )
			{
				mexPrintf("lambda >= 0, force to 1/N\n");	
				options.lambda            = 1.0/N;
			}
			else
			{
				options.lambda            = temp;
			}
		}

		mxtemp                            = mxGetField(prhs[2] , 0 , "B");
		if(mxtemp != NULL)
		{
			tmp                           = mxGetPr(mxtemp);
			temp                          = tmp[0];
			options.B                     = temp;
		}

		mxtemp                            = mxGetField(prhs[2] , 0 , "nbite");
		if(mxtemp != NULL)
		{
			tmp                           = mxGetPr(mxtemp);
			tempint                       = (int) tmp[0];
			if( (tempint < 1) )
			{
				mexPrintf("nbite > 0 , force to 20*N\n");	
				options.nbite             = 20*N;
			}
			else
			{
				options.nbite             = tempint;
			}
		}
		
		mxtemp                            = mxGetField(prhs[2] , 0 , "reguperiod");
		if(mxtemp != NULL)
		{
			tmp                           = mxGetPr(mxtemp);
			tempint                       = (int) tmp[0];
			if( (tempint < 1) )
			{

				mexPrintf("reguperiod > 0 , force to 10\n");	
				options.reguperiod        = 10;
			}
			else
			{
				options.reguperiod        = tempint;
			}
		}

		mxtemp                            = mxGetField(prhs[2] , 0 , "seed");
		if(mxtemp != NULL)
		{
			tmp                           = mxGetPr(mxtemp);
			templint                      = (UL) tmp[0];
			if( (templint < 1) )
			{
				mexPrintf("seed >= 1 , force to NULL (random seed)\n");	
				options.seed             = (UL)NULL;
			}
			else
			{
				options.seed             = templint;
			}
		}

#ifdef OMP 
		mxtemp                            = mxGetField( prhs[2] , 0, "num_threads" );
		if(mxtemp != NULL)
		{
			tmp                           = mxGetPr(mxtemp);	
			tempint                       = (int) tmp[0];
			if((tempint < -2))
			{								
				options.num_threads       = -1;
			}
			else
			{
				options.num_threads       = tempint;	
			}			
		}
#endif
	}

	randini(options.seed);

	/*----------------------- Outputs & Main Call -------------------------------*/

	if(issingle)
	{
		plhs[0]            =  mxCreateNumericMatrix(d + (options.B > 0) , 1, mxSINGLE_CLASS , mxREAL);
		sw                 =  (float *) mxGetData(plhs[0]);
		spegasos_train(sX , sy , d ,  N , options , sw );
	}
	else
	{
		plhs[0]            =  mxCreateNumericMatrix(d + (options.B > 0) , 1, mxDOUBLE_CLASS , mxREAL);
		dw                 =  (double *) mxGetData(plhs[0]);
		dpegasos_train(dX , dy , d ,  N , options , dw );
	}
}

#else

#endif
/*----------------------------------------------------------------------------------------------------------------------------------------- */
void spegasos_train(float *X , float *y , int d , int N  , struct opts options , float *w )
{
	int nbite = options.nbite , reguperiod = options.reguperiod;
	float lambda = (float)options.lambda, B = (float)options.B ;
	int iteration, i , k , kd , currentlabel;
	int addbias = (B != 0.0f);

	float eta , acc , iteration0 = 1.0f/lambda;
	float learningrate;
#ifdef BLAS
	int inc     = 1;
#endif
#ifdef OMP 
	int num_threads = options.num_threads;
	num_threads     = (num_threads == -1) ? min(MAX_THREADS,omp_get_num_procs()) : num_threads;
	omp_set_num_threads(num_threads);
#endif

	for (iteration = 0 ; iteration < nbite ; iteration ++) 
	{
		k              = (int) floor(N*rand());
		kd             = k*d;
		currentlabel   = y[k];

		/* learning rate */
		learningrate   = 1.0f / ((iteration + iteration0) * lambda) ;

		if ((iteration % reguperiod) == 0) 
		{
			eta = learningrate*reguperiod*lambda ;
			for (i = 0 ; i < (d + addbias) ; ++i) 
			{
				w[i] -= (eta*w[i]);
			}
		}

		/* project on the weight vector */

#ifdef BLAS
		acc            = BLASCALL(sdot)(&d , X + kd , &inc , w , &inc);
#else
		acc            = 0.0f;
#ifdef OMP 
#pragma omp parallel for default(none) private(i) shared (w,X,kd,d) reduction(+:acc)
#endif
		for (i = 0 ; i < d ; i++)
		{
			acc       += (w[i]*X[i+kd]);
		}
#endif
		if (addbias) 
		{
			acc       += (B*w[d]);
		}
		
		/* margin violated */

		if ((currentlabel * acc) < 1.0f) 
		{
		/* learning rate */

			eta = currentlabel * learningrate;
			
#ifdef OMP 
#pragma omp parallel for default(none) private(i) shared (X,w,kd,d,eta)
#endif
			for (i = 0 ; i < d ; i++) 
			{
				w[i] += (eta*X[i + kd]);
			}
			if (addbias)
			{
				w[d] += (eta * B);
			}
		} 
	}
}
/*----------------------------------------------------------------------------------------------------------------------------------------- */
void dpegasos_train(double *X , double *y , int d , int N  , struct opts options , double *w )
{
	int nbite = options.nbite , reguperiod = options.reguperiod;
	double lambda = options.lambda, B = options.B ;
	int iteration, i , k , kd , currentlabel;
	int addbias = (B != 0.0);

	double eta , acc , iteration0 = 1.0/lambda;
	double learningrate;
#ifdef BLAS
	int inc     = 1;
#endif
#ifdef OMP 
	int num_threads = options.num_threads;
	num_threads     = (num_threads == -1) ? min(MAX_THREADS,omp_get_num_procs()) : num_threads;
	omp_set_num_threads(num_threads);
#endif

	for (iteration = 0 ; iteration < nbite ; iteration ++) 
	{
		k              = (int) floor(N*rand());
		kd             = k*d;
		currentlabel   = y[k];

		/* learning rate */
		learningrate   = 1.0 / ((iteration + iteration0) * lambda) ;

		if ((iteration % reguperiod) == 0) 
		{
			eta = learningrate*reguperiod*lambda ;
			for (i = 0 ; i < (d + addbias) ; ++i) 
			{
				w[i] -= (eta*w[i]);
			}
		}
		/* project on the weight vector */

#ifdef BLAS
		acc            = BLASCALL(ddot)(&d , X + kd , &inc , w , &inc);
#else
		acc            = 0.0;
#ifdef OMP 
#pragma omp parallel for default(none) private(i) shared (w,X,kd,d) reduction(+:acc)
#endif
		for (i = 0 ; i < d ; i++)
		{
			acc       += (w[i]*X[i+kd]);
		}
#endif
		if (addbias) 
		{
			acc       += (B*w[d]);
		}
		
		/* margin violated */

		if ((currentlabel * acc) < 1.0) 
		{
		/* learning rate */

			eta = currentlabel * learningrate;
			
#ifdef OMP 
#pragma omp parallel for default(none) private(i) shared (X,w,kd,d,eta)
#endif
			for (i = 0 ; i < d ; i++) 
			{
				w[i] += (eta*X[i + kd]);
			}
			if (addbias)
			{
				w[d] += (eta * B);
			}
		} 
	}
}
/*----------------------------------------------------------------------------------------------------------------------------------------- */
void randini(UL seed)
{
	/* SHR3 Seed initialization */

	if(seed == (UL)NULL)
	{
		jsrseed  = (UL) time( NULL );
		jsr     ^= jsrseed;
	}
	else
	{
		jsr     = (UL)NULL;
		jsrseed = seed;
		jsr    ^= jsrseed;
	}
}
/*----------------------------------------------------------------------------------------------------------------------------------------- */
