



@model function ausmodel(years::Vector{Int64},gdppercap::Vector{T},
        guns::Vector{T}, gunowners::Vector{T}, popn::Vector{T},
        hom::Vector{T},rape::Vector{T},rob::Vector{T},bne::Vector{T},vehth::Vector{T},theft::Vector{T}) where T

    f ~ Beta(3.0,3.0)
    err ~ Gamma(3.0,1.0/2.0)
    stuff ~ MvNormal(fill(0.0,length(years)),1.0)
    phom = copy(stuff)
    eqhom = copy(stuff)

    prape = copy(stuff)
    eqrape = copy(stuff)

    prob = copy(stuff)
    eqrob = copy(stuff)

    pbne = copy(stuff)
    eqbne = copy(stuff)

    pvehth = copy(stuff)
    eqvehth = copy(stuff)

    ptheft = copy(stuff)
    eqtheft = copy(stuff)

    homcoefs ~ MvNormal(fill(0.0,7),3.0)
    rapecoefs ~ MvNormal(fill(0.0,7),3.0)
    robcoefs ~ MvNormal(fill(0.0,7),3.0)
    bnecoefs ~ MvNormal(fill(0.0,7),3.0)
    vehthcoefs ~ MvNormal(fill(0.0,7),3.0)
    theftcoefs ~ MvNormal(fill(0.0,7),3.0)

    eqhom[1] = one(typeof(stuff[1]))
    eqrape[1] = one(typeof(stuff[1]))
    eqrob[1] = one(typeof(stuff[1]))
    eqbne[1] = one(typeof(stuff[1]))
    eqvehth[1] = one(typeof(stuff[1]))
    eqtheft[1] = one(typeof(stuff[1]))

    phom[1] = one(typeof(stuff[1]))
    prape[1] = one(typeof(stuff[1]))
    prob[1] = one(typeof(stuff[1]))
    pbne[1] = one(typeof(stuff[1]))
    pvehth[1] = one(typeof(stuff[1]))
    ptheft[1] = one(typeof(stuff[1]))

    for yr in 2:length(years)
        preds = [gdppercap[yr-1],gdppercap[yr]-gdppercap[yr-1],guns[yr-1]/popn[yr-1], guns[yr]/popn[yr] - guns[yr-1]/popn[yr-1], 
            gunowners[yr]/popn[yr], gunowners[yr]/popn[yr] - gunowners[yr-1]/popn[yr-1],  1.0]
        
        eqhom[yr] = exp(dot(homcoefs,preds))
        eqrape[yr] = exp(dot(rapecoefs,preds))
        eqrob[yr] = exp(dot(robcoefs,preds))
        eqbne[yr] = exp(dot(bnecoefs,preds))
        eqvehth[yr] = exp(dot(vehthcoefs,preds))
        eqtheft[yr] = exp(dot(theftcoefs,preds))

        phom[yr] = phom[yr-1] + f * (eqhom[yr] - phom[yr-1])
        prape[yr] = prape[yr-1] + f * (eqrape[yr] - prape[yr-1])
        prob[yr] = prob[yr-1] + f * (eqrob[yr] - prob[yr-1])
        pbne[yr] = pbne[yr-1] + f * (eqbne[yr] - pbne[yr-1])
        pvehth[yr] = pvehth[yr-1] + f * (eqvehth[yr] - pvehth[yr-1])
        ptheft[yr] = ptheft[yr-1] + f * (eqtheft[yr] - ptheft[yr-1])

    end
    hom ~ MvNormal(phom,err)
    rape ~ MvNormal(prape,err)
    rob ~ MvNormal(prob,err)
    bne ~ MvNormal(pbne,err)
    vehth ~ MvNormal(pvehth,err)
    theft ~ MvNormal(ptheft,err)
    return((phom = phom, prape=prape,prob=prob,pbne=pbne,pvehth=pvehth,ptheft=ptheft))
end

