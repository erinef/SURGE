library(rjags)
##beta=22535 ##check number, seems ridiculous
tide=hist_tide_height ##pull from tide data
##as.numeric(levels(tide_height$f)[tide_height$f]) ##use to convert tide to numeric?
wind=hist_wind ##pull from wind data 
pressure=hist_pres ## pull from pressure data
n=length(tide)
SurgeHeight = "
model{

#### Data Model
##for(i in 1:n){
##y[i] ~ dnorm(x[i],tau_obs)
##}

for(i in 1:n){
wind.effect[i] ~ dnorm(wind[i],tau_wind)
}

for (i in 1:n){
tide.effect[i] ~ dnorm(tide[i], tau_tide)
}

for(i in 1:n){
pressure.effect[i] ~dnorm(pressure[i], tau_pressure)
}

#### Process Model
for(i in 2:n){
total[i] <- (beta * 901.4 * wind.effect[i] ) * ((9.8/tide.effect[i])*(beta + 10)) 
surge[i]~dnorm(total[i],tau_add)##change to how surge changes
}

#### Priors
surge[1] ~ dunif(-1,10)
##tau_obs ~ dgamma(a_obs,r_obs) ##observation error for tide height
tau_add ~ dgamma(a_add,r_add) ##process error
beta ~ dnorm(25,0.16)
tau_wind ~ dgamma(1,.5) ##obervation error for wind measurements
wind[1] ~ dnorm(0,3) ##uninformative prior for wind ##3 makes sense w/ units?
##pressure[1] ~ dunif(10,50) ##uninformative prior for pressure
##what are pressure units (inches of Hg), does prior make sense
##tau_pressure ~dgamma(1,.1) ##obs error for pressure measurement
tau_tide ~ dgamma(1,.1)
tide[1] ~dnorm(25,0.16)
##all taus unknown, so went with same as given taus
}
"

data <- list(tide=tide,wind=wind,pressure=hist_pres,n=length(tide),a_obs=1,r_obs=1,a_add=1,r_add=1)
#data <- list(y=y,wind.effect=hist_wind,pressure.effect=hist_pres,n=100,a_obs=1,r_obs=1,a_add=1,r_add=1)
nchain = 3
init <- list()
for(i in 1:nchain){
  tide.samp = sample(tide,length(tide),replace=TRUE)
  samp = as.numeric(as.character(tide.samp$f2))
  init[[i]] <- list(tau_add=1/var(diff(samp)),tau_tide=1/var(samp),tau_wind=1/var(diff(samp)),tau_pressure=1/var(diff(samp)))
}
j.model   <- jags.model (file = textConnection(SurgeHeight),
                         data = data,
                         init = init,
                         n.chains = 3)
jags.out   <- coda.samples (model = j.model,
                            variable.names = c("tau_add","tau_tide","tau_wind","tau_pressure"),
                            n.iter = 100)
plot(jags.out)


## after convergence
jags.out   <- coda.samples (model = j.model,
                            variable.names = c("surge", "tau_add","tau_tide","tau_wind","tau_pressure"),
                            n.iter = 10000,
                            thin = 10)
time = 1:length(tide)
time.rng = c(1,data$n) ## adjust to zoom in and out
ciEnvelope <- function(x,ylo,yhi,...){
  polygon(cbind(c(x, rev(x), x[1]), c(ylo, rev(yhi),
                                      ylo[1])), border = NA,...) 
}
out <- as.matrix(jags.out)
ci <- apply(out[,3:ncol(out)],2,quantile,c(0.025,0.5,0.975))

plot(time,ci[2,],type='l',ylim=range(tide[1:data$n],na.rm=TRUE),ylab="Surge Height",xlim=time[time.rng])
## adjust x-axis label to be monthly if zoomed
if(diff(time.rng) < 100){ 
  axis.Date(1, at=seq(time[time.rng[1]],time[time.rng[2]],by='month'), format = "%Y-%m")
}
ciEnvelope(time,ci[1,],ci[3,],col="lightBlue")
points(time,tide[1,data$n],pch="+",cex=0.5)


layout(matrix(c(1,2,3,3),2,2,byrow=TRUE))
hist(1/sqrt(out[,1]),main=colnames(out)[1])
hist(1/sqrt(out[,2]),main=colnames(out)[2])
plot(out[,1],out[,2],pch=".",xlab=colnames(out)[1],ylab=colnames(out)[2])
cor(out[,1:2])