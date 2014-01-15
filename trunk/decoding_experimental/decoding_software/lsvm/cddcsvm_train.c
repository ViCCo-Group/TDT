/*

Train binary Linear SVM classifier with coordinate descent algorithm on dual form

MIN_w lambda/2 |w|^2 + 1/N SUM_i LOSS(w, X(:,i), y(i))
where LOSS(w,x,y) = MAX(0, 1 - y w'x)² is the square hinge loss 


Usage
------

w = cddcsvm_train(X , y , [options] );

Inputs
------

X                              Input data (d x N) in single/double format. 
y                              Binary label vector (1 x N) where y_i ={-1,1}, i=1,...,N in single/double format
options 
        c                      Regularizer (default c = 1.0); 
        B                      Bias term (default B   = 0.0);
        l1loss                 Equal to 1 if L1 loss is used instead of l2 loss (default l1loss = 0)
        nbite                  Maximum number of iteration (default nbite = 1000);
        wp                     Weight for positives (default wp = 1)
        wn                     Weight for negatives (default wn = 1)
        eps                    Small value for convergence (default eps = 0.1)
        tolPG                  Small value for convergence (default tolPG = 1.0e-12)
        seed                   Seed number for internal random generator (default random seed according to time)

If compiled with the "OMP" compilation flag

        num_threads            Number of threads. If num_threads = -1, num_threads = number of core  (default num_threads = -1)

Outputs
-------

w                              Model weights vector ((d + (biasmult != 0)) x 1) in single/double format.

To compile
----------

mex  -g cddcsvm_train.c 

mex  -f mexopts_intel10.bat cddcsvm_train.c

If compiled with OMP option, OMP support

mex -v -DOMP -f mexopts_intel10.bat cddcsvm_train.c "C:\Program Files\Intel\Compiler\11.1\065\mkl\ia32\lib\mkl_core.lib" "C:\Program Files\Intel\Compiler\11.1\065\mkl\ia32\lib\mkl_intel_c.lib" "C:\Program Files\Intel\Compiler\11.1\065\mkl\ia32\lib\mkl_intel_thread.lib" "C:\Program Files\Intel\Compiler\11.1\065\lib\ia32\libiomp5md.lib"

If compiled with BLAS & OMP options

mex -v -DBLAS -DOMP -f mexopts_intel10.bat cddcsvm_train.c "C:\Program Files\Intel\Compiler\11.1\065\mkl\ia32\lib\mkl_core.lib" "C:\Program Files\Intel\Compiler\11.1\065\mkl\ia32\lib\mkl_intel_c.lib" "C:\Program Files\Intel\Compiler\11.1\065\mkl\ia32\lib\mkl_intel_thread.lib" "C:\Program Files\Intel\Compiler\11.1\065\lib\ia32\libiomp5md.lib"

mex -v -DOMP  cddcsvm_train.c "C:\Program Files (x86)\Intel\Composer XE 2011 SP1\mkl\lib\intel64\mkl_core.lib" "C:\Program Files (x86)\Intel\Composer XE 2011 SP1\mkl\lib\intel64\mkl_intel_lp64.lib" "C:\Program Files (x86)\Intel\Composer XE 2011 SP1\mkl\lib\intel64\mkl_intel_thread.lib" -largeArrayDims




mex -v -DOS64 -DOMP  cddcsvm_train.c "C:\Program Files (x86)\Intel\Composer XE 2011 SP1\mkl\lib\intel64\mkl_core.lib" "C:\Program Files (x86)\Intel\Composer XE 2011 SP1\mkl\lib\intel64\mkl_intel_lp64.lib" "C:\Program Files (x86)\Intel\Composer XE 2011 SP1\mkl\lib\intel64\mkl_intel_thread.lib" -largeArrayDims


mex -g -DOS64 cddcsvm_train.c "C:\Program Files (x86)\Intel\Composer XE 2011 SP1\mkl\lib\intel64\mkl_core.lib" "C:\Program Files (x86)\Intel\Composer XE 2011 SP1\mkl\lib\intel64\mkl_intel_lp64.lib" "C:\Program Files (x86)\Intel\Composer XE 2011 SP1\mkl\lib\intel64\mkl_intel_thread.lib" -largeArrayDims

Example 1
---------
d                    = 10240;
N                    = 4485;

s                    = RandStream.create('mt19937ar','seed',144881);
RandStream.setDefaultStream(s);


X                    = rand(d , N);
y                    = double(rand(1,N)>0.5);
y(y==0)              = -1;

options.c            = 1;
options.B            = 1.0;
options.l1loss       = 0;
options.nbite        = 1000;
options.wp           = 1;
options.wn           = 1;
options.eps          = 0.1;
options.tolPG        = 1.0e-12;
options.seed         = 1234543;
options.num_threads  = -1;


w                    = cddcsvm_train(X , y  , options);
b                    = w(d+(options.B>0));
w                    = w(1:d);

fX                   = w'*X+b;

figure(1)
plot(1:N,fX);



Example 2
---------

d                    = 10240;
N                    = 4485;

s                    = RandStream.create('mt19937ar','seed',144881);
RandStream.setDefaultStream(s);


X                    = rand(d , N , 'single');
y                    = single(rand(1,N)>0.5);
y(y==0)              = -1;

options.c            = 1;
options.B            = 1.0;
options.l1loss       = 0;
options.nbite        = 1000;
options.wp           = 1;
options.wn           = 1;
options.eps          = 0.1;
options.tolPG        = 1.0e-12;
options.seed         = 1234543;
options.num_threads  = -1;


w                    = cddcsvm_train(X , y  , options);
b                    = w(d+(options.B>0));
w                    = w(1:d);

fX                   = w'*X+b;

figure(1)
plot(1:N,fX);


Author : Sébastien PARIS : sebastien.paris@lsis.org
-------  Date : 06/24/2011

References  [1] Liblinear: http://www.csie.ntu.edu.tw/~cjlin/liblinear/
----------               

*/

