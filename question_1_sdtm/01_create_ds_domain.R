# --------------------------------------------------------------------------------
# Genentech: ADS Programmer Coding Assessment
# Author: Jay Sminchak
# Date: 05/2026
# Question 1: SDTM DS Domain Creation
# --------------------------------------------------------------------------------
rm(list = ls()) # Clears the environment to ensure code runs properly from the top

# --------------------------------------------------------------------------------
### Libraries ####
# --------------------------------------------------------------------------------
library(tidyverse)      # Includes dplyr, tidyr, and ggplot2 packages
library(admiral)        # Used for convert_blanks_to_na(), derive_seq(), derive_study_day()
library(sdtm.oak)       # SDTM mapping package
library(pharmaverseraw) # Raw data for SDTM
library(here)           # contributes to export reproduceability, sets project root

# Raw Data:       pharmaverseraw::ds_raw
# CT file:        sdtm_ct.csv
# Topic Variable: DSTERM 

# --------------------------------------------------------------------------------
### Reading Raw Data + CT Specification ####
# --------------------------------------------------------------------------------
ds_raw <- pharmaverseraw::ds_raw
# converting any potential blanks to NA (admiral package)
ds_raw <- convert_blanks_to_na(ds_raw)

# dm domain read-in for final variable derivations
dm <- pharmaversesdtm::dm

# creating id vars
ds_raw <- ds_raw %>%
  generate_oak_id_vars(
    pat_var = "PATNUM",
    raw_src = "ds_raw"
  )

# Reading CT Specs - sdtm_ct.csv downloaded from linked GitHub
study_ct <- read_csv(here("datasets", "sdtm_ct.csv"))

# NOTE: Many collected_value's in the study_ct file DO NOT match the collected aCRF values, and were
#       un-mapped initially. Correctly collected values were cross-referenced with aCRF and the ds_raw dataset,
#       and the study_ct list was updated.

study_ct <- study_ct %>%
  mutate(collected_value = case_when(
    codelist_code == "C66727" & term_value == "COMPLETED"                   ~ "Completed",
    codelist_code == "C66727" & term_value == "LOST TO FOLLOW-UP"           ~ "Lost to Follow-Up",
    codelist_code == "C66727" & term_value == "STUDY TERMINATED BY SPONSOR" ~ "Study Terminated by Sponsor",
    codelist_code == "C66727" & term_value == "SCREEN FAILURE"              ~ "Screen Failure",
    codelist_code == "VISIT"    & term_value == "AMBUL ECG REMOVAL"         ~ "Ambul Ecg Removal",
    codelist_code == "VISITNUM" & term_value == "6"                         ~ "Ambul Ecg Removal",
    TRUE ~ collected_value
  ))
# Unscheduled visits absent from study_ct entirely. Rows added following the
# pattern of existing "Unscheduled 3.1" entries. VISITNUM decimal convention
# per SDTMIG 4.4.5; values confirmed against pharmaversesdtm::ds.

unscheduled_ct <- tribble(
  ~codelist_code, ~term_code, ~term_value,        ~collected_value,   ~term_preferred_term, ~term_synonyms,
  "VISITNUM",     "VISITNUM", "1.1",              "Unscheduled 1.1",  NA,                   NA,
  "VISITNUM",     "VISITNUM", "4.1",              "Unscheduled 4.1",  NA,                   NA,
  "VISITNUM",     "VISITNUM", "5.1",              "Unscheduled 5.1",  NA,                   NA,
  "VISITNUM",     "VISITNUM", "6.1",              "Unscheduled 6.1",  NA,                   NA,
  "VISITNUM",     "VISITNUM", "8.2",              "Unscheduled 8.2",  NA,                   NA,
  "VISITNUM",     "VISITNUM", "13.1",             "Unscheduled 13.1", NA,                   NA,
  "VISIT",        "VISIT",    "UNSCHEDULED 1.1",  "Unscheduled 1.1",  NA,                   NA,
  "VISIT",        "VISIT",    "UNSCHEDULED 4.1",  "Unscheduled 4.1",  NA,                   NA,
  "VISIT",        "VISIT",    "UNSCHEDULED 5.1",  "Unscheduled 5.1",  NA,                   NA,
  "VISIT",        "VISIT",    "UNSCHEDULED 6.1",  "Unscheduled 6.1",  NA,                   NA,
  "VISIT",        "VISIT",    "UNSCHEDULED 8.2",  "Unscheduled 8.2",  NA,                   NA,
  "VISIT",        "VISIT",    "UNSCHEDULED 13.1", "Unscheduled 13.1", NA,                   NA
)

