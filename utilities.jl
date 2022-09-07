
using Downloads

function getifnotthere(filename,URL)
    if !Base.Filesystem.ispath(filename)
        # see https://www.aic.gov.au/statistics/homicide
        Downloads.download(URL,filename)
    end
end

