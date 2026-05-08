# --------------------------------------------------------------------------------
# Genentech: ADS Programmer Coding Assessment
# Author: Jay Sminchak
# Date: 05/2026
# Question 3 Part 1: AE Table
# --------------------------------------------------------------------------------
rm(list = ls()) # Clears the environment to ensure code runs properly from the top

# --------------------------------------------------------------------------------
### Libraries ####
# --------------------------------------------------------------------------------
library(tidyverse)        # Data manipulation packages
library(gtsummary)        # Creates descriptive tables/listings
library(gt)               # Customized gtsummary tables, exports as HTML
library(pharmaverseadam)  # Contains ADaM datasets
library(here)             # contributes to export reproduceability, sets project root

# datasets
adsl <- pharmaverseadam::adsl
adae <- pharmaverseadam::adae

# --------------------------------------------------------------------------------
### Pre-processing ####
# --------------------------------------------------------------------------------
# Filter to TEAEs
adae <- adae %>%  
  filter(TRTEMFL == "Y")

# Filter ADSL population to reflect safety population, accurate total column and denominator
adsl <- adsl %>% 
  filter(
    SAFFL == "Y"  # Filters out subjects who did not receive any treatment dose
  )


# --------------------------------------------------------------------------------
### Creating the table ####
# --------------------------------------------------------------------------------
tbl <- adae %>%
  tbl_hierarchical(
    variables = c(AESOC, AETERM),
    by = ACTARM,                # stratified by treatment arm
    id = USUBJID,
    denominator = adsl,
    overall_row = TRUE,
    label       = list("..ard_hierarchical_overall.." ~ "Treatment Emergent AEs"),
  ) %>% 
  modify_caption(   # creates table title
    "**Table 10:** Treatment-Emergent Adverse Events by Primary System Organ Class Reported Term"
  ) %>%
  add_overall(     # Adds total column
    last = TRUE, 
    col_label = "**Total**<br>N&nbsp;=&nbsp;{n}"  # Changing "overall" to "total" 
  ) %>% 
  modify_table_styling(
    column = all_stat_cols(), 
    align = "center"        # Standard for AE tables
  ) %>% 
  modify_spanning_header(
    all_stat_cols() ~ "**Treatment Group**"
  ) %>%
  modify_footnote(
    all_stat_cols() ~ "n, (%) - Percentages are based on the number of subjects in the Safety Population (N)."
  ) %>%
  sort_hierarchical()      # ensures table is sorted by descending frequency
tbl 

# --------------------------------------------------------------------------------
### Exporting as HTML ####
# --------------------------------------------------------------------------------
tbl %>% as_gt() %>%
  gtsave(here("question_3_tlg", "ae_summary_table.html"))