study_ct <- bind_rows(study_ct, unscheduled_ct)
message("CT corrections applied: 4 collected_value fixes in C66727, ",
        "2 VISIT/VISITNUM case fixes, 6 unscheduled visits added via bind_rows.")
message("Informational warnings for RANDOMIZED/FINAL LAB VISIT/FINAL RETRIEVAL VISIT ",
        "are expected — no C66727 mapping exists; uppercase passthrough confirmed ",
        "against pharmaversesdtm::ds.")
# --------------------------------------------------------------------------------
### Mapping Topic Variable - DSTERM ####
#   -  Conditional Logic via eCRF: 
#   -  if OTHERSP not null, map OTHERSP to DSTERM (and DSDECOD)
#   -  if OTHERSP is null, map IT.DSTERM to DSTERM
# --------------------------------------------------------------------------------
ds <- assign_no_ct(
  raw_dat = condition_add(ds_raw, is.na(ds_raw$OTHERSP)), # flags condition of null OTHERSP
  raw_var = "IT.DSTERM",
  tgt_var = "DSTERM",
  id_vars = oak_id_vars()
  ) %>%
      assign_no_ct(
  raw_dat = condition_add(ds_raw, !is.na(ds_raw$OTHERSP)), # flags condition of not null OTHERSP
  raw_var = "OTHERSP",
  tgt_var = "DSTERM",
  id_vars = oak_id_vars()
  )

# --------------------------------------------------------------------------------
# Map DSDECOD (CT-controlled decode of DSTERM)
# Conditional Logic:
#   - If OTHERSP is NA → decode IT.DSDECOD via C66727 (standard CT decode)
#   - If OTHERSP is not NA → OTHERSP
# # --------------------------------------------------------------------------------
## DSDECOD ####
ds <- ds %>% assign_ct(
  raw_dat = condition_add(ds_raw, is.na(ds_raw$OTHERSP)), # flags condition of null OTHERSP
  raw_var = "IT.DSDECOD",
  tgt_var = "DSDECOD",
  ct_spec = study_ct,
  ct_clst = "C66727",
  id_vars = oak_id_vars()
) %>%
  assign_ct(
    raw_dat = condition_add(ds_raw, !is.na(ds_raw$OTHERSP)), # flags condition of not null OTHERSP
    raw_var = "OTHERSP",
    tgt_var = "DSDECOD",
    ct_spec = study_ct,
    ct_clst = "C66727",
    id_vars = oak_id_vars()
  )

# NOTE: "RANDOMIZED", "FINAL LAB VISIT", and "FINAL RETRIEVAL VISIT" produce informational warnings 
#       from assign_ct() as they have no collected_value match in C66727 (SDTMIG Terminology). 
#       sdtm.oak passes these through in uppercase, which is consistent with the target pharmaversesdtm::ds.
# --------------------------------------------------------------------------------
# Map DSCAT (CT-controlled decode, C74558)
# Conditional Logic - Hardcode values from aCRF
#   - If OTHERSP is not NA → "Other Event"
#   - If IT.DSDECOD is "Randomized" → "Protocol Milestone"
#   - If IT.DSDECOD is not "Randomized" → "Disposition Event"
# # --------------------------------------------------------------------------------
## DSCAT ####
ds <- ds %>%
  # "Protocol Milestone" - Randomized checkbox, no OTHERSP
  hardcode_ct(
    raw_dat = condition_add(ds_raw, IT.DSDECOD == "Randomized" & is.na(OTHERSP)),
    raw_var = "IT.DSDECOD",
    tgt_var = "DSCAT",
    tgt_val = "PROTOCOL MILESTONE",
    ct_spec = study_ct,
    ct_clst = "C74558",
    id_vars = oak_id_vars()
  ) %>%
  # "Disposition Event" - any other checkbox, no OTHERSP
  hardcode_ct(
    raw_dat = condition_add(ds_raw, IT.DSDECOD != "Randomized" & is.na(OTHERSP)),
    raw_var = "IT.DSDECOD",
    tgt_var = "DSCAT",
    tgt_val = "DISPOSITION EVENT",
    ct_spec = study_ct,
    ct_clst = "C74558",
    id_vars = oak_id_vars()
  ) %>%
  # "Other Event" - free-text OTHERSP filled (mutually exclusive by is.na guards above)
  hardcode_ct(
    raw_dat = condition_add(ds_raw, !is.na(OTHERSP)),
    raw_var = "OTHERSP",
    tgt_var = "DSCAT",
    tgt_val = "OTHER EVENT",
    ct_spec = study_ct,
    ct_clst = "C74558",
    id_vars = oak_id_vars()
  )

