# download the entire PUMS microdata dataset, year by year from 2000 to 2020

using Downloads

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