#include <time.h>
#include <math.h>
#include <mex.h>

#ifdef OMP
 #include <omp.h>
#endif

#define INF HUGE_VAL
#define PI 3.14159265358979323846
#ifndef max
    #define max(a,b) (a >= b ? a : b)
    #define min(a,b) (a <= b ? a : b)
#endif

#ifndef MAX_THREADS
#define MAX_THREADS 64
#endif

#if defined(__OS2__)  || defined(__WINDOWS__) || defined(WIN32) || defined(WIN64) || defined(_MSC_VER)
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
    double         c;
	double         B;
	int            l1loss;
	int            nbite;
	double         wp;
	double         wn;
	double         eps;
	double         tolPG;
	UL             seed;
#ifdef OMP 
    int            num_threads;
#endif
};

/*-------------------------------------------------------------------------------------------------------------- */
/* Function prototypes */

#ifdef BLAS
extern float BLASCALL(sdot)(int *, float *, int *, float *, int *);
extern void BLASCALL(saxpy)(int *, float *, float *, int *, float *, int *);
extern double BLASCALL(ddot)(int *, double *, int *, double *, int *);
extern void BLASCALL(daxpy)(int *, double *, double *, int *, double *, int *);
#endif
void randini(UL);
void shuffle(int * , int);
#ifdef OS64
void scddcsvm_train(float * , float * , mwIndex  , mwIndex , struct opts , float * );
void dcddcsvm_train(double * , double * , int  , int , struct opts , double * );
#else
void scddcsvm_train(float * , float * , int  , int , struct opts , float * );
void dcddcsvm_train(double * , double * , int  , int , struct opts , double * );
#endif

