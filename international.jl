
using Pkg
Pkg.activate(".")

using CSV,DataFrames,Downloads,DataFramesMeta, StatsPlots, XLSX, 
    Dates, Statistics, Turing, LinearAlgebra, Interpolations, Serialization,
    GLM, Colors, ColorSchemes



function getifnotthere(filename,URL)
    if !Base.Filesystem.ispath(filename)
        # see https://www.aic.gov.au/statistics/homicide
        Downloads.download(URL,filename)
    end
end

getifnotthere("data/intl-homicides-unodc.xlsx","https://dataunodc.un.org/sites/dataunodc.un.org/files/data_cts_intentional_homicide.xlsx")
getifnotthere("data/country-populations-unpop.xlsx","https://population.un.org/wpp/Download/Files/1_Indicators%20(Standard)/EXCEL_FILES/1_General/WPP2022_GEN_F01_DEMOGRAPHIC_INDICATORS_COMPACT_REV1.xlsx")

homdata = DataFrame(XLSX.readtable("./data/intl-homicides-unodc.xlsx",1; first_row=3)...)
rename!(homdata,Dict(Symbol("Unit of measurement") => :units, :VALUE => :homicide))
@subset!(homdata,:Indicator .== "Victims of intentional homicide" .&& :Dimension .== "Total" .&& :Sex .== "Total")

popdata = DataFrame(XLSX.readtable("./data/country-populations-unpop.xlsx",1,"A:BM"; first_row=17)...) 
rename!(popdata,Dict(Symbol("ISO3 Alpha-code") => :Iso3_code, 
    Symbol("Region, subregion, country or area *") => :country,
    Symbol("Total Population, as of 1 January (thousands)") => :PopulationJan,
        Symbol("Population Density, as of 1 July (persons per square km)") => :popdensperkm2,
        Symbol("Median Age, as of 1 July (years)") => :medianage))

@rtransform!(popdata,:PopulationJan = if :PopulationJan == "..." missing else :PopulationJan .* 1000.0 end)

countrycodes = unique(@select(popdata,:country,:Iso3_code))


alldat = @orderby(@subset(leftjoin(homdata,popdata; on = [:Iso3_code,:Year],matchmissing=:notequal),
    :units .== "Counts"), :Iso3_code,:Year)
    
## plot comparisons for countries with 3M people by region
bigcount = @subset(alldat,:PopulationJan .> 3e6)
let p = []
    for r in unique(bigcount.Region)
        dat = @subset(bigcount,:Region .== r)
        push!(p,plot(dat.Year,dat.homicide ./ dat.PopulationJan .* 100000.0; group=dat.Iso3_code, title="Homicide Rate\n$r",legend=false))
    end
    plot(p...,size=(1000,1000))
end


getifnotthere("data/worldbank-gini-data.zip","https://api.worldbank.org/v2/en/indicator/SI.POV.GINI?downloadformat=csv")

ginidat = CSV.read("data/API_SI.POV.GINI_DS2_en_csv_v2_4333947.csv",DataFrame; skipto=6, header=5)
ginidat = ginidat[:,1:end-1] # drop meaningless final column
rename!(ginidat,Dict(Symbol("Country Name") => :Country, Symbol("Country Code") => :countrycode, 
    Symbol("Indicator Name") => :indicator, Symbol("Indicator Code") => :indicatorcode))
ginistack = DataFramesMeta.stack(ginidat,Not([:Country, :countrycode,:indicator,:indicatorcode]))
rename!(ginistack,Dict("variable" => "Year", "value" => "ginicoef"))
ginistack.Year = tryparse.(Int64,ginistack.Year)

alldat2 = leftjoin(alldat,ginistack; on = [:Iso3_code => :countrycode, :Year], makeunique=true)

p = @df @subset(alldat2,:PopulationJan .> 1e6) scatter(:ginicoef, :homicide ./ :PopulationJan .* 100000.0; title="Homicide Rate vs Inequality",ylab="Homicides/100k",xlab="Gini Index 0-100")
display(p)

p = @df @subset(alldat2,:PopulationJan .> 1e6) scatter(:ginicoef, log.(:homicide ./ :PopulationJan .* 100000.0); group=:Iso3_code, title="log(Homicide Rate) vs Gini (Inequality)",ylab="log(Homicides/100k)",xlab="Gini Index 0-100",legend=false, alpha=0.5)
display(p)

