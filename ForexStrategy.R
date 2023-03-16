# FOREX Trading Strategy Implementation

# Install and require libraries
install.packages('quantmod')
install.packages('timeSeries')
install.packages('rugarch')
require('quantmod')
require('timeSeries')
require('rugarch')

# Read csv file containing EUR/USD data via 
# https://www.udemy.com/course/quantitative-finance-algorithmic-trading-ii-time-series/
eurusd <- read.csv(file="data/EURUSD.csv")
dates <- as.Date(as.character(eurusd[, 1]), format="%d/%m/%Y")
# Log returns the relative changes of closing prices
returns <- diff(log(eurusd$C))

# Using 100 observations (window) to fit the ARMA and GARCH models
# Shift the window one step and fit the models again
window.length <- 100
forecasts.length <- length(returns) - window.length
forecasts <- vector(mode="numeric", length=forecasts.length) 
# Need this feature: +1 for positive return -1 for negative return
directions <- vector(mode="numeric", length=forecasts.length) 

# Consider every trading day and calculate optimal model parameters 
# (just consider the items within the window)
# Make a prediction for next day's return
for (i in 0:forecasts.length) {
  # Let's create rolling window
  roll.returns <- returns[(1+i):(window.length + i)] 
  final.aic <- Inf
  final.order <- c(0,0,0)
  
  # ARMA model order p,q < 4 !!!
  for (p in 1:4) for (q in 1:4) { 
    
    # Because of the error=function(err) FALSE in case of an error it return FALSE
    model <- tryCatch( arima(roll.returns, order = c(p,0,q)), error = function( err ) FALSE, warning = function( err ) FALSE )
    
    # FALSE means the model fit was unsuccessful (needs more iteration for example)
    # We find the best model based in AIC !!! 
    if (!is.logical( model)) {
      current.aic <- AIC(model)
      if (current.aic < final.aic) {
        final.aic <- current.aic
        final.order <- c(p,0,q)
        final.arima <- arima(roll.returns, order = final.order)
      }
    }
  }
  
  # We use GARCH(1,1) model 
  # Variance: GARCH is needed - mean: ARMA is needed
  # The errors have skew-generalized error distribution - sged
  spec = ugarchspec(variance.model <- list(garchOrder=c(1,1)),
                    mean.model <- list(armaOrder <- c(final.order[1], final.order[3]), include.mean = T),
                    distribution.model = "sged")
  
  # This is how we actually fit the GARCH(1,1) model
  # We just want to fit the model to the rolling window returns + hybrid tried different solvers
  fit = tryCatch(ugarchfit(spec, roll.returns, solver = 'hybrid'), error = function(e) e, warning = function(w) w)
  
  # Make predictions with the fitted model
  # Model does not always converge - assign value of 0 to prediction
  if (is(fit, "warning")) {
    forecasts[i+1] <- 0
  } else {
    # Predict the return tomorrow (so 1 day ahead)
    next.day.forecast = ugarchforecast(fit, n.ahead = 1)
    # x variable contains the value of the return
    x = next.day.forecast@forecast$seriesFor
    # Need the predictions: +1 (positive return) or -1 (negative return) / x[1] is the return itself
    directions[i+1] <- ifelse(x[1] > 0, 1, -1) 
    # actual value of forecast: we predict returns
    forecasts[i+1] <- x[1] 
  }
}

forecasts
# Use the first window.length data to fit the model ... we need the date for the forecasted values
forecasts.ts <- xts(forecasts, dates[(window.length):length(returns)])
forecasts.ts
# Create lagged series (shift one step to the right) of forecasts and sign of forecast
strategy.forecasts <- Lag(forecasts.ts, 1)
strategy.forecasts
strategy.direction <- ifelse(strategy.forecasts > 0, 1, ifelse(strategy.forecasts < 0, -1, 0))

# Need the directions as well + the returns
strategy.direction.returns <- strategy.direction * returns[(window.length):length(returns)]
# Remove the first NA invalid value
strategy.direction.returns[1] <- 0

# Cumulative sum: we sum up the daily returns for the plot
strategy.curve <- cumsum(strategy.direction.returns)
# Long Term Investment ... we need the dates as well
longterm.ts <- xts(returns[(window.length):length(returns)], dates[(window.length):length(returns)])
longterm.curve <- cumsum(longterm.ts)
# Merge the two sets: trading strategy + buy&hold
both.curves <- cbind(strategy.curve, longterm.curve)
# Rename the columns accordingly
names(both.curves) <- c("Strategy Returns", "Long Term Investing Returns")

# {lot ARIMA+GARCH strategy as well as the long term investing method
plot(x = both.curves[,"Strategy Returns"], xlab = "Time", ylab = "Cumulative Return",
     main = "Cumulative Returns", ylim = c(-0.25, 0.4), major.ticks= "quarters",
     minor.ticks = FALSE, col = "green")
lines(x = both.curves[,"Long Term Investing Returns"], col = "red")
strategy_colors <- c( "green", "red") 
# Green is our ARIMA+GARCH STRATEGY and Red is the Long Term Investing Strategy
legend(x = 'bottomleft', legend = c("ARIMA&GARCH", "Long Term Investing"),
       lty = 1, col = strategy_colors)

# Green is out strategy
# Red is long term hold