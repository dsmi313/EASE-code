library(DBI)
library(odbc)
library(dplyr)
library(lubridate)

# ---- Parameters ----
SY      <- 2024L  # SpawnYear value in vwLGDMasterCombine
species <- "S"    # LGDSpecies code — confirm with:
                  # dbGetQuery(con, "SELECT DISTINCT LGDSpecies FROM dbo.vwLGDMasterCombine WHERE LGDSpecies IS NOT NULL")

# ---- Output paths ----
raw_path   <- "C:/SCOBI/InputFilePrep/LGD_adult_raw.csv"
final_path <- "C:/SCOBI/InputFilePrep/LGD_adult_SCOBI_input.csv"

# ---- Connect ----
con <- dbConnect(
  odbc::odbc(),
  Driver             = "SQL Server",
  Server             = "idfgnrsql2",
  Database           = "LGDTrapping",
  Trusted_Connection = "Yes"
)
on.exit(dbDisconnect(con), add = TRUE)

# ---- Query ----
# Single source: vwLGDMasterCombine already joins genetics, marks, tags, and
# PTAGIS fields — no secondary join needed.
# LGDTagsAll and PtagisFlags come directly from this view.
# BioScaleFinalAge (e.g. "1.2") is parsed into fwAge / swAge / totalAge in R.
sql <- "
SELECT
    MasterID,
    CollectionDate,
    LGDFLmm,
    LGDMarkAD,
    LGDMarkADComment,
    LGDMarksAll,
    LGDTagsAll,
    LGDFishComments,
    PtagisFlags,
    BioScaleFinalAge,
    GenMa,
    GenPa,
    GenSex,
    GenStock,
    GenStockProb,
    GenComments,
    GenPBT_RGroup
FROM   dbo.vwLGDMasterCombine
WHERE  SpawnYear  = ?
  AND  LGDSpecies = ?
"

raw <- dbGetQuery(con, sql, params = list(SY, species))
cat("Rows returned from query:", nrow(raw), "\n")

# ---- Raw export ----
dir.create(dirname(raw_path), showWarnings = FALSE, recursive = TRUE)
write.csv(raw, raw_path, row.names = FALSE, na = "")
cat("Raw export written:", nrow(raw), "rows ->", raw_path, "\n")

# ---- Build SCOBI input file ----
# BioScaleFinalAge format "fw.sw" (e.g. "1.2" → fwAge=1, swAge=2, totalAge=3)
scobi <- raw |>
  mutate(
    CollectionDate = as.Date(CollectionDate),
    week           = isoweek(CollectionDate),
    Length         = LGDFLmm,
    Adipose        = LGDMarkAD,
    fwAge          = suppressWarnings(as.integer(sub("\\..*", "", BioScaleFinalAge))),
    swAge          = suppressWarnings(as.integer(sub(".*\\.",  "", BioScaleFinalAge))),
    totalAge       = fwAge + swAge
  ) |>
  select(
    MasterID,
    CollectionDate,
    week,
    Length,
    Adipose,
    GenMa,
    GenPa,
    GenSex,
    GenStock,
    GenStockProb,
    LGDFishComments,
    GenComments,
    LGDMarksAll,
    LGDTagsAll,
    LGDMarkADComment,
    PtagisFlags,
    fwAge,
    swAge,
    totalAge,
    GenPBT_RGroup
  )

dir.create(dirname(final_path), showWarnings = FALSE, recursive = TRUE)
write.csv(scobi, final_path, row.names = FALSE, na = "")
cat("SCOBI input file written:", nrow(scobi), "rows ->", final_path, "\n")