gdp = CSV.read("data/API_NY.GDP.PCAP.CD_DS2_en_csv_v2_4251004.csv",DataFrame; header=5,skipto=6)
rename!(gdp,[Symbol("Country Name") => :country, Symbol("Country Code") => :ccode])
gdp = gdp[:,1:end-1]
gdpstack = DataFramesMeta.stack(gdp,Not(["country","ccode","Indicator Name","Indicator Code"]))

rename!(gdpstack,Dict("variable" => "Year", "value" => "gdp2020dol"))
gdpstack.Year = tryparse.(Int64,gdpstack.Year)

alldat3 = leftjoin(alldat2,gdpstack; on = [:Iso3_code => :ccode, :Year],makeunique=true)

alldat3.medianage = map(x -> if typeof(x) != Float64 missing else x end,alldat3.medianage)
alldat3.popdensperkm2 = map(x -> if typeof(x) != Float64 missing else x end,alldat3.popdensperkm2)


p = @df alldat3 scatter(log.(:gdp2020dol), log.(:homicide ./ :PopulationJan .*100000.0); title="Log Homicide vs Log GDP/capita",
    xlab="log(GDP/capita)",ylab="log(homicide/100k/yr)", legend=false, alpha=0.2,smooth=true,linewidth=5)
display(p)

alldat3.loghom = log.((alldat3.homicide .+ 0.1) ./ alldat3.PopulationJan .* 100e3)
alldat3.loggdppc = log.(alldat3.gdp2020dol)
alldat3.logpopdens = log.(alldat3.popdensperkm2)

gdpmod = lm(@formula(loghom ~ loggdppc + loggdppc^2),alldat3)

plot!(collect(4:1:12),predict(gdpmod,DataFrame(loggdppc=collect(4:1:12))))



mod = lm(@formula(loghom  ~ loggdppc + ginicoef + logpopdens  ),alldat3)

display(mod)

@df alldat3 plot(:ginicoef, residuals(mod))

alldat4 = @subset(alldat3,.!ismissing.(alldat3.gdp2020dol) .&& .! ismissing.(alldat3.ginicoef))

p = scatter(alldat4.ginicoef,predict(mod,alldat4),alpha=.1, title="Predicted Log(Homicide rate) vs Gini",ylim=(-2,5),xlim=(25,60),size=(500,500),legend=false)
display(p)
#p = scatter(alldat4.ginicoef,alldat4.loghom; marker_z=alldat4.gdp2020dol ./ 75000.0, legend=false, seriescolor = cgrad([:lightgrey,:darkblue]), title="Log(Homicide rate) vs Gini\nActual (Color = GDP/capita)",ylim=(-4,4))

#display(p)

p = scatter(alldat4.ginicoef,alldat4.loghom;  color = "black", title="Log(Homicide rate) vs Gini",
    ylim=(-2,5),xlim=(25,60),label="worldwide",legend=false,size=(500,500),alpha=0.1)

countries = ("USA","AUT","AUS","CHE","ISR","NLD","NOR","ESP","DEU","FRA","CZE","GRC","BRA","MEX","ARG","CAN")
colors = [get(colorschemes[:rainbow],(i-1) / length(countries)) for i in 1:length(countries)]
selectcountry = @subset(alldat4,in.(alldat4.Iso3_code,Ref(countries)))
#@df selectcountry scatter!(:ginicoef,:loghom,markercolor=colors[indexin(:Iso3_code,collect(countries))])

countrydat = @by(@subset(alldat4,in.(:Iso3_code,Ref(countries)) .&& .! ismissing.(:ginicoef)),:Iso3_code,
    :ginimean = mean(:ginicoef),
    :loghommean = mean(:loghom))


annotations = [(countrydat.ginimean[i],countrydat.loghommean[i],(countrydat.Iso3_code[i],8 #,colors[i]
    )) for i in 1:nrow(countrydat)]
annotate!(annotations)
display(p)





p = @df alldat3 scatter(:medianage, :loghom, title="Log homicide vs median age")
display(p)
p = @df alldat3 scatter(log.(:popdensperkm2), :loghom, title="Log homicide vs Log Pop Density")
display(p)



if Base.Filesystem.ispath("data/smallarms2020-clean.csv")
    gundata = CSV.read("data/smallarms2020-clean.csv",DataFrame)
else

    rws = CSV.Rows("data/smallarms2020.csv",header=false)
    gundata = DataFrame(countrycode = String[],civguns= Float64[], esttype = Int64[])
    for r in rws
        #@show(r)
        #@show(length(r))
        n = 0
        code = r[1]
        civguns = 0
        esttype = 0
        for v in 2:length(r)
            num = nothing
            if !ismissing(r[v])
                num = tryparse(Float64,r[v])
            end
            if ! isnothing(num)
                n = n+1
                if n == 2 
                    civguns = num
                elseif n == 4
                    esttype = round(Int64,num)
                    break
                end
            end
        end
        push!(gundata,(countrycode=code,civguns=civguns,esttype=esttype))
    end
    CSV.write("data/smallarms2020-clean.csv",gundata)
