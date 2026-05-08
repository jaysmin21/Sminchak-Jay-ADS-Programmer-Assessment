# Genentech ADS Programmer Coding Assessment — Jay Sminchak

## Overview
Solutions for the 4-question Pharmaverse + Python coding assessment.
Questions 1–3 implement SDTM/ADaM/TLG workflows in R using pharmaverse;
Question 4 is a Python GenAI agent that maps natural-language queries
to SDTM AE filters.

## Repo structure
- `question_1_sdtm/` — SDTM DS domain creation using {sdtm.oak}
- `question_2_adam/` — ADSL dataset using {admiral}
- `question_3_tlg/`  — AE summary table ({gtsummary}) + 2 plots ({ggplot2})
- `question_4_python/` — ClinicalTrialDataAgent (mocked LLM)
- `datasets/`        — sdtm_ct.csv (study controlled terminology, taken from https://github.com/pharmaverse/examples/blob/main/metadata/sdtm_ct.csv)
- `tests/`           - Validation tests on Q1 and Q2 final dataset outputs

Each R folder has the script, the resulting dataset/output, and a `.txt` log
showing the script ran error-free.

## Environment
- R 4.4
- Python 3.10+ (pandas)
- Run R scripts from the Rproj root; here() handles all paths.
- Run Python from the Rproj root: `python question_4_python/04_clinical_data_agent.py`

## How to run
1. Open the `.Rproj` in RStudio (or set working directory to repo root).
2. Install required R packages (see below).
3. Run scripts from each question folder:
   - `question_1_sdtm/01_create_ds_domain.R`
   - `question_2_adam/02_create_adsl.R`
   - `question_3_tlg/01_create_ae_summary_table.R`
   - `question_3_tlg/02_create_visualizations.R`
4. For Q4: `python3 question_4_python/04_clinical_data_agent.py`
   (runs from any directory — uses `Path(__file__).parent`)
5. For the tests of the final DS and ADSL outputs, ensure that the "testthat" package is installed.
   - a txt log file will be included showing script success.

## Required R packages
```r
install.packages(c("tidyverse", "admiral", "sdtm.oak",
                   "pharmaverseraw", "pharmaversesdtm",
                   "pharmaverseadam", "gtsummary", "gt", "here", "testthat"))
```
## Question-by-question notes

### Q1 — DS Domain
- Mapped a Disposition domain dataset from raw clinical trial data from pharmaverseraw::ds_raw.
- Utilized sdtm.oak pharmaverse package for sdtm mapping.
- Used https://pharmaverse.github.io/examples/sdtm/ae.html as an SDTM mapping in sdtm.oak reference. 
- Controlled Terminology file downloaded here: https://github.com/pharmaverse/examples/blob/main/metadata/sdtm_ct.csv
- Identified and corrected mismatches between sdtm_ct.csv and the aCRF
  collected values (case sensitivity, missing unscheduled visits).
  Documented in script comments.
- "RANDOMIZED" / "FINAL LAB VISIT" / "FINAL RETRIEVAL VISIT" produce
  intentional informational warnings — these have no C66727 mapping;
  uppercase pass-through matches pharmaversesdtm::ds.
- Output includes final DS domain dataset, R script, log .txt file

### Q2 — ADSL
- Programmed a full ADSL dataset from the pharmaversesdtm dm, vs, ex, ds, and ae datasets.
- Utilized admiral pharmaverse package for ADaM dataset creation.
- Used https://pharmaverse.github.io/admiral/cran-release/articles/adsl.html#death_date as an ADSL mapping in Admiral reference.
- Heavy use of admiral functions per spec. Required vars (AGEGR9/AGEGR9N,
  TRTSDTM/TRTSTMF, ITTFL, LSTAVLDT) all derived.
- TRTSTMF: ignore_seconds_flag = TRUE per spec ("if only seconds missing,
  do not populate flag").
- LSTAVLDT: included traceability vars (LALVSEQ, LALVDOM, LALVVAR) above
  spec for source tracking.
- Output includes final ADSL ADaM dataset, R script, log .txt file.

### Q3 — AE Summary + Visualizations
- Programmed adverse event summary listings and visualizations in gtsummary and ggplot2.
- Population: Safety Population (SAFFL == "Y", N = 254). Affects total
  column denominator and Plot 2 percentages.
- Plot 2 CIs: Clopper-Pearson exact, computed via binom.test().
- Output includes R scripts, AE listing HTML, AE visualization PNGs, log.txt files.

### Q4 — Clinical Data Agent (Bonus)
- Built a Python agent that translates natural-language questions about the AE
  dataset into structured pandas filters via a mocked LLM call.
- AI assistance was leaned on heavily here to bridge into Python and LLM territory.
  Implementation was deliberately kept simple.
- Architecture follows the spec's Prompt → Parse → Execute flow.
  `mock_llm_response()` is the single swap point for a real LLM call; the rest
  of the pipeline is unchanged when wired to a real API.
- Treated as a learning opportunity rather than a chance to ship
  something I couldn't explain.
- Output includes Python script, and adae.csv.




## Reproducibility
Each R script begins with rm(list = ls()) and uses here() for paths.
Logs in each folder confirm error-free execution.