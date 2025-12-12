# Script to investigate missing tag rates for SY2025 STHD
# This script helps identify why there are NA values in release groups

library(tidyverse)

# Load the data files (adjust paths as needed)
cat("Loading data files...\n")

# If you're reading from files:
# trap_scobi_check <- read.csv("SY2025STHD_trap_forSCOBI.csv")
# tags_scobi_check <- read.csv("SY2025STHD_tagRates_forSCOBI.csv")

# Or if you have the main trap file:
trap <- read.csv("SY2025STHD_trap.csv")

# STEP 1: Investigate NA release groups
cat("\n=== STEP 1: Investigating NA release groups ===\n")

# Count records with NA release groups
na_release_count <- trap %>%
  filter(is.na(releaseGroup)) %>%
  nrow()

cat("Total records with NA releaseGroup:", na_release_count, "\n")

# Break down NA release groups by rear type and mark status
cat("\nBreakdown of NA releaseGroup by Rear and LGDMarkAD:\n")
trap %>%
  filter(is.na(releaseGroup)) %>%
  count(Rear, LGDMarkAD) %>%
  print()

# STEP 2: Check PBT assignment status for fish with NA release groups
cat("\n=== STEP 2: PBT Assignment Status ===\n")

# Check if these fish have PBT data
cat("\nPBT assignments for fish with NA releaseGroup:\n")
trap %>%
  filter(is.na(releaseGroup)) %>%
  count(PBTBYHat, PBTRGroup) %>%
  arrange(desc(n)) %>%
  print(n = 20)

# STEP 3: Check GenStock assignments for wild fish with NA release groups
cat("\n=== STEP 3: GenStock for Wild Fish ===\n")

# For wild fish, they should have "Unassigned" as releaseGroup if they have a GenStock
wild_na_release <- trap %>%
  filter(is.na(releaseGroup), Rear == "W")

cat("Wild fish with NA releaseGroup:", nrow(wild_na_release), "\n")

if(nrow(wild_na_release) > 0) {
  cat("\nGenStock assignments for wild fish with NA releaseGroup:\n")
  wild_na_release %>%
    count(GenStock) %>%
    arrange(desc(n)) %>%
    print(n = 20)
}

# STEP 4: Check hatchery fish without PBT assignments
cat("\n=== STEP 4: Hatchery Fish Without Assignments ===\n")

hatchery_na_release <- trap %>%
  filter(is.na(releaseGroup), Rear %in% c("H", "HNC"))

cat("Hatchery fish with NA releaseGroup:", nrow(hatchery_na_release), "\n")

if(nrow(hatchery_na_release) > 0) {
  cat("\nSample of hatchery fish with NA releaseGroup:\n")
  hatchery_na_release %>%
    select(MasterID, LGDMarkAD, Rear, physTag, PBTBYHat, PBTRGroup, releaseGroup) %>%
    head(20) %>%
    print()
}

# STEP 5: Recommended fixes
cat("\n=== STEP 5: Recommended Fixes ===\n")

cat("\nBased on the EASE workflow, here's what should happen:\n")
cat("1. Wild fish (Rear = 'W') with GenStock assignment should have releaseGroup = 'Unassigned'\n")
cat("2. Wild fish without GenStock should have releaseGroup = NA\n")
cat("3. Hatchery fish (H/HNC) without PBT assignment should have releaseGroup = NA\n")
cat("4. For SCOBI checks, you should EXCLUDE NA values from the comparison\n")

# STEP 6: Corrected SCOBI check (excluding NAs)
cat("\n=== STEP 6: Corrected SCOBI Check ===\n")

# Create the corrected check
cat("\nProper SCOBI check (excluding NA release groups):\n")
cat("
# Corrected code:
trap_release_groups <- trap %>%
  filter(!is.na(releaseGroup), releaseGroup != 'Unassigned') %>%
  pull(releaseGroup) %>%
  unique()

# Compare with tag rates (assumes you have tagRates loaded)
# missing_tagrates <- setdiff(trap_release_groups, tagRates$group)
#
# if(length(missing_tagrates) > 0) {
#   cat('WARNING: These release groups in trap are missing from tagRates:\\n')
#   print(missing_tagrates)
# } else {
#   cat('✓ All trap release groups have corresponding tag rates\\n')
# }
")

# STEP 7: Summary statistics
cat("\n=== STEP 7: Summary Statistics ===\n")

summary_stats <- trap %>%
  summarise(
    total_fish = n(),
    has_releaseGroup = sum(!is.na(releaseGroup)),
    na_releaseGroup = sum(is.na(releaseGroup)),
    unassigned_releaseGroup = sum(releaseGroup == "Unassigned", na.rm = TRUE),
    assigned_to_hatchery = sum(!is.na(releaseGroup) & releaseGroup != "Unassigned", na.rm = TRUE)
  )

print(summary_stats)

cat("\nRelease group breakdown:\n")
trap %>%
  mutate(releaseGroup_status = case_when(
    is.na(releaseGroup) ~ "NA",
    releaseGroup == "Unassigned" ~ "Unassigned (Wild)",
    TRUE ~ "Assigned (Hatchery)"
  )) %>%
  count(releaseGroup_status, Rear) %>%
  arrange(Rear, releaseGroup_status) %>%
  print()

cat("\n=== Analysis Complete ===\n")
cat("\nNext steps:\n")
cat("1. Review the output above to understand why fish have NA release groups\n")
cat("2. For SCOBI checks, exclude NA and 'Unassigned' values\n")
cat("3. If wild fish should have 'Unassigned' but have NA, you may need to fix the data\n")
