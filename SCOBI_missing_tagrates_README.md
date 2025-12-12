# SCOBI Missing Tag Rates Issue - SY2025 STHD

## Problem

When running your SCOBI check, you got this warning:
```
WARNING: These release groups in trap are missing from tagRates:
[1] NA
```

## Root Cause

The issue is that your trap data contains records with `NA` (missing) values in the `GenPBT_ByHatGenPBT_RGroup` column, and your SCOBI check is treating these NAs as actual release groups that need tag rates.

**NA values are EXPECTED** in the following cases:
1. **Wild fish without GenStock assignments** - These fish weren't successfully assigned to a genetic stock
2. **Hatchery fish without PBT assignments** - These fish failed genotyping or weren't genotyped

## Why This Happens

Looking at your data preparation workflow (Step 1A), the `releaseGroup` field is set according to these rules:

```r
releaseGroup = case_when(
  Rear == "W" & !is.na(GenStock) ~ 'Unassigned',    # Wild with GenStock
  Rear == "W" & is.na(GenStock) ~ NA_character_,     # Wild without GenStock → NA
  is.na(PBTBYHat) ~ NA_character_,                    # No PBT assignment → NA
  PBTBYHat == "Unassigned" ~ "Unassigned",           # Failed PBT
  TRUE ~ PBTRGroup                                    # Successful PBT assignment
)
```

## Solution

### The Quick Fix

**Exclude NA values from your SCOBI check:**

```r
# INCORRECT (your current code):
missing_tagrates_scobi <- setdiff(unique(trap_scobi_check$GenPBT_ByHatGenPBT_RGroup),
                                   tags_scobi_check$PBT_RELEASE_GROUP)

# CORRECT:
missing_tagrates_scobi <- setdiff(
  trap_scobi_check %>%
    filter(!is.na(GenPBT_ByHatGenPBT_RGroup),
           GenPBT_ByHatGenPBT_RGroup != "Unassigned") %>%
    pull(GenPBT_ByHatGenPBT_RGroup) %>%
    unique(),
  tags_scobi_check$PBT_RELEASE_GROUP
)
```

### Why Exclude NAs and "Unassigned"?

- **NA release groups** - These fish don't have PBT assignments, so they don't need tag rates
- **"Unassigned" release groups** - These are wild fish or hatchery fish that failed PBT. Tag rates don't apply to them.
- **Only hatchery-assigned fish** need tag rates for escapement estimation

## Scripts Provided

I've created three R scripts to help you:

### 1. `check_missing_tagrates_SY2025STHD.R`
**Purpose:** Diagnose why you have NA release groups
- Counts fish with NA release groups
- Breaks them down by rear type and mark status
- Helps you understand your data

**Run this first** to understand what's in your data.

### 2. `corrected_SCOBI_check_SY2025STHD.R`
**Purpose:** Properly check for missing tag rates
- Excludes NA and "Unassigned" values
- Runs comprehensive QC checks
- Validates tag rate coverage

**Run this** to get an accurate list of truly missing tag rates.

### 3. `create_SCOBI_exports_SY2025STHD.R`
**Purpose:** Create properly formatted SCOBI export files
- Creates `SY2025STHD_trap_forSCOBI.csv`
- Creates `SY2025STHD_tagRates_forSCOBI.csv`
- Runs validation checks
- Exports summary report

**Run this** if you need to create new SCOBI export files.

## How to Use These Scripts

### Step 1: Investigate the Issue
```r
source("check_missing_tagrates_SY2025STHD.R")
```

This will show you:
- How many fish have NA release groups
- What types of fish they are (wild vs hatchery)
- Whether this is expected

### Step 2: Run Corrected SCOBI Check
```r
source("corrected_SCOBI_check_SY2025STHD.R")
```

This will tell you if you truly have missing tag rates (excluding the expected NAs).

### Step 3: (Optional) Create New SCOBI Files
```r
source("create_SCOBI_exports_SY2025STHD.R")
```

This creates clean SCOBI export files with proper formatting.

## Expected Results

After running the corrected SCOBI check, you should see:

**If everything is good:**
```
✅ SUCCESS! All trap release groups have corresponding tag rates
```

**If you have actual missing tag rates:**
```
⚠️  WARNING: These release groups in trap are missing from tagRates:
[1] "2023-XXXX-YYYY-ZZZZ"
[2] "2024-AAAA-BBBB-CCCC"
```

In the second case, you'll need to:
1. Contact the PBT lab or hatchery coordinators
2. Get tag rates for those specific release groups
3. Add them to your tag rates file

## Key Takeaway

**NA release groups are NORMAL and EXPECTED** in EASE data. Your SCOBI check should:
- ✅ Include fish assigned to specific hatchery release groups
- ❌ Exclude fish with NA release groups (no PBT assignment)
- ❌ Exclude fish with "Unassigned" release groups (wild fish)

## Questions?

If you're still seeing issues after running these scripts:
1. Check how many fish have each release group status
2. Verify that wild fish are properly coded as "Unassigned" or NA
3. Ensure hatchery fish with successful PBT have specific release groups
4. Contact the genetics lab if you have hatchery fish missing tag rates

---
**Created:** $(date)
**For:** SY2025 STHD EASE Analysis
**Issue:** Missing tag rates showing as "NA" in SCOBI check
