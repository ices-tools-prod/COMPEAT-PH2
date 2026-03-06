library(sf)
library(data.table)
library(dplyr)
library(terra)
library(exactextractr)
library(ncdf4)

# Define assessment period
assessment_period <- "1877-9999"

# Define paths
input_path <- file.path("Input", assessment_period)
output_path <- file.path("Output", assessment_period)

# Create paths
dir.create(input_path, showWarnings = FALSE, recursive = TRUE)
dir.create(output_path, showWarnings = FALSE, recursive = TRUE)

# Assessment units -------------------------------------------------------------

# Read assessment units from WKT
units <- st_read(paste0("/vsizip/", "/vsicurl/", "https://icesoceanography.blob.core.windows.net/compeat/AssessmentUnits.zip")) %>%
  st_set_crs(4326)

# Remove unnecessary dimensions and convert data.frame to data.table
units <- as.data.table(st_zm(units)) 

# Order, Rename and Remove columns 
units <- units[order(ID), .(Code = ID, Description = LongName, Wkt = geometry)] %>%
  st_sf()

# Assign Ids
units$Id = 1:nrow(units)

# Rearrange columns
units <- units[, c("Id", "Code", "Description", "Wkt")]

# Get boundary box
bbox <- st_bbox(units)

# In-situ data -----------------------------------------------------------------
#
# Data can be downloaded from ICES data portal at https://data.ices.dk
# selecting the following options:
# the ocean hydrochemstry theme
# the Bottle and low resolution CTD dataset
# the temporal coverage to the period 1877 to 9999
# the spatial coverage to the OSPAR sub regions   

# Read station samples
station_samples <- fread(input = "https://icesoceanography.blob.core.windows.net/compeat/comp5/StationSamples1877-9999BOT_2026-02-17.csv.gz", na.strings = "NULL", stringsAsFactors = FALSE, header = TRUE, check.names = TRUE)

# Filter station samples for chlorophyll a only
#station_samples <- station_samples[!is.na(Chlorophyll.a..CPHLZZXX_UGPL...ug.l.), .(Cruise, Station, Type, yyyy.mm.ddThh.mm.ss.sss, Longitude..degrees_east., Latitude..degrees_north., Chlorophyll.a..CPHLZZXX_UGPL...ug.l. , QV.ODV.Chlorophyll.a..CPHLZZXX_UGPL...ug.l.)]

# Unique stations by natural key
uniqueN(station_samples, by = c("Cruise", "Station", "Type", "yyyy.mm.ddThh.mm.ss.sss", "Longitude..degrees_east.", "Latitude..degrees_north."))

# Assign station ID by natural key
station_samples[, StationId := .GRP, by = .(Cruise, Station, Type, yyyy.mm.ddThh.mm.ss.sss, Longitude..degrees_east., Latitude..degrees_north.)]

# Classify station samples into units ------------------------------------------

# Extract unique stations i.e. longitude/latitude pairs
stations <- unique(station_samples[, .( Longitude..degrees_east., Latitude..degrees_north.)])

# Make stations spatial keeping original latitude/longitude
stations <- st_as_sf(stations, coords = c("Longitude..degrees_east.", "Latitude..degrees_north."), remove = FALSE, crs = 4326)

# Classify stations into units
stations <- st_join(stations, st_cast(units), join = st_intersects)

# Delete stations not classified
stations <- na.omit(stations)

# Remove spatial column and make into data table
stations <- st_set_geometry(stations, NULL) %>% as.data.table()

# Merge stations back into station samples - getting rid of station samples not classified into assessment units
station_samples <- stations[station_samples, on = .(Longitude..degrees_east., Latitude..degrees_north.), nomatch = 0]

# Output station samples mapped to assessment units for contracting parties to check i.e. acceptance level 1
fwrite(station_samples, file.path(output_path, "StationSamples.csv"))

# Calculate monthly means-------------------------------------------------------

# Filter stations rows and columns --> UnitID, Year, Month, Day, StationID, Depth, Chlorophyll
wk <- station_samples[!is.na(Chlorophyll.a..CPHLZZXX_UGPL...ug.l.) & QV.ODV.Chlorophyll.a..CPHLZZXX_UGPL...ug.l. <= 1 & Depth..ADEPZZ01_ULAA...m. <= 10, .(IndicatorId = 301, UnitId = Id, Year = as.integer(substr(yyyy.mm.ddThh.mm.ss.sss, 1, 4)), Month = as.integer(substr(yyyy.mm.ddThh.mm.ss.sss, 6, 7)), Day = as.integer(substr(yyyy.mm.ddThh.mm.ss.sss, 9, 10)), StationId, Depth = Depth..ADEPZZ01_ULAA...m. ,ES = Chlorophyll.a..CPHLZZXX_UGPL...ug.l.)]

