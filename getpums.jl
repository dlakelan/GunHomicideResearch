# download the entire PUMS microdata dataset, year by year from 2000 to 2020

using Downloads,Printf,DataFramesMeta,DataFrames,CSV,StatsPlots,Distributed

censproc = addprocs(["census.lan"]; dir = "/var/local/dlakelan/GunHomicideResearch/", exename="/home/dlakelan/julia/bin/julia")



function geturlh(yr)
    if yr < 2007
        return "https://www2.census.gov/programs-surveys/acs/data/pums/$yr/csv_hus.zip"
    else
        return "https://www2.census.gov/programs-surveys/acs/data/pums/$yr/1-Year/csv_hus.zip"
    end
end
function geturlp(yr)
    if yr < 2007
        return "https://www2.census.gov/programs-surveys/acs/data/pums/$yr/csv_pus.zip"
    else
        return "https://www2.census.gov/programs-surveys/acs/data/pums/$yr/1-Year/csv_pus.zip"
    end
end


getpums = false

if getpums

    @spawnat censproc begin
        let f = "", maindir = pwd()
            for i in 2000:2019
                mkpath("data/pums/$i"; mode = 0o750)
                f = "data/pums/$i/csv_hus.zip"
                if !isfile(f)
                    Downloads.download(geturlh(i),f)
                end
                cd(dirname(f))
                run(`unzip -o $(basename(f))`)
                cd(maindir)

                f = "data/pums/$i/csv_pus.zip"
                if !isfile(f)
                    Downloads.download(geturlp(i),f)
                end
                cd(dirname(f))
                run(`unzip -o $(basename(f))`)
                cd(maindir)
            end
        end
    end
end

## now also download the IRS tax stats:

if !isdir("data/irs")
    mkdir("data/irs")
end
wd = pwd()
try
    cd("data/irs")
    for i in 2001:2019
        yr2 = mod(i,100)
        yr2str = @sprintf("%02d",yr2)
        if !isfile("$(yr2)in12ms.xls")
            Downloads.download("https://www.irs.gov/pub/irs-soi/$(yr2str)in12ms.xls", "$(yr2str)in12ms.xls")
        end
        run(Cmd(`ssconvert $(yr2str)in12ms.xls $(yr2str)in12ms.csv`))
    end
finally 
    cd(wd)
end


tst = let tst = DataFrame();
    for yr in 2001:2019
        headers = ["AdjGrossGroup","Nreturns","AdjGrossLessDef","ExempAmt","NitemizedRets","TotItemDed","NItemizedRets","TotItemAmount",
            "NStdDedRets","StdDedAmt","NTaxableRets","TaxableAmt","NIncTax","IncTaxAmt","MiscExtra","MiscExtra2"]
        if yr >= 2018
            headers = ["AdjGrossGroup","Nreturns","AdjGrossLessDef","NitemizedRets","TotItemAmount",
            "NStdDedRets","StdDedAmt","NTaxableRets","TaxableAmt","NIncTax","IncTaxAmt","MiscExtra","MiscExtra2"]
        end
        new = CSV.read(@sprintf("data/irs/%02din12ms.csv",mod(yr,100)),DataFrame; skipto=11,
            header=headers,limit=18)
        @select!(new,:AdjGrossGroup,:Nreturns,:AdjGrossLessDef,:NTaxableRets,:TaxableAmt,:NIncTax,:IncTaxAmt,:SMP)

        new.Year = [yr for i in 1:nrow(new)]
        @show new
        if ncol(tst) == 0 
            tst = new
        else
            tst = [tst; new]
        end
    end
    tst
end

oasdipct = .0765

@df @subset(tst,in.(:Year,  Ref([2001,2005,2010,2015,2019]))) plot(:AdjGrossLessDef ./ :Nreturns,:IncTaxAmt ./:AdjGrossLessDef .+ oasdipct; xlim=(0.0,500),ylim=(0.0,.4),group=:Year,
    title="Effective Tax Rate vs Adj Gross",xlab="Adj Gross Income (thousands \$)",ylab="Tax Rate",legend=:topright,size=(800,800))

incs = collect(5.0:5.0:500)
plot!(incs,1.0 .- (incs*(1-.35).+12)./incs ,label="35% flat + 12k UBI (1 person)")
plot!(incs,1.0 .- (incs*(1-.35).+24)./incs,label="35% flat + 24k UBI (2 people)")
plot!(incs,1.0 .- (incs*(1-.35).+48)./incs,label="35% flat + 48k UBI (4 people)")

@df @subset(tst,in.(:Year,  Ref([2001,2005,2010,2015,2019]))) plot(:AdjGrossLessDef ./ :Nreturns,:IncTaxAmt ./:AdjGrossLessDef; xlim=(0.0,150),ylim=(0.0,.4),group=:Year,
    title="Effective Tax Rate vs Adj Gross",xlab="Adj Gross Income (thousands \$)",ylab="Tax Rate",legend=:topright)

