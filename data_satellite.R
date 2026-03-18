## Download and Preprocess satellite data

# To note
# - The first time you run this code, copernicusmarine.exe will be downloaded.
#   You need to manually run "copernicusmarine.exe login" in the command line
#   to login with your Copernicus Marine account to be able to download the data.
#
# - https://data.marine.copernicus.eu/product/OCEANCOLOUR_ATL_BGC_L4_MY_009_118/services
#   cmems_obs-oc_atl_bgc-plankton_my_l4-multi-1km_P1M
#   cmems_obs-oc_atl_bgc-plankton_my_l4-gapfree-multi-1km_P1D
#
# - https://data.marine.copernicus.eu/product/OCEANCOLOUR_ATL_BGC_L3_MY_009_113/services
#   cmems_obs-oc_atl_bgc-plankton_my_l3-multi-1km_P1D

library(icesTAF)
library(sf)

executable_path <- file.path("copernicusmarine.exe")
data_path <- file.path("data")
dataset <- "cmems_obs-oc_atl_bgc-plankton_my_l4-multi-1km_P1M"
year_start <- 1997
year_end <- 2026

# Check if executable exists, otherwise download
if (!file.exists(executable_path)) {
  download.file("https://github.com/mercator-ocean/copernicus-marine-toolbox/releases/download/v2.3.0/copernicusmarine.exe", executable_path, mode = "wb")
}

# Read units shape file
units <- st_read(file.path("data", "units.shp"))

# Get bounding box of units to subset satellite data
bbox <- st_bbox(units)

# If the data files for years in sequence exist, then skip this step, otherwise download data for all missing years
year_strings <- year_start:year_end
data_files <- list.files(data_path, pattern = "satellite_.*\\.nc", full.names = TRUE)
years_present <- year_strings[sapply(year_strings, function(y) any(grepl(y, data_files)))]
years_missing <- setdiff(year_strings, years_present)

if (length(years_missing) == 0) {
  message("Data files already exist. Skipping download.")
} else {
  for (year in sort(years_missing)) {
    command <- paste(executable_path, "subset",
                     "--dataset-id ", dataset,
                     "--variable CHL",
                     "--start-datetime ", paste0(year, "-01-01"),
                     "--end-datetime ", paste0(year, "-12-31"),
                     "--minimum-longitude ", bbox["xmin"],
                     "--maximum-longitude ", bbox["xmax"],                   
                     "--minimum-latitude ", bbox["ymin"],
                     "--maximum-latitude ", bbox["ymax"],
                     "--disable-progress-bar",
                     "--output-directory ", data_path,
                     "--output-filename" , paste0("satellite_", year, ".nc"))
    system(command)
  }
}