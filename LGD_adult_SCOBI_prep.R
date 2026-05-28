library(DBI)
library(odbc)
library(dplyr)
library(lubridate)

# ---- Parameters ----
SY      <- 2024L   # Spawn year
species <- "STHD"  # Species code as stored in the database

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
# LGDTagsAll and PtagisFlags come directly from LGDTrapping (not a secondary join).
# Genetics fields (Gen*, releaseGroup) come from LGDGenetics via LEFT JOIN.
# Verify table names (LGDTrapping, LGDGenetics) and column names
# (SurveyYear, Species) against the actual schema before running.
sql <- "
SELECT
    t.MasterID,
    t.CollectionDate,
    t.LGDFLmm,
    t.LGDMarkAD,
    t.LGDMarkADComment,
    t.LGDMarksAll,
    t.LGDTagsAll,
    t.LGDFishComments,
    t.PtagisFlags,
    t.fwAge,
    t.swAge,
    t.totalAge,
    g.GenMa,
    g.GenPa,
    g.GenSex,
    g.GenStock,
    g.GenStockProb,
    g.GenComments,
    g.releaseGroup
FROM   LGDTrapping  t
LEFT JOIN LGDGenetics g
    ON  t.MasterID = g.MasterID
WHERE  t.SurveyYear = ?
  AND  t.Species    = ?
"

raw <- dbGetQuery(con, sql, params = list(SY, species))
cat("Rows returned from query:", nrow(raw), "\n")

# ---- Raw export ----
dir.create(dirname(raw_path), showWarnings = FALSE, recursive = TRUE)
write.csv(raw, raw_path, row.names = FALSE, na = "")
cat("Raw export written:", nrow(raw), "rows ->", raw_path, "\n")

# ---- Build SCOBI input file ----
scobi <- raw |>
  mutate(
    CollectionDate = as.Date(CollectionDate),
    week           = isoweek(CollectionDate),
    Length         = LGDFLmm,
    Adipose        = LGDMarkAD,
    GenPBT_RGroup  = releaseGroup
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
