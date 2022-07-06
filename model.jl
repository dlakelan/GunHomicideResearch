
@model function guns(state,nstates,region,nregions,centers,width,year,lograte,startlaw)
    ## state is an integer corresponding to the state
    n = length(lograte)
    nc = length(centers)
    scale ~ Gamma(5.0,log(1.25)/4.0) # should predict to within 25%
    statebase ~ MvNormal([2.0 for i in 1:nstates], 3.0)
    nationcoefs ~ MvNormal(zeros(Float64,nc),2.0)
    regioncoefs = fill(nationcoefs,nregions)
    for i in 1:length(regioncoefs)
        regioncoefs[i] ~ MvNormal(nationcoefs,2.0)
    end
    statecoefs = fill(nationcoefs,nstates)
    for i in 1:nstates
        statecoefs[i] ~ MvNormal(fill(0.0,length(nationcoefs)),1.0)
    end
    lawrate ~ Gamma(5.0,3.0/4.0) ## about 3/yr
    meanlawcoef ~ Normal(0.0,log(2.0)/2.0) # no more than a doubling of homicide
    statelawcoef ~ MvNormal(fill(0.0,nstates),log(2.0)/4.0) # perturbation of up to log(2)/4
    predicted = zeros(typeof(statelawcoef[1]),n)

    for i in 1:length(lograte)
        predicted[i] = statebase[state[i]] + timeser(year[i],regioncoefs[region[i]] .+ (statecoefpert .* statecoefs[state[i]]),centers,width) + 
            (meanlawcoef + statelawcoef[state[i]]) * laweffect(year[i],lawrate,startlaw[state[i]])
    end
    lograte ~ MvNormal(predicted,scale)
end
