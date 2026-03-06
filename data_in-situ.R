## Download and Preprocess in-situ data

# To do
# - Add option to download from ICES data portal at https://data.ices.dk
#   Station samples in-situ data can also be downloaded directly from ICES data portal at https://data.ices.dk selecting the following options:
#   Theme: Ocean hydrochemstry
#   Dataset: Bottle and low resolution CTD data
#   Temporal coverage: 1877 to 9999
#   Spatial coverage: OSPAR sub regions


library(icesTAF)
library(sf)
library(data.table)

url <- "https://icesoceanography.blob.core.windows.net/compeat/comp5/StationSamples1877-9999BOT_2026-03-04.csv.gz"

path_data_downloaded  <- file.path("data", "in-situ_downloaded.csv.gz")
path_data_processed <- file.path("data", "in-situ_processed.csv")

# Skip this step, if processed data already exists
if (!file.exists(path_data_processed)) {
  # Skip this step, if downloaded data already exists
  if (!file.exists(path_data_downloaded)) {
    download.file(url, path_data_downloaded, mode = "wb")
  }

  station_samples <- fread(input = path_data_downloaded, na.strings = "NULL", stringsAsFactors = FALSE, header = TRUE, check.names = TRUE)

  # Filter station samples for chlorophyll a only
  #station_samples <- station_samples[!is.na(Chlorophyll.a..CPHLZZXX_UGPL...ug.l.), .(Cruise, Station, Type, yyyy.mm.ddThh.mm.ss.sss, Longitude..degrees_east., Latitude..degrees_north., Chlorophyll.a..CPHLZZXX_UGPL...ug.l. , QV.ODV.Chlorophyll.a..CPHLZZXX_UGPL...ug.l.)]
  
  # Unique stations by natural key
  uniqueN(station_samples, by = c("Cruise", "Station", "Type", "yyyy.mm.ddThh.mm.ss.sss", "Longitude..degrees_east.", "Latitude..degrees_north."))
  
  # Assign station ID by natural key
  station_samples[, StationId := .GRP, by = .(Cruise, Station, Type, yyyy.mm.ddThh.mm.ss.sss, Longitude..degrees_east., Latitude..degrees_north.)]
  
  # Classify station samples into units ----------------------------------------
  
  # Extract unique stations i.e. longitude/latitude pairs
  stations <- unique(station_samples[, .( Longitude..degrees_east., Latitude..degrees_north.)])
  
  # Make stations spatial keeping original latitude/longitude
  stations <- st_as_sf(stations, coords = c("Longitude..degrees_east.", "Latitude..degrees_north."), remove = FALSE, crs = 4326)
  
  # Read units shape file
  units <- st_read(file.path("data", "units.shp"))
  
  # Classify stations into units
  stations <- st_join(stations, st_cast(units), join = st_intersects)
  
  # Delete stations not classified
  stations <- na.omit(stations)
  
  # Remove spatial column and make into data table
  stations <- st_set_geometry(stations, NULL) %>% as.data.table()
  
  # Merge stations back into station samples - getting rid of station samples not classified into assessment units
  station_samples <- stations[station_samples, on = .(Longitude..degrees_east., Latitude..degrees_north.), nomatch = 0]
  
  # Output station samples mapped to assessment units
  fwrite(station_samples, path_data_processed)
}
