## Run analysis, write model results

library(icesTAF)

path_data_processed <- file.path("data", "in-situ_processed.csv")
path_data_processed_monthly_means <- file.path("model", "in-situ_processed_monthly_means.csv")

# Read preprocessed station samples data
station_samples <- fread(path_data_processed)

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

# Output annual monthly means --> UnitID, Year, Month, ES, SD, N, ND
fwrite(wk2, path_data_processed_monthly_means)
