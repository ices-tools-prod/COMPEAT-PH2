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

executable_path <- file.path("copernicusmarine.exe")
data_path <- file.path("data")
dataset <- "cmems_obs-oc_atl_bgc-plankton_my_l4-multi-1km_P1M"
year_start <- 1997
year_end <- 2026

# Check if executable exists, otherwise download
if (!file.exists(executable_path)) {
  download.file("https://github.com/mercator-ocean/copernicus-marine-toolbox/releases/download/v2.3.0/copernicusmarine.exe", executable_path, mode = "wb")
}

# If any of the data files exist, then skip this step, otherwise download data for all years
data_files <- list.files(data_path, pattern = "satellite_.*\\.nc", full.names = TRUE)
if (length(data_files) > 0) {
  message("Data files already exist. Skipping download.")
} else {
  for (year in seq(year_start, year_end)) {
    command <- paste(executable_path, "subset",
                     "--dataset-id ", dataset,
                     "--variable CHL",
                     "--start-datetime", paste0(year, "-01-01"),
                     "--end-datetime", paste0(year, "-12-31"),
                     "--minimum-longitude -16.07389",
                     "--maximum-longitude 12.67383",                   
                     "--minimum-latitude 34.87719",
                     "--maximum-latitude 63.88748",
                     "--disable-progress-bar",
                     "--output-directory", data_path,
                     "--output-filename", paste0("satellite_", year, ".nc"))
    system(command)
  }
}