# --------------------------------------------------------------------------------
# Map VISITNUM/VISIT (CT-controlled decode, VISITNUM/VISIT)
# Logic: 
#   - ds_raw variable INSTANCE carries information relating to CT-coded values
# # --------------------------------------------------------------------------------
## VISITNUM/VISIT ####
ds <- ds %>% assign_ct(
  raw_dat = ds_raw,
  raw_var = "INSTANCE",
  tgt_var = "VISITNUM",
  ct_spec = study_ct,
  ct_clst = "VISITNUM",
  id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "INSTANCE",
    tgt_var = "VISIT",
    ct_spec = study_ct,
    ct_clst = "VISIT",
    id_vars = oak_id_vars()
  )


# --------------------------------------------------------------------------------
# DATETIME Derivations (ISO8601 formatting)
# Logic: 
#   - IT.DSSTDAT maps to DSSTDTC
#   - DSDTCOL AND DSTMCOL map to DSDTC
# # --------------------------------------------------------------------------------
## DSSTDTC/DSDTC ####
ds <- ds %>% assign_datetime(
    raw_dat = ds_raw,
    raw_var = "IT.DSSTDAT",
    tgt_var = "DSSTDTC",
    raw_fmt = "m-d-y",
    raw_unk = c("UN", "UNK"),
    id_vars = oak_id_vars()
  ) %>%
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = c("DSDTCOL", "DSTMCOL"),
    tgt_var = "DSDTC",
    raw_fmt = c("m-d-y", "H:M"),  # H:M included for hour/minute time
    raw_unk = c("UN", "UNK"),
    id_vars = oak_id_vars()
  )

# --------------------------------------------------------------------------------
# DERIVING ALL OTHER VARIABLES - Via dplyr and Admiral
# --------------------------------------------------------------------------------
## Other Variable Derivations ####
ds <- ds %>% 
  mutate(
    STUDYID = ds_raw$STUDY,
    DOMAIN  = "DS",
    USUBJID = paste0("01-", ds_raw$PATNUM)
  ) %>%
  derive_seq(
    tgt_var  = "DSSEQ",
    rec_vars = c("USUBJID", "DSSTDTC", "DSTERM") # Date var for chronological seq, DSTERM for same-day tiebreakers
  ) %>%                                          # Matches SDTMIG mapping more closely
  derive_study_day(
    sdtm_in      = .,
    dm_domain    = dm,
    tgdt         = "DSSTDTC",
    refdt        = "RFXSTDTC",
    study_day_var = "DSSTDY"
  ) %>%
  select(
    "STUDYID", "DOMAIN", "USUBJID", "DSSEQ", "DSTERM", 
    "DSDECOD", "DSCAT", "VISITNUM", "VISIT", "DSDTC",
    "DSSTDTC", "DSSTDY"
  )


# Quick validation: confirm expected variables, the domain is purley DS, all DSCATS are accounted for
stopifnot(
  all(c("STUDYID","DOMAIN","USUBJID","DSSEQ","DSTERM","DSDECOD",
        "DSCAT","VISITNUM","VISIT","DSDTC","DSSTDTC","DSSTDY") %in% names(ds)),
  unique(ds$DOMAIN) == "DS"
)

# Exporting final DS Domain dataset
write_csv(ds, here("question_1_sdtm", "ds.csv"))


