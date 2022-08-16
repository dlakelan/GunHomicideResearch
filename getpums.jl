# download the entire PUMS microdata dataset, year by year from 2000 to 2020

using Downloads

let f = ""

for i in 2000:2020
    f = "data/pums/$i/csv_hus.zip"
    if !isfile(f)
        download("https://www2.census.gov/programs-surveys/acs/data/pums/$i/csv_hus.zip",f)
    end
    f = "data/pums/$i/csv_pus.zip"
    if !isfile(f)
        download("https://www2.census.gov/programs-surveys/acs/data/pums/$i/csv_pus.zip",f)
    end
end

