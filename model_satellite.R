## Run analysis, write model results

library(icesTAF)
library(sf)
library(data.table)
library(terra)
library(exactextractr)

data_path <- file.path("data")
model_path <- file.path("model")
path_data_processed_monthly_means <- file.path(model_path, "satellite_processed_monthly_means.csv")

data_files <- list.files(data_path, pattern = "satellite_.*\\.nc", full.names = TRUE)

# Read units shape file
units <- st_read(file.path("data", "units.shp"))

# Read NetCDF files as SpatRasters and calculate mean per unit
results_list <- lapply(data_files, function(data_file) {
  r <- rast(data_file)
  
  # Extract mean values for each assessment unit
  exact_extracted <- exact_extract(r, units, c("mean", 'stdev', 'count'), append_cols = "Id", progress = TRUE)

  # Get months numbers from raster time metadata
  month_numbers <- month(time(r))

  # Rename columns using the month metadata
  new_colnames <- c("Id", paste(rep(c("mean", "stdev", "count"), each = length(month_numbers)), rep(month_numbers, 3), sep = "_"))
  
  names(exact_extracted) <- new_colnames
  
  # Pivot to "long" format
  exact_extracted_long <- exact_extracted %>%
    pivot_longer(cols = -Id, 
                 names_to = c(".value", "month"), 
                 names_sep = "_")
  
  # Add year column based on the month numbers and raster time metadata
  year_numbers <- year(time(r))
  exact_extracted_long <- exact_extracted_long %>%
    mutate(month = as.numeric(month), year = year_numbers[match(month, month_numbers)])
  
  # Rename columns and reorder into data table
  exact_extracted_long <- as.data.table(exact_extracted_long) %>%
    .[, .(IndicatorId = 302, UnitId = Id, Year = year, Month = month, ES = mean, SD = stdev, N = count)]
})

result <- rbindlist(results_list)

# Output annual monthly means --> UnitID, Year, Month, ES, SD, N, ND
fwrite(result, path_data_processed_monthly_means)

