# Non-Seasonal Local Global Trend homoscedastic (LGThSkew) algorithm, skew
# Dec 2016
# Slawek
#############################################

library(rstan)

predictionAlgorithm=paste('LGThSkew');

#non-seasonal model
parameters = c("l", "b", "nu", "sigma", "levSm",  "bSm", 
		"coefTrend",  "powTrend", "locTrendFract")
modelX = '
  functions { 
	  real skew_student_t_log(real y, real nu, real mu, real sigma, real skew) {
		  real z; real zc; 
		  if (sigma <= 0)
		    reject("Scale has to be positive.  Found sigma=", sigma);

      z= (y-mu)/sigma;
      zc= skew*z*sqrt((nu+1)/(nu+square(z)));
		  return -log(sigma) + student_t_lpdf(z | nu, 0, 1)
                       + student_t_lcdf(zc | nu+1, 0, 1);
		}
	}
	data {  
		real<lower=0> CAUCHY_SD;
		real MIN_POW;  real MAX_POW;
		real<lower=0> MIN_SIGMA;
		real<lower=1> MIN_NU; real<lower=1> MAX_NU;
		int<lower=1> N;
		vector<lower=0>[N] y;
		real<lower=0> POW_TREND_ALPHA; real<lower=0> POW_TREND_BETA; 
	}
	parameters {
		real<lower=MIN_NU,upper=MAX_NU> nu; 
		real<lower=MIN_SIGMA> sigma;
		real <lower=0,upper=1>levSm;
		real <lower=0,upper=1> bSm;
		real bInit;
		real <lower=0,upper=1> powTrendBeta;
		real coefTrend;
		real <lower=-0.25,upper=1> locTrendFract;
	} 
	transformed parameters {
		real <lower=MIN_POW,upper=MAX_POW>powTrend;
		vector[N] l; vector[N] b;
		
		l[1] = y[1]; b[1] =  bInit;
		powTrend= (MAX_POW-MIN_POW)*powTrendBeta+MIN_POW;
		
		for (t in 2:N) {
			l[t]  = levSm*y[t] + (1-levSm)*l[t-1] ;
			b[t]  = bSm*(l[t]-l[t-1]) + (1-bSm)*b[t-1] ;
		}
	}
	model {
		sigma ~ cauchy(MIN_SIGMA,CAUCHY_SD) T[MIN_SIGMA,];
		coefTrend ~ cauchy(0,CAUCHY_SD);
		powTrendBeta ~ beta(POW_TREND_ALPHA, POW_TREND_BETA);
		bInit ~ normal(0,CAUCHY_SD);
		
		for (t in 2:N) {
			y[t] ~ skew_student_t(nu, l[t-1]+coefTrend*fabs(l[t-1])^powTrend+locTrendFract*b[t-1], sigma, SKEW);
		}
	}
'    
stanModel = stan_model(model_code=modelX)
#str(stanModel)
