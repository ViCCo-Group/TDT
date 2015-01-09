/*

 Normalize data X (d x N) inplace along the second dimension with various method
 
 Usage
 -----

 [a , b] = normalize(X , [method] , [a] , [b]);

 Inputs
 ------

 X             data   (d x N) in single/double format
 method        method of normalization: 
               method = 1 <=> X~[-1,1], method = 2 <=> X~N(0,1) (default method = 1)

 a             vector (d x 1). if method = 1, each elements of a is the minimum value to apply to X, if method = 2, a is the mean value
 b             vector (d x 1). if method = 2, each elements of a is the maximum value to apply to X, if method = 2, a is the std value

 Ouputs
 ------

 a             vector (d x 1) in single/double format. if method = 1, each elements of a is the minimum value computed from X, if method = 2, a is the mean value
 b             vector (d x 1) in single/double format. if method = 2, each elements of a is the maximum value computed from X , if method = 2, a is the std value



 To compile
 ----------

mex  -v normalize.c 
mex  -g -v normalize.c 
mex -f mexopts_intel10.bat  normalize.c

Example 1
---------

d                    = 100;
N                    = 1000;
X                    = randn(d , N);
method               = 1;
[a , b]              = normalize(X , method);

X1                    = randn(d , N);
normalize(X1 , method , a , b);

 

Author : Sébastien PARIS : sebastien.paris@lsis.org
------


v.1.1 - Add init parameter to scale data

v.1.0 - Initial release
      - Bug correction

*/

#include <math.h>
#include "mex.h"

#define BIG 1e250
#define SMALL -1e250

/*--------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------*/

void dnormalize(double * , int, int , int , double * , double * , int);
void snormalize(float * , int, int , int , float * , float * , int );

/*--------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------*/

