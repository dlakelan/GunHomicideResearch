# download the entire PUMS microdata dataset, year by year from 2000 to 2020

using Downloads

function geturlh(yr)
    if yr < 2007
        return "https://www2.census.gov/programs-surveys/acs/data/pums/$i/csv_hus.zip"
    else
        return "https://www2.census.gov/programs-surveys/acs/data/pums/$i/1-year/csv_hus.zip"
    end
end
function geturlp(yr)
    if yr < 2007
        return "https://www2.census.gov/programs-surveys/acs/data/pums/$i/csv_pus.zip"
    else
        return "https://www2.census.gov/programs-surveys/acs/data/pums/$i/1-year/csv_pus.zip"
    end
end


let f = ""
    for i in 2000:2020
        mkpath("data/pums/$i"; mode = 0o750)
        f = "data/pums/$i/csv_hus.zip"
        if !isfile(f)
            Downloads.download(geturlh(i),f)
        end
        f = "data/pums/$i/csv_pus.zip"
        if !isfile(f)
            Downloads.download(geturlp(i),f)
        end
    end

end