/*-------------------------------------------------------------------------------------------------------------- */
#ifdef MATLAB_MEX_FILE
void mexFunction( int nlhs, mxArray *plhs[] , int nrhs, const mxArray *prhs[] )
{  
	double *dX , *dy;
	float *sX , *sy;
#ifdef OS64
	mwIndex  d , N ;
#else
	int    d , N;
#endif
	int issingle = 0;
	double *dw;
	float *sw;
#ifdef OMP 
	struct opts options = {1 , 0.0 , 0 , 1000 , 1.0 , 1.0 , 0.1 , 1e-12 , (UL)NULL , -1};
#else
	struct opts options = {1 , 0.0 , 0 , 1000 , 1.0 , 1.0 , 0.1 , 1e-12 , (UL)NULL};
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
			"Train binary Linear SVM classifier with coordinate descent algorithm on dual form\n"
			"\n"
			"MIN_w lambda/2 |w|^2 + 1/N SUM_i LOSS(w, X(:,i), y(i))\n"
			"where LOSS(w,x,y) = MAX(0, 1 - y w'x)² is the square hinge loss \n"
			"\n"
			"\n"
			"\n"
			"Usage\n"
			"------\n"
			"\n"
			"\n"
			"w = cddcsvm_train(X , y , [options] );\n"
			"\n"
			"\n"
			"\n"
			"Inputs\n"
			"-------\n"
			"\n"
			"X                              Input data (d x N) in single/double format. \n"
			"y                              Binary label vector (1 x N) where y_i ={-1,1}, i=1,...,N in single/double format.\n"
			"options \n"
			"        c                      Regularizer (default c = 1.0); \n"
			"        B                      Bias term (default B   = 0.0);\n"
			"        l1loss                 Equal to 1 if L1 loss is used instead of l2 loss (default l1loss = 0)\n"
			"        nbite                  Maximum number of iteration (default nbite = 1000);\n"
			"        wp                     Weight for positives (default wp = 1)\n"
			"        wn                     Weight for negatives (default wn = 1)\n"
			"        eps                    Small value for convergence (default eps = 0.1)\n"
			"        tolPG                  Small value for convergence (default tolPG = 1.0e-12)\n"
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

	d           = mxGetM(prhs[0]);
	N           = mxGetN(prhs[0]);

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

	if ((nrhs > 1) && !mxIsEmpty(prhs[2]) )
	{
		mxtemp                            = mxGetField(prhs[2] , 0 , "c");
		if(mxtemp != NULL)
		{
			tmp                           = mxGetPr(mxtemp);
			temp                          = tmp[0];
			if( (temp < 0.0) )
			{
				mexPrintf("c >= 0, force to 1\n");	
				options.c                 = 1.0;
			}
			else
			{
				options.c                 = temp;
			}
		}

		mxtemp                            = mxGetField(prhs[2] , 0 , "B");
		if(mxtemp != NULL)
		{
			tmp                           = mxGetPr(mxtemp);
			temp                          = tmp[0];
			options.B                     = temp;
		}

		mxtemp                            = mxGetField(prhs[2] , 0 , "l1loss");
		if(mxtemp != NULL)
		{
			tmp                           = mxGetPr(mxtemp);
			tempint                       = (int) tmp[0];
			if( (tempint < 0) || (tempint > 1) )
			{
				mexPrintf("l1loss = {0,1} , force to 0\n");	
				options.l1loss            = 0;
			}
			else
			{
				options.l1loss            = tempint;
			}
		}

		mxtemp                            = mxGetField(prhs[2] , 0 , "nbite");
		if(mxtemp != NULL)
		{
			tmp                           = mxGetPr(mxtemp);
			tempint                       = (int) tmp[0];
			if( (tempint < 1) )
			{
				mexPrintf("nbite > 0 , force to 1000\n");	
				options.nbite           = 1000;
			}
			else
			{
				options.nbite           = tempint;
			}
		}
		
		mxtemp                            = mxGetField(prhs[2] , 0 , "wp");
		if(mxtemp != NULL)
		{
			tmp                           = mxGetPr(mxtemp);
			temp                          = tmp[0];
			if( (temp < 0.0) )
			{
				mexPrintf("wp >= 0, force to 1\n");	
				options.wp                 = 1.0;
			}
			else
			{
				options.wp                 = temp;
			}
		}

		mxtemp                            = mxGetField(prhs[2] , 0 , "wn");
		if(mxtemp != NULL)
		{
			tmp                           = mxGetPr(mxtemp);
			temp                          = tmp[0];
			if( (temp < 0.0) )
			{
				mexPrintf("wn >= 0, force to 1\n");	
				options.wn                 = 1.0;
			}
			else
			{
				options.wn                = temp;
			}
		}

		mxtemp                            = mxGetField(prhs[2] , 0 , "eps");
		if(mxtemp != NULL)
		{
			tmp                           = mxGetPr(mxtemp);
			temp                          = tmp[0];
			if( (temp < 0.0) )
			{
				mexPrintf("eps >= 0, force to 0.1\n");	
				options.eps                 = 0.1;
			}
			else
			{
				options.eps                 = temp;
			}
		}

		mxtemp                            = mxGetField(prhs[2] , 0 , "tolPG");
		if(mxtemp != NULL)
		{
			tmp                           = mxGetPr(mxtemp);
			temp                          = tmp[0];
			if( (temp < 0.0) )
			{
				mexPrintf("tolPG >= 0, force to 1e-12\n");	
				options.tolPG             = 1e-12;
			}
			else
			{
				options.tolPG             = temp;
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

	if(issingle)
	{
		plhs[0]            =  mxCreateNumericMatrix(d + (options.B > 0) , 1, mxSINGLE_CLASS , mxREAL);
		sw                 =  (float *) mxGetData(plhs[0]);
		scddcsvm_train(sX , sy , d  ,  N , options , sw );
	}
	else
	{
		plhs[0]            =  mxCreateNumericMatrix(d + (options.B > 0) , 1, mxDOUBLE_CLASS , mxREAL);
		dw                 =  (double *) mxGetData(plhs[0]);
		dcddcsvm_train(dX , dy , d  ,  N , options , dw );
	}
}

#else


#endif

/*----------------------------------------------------------------------------------------------------------------------------------------- */
#ifdef OS64
void dcddcsvm_train(double *X , double *y , mwIndex d , mwIndex N  , struct opts options , double *w )
#else
void dcddcsvm_train(double *X , double *y , int d , int N  , struct opts options , double *w )
#endif
{
	int nbite = options.nbite , l1loss = options.l1loss;
	double c = options.c, B = options.B , bias2 = B*B , eps = options.eps , tolPG = options.tolPG , Cp = c*options.wp , Cn = c*options.wn;
#ifdef OS64
	mwIndex i , j , k , kd  , kind;
#else
	int i , j , k , kd  , kind;
#endif	
	int addbias = (B != 0.0) , dd = d + addbias;
	int active_N = N;

	int iter = 0 , ind , tmpind;
	double PG, PGmax_old = INF , PGmin_old = -INF , PGmax_new, PGmin_new , C;
	double diag_p = 0.5/Cp, diag_n = 0.5/Cn;
	double upper_bound_p = INF, upper_bound_n = INF;
	double sum ;
    int *index;
	char yind;
	double *QD, *alpha; 
	double alphaind , diff , G;
#ifdef BLAS
	int inc     = 1;
#else
    double temp;
#endif
#ifdef OMP 
	int num_threads = options.num_threads;
	num_threads     = (num_threads == -1) ? min(MAX_THREADS,omp_get_num_procs()) : num_threads;
	omp_set_num_threads(num_threads);
#endif

	QD                = (double *) malloc(N*sizeof(double));
    alpha             = (double *) malloc(N*sizeof(double));
	index             = (int *)    malloc(N*sizeof(int));

	if(l1loss)
	{
		diag_p        = 0.0; 
		diag_n        = 0.0;
		upper_bound_p = Cp; 
		upper_bound_n = Cn;
	}

	for(i = 0; i < dd ; i++)
	{
		w[i]     = 0.0;
	}

	for(k = 0 ; k < N ; k++)
	{
		alpha[k] = 0.0;
		index[k] = k;
		kd       = k*d;

		if(y[k] > 0.0)
		{
			QD[k] = diag_p;
		}
		else
		{
			QD[k] = diag_n;
		}

#ifdef BLAS
		sum        = BLASCALL(ddot)(&d , X+kd , &inc , X+kd , &inc);
#else
		sum        = 0.0;

#ifdef OMP 
#pragma omp parallel for default(none) private(i,temp) shared(X,kd,d) reduction (+:sum)
#endif
		for(i = kd ; i < kd + d ; i++)
		{
			temp   =  X[i]; 
			sum   += (temp*temp);
		}
#endif

		QD[k]     += (sum + bias2);
	}

	while (iter < nbite)
	{
		PGmax_new = -INF;
		PGmin_new = INF;

		for (i = 0 ; i < active_N ; i++)
		{
			j               = i + randint%(active_N - i);
			tmpind          = index[i];
			index[i]        = index[j];
			index[j]        = tmpind;
		}
/*
		shuffle(index , active_N);
*/
		for (k = 0 ; k < active_N ; k++)
		{
			ind      = index[k];
			kind     = ind*d;
            alphaind = alpha[ind];
			yind     = (signed char) y[ind];

			G        = 0.0;
#ifdef BLAS
	    	G        = BLASCALL(ddot)(&d , X+kind , &inc , w , &inc);
#else
#ifdef OMP 
#pragma omp parallel for default(none) private(i) shared(w,X,d,kind) reduction (+:G)
#endif
			for(i = 0 ; i < d ; i++)
			{
				G   += (w[i]*X[i + kind]);
			}
#endif
			if(addbias)
			{
				G   += (w[d]*B);
			}

			G        = G*yind - 1.0;
			if(yind == 1)
			{
				C    = upper_bound_p; 
				G   += (alphaind*diag_p); 
			}
			else 
			{
				C    = upper_bound_n;
				G   += (alphaind*diag_n); 
			}

			PG       = 0.0;
			if (alphaind == 0.0)
			{
				if (G > PGmax_old)
				{
					active_N--;
					tmpind          = index[k];
                    index[k]        = index[active_N];
					index[active_N] = tmpind;
					k--;
					continue;
				}
				else if (G < 0.0)
				{
					PG              = G;
				}
			}
			else if (alphaind == C)
			{
				if (G < PGmin_old)
				{
					active_N--;
					tmpind          = index[k];
                    index[k]        = index[active_N];
					index[active_N] = tmpind;
					k--;
					continue;
				}
				else if (G > 0.0)
				{
					PG              = G;
				}
			}
			else
			{
				PG                  = G;
			}

			PGmax_new            = max(PGmax_new, PG);
			PGmin_new            = min(PGmin_new, PG);

			if(fabs(PG) > tolPG)
			{
				alpha[ind]       = min(max(alphaind - G/QD[ind], 0.0), C);
				diff             = (alpha[ind] - alphaind)*yind;			
#ifdef BLAS
				BLASCALL(daxpy)(&d , &diff , X + kind , &inc , w , &inc);
#else
#ifdef OMP 
#pragma omp parallel for default(none) private(i) shared(w,diff,X,d,G,kind) 
#endif
				for(i = 0 ; i < d ; i++)
				{
					w[i]        += (diff*X[i + kind]);
				}
#endif
				if(addbias)
				{
					w[d]        += (diff*B);
				}
			}
		}

		iter++;
		if((PGmax_new - PGmin_new) <= eps)
		{
			if(active_N == N)
			{
				break;
			}
			else
			{
				active_N  = N;
				PGmax_old = INF;
				PGmin_old = -INF;
				continue;
			}
		}

		PGmax_old = PGmax_new;
		PGmin_old = PGmin_new;
		if (PGmax_old <= 0.0)
		{
			PGmax_old = INF;
		}
		if (PGmin_old >= 0.0)
		{
			PGmin_old = -INF;
		}
	}
	free(QD);
	free(alpha);
	free(index);
}
/*----------------------------------------------------------------------------------------------------------------------------------------- */
#ifdef OS64
void scddcsvm_train(float *X , float *y , mwIndex d , mwIndex N  , struct opts options , float *w )
#else
void scddcsvm_train(float *X , float *y , int d , int N  , struct opts options , float *w )
#endif
{
	int nbite = options.nbite , l1loss = options.l1loss;
	float c = (float)options.c, B = (float)options.B , bias2 = B*B , eps = (float)options.eps;
	float tolPG = (float)options.tolPG , Cp = c*(float)options.wp , Cn = c*(float)options.wn;
#ifdef OS64
	mwIndex i , j , k , kd  , kind;
#else
	int i , j , k , kd  , kind;
#endif
	int addbias = (B != 0.0f) , dd = d + addbias;
	int active_N = N;
	int iter = 0 , ind , tmpind;
	double PG, PGmax_old = INF , PGmin_old = -INF , PGmax_new, PGmin_new;
	float diag_p = 0.5f/Cp, diag_n = 0.5f/Cn , C;
	double upper_bound_p = INF, upper_bound_n = INF;
	float sum;
    int *index;
	char yind;
	float *QD, *alpha; 
	float alphaind , diff , G;
#ifdef BLAS
	int inc         = 1;
#else
    float temp;
#endif
#ifdef OMP 
    int num_threads = options.num_threads;
    num_threads     = (num_threads == -1) ? min(MAX_THREADS,omp_get_num_procs()) : num_threads;
    omp_set_num_threads(num_threads);
#endif

	QD                = (float *) malloc(N*sizeof(float));
    alpha             = (float *) malloc(N*sizeof(float));
	index             = (int *)   malloc(N*sizeof(int));

	if(l1loss)
	{
		diag_p        = 0.0f; 
		diag_n        = 0.0f;
		upper_bound_p = Cp; 
		upper_bound_n = Cn;
	}

	for(i = 0; i < dd ; i++)
	{
		w[i]     = 0.0f;
	}

	for(k = 0 ; k < N ; k++)
	{
		alpha[k] = 0.0f;
		index[k] = k;
		kd       = k*d;

		if(y[k] > 0.0f)
		{
			QD[k] = diag_p;
		}
		else
		{
			QD[k] = diag_n;
		}

#ifdef BLAS
		sum        = BLASCALL(sdot)(&d , X+kd , &inc , X+kd , &inc);
#else
		sum        = 0.0f;

#ifdef OMP 
#pragma omp parallel for default(none) private(i,temp) shared(X,kd,d) reduction (+:sum)
#endif
		for(i = kd ; i < kd + d ; i++)
		{
			temp   =  X[i]; 
			sum   += (temp*temp);
		}
#endif

		QD[k]     += (sum + bias2);
	}

	while (iter < nbite)
	{
		PGmax_new = -INF;
		PGmin_new = INF;

		for (i = 0 ; i < active_N ; i++)
		{
			j               = i + randint%(active_N - i);
			tmpind          = index[i];
			index[i]        = index[j];
			index[j]        = tmpind;
		}

		for (k = 0 ; k < active_N ; k++)
		{
			ind      = index[k];
			kind     = ind*d;
            alphaind = alpha[ind];
			yind     = (signed char) y[ind];

			G        = 0.0f;
#ifdef BLAS
	    	G        = BLASCALL(sdot)(&d , X+kind , &inc , w , &inc);
#else
#ifdef OMP 
#pragma omp parallel for default(none) private(i) shared(w,X,d,kind) reduction (+:G)
#endif
			for(i = 0 ; i < d ; i++)
			{
				G   += (w[i]*X[i + kind]);
			}
#endif
			if(addbias)
			{
				G   += (w[d]*B);
			}

			G        = G*yind - 1.0f;
			if(yind == 1)
			{
				C    = upper_bound_p; 
				G   += (alphaind*diag_p); 
			}
			else 
			{
				C    = upper_bound_n;
				G   += (alphaind*diag_n); 
			}

			PG       = 0.0f;
			if (alphaind == 0.0f)
			{
				if (G > PGmax_old)
				{
					active_N--;
					tmpind          = index[k];
                    index[k]        = index[active_N];
					index[active_N] = tmpind;
					k--;
					continue;
				}
				else if (G < 0.0f)
				{
					PG              = G;
				}
			}
			else if (alphaind == C)
			{
				if (G < PGmin_old)
				{
					active_N--;
					tmpind          = index[k];
                    index[k]        = index[active_N];
					index[active_N] = tmpind;
					k--;
					continue;
				}
				else if (G > 0.0f)
				{
					PG              = G;
				}
			}
			else
			{
				PG                  = G;
			}

			PGmax_new            = max(PGmax_new, PG);
			PGmin_new            = min(PGmin_new, PG);

			if((float)fabs(PG) > tolPG)
			{
				alpha[ind]       = min(max(alphaind - G/QD[ind], 0.0f), C);
				diff             = (alpha[ind] - alphaind)*yind;			
#ifdef BLAS
				BLASCALL(saxpy)(&d , &diff , X + kind , &inc , w , &inc);
#else
#ifdef OMP 
#pragma omp parallel for default(none) private(i) shared(w,diff,X,d,G,kind) 
#endif
				for(i = 0 ; i < d ; i++)
				{
					w[i]        += (diff*X[i + kind]);
				}
#endif
				if(addbias)
				{
					w[d]        += (diff*B);
				}
			}
		}

		iter++;
		if((PGmax_new - PGmin_new) <= eps)
		{
			if(active_N == N)
			{
				break;
			}
			else
			{
				active_N  = N;
				PGmax_old = INF;
				PGmin_old = -INF;
				continue;
			}
		}

		PGmax_old = PGmax_new;
		PGmin_old = PGmin_new;
		if (PGmax_old <= 0.0f)
		{
			PGmax_old = INF;
		}
		if (PGmin_old >= 0.0f)
		{
			PGmin_old = -INF;
		}
	}
	free(QD);
	free(alpha);
	free(index);
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
void shuffle(int *index , int n)
{
	int i , j , tmp;
	for (i = n - 1 ; i >= 0; i--) 
	{
		j         = (int) floor((i + 1) * rand());  /* j is uniformly distributed on {0, 1, ..., i} */	
		tmp       = index[j];
		index[j]  = index[i];
		index[i]  = tmp;
	}
}
/*----------------------------------------------------------------------------------------------------------------------------------------- */