# Calculate station depth mean --> UnitID, Year, Month, Day, StationId, Depth, ES, SD, N
wk0 <- wk[, .(ES = mean(ES), SD = sd(ES), N = .N), keyby = .(IndicatorId, UnitId, Year, Month, Day, StationId, Depth)]

# Calculate station mean --> UnitID, Year, Month, Day, StationId, ES, SD, N
wk1 <- wk0[, .(ES = mean(ES), SD = sd(ES), N = .N), keyby = .(IndicatorId, UnitId, Year, Month, Day, StationId)]

# Calculate annual monthly mean --> UnitID, Year, Month, ES, SD, N, ND
wk2 <- wk1[, .(ES = mean(ES), SD = sd(ES), N = .N, ND = uniqueN(Day)), keyby = .(IndicatorId, UnitId, Year, Month)]

# Calculate annual mean --> UnitID, Year, ES, SD, N, NM
wk3 <- wk1[, .(ES = mean(ES), SD = sd(ES), N = .N, NM = uniqueN(Month)), keyby = .(IndicatorId, UnitId, Year)]

# Download satellite data-------------------------------------------------------



# Calculate monthly means ------------------------------------------------------

nc_file <- "C:/Users/Hjalte/Downloads/CopernicusMarine/New/cmems_obs-oc_atl_bgc-plankton_my_l3-multi-1km_P1D_CHL_16.07W-12.67E_34.88N-63.88N_2020-01-01-2020-12-31.nc"
nc_file <- "C:/Users/Hjalte/Downloads/CopernicusMarine/New/cmems_obs-oc_atl_bgc-plankton_my_l3-multi-1km_P1D_CHL_16.07W-12.67E_34.88N-63.88N_2025-01-01-2025-12-31.nc"

nc_file <- "C:/Users/Hjalte/Downloads/CopernicusMarine/New/cmems_obs-oc_atl_bgc-plankton_my_l4-gapfree-multi-1km_P1D_CHL_16.07W-12.67E_34.88N-63.88N_2025-01-01-2025-12-31.nc"

nc_file <- "C:/Users/Hjalte/Downloads/CopernicusMarine/New/cmems_obs-oc_atl_bgc-plankton_my_l4-multi-1km_P1M_CHL_16.07W-12.67E_34.88N-63.88N_2025-01-01-2025-12-01.nc"

# Read NetCDF as SpatRaster
r <- rast(nc_file)

# Check CRS
st_crs(units)
crs(r)

# Ensure CRS matches between raster and shapefile
if (st_crs(units) != crs(r)) {
  units <- st_transform(units, crs(r))
}

# Extract mean values for each assessment unit
exact_extracted0 <- exact_extract(r, units, "mean")

exact_extracted1 <- exact_extract(r, units, c("mean", 'stdev', 'count'))

exact_extracted2 <- exact_extract(r, units, 
                       fun = function(values, coverage_fraction) {
                         # Remove NA values
                         values <- values[!is.na(values)]
                         if (length(values) == 0) {
                           return(data.frame(mean = NA, sd = NA, n = 0))
                         }
                         data.frame(
                           mean = mean(values),
                           sd   = sd(values),
                           n    = length(values)
                         )
                       },
                       progress = TRUE)




extracted <- extract(r, vect(units), fun = "mean", na.rm = TRUE)
extracted_dt <- rbindlist(lapply(extracted, as.data.table), idcol = "Id")

write.csv(extracted, "C:/Users/Hjalte/Downloads/CopernicusMarine/New/COMPEAT_P1M_CHL_MeanValues_2020.csv", row.names = FALSE)

df <- as.data.frame(r, xy = TRUE)



# ------------------------------------------------------------------------------
# Average per unit
# Average of daily averages per unit


# ------------------------------------------------------------------------------

# nc_file <- "C:/Users/Hjalte/Downloads/CopernicusMarine/New/cmems_obs-oc_atl_bgc-plankton_my_l3-multi-1km_P1D_CHL_16.07W-12.67E_34.88N-63.88N_2025-01-01-2025-12-31.nc"
# 
# nc_data <- nc_open(nc_file)
# 
# lon <- ncvar_get(nc_data, "longitude")
# lat <- ncvar_get(nc_data, "latitude")
# time <- ncvar_get(nc_data, "time")
# 
# chl <- ncvar_get(nc_data, "CHL")
# 
# nc_close(nc_data)
# 
# time_origin <- as.Date("1900-01-01")
# dates <- time_origin + time
# 
# chl_dt <- data.table(Date = rep(dates, each = length(lon) * length
# (lat)),
#                      Lon = rep(lon, times = length(lat) * length(dates)),
#                      Lat = rep(lat, each = length(lon), times = length(dates)),
#                      CHL = as.vector(chl))
# 
# chl_dt <- na.omit(chl_dt)
# 
# head(chl_dt)

# Test
#
# 0 - Mean of all grid cells values within each unit per year

# 1 - Temporal mean of grid cell values per year and then spatial mean of grid cell values per unit

# 2 - Terra approach.

