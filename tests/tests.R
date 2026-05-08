# --------------------------------------------------------------------------------
# Genentech: ADS Programmer Coding Assessment
# Author: Jay Sminchak
# Date: 05/2026
# Validation Tests on Q1 and Q2 final datasets using testthat package
# All tests are described in the "test_that" line
# --------------------------------------------------------------------------------

# --------------------------------------------------------------------------------
### Libraries ####
# --------------------------------------------------------------------------------
library(testthat)
library(dplyr)
library(readr)
library(here)

# --------------------------------------------------------------------------------
### Q1 - DS SDTM Dataset ####
# --------------------------------------------------------------------------------

# Validates CDISC invariants on the saved ds.csv
ds <- read_csv(here("question_1_sdtm", "ds.csv"))  # final output from Q1

test_that("DS domain has all required variables", {
  required <- c("STUDYID", "DOMAIN", "USUBJID", "DSSEQ", "DSTERM",
                "DSDECOD", "DSCAT", "VISITNUM", "VISIT", "DSDTC",
                "DSSTDTC", "DSSTDY")
  expect_true(all(required %in% names(ds)))
})

test_that("DOMAIN is the constant 'DS'", {
  expect_equal(unique(ds$DOMAIN), "DS")
})

test_that("DSSEQ is unique within USUBJID (SDTMIG identifier rule)", {
  dups <- ds %>%
    count(USUBJID, DSSEQ) %>%
    filter(n > 1)
  expect_equal(nrow(dups), 0)
})

test_that("DSCAT values are restricted to expected CT", {
  expect_true(all(unique(ds$DSCAT) %in%
                    c("PROTOCOL MILESTONE", "DISPOSITION EVENT", "OTHER EVENT")))
})

test_that("DSDECOD values are uppercase (C66727 + passthrough convention)", {
  vals <- ds$DSDECOD[!is.na(ds$DSDECOD)]
  expect_equal(vals, toupper(vals))
})

test_that("USUBJID follows the '01-SITE-SUBJECT' pattern", {
  expect_true(all(grepl("^01-\\d+-\\d+$", ds$USUBJID)))
})

test_that("DSSTDTC parses as a valid ISO 8601 date", {
  parsed <- suppressWarnings(as.Date(ds$DSSTDTC))
  unparseable <- sum(is.na(parsed) & !is.na(ds$DSSTDTC))
  expect_equal(unparseable, 0)
})

# --------------------------------------------------------------------------------
### Q2 - ADSL ADaM Dataset ####
# --------------------------------------------------------------------------------
# Validates one-row-per-subject and spec-derived variable invariants

adsl <- read_csv(here("question_2_adam", "adsl.csv")) # final output from Q2

test_that("ADSL has one row per USUBJID", {
  expect_equal(nrow(adsl), n_distinct(adsl$USUBJID))
})

test_that("All spec-required variables are present", {
  spec_vars <- c("AGEGR9", "AGEGR9N", "TRTSDTM", "TRTSTMF",
                 "ITTFL", "LSTAVLDT")
  expect_true(all(spec_vars %in% names(adsl)))
})

test_that("ITTFL is restricted to Y/N", {
  expect_true(all(adsl$ITTFL %in% c("Y", "N")))
})

test_that("ITTFL='Y' iff ARM is populated (per spec)", {
  bad_y <- adsl %>% filter(ITTFL == "Y", is.na(ARM))
  bad_n <- adsl %>% filter(ITTFL == "N", !is.na(ARM))
  expect_equal(nrow(bad_y), 0)
  expect_equal(nrow(bad_n), 0)
})

test_that("AGEGR9N takes only expected values", {
  expect_true(all(adsl$AGEGR9N %in% c(1L, 2L, 3L, NA_integer_)))
})

test_that("AGEGR9 and AGEGR9N are 1:1 consistent", {
  pairs <- adsl %>%
    distinct(AGEGR9, AGEGR9N) %>%
    filter(!is.na(AGEGR9N))
  # Each numeric code should map to exactly one label
  expect_equal(nrow(pairs), n_distinct(pairs$AGEGR9N))
})

test_that("TRTSDT precedes or equals TRTEDT when both populated", {
  both <- adsl %>% filter(!is.na(TRTSDT), !is.na(TRTEDT))
  expect_true(all(both$TRTSDT <= both$TRTEDT))
})

test_that("LSTAVLDT is not in the future", {
  expect_true(all(is.na(adsl$LSTAVLDT) | adsl$LSTAVLDT <= Sys.Date()))
})