end




alldat5 = leftjoin(alldat4,gundata; on=:Iso3_code => :countrycode)

alldat5.civgpcap = alldat5.civguns ./ alldat5.PopulationJan
alldat5.logcivgpcap = log.(alldat5.civgpcap)

alldat5recent = @subset(alldat5,in.(:Year, Ref((2017,2018,2019))))

p = @df alldat5recent scatter(:logcivgpcap, :loghom,title="Log(Hom rate) vs log(guns/capita)")
display(p)

modlguns = lm(@formula(loghom ~ civgpcap), alldat5recent)

display(modlguns)


#modlwguns = lm(@formula(loghom ~ ginicoef + loggdppc + civgpcap),alldat5recent)

#modlwguns = lm(@formula(loghom ~ ginicoef + loggdppc + logcivgpcap),alldat5recent)

# we only have an estimate of the guns/capita at a single time point, if we use multiple years, the changing "capita" 
# will create an artificial trend 
modlwguns2019 = lm(@formula(loghom ~ ginicoef + loggdppc + logcivgpcap),@subset(alldat5recent,:Year .== 2019))

display(modlwguns2019)

p = scatter(residuals(modlwguns2019),title="Residual on model")

display(p)

p = @df @subset(alldat5,.! ismissing.(:civgpcap)) histogram(:civgpcap; title="Distribution of Guns/Capita",legend=false)

display(p)



getifnotthere("data/pums-2020-5yr-hus.zip","https://www2.census.gov/programs-surveys/acs/data/pums/2020/5-Year/csv_hus.zip")

#getifnotthere("data/pums-2020-csv-hus.zip","https://www2.census.gov/programs-surveys/acs/experimental/2020/data/pums/1-Year/csv_hus.zip")
#getifnotthere("data/PUMS_Data_Dictionary_2020.csv","https://www2.census.gov/programs-surveys/acs/experimental/2020/documentation/pums/PUMS_Data_Dictionary_2020.csv")
getifnotthere("data/PUMS_Data_Dectionary_2016-2020.pdf","https://www2.census.gov/programs-surveys/acs/tech_docs/pums/data_dict/PUMS_Data_Dictionary_2016-2020.pdf")

if ! Base.Filesystem.ispath("data/psam_husa.csv") || ! Base.Filesystem.ispath("data/psam_husb.csv")
    cd("data")
    run(`unzip pums-2020-5yr-hus.zip`)
    cd("..")
end

#pumsdd = CSV.read("data/PUMS_Data_Dictionary_2020.csv",DataFrame; header=false)
#rename!(pumsdd,["IDFlag","varname","vartype","length","title_startval","endval","description"])

psamh = let psamh = DataFrame()
    for i in ["a","b","c","d"]
        new = CSV.read("data/psam_hus$(i).csv",DataFrame,select=[:SERIALNO,:ST,:FINCP,:NP,:WGTP])
        @subset!(new,.!ismissing.(:FINCP) .&& .! ismissing.(:NP))
        psamh = [psamh ; 
            new[wsample(1:nrow(new),new.WGTP,round(Int64,0.1*nrow(new))),:] ]
    end
    psamh
end
psamh.Year = tryparse.(Int64,psamh.SERIALNO[i][1:4] for i in 1:nrow(psamh))


function ginicoef(incs,n)
"Calculate the gini coefficient from a sample of incomes using sample of size n"
    avg = mean(incs)
    absdiff = abs.(sample(incs,n) .- sample(incs,n))
    mean(absdiff)/2/avg
end


fips = CSV.read("data/fipscodes.csv",DataFrame)

psamh.pcapinc = psamh.FINCP ./ psamh.NP

stateginis = @by(psamh,[:Year,:ST],:gini = ginicoef(:pcapinc,2000),:logmeaninc = log(mean(:pcapinc)))
stateginis = leftjoin(stateginis,fips; on = :ST => :STATE)
stateginis.gini100 = stateginis.gini .* 100.0