void mexFunction( int nlhs, mxArray *plhs[] , int nrhs, const mxArray *prhs[] )
{	
	double  *dX , *da , *db;	
	float *sX , *sa , *sb;
    int method = 0;
	int d, N , issingle = 0 , use_init = 0;
	
	/*--------------------------------------------------------------------------------*/
	/*--------------------------------------------------------------------------------*/
	/* -------------------------- Parse INPUT  -------------------------------------- */
	/*--------------------------------------------------------------------------------*/	
	/*--------------------------------------------------------------------------------*/
		
	if (nrhs < 1) 
	{
		mexPrintf(
			"\n"
			"\n"
			"\n"
			"Normalize data X (d x N) inplace along the second dimension with various method\n"
			"\n"
			"\n"
			"Usage\n"
			"-----\n"
			"\n"
			"\n"
			"[a , b] = normalize(X , [method] , [a] , [b]);\n"
			"\n"
			"\n"
			"Inputs\n"
			"------\n"
			"\n"
			"\n"
			"X             data   (d x N) in single/double format\n"
			"method        method of normalization: \n"
			"              method = 1 <=> X~[-1,1], method = 2 <=> X~N(0,1) (default method = 1)\n"
            "a             vector (d x 1). if method = 1, each elements of a is the minimum value to apply to X, if method = 2, a is the mean value\n"
            "b             vector (d x 1). if method = 2, each elements of a is the maximum value to apply to X, if method = 2, a is the std value\n"
			"\n"
            "Ouputs\n"
            "------\n"
			"\n"
			"\n"
            "a             vector (d x 1) in single/double format. if method = 1, each elements of a is the minimum value computed from X, if method = 2, a is the mean value\n"
            "b             vector (d x 1) in single/double format. if method = 2, each elements of a is the maximum value computed from X , if method = 2, a is the std value\n"
			"\n"
			"\n"
			);
			return;
	}

	/* ----- Input 1 ----- */

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
	
	/* ----- Input 2 ----- */

	if ((nrhs > 1) && !mxIsEmpty(prhs[1]) )
	{
		method       = (int) mxGetScalar(prhs[1]);
		if(method < 0 || method > 4)
		{
			mexErrMsgTxt("method = {0,1,2,3,4}");		
		}
	}

	if (( nrhs > 3) && !mxIsEmpty(prhs[2]) && !mxIsEmpty(prhs[3]) )
	{
		if(issingle)
		{
			sa  = (float *)mxGetData(prhs[2]);
			sb  = (float *)mxGetData(prhs[3]);
		}
		else
		{
			da  = (double *)mxGetData(prhs[2]);
			db  = (double *)mxGetData(prhs[3]);
		}

		use_init  = 1;
	}
	else
	{
		if(issingle)
		{
			sa  = (float *)malloc(d*sizeof(float));
			sb  = (float *)malloc(d*sizeof(float));

		}
		else
		{
			sa  = (double *)malloc(d*sizeof(double));
			sb  = (double *)malloc(d*sizeof(double));
		}
	}

	if(issingle)
	{

		plhs[0]            =  mxCreateNumericMatrix(d , 1, mxSINGLE_CLASS , mxREAL);
		plhs[1]            =  mxCreateNumericMatrix(d , 1, mxSINGLE_CLASS , mxREAL);
		if(!use_init)
		{
			sa                 = (float *) mxGetData(plhs[0]);
			sb                 = (float *) mxGetData(plhs[1]);
		}
	}
	else
	{
		plhs[0]            =  mxCreateNumericMatrix(d  , 1, mxDOUBLE_CLASS , mxREAL);
		plhs[1]            =  mxCreateNumericMatrix(d  , 1, mxDOUBLE_CLASS , mxREAL);
		if(!use_init)
		{
			da                 = (double *) mxGetData(plhs[0]);
			db                 = (double *) mxGetData(plhs[1]);
		}
	}

	
	/*---------------------------------------------------------------------------------*/
	/*---------------------------------------------------------------------------------*/
	/* ----------------------- MAIN CALL  -------------------------------------------- */
	/*---------------------------------------------------------------------------------*/
	/*---------------------------------------------------------------------------------*/	
	/*---------------------------------------------------------------------------------*/
	
	if(issingle)
	{
		snormalize(sX , method , d ,  N , sa , sb , use_init);
	}
	else
	{
		dnormalize(dX , method , d ,  N , da , db , use_init);
	}


	if(use_init)
	{
		if(issingle)
		{
			sa                 = (float *) mxGetData(plhs[0]);
			sb                 = (float *) mxGetData(plhs[1]);
		}
		else
		{
			da                 = (double *) mxGetData(plhs[0]);
			db                 = (double *) mxGetData(plhs[1]);
		}
	}
}
/*--------------------------------------------------------------------------------*/
void dnormalize(double *X , int method , int d , int N , double *a , double *b , int use_init)
{
	int i,j,jd , N1 = N-1;
	double m, std, min, max, temp;
	double diff;

	if(method == 1)
	{
		for (i = 0 ; i < d ; i++)
		{
			if(use_init)
			{
				min = a[i];
				max = b[i];
			}
			else
			{
				min  = BIG;
				max  = SMALL;
				for(j = 0 ; j < N ; j++)
				{
					temp = X[i + j*d];
					if(temp < min)
					{
						min = temp;
					}
					if(temp > max)
					{
						max = temp;
					}
				}
				a[i] = min;
				b[i] = max;
			}
			diff = max - min;
			if(diff == 0.0)
			{
				diff = 1.0;
			}
			else
			{
				diff = 1.0/diff;
			}
			for(j = 0 ; j < N ; j++)
			{
				jd         = j*d;
				X[i + jd]  = 2.0*(X[i + jd] - min)*diff - 1.0;
			}
		}
	}
	else if(method == 2)
	{
		for (i = 0 ; i < d ; i++)
		{
			if(use_init)
			{
				m   = a[i];
				std = b[i];
			}
			else
			{
				m    = 0.0;
				for(j = 0 ; j < N ; j++)
				{
					m += X[i + j*d];
				}
				m   = m/N;
				std = 0.0;
				for(j = 0 ; j < N ; j++)
				{
					jd           = j*d;
					X[i + jd]   -= m;
					temp         = X[i + jd];
					std         += (temp*temp);
				}
				std = sqrt(std/N1);
				if(std == 0.0)
				{
					std = 1.0;
				}
				else
				{
					std = 1.0/std;
				}
				a[i] = m;
				b[i] = std;
			}
			for(j = 0 ; j < N ; j++)
			{
				X[i + j*d] *= std;
			}
		}
	}
}
/*--------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------*/
void snormalize(float *X , int method , int d , int N , float *a , float *b , int use_init)
{
	int i,j,jd , N1 = N-1;
	float m, std, min, max, temp;
	float diff;

	if(method == 1)
	{
		for (i = 0 ; i < d ; i++)
		{
			if(use_init)
			{
				min = a[i];
				max = b[i];
			}
			else
			{
				min  = BIG;
				max  = SMALL;
				for(j = 0 ; j < N ; j++)
				{
					temp = X[i + j*d];
					if(temp < min)
					{
						min = temp;
					}
					if(temp > max)
					{
						max = temp;
					}
				}
				a[i] = min;
				b[i] = max;
			}
			diff = max - min;
			if(diff == 0.0f)
			{
				diff = 1.0f;
			}
			else
			{
				diff = 1.0f/diff;
			}
			for(j = 0 ; j < N ; j++)
			{
				jd         = j*d;
				X[i + jd]  = 2.0f*(X[i + jd] - min)*diff - 1.0;
			}
		}
	}
	else if(method == 2)
	{
		for (i = 0 ; i < d ; i++)
		{
			if(use_init)
			{
				m   = a[i];
				std = b[i];
			}
			else
			{
				m      = 0.0f;
				for(j = 0 ; j < N ; j++)
				{
					m += X[i + j*d];
				}
				m   = m/N;
				std = 0.0f;
				for(j = 0 ; j < N ; j++)
				{
					jd           = j*d;
					X[i + jd]   -= m;
					temp         = X[i + jd];
					std         += (temp*temp);
				}
				std = (float)sqrt(std/N1);
				if(std == 0.0f)
				{
					std = 1.0f;
				}
				else
				{
					std = 1.0f/std;
				}
				a[i] = m;
				b[i] = std;
			}
			for(j = 0 ; j < N ; j++)
			{
				X[i + j*d] *= std;
			}
		}
	}
}
/*--------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------*/
