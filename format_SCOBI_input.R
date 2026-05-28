library(dplyr)
library(lubridate)

# ---- Paths ----
in_path  <- "C:/path/to/SY2025STHD_trap.csv"
out_path <- "C:/SCOBI/InputFilePrep/SY2025STHD_SCOBI_input.csv"

# ---- Read ----
trap <- read.csv(in_path, stringsAsFactors = FALSE, na.strings = c("", "NA"))
cat("Rows read:", nrow(trap), "\n")

# ---- Format ----
scobi <- trap |>
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

# ---- Export ----
dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
write.csv(scobi, out_path, row.names = FALSE, na = "")
cat("SCOBI input written:", nrow(scobi), "rows ->", out_path, "\n")
