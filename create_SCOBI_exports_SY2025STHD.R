# Create SCOBI Export Files for SY2025 STHD
# This script creates the properly formatted files for SCOBI checks

library(tidyverse)

cat("=== Creating SCOBI Export Files for SY2025 STHD ===\n\n")

# Set parameters
sy <- 2025
spp <- "STHD"

# Load data files
cat("Loading data files...\n")
trap <- read.csv(paste0("SY", sy, spp, "_trap.csv"))
tagRates <- read.csv(paste0("SY", sy, spp, "_tagRates.csv"))

# Standardize column names in tagRates
if(!"group" %in% names(tagRates)) {
  names(tagRates)[1] <- "group"
}
if(!"tagRate" %in% names(tagRates)) {
  names(tagRates)[2] <- "tagRate"
}

cat("Loaded", nrow(trap), "trap records\n")
cat("Loaded", nrow(tagRates), "tag rate records\n\n")

# ==============================================================================
# PART 1: Create trap data for SCOBI check
# ==============================================================================

cat("--- Creating trap data for SCOBI ---\n")

# Select relevant columns for SCOBI check
# Include the column name that SCOBI expects for release groups
trap_for_scobi <- trap %>%
  mutate(
    # Create SCOBI-friendly column name
    GenPBT_ByHatGenPBT_RGroup = releaseGroup
  ) %>%
  select(
    MasterID,
    CollectionDate,
    sWeek,
    LGDMarkAD,
    Rear,
    physTag,
    PBTBYHat,
    PBTRGroup,
    GenPBT_ByHatGenPBT_RGroup,  # This is what SCOBI checks against
    releaseGroup,
    GenStock,
    MPG,
    Age,
    GenSex,
    LGDFLmm
  )

# Save trap data for SCOBI
trap_file <- paste0("SY", sy, spp, "_trap_forSCOBI.csv")
write.csv(trap_for_scobi, trap_file, row.names = FALSE)
cat("✅ Created:", trap_file, "\n")
cat("   Records:", nrow(trap_for_scobi), "\n")

# Show summary of release groups in trap data
cat("\n   Release group summary:\n")
release_summary <- trap_for_scobi %>%
  mutate(status = case_when(
    is.na(GenPBT_ByHatGenPBT_RGroup) ~ "NA (No assignment)",
    GenPBT_ByHatGenPBT_RGroup == "Unassigned" ~ "Unassigned",
    TRUE ~ "Hatchery group"
  )) %>%
  count(status)
print(release_summary)

# ==============================================================================
# PART 2: Create tag rates for SCOBI check
# ==============================================================================

cat("\n--- Creating tag rates for SCOBI ---\n")

# Create SCOBI-friendly tag rates file
tagRates_for_scobi <- tagRates %>%
  rename(
    PBT_RELEASE_GROUP = group,
    TAG_RATE = tagRate
  ) %>%
  select(PBT_RELEASE_GROUP, TAG_RATE)

# Save tag rates for SCOBI
tagrates_file <- paste0("SY", sy, spp, "_tagRates_forSCOBI.csv")
write.csv(tagRates_for_scobi, tagrates_file, row.names = FALSE)
cat("✅ Created:", tagrates_file, "\n")
cat("   Records:", nrow(tagRates_for_scobi), "\n")

# ==============================================================================
# PART 3: Run SCOBI check on exported files
# ==============================================================================

cat("\n--- Running SCOBI Check ---\n")

# Reload the files we just created (to verify they work)
trap_scobi_check <- read.csv(trap_file)
tags_scobi_check <- read.csv(tagrates_file)

# Get unique release groups from trap data, EXCLUDING NA values
trap_groups <- trap_scobi_check %>%
  filter(!is.na(GenPBT_ByHatGenPBT_RGroup),
         GenPBT_ByHatGenPBT_RGroup != "Unassigned") %>%
  pull(GenPBT_ByHatGenPBT_RGroup) %>%
  unique()

# Compare with tag rates
missing_tagrates_scobi <- setdiff(trap_groups, tags_scobi_check$PBT_RELEASE_GROUP)

if(length(missing_tagrates_scobi) > 0) {
  cat("⚠️  WARNING: These release groups in trap are missing from tagRates:\n")
  print(missing_tagrates_scobi)

  # Show affected fish
  cat("\nFish affected by missing tag rates:\n")
  affected <- trap_scobi_check %>%
    filter(GenPBT_ByHatGenPBT_RGroup %in% missing_tagrates_scobi) %>%
    count(GenPBT_ByHatGenPBT_RGroup, Rear) %>%
    arrange(desc(n))
  print(affected)

} else {
  cat("✅ All trap release groups have corresponding tag rates\n")
}

# ==============================================================================
# PART 4: Create summary report
# ==============================================================================

cat("\n--- Summary Report ---\n")

summary_report <- list(
  trap_file = trap_file,
  tagrates_file = tagrates_file,
  total_trap_records = nrow(trap_scobi_check),
  total_tag_rates = nrow(tags_scobi_check),
  unique_hatchery_groups_in_trap = length(trap_groups),
  missing_tag_rates = length(missing_tagrates_scobi),
  na_release_groups = sum(is.na(trap_scobi_check$GenPBT_ByHatGenPBT_RGroup)),
  unassigned_groups = sum(trap_scobi_check$GenPBT_ByHatGenPBT_RGroup == "Unassigned", na.rm = TRUE)
)

cat("\nFiles created:\n")
cat("  1. ", summary_report$trap_file, "\n")
cat("  2. ", summary_report$tagrates_file, "\n\n")

cat("Summary statistics:\n")
cat("  Total trap records:", summary_report$total_trap_records, "\n")
cat("  Total tag rates:", summary_report$total_tag_rates, "\n")
cat("  Unique hatchery groups in trap:", summary_report$unique_hatchery_groups_in_trap, "\n")
cat("  Missing tag rates:", summary_report$missing_tag_rates, "\n")
cat("  Records with NA release groups:", summary_report$na_release_groups, "(expected)\n")
cat("  Records with 'Unassigned' groups:", summary_report$unassigned_groups, "(expected)\n")

if(summary_report$missing_tag_rates == 0) {
  cat("\n✅ SUCCESS! Files are ready for SCOBI\n")
} else {
  cat("\n⚠️  WARNING! You need to add tag rates for missing groups before using with SCOBI\n")
}

cat("\n=== SCOBI Export Complete ===\n")
cat("\nNext steps:\n")
cat("1. Review the files created above\n")
cat("2. If there are missing tag rates, contact the PBT lab\n")
cat("3. Use these files for SCOBI validation\n")
