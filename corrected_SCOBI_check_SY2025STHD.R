# Corrected SCOBI Check for SY2025 STHD
# This script properly checks for missing tag rates while handling NA values

library(tidyverse)

cat("=== SCOBI Tag Rate Check for SY2025 STHD ===\n\n")

# Load data
cat("Loading data files...\n")

# Option 1: If you have the forSCOBI files
# trap_scobi_check <- read.csv("SY2025STHD_trap_forSCOBI.csv")
# tags_scobi_check <- read.csv("SY2025STHD_tagRates_forSCOBI.csv")

# Option 2: Load from main files
trap <- read.csv("SY2025STHD_trap.csv")
tagRates <- read.csv("SY2025STHD_tagRates.csv")

# Standardize column names if needed
if("group" %in% names(tagRates)) {
  # Already standardized
} else if("PBT_RELEASE_GROUP" %in% names(tagRates)) {
  tagRates <- tagRates %>% rename(group = PBT_RELEASE_GROUP)
} else {
  # Use first column as group
  names(tagRates)[1] <- "group"
}

# CORRECTED SCOBI CHECK
cat("\n--- Checking for missing tag rates ---\n")

# Extract unique release groups from trap data
# IMPORTANT: Exclude NA and "Unassigned" values
# NA = fish without PBT assignments (expected)
# Unassigned = wild fish or hatchery fish that failed PBT (don't need tag rates)
trap_release_groups <- trap %>%
  filter(!is.na(releaseGroup),
         releaseGroup != "Unassigned") %>%
  pull(releaseGroup) %>%
  unique()

cat("Total unique hatchery release groups in trap data:", length(trap_release_groups), "\n")
cat("Total release groups in tag rates file:", nrow(tagRates), "\n\n")

# Find missing tag rates
missing_tagrates <- setdiff(trap_release_groups, tagRates$group)

# Display results
if(length(missing_tagrates) > 0) {
  cat("⚠️  WARNING: These release groups in trap data are missing from tagRates:\n")
  print(missing_tagrates)

  # Show how many fish are affected
  cat("\nNumber of fish affected by missing tag rates:\n")
  affected_fish <- trap %>%
    filter(releaseGroup %in% missing_tagrates) %>%
    count(releaseGroup) %>%
    arrange(desc(n))
  print(affected_fish)

  cat("\nTotal fish affected:", sum(affected_fish$n), "\n")

  cat("\n--- ACTION REQUIRED ---\n")
  cat("You need to add these release groups to your tag rates file.\n")
  cat("Contact the PBT lab or hatchery coordinators to get tag rates for these groups.\n")

} else {
  cat("✅ SUCCESS! All trap release groups have corresponding tag rates\n")
}

# Additional QC checks
cat("\n\n--- Additional Quality Checks ---\n")

# Check 1: Summary of release group assignments
cat("\n1. Release group assignment summary:\n")
release_summary <- trap %>%
  mutate(status = case_when(
    is.na(releaseGroup) ~ "NA (No PBT assignment)",
    releaseGroup == "Unassigned" ~ "Unassigned (Wild/Failed PBT)",
    TRUE ~ "Assigned (Hatchery)"
  )) %>%
  count(status, Rear) %>%
  arrange(status)

print(release_summary)

# Check 2: Verify all hatchery fish with assignments have tag rates
cat("\n2. Verifying tag rates coverage:\n")
hatchery_with_assignment <- trap %>%
  filter(!is.na(releaseGroup),
         releaseGroup != "Unassigned",
         Rear %in% c("H", "HNC"))

if(nrow(hatchery_with_assignment) > 0) {
  coverage <- hatchery_with_assignment %>%
    left_join(tagRates, by = c("releaseGroup" = "group")) %>%
    summarise(
      total_hatchery = n(),
      with_tagrate = sum(!is.na(tagRate)),
      missing_tagrate = sum(is.na(tagRate))
    )

  print(coverage)

  if(coverage$missing_tagrate == 0) {
    cat("✅ All hatchery fish have tag rates\n")
  } else {
    cat("⚠️  Some hatchery fish are missing tag rates\n")
  }
} else {
  cat("No hatchery fish with PBT assignments found\n")
}

# Check 3: Tag rate distribution
cat("\n3. Tag rate distribution:\n")
if(nrow(tagRates) > 0) {
  cat("Tag rate summary statistics:\n")
  print(summary(tagRates$tagRate))

  # Check for invalid tag rates
  invalid_rates <- tagRates %>%
    filter(tagRate <= 0 | tagRate > 1 | is.na(tagRate))

  if(nrow(invalid_rates) > 0) {
    cat("\n⚠️  WARNING: Found invalid tag rates (should be between 0 and 1):\n")
    print(invalid_rates)
  } else {
    cat("\n✅ All tag rates are valid (between 0 and 1)\n")
  }
}

# Check 4: Duplicate groups in tag rates
cat("\n4. Checking for duplicate groups in tag rates:\n")
duplicates <- tagRates %>%
  count(group) %>%
  filter(n > 1)

if(nrow(duplicates) > 0) {
  cat("⚠️  WARNING: Found duplicate release groups in tag rates:\n")
  print(duplicates)
} else {
  cat("✅ No duplicate release groups in tag rates\n")
}

cat("\n=== SCOBI Check Complete ===\n")
