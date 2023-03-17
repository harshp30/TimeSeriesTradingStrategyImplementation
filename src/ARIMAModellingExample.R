# Asset Modelling with ARIMA Implementation

# install and require packages
install.packages('quantmod')
install.packages('forecast')
require('quantmod')
require('forecast')

# Download IBM stock data from yahoo finance
getSymbols('IBM', src='yahoo')

# get original daily returns
returns <- diff(log(Ad(IBM)))

# Remove first value since it's NA
returns <- returns[-1]

# Find optimal p,d,q values with AIC
result.aic <- Inf
result.order <- c(0,0,0)

for (p in 1:4) for (d in 0:1) for (q in 1:4){
  actual.aic <- AIC(arima(returns, order=c(p,d,q), optim.control=list(maxit=1000)))
  if(actual.aic < result.aic){
    result.aic <- actual.aic
    result.order <- c(p,d,q)
    result.arima <- arima(returns, order=c(p,d,q), optim.control=list(maxit=1000))
  }
}

# order of ARIMA model
result.order
# 4 0 4
# 4th order Ar and 4th order MA

# Check for autocorrelation
acf(resid(result.arima), na.action=na.omit)

# check Ljung-Box p-value test
Box.test(resid(result.arima), lag=25, type='Ljung-Box')
# X-squared = 35.165, df = 25, p-value = 0.08527

# Forecast the log daily returns for 50 future day
plot(forecast(result.arima, h=50))
# end blue line is the prediction
