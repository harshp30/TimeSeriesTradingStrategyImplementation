# GARCH Asset Modelling Implementation

# Install and require packages
install.packages('quantmod')
install.packages('tseries')
require('quantmod')
require('tseries')

# Download S&P500 data from FRED
data <- getSymbols('SP500', src='FRED', from='1990-01-01')

# Log original daily returns
# **** WHY NOT AD(GSPC) ?? ***
returns <- diff(log((SP500)))

# We are curious about the returns exclusively (not dates included)
returns <- as.numeric(returns)
# Remove NA invalid values
returns <- returns[!is.na(returns)]

# Finding the optimal coefficients for ARIMA(p,d,q)
result.aic <- Inf
result.order <- c(0,0,0)

for(p in 1:4) for(d in 0:1) for (q in 1:4){
  actual.aic <- AIC(arima(returns, order=c(p,d,q), optim.control=list(maxit=1000)))
  if (actual.aic < result.aic){
    result.aic <- actual.aic
    result.order <- c(p,d,q)
    result.arima <- arima(returns, order=c(p,d,q), optim.control=list(maxit=1000))
  }
}

# order of final ARIMA model
result.order
# 4 0 4

# it is very similar to white noise
acf(resid(result.arima))

# We have to check the square as well since there is some Heteroskedastic Behavior
# since the variance is changing var(t) !
acf(resid(result.arima)^2)
# There's a lot of volatility clustering

# Let's use the GARCH model to explain autocorrelation in the residual
# We apply GARCH on ARIMA model residuals
result.garch <- garch(resid(result.arima),trace=F)
# get rid of the first NA invalid value
result.residuals <- result.garch$res[-1]

# The residuals are ok but we have to check the squared residuals to make sure
# we can explain the heteroskedastic behavior
acf(result.residuals)

# squared residuals autocorrelation is like white noise: we can explain heteroskedasticity
acf(result.residuals^2) # Actual saved plot
# We can explain the volatility clustering now