# manually downloaded CDC wonder gun homicide data using online form 
gunhomicidesnew = CSV.read("./data/wonder-gun-homicide-byyear.csv",DataFrame)
gunhomicidesold = CSV.read("./data/cdc-wonder-firearm-homicide-1979-1998.csv",DataFrame)
gunhomicides = [gunhomicidesnew ; gunhomicidesold]
gunhomicides = @chain rename(gunhomicides,Dict("Crude Rate" => "crudedeathrate", "State Code" => "StateCode", "Year" => "year", "Year Code" => "YearCode")) begin
    @subset(.! ismissing.(:Deaths))
    @transform(:crudedeathrate = map(x -> isnothing(x) ? missing : x, tryparse.(Float64,String.(:crudedeathrate))),
        :state = String31.(:State))
    @subset(.! ismissing.(:crudedeathrate))
    @orderby(:StateCode,:year)
end




p = plot(@by(stateginis,:ST,:pl = plot(:Year,:gini100,title="$(:STUSAB[1])",ylim=(30,60),size=(500,500))).pl...; size=(2000,2000))
display(p)

stateginis = leftjoin(stateginis,gunhomicides; on = [:Year => :year, :ST => :StateCode])


p = @df stateginis scatter(:gini100,log.(:crudedeathrate); title="log(Firearm Homicide rate) vs Gini\nUS States 2016-2020", legend=false, size=(500,500))
display(p)

stateginis.loghom = log.(stateginis.crudedeathrate)

mod = lm(@formula(loghom ~ gini100),stateginis)

Plots.abline!(coef(mod)[2],coef(mod)[1])

mod2 = lm(@formula(loghom ~ gini100 + logmeaninc),stateginis)


p = @df stateginis scatter(:gini100,:loghom; marker_z=:logmeaninc,title="Log(firearm homicide) vs Gini\nColor = log(MeanIncome)")
display(p)

p = scatter(residuals(mod2); title = "Residuals\nloghom ~ 1 + gini100 + logmeanincome")
display(p)

suic = CSV.read("data/cdc-wonder-suicide-all-byyear.csv",DataFrame)


@subset!(suic,.! ismissing.(:Year)) # drop summary/totals etc
rename!(suic,[:Notes,:State,:StateCode,:Year,:YearCode,:Deaths,:Population,:suicrate])

stateginis = leftjoin(stateginis,suic; on = [:Year,:ST => :StateCode], makeunique=true)

p = @df stateginis scatter(:gini100,log.(:suicrate); title = "Log(Suicide Rate) vs Gini, in US",alpha=0.2)
p = @df stateginis annotate!(:gini100,log.(:suicrate),:STUSAB,font(8))
display(p)

stateginis.logsuic = log.(stateginis.suicrate)

suicmod = lm(@formula(logsuic ~ gini100 + logmeaninc),stateginis)


p = @df stateginis scatter(:gini100,:logmeaninc,title="log(Mean income) vs gini",alpha=0.2)

p = @df stateginis annotate!(:gini100,:logmeaninc,:STUSAB,title="log(Mean income) vs gini",font(8))
display(p)




## Downloaded csv file from "https://www.who.int/data/gho/data/themes/mental-health/suicide-rates"
getifnotthere("data/who-suicide-data.csv","blob:null/25854b46-0aa5-4169-803f-54f897a51fb9") ## this doesn't actually work obviously, but it's the link on the above page where I got the data

whosuic = CSV.read("data/who-suicide-data.csv",DataFrame)


whosuicbs = @select(@subset(whosuic,:Dim1 .== "Both sexes"),:countrycode = :SpatialDimValueCode,:Year = :Period,:suicrate = :FactValueNumeric)


suicginidat = leftjoin(whosuicbs,ginistack; on = [:countrycode, :Year],makeunique=true)
suicginidat.logsuic = log.(suicginidat.suicrate)

p = @df suicginidat scatter(:ginicoef,log.(:suicrate); title = "global log(Suicide) vs gini")
display(p)

suimod = lm(@formula(logsuic ~ ginicoef),suicginidat)


suihomcomb = @select(leftjoin(alldat2,whosuicbs; on = [:Iso3_code => :countrycode,:Year]),:countrycode=:Iso3_code,:Year,:homiciderate = :homicide ./ :PopulationJan .* 100_000,:suicrate,:ginicoef)


suihomcomb.logshrate = log.(suihomcomb.suicrate .+ suihomcomb.homiciderate)

p = @df suihomcomb scatter(:ginicoef,log.(:homiciderate .+ :suicrate); title = "log(Suic+Hom) vs Gini",label="log(Suicide + Homicide)")

shmod2 = lm(@formula(logshrate ~ 1 + ginicoef + ginicoef^2),suihomcomb)



plot!(collect(20:60),predict(shmod2,DataFrame(ginicoef=collect(20:60))); linewidth=3,label="prediction")

display(p)

