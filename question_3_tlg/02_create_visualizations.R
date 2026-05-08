# --------------------------------------------------------------------------------
# Genentech: ADS Programmer Coding Assessment
# Author: Jay Sminchak
# Date: 05/2026
# Question 3 Part 2: AE Visualizations
# Plot 1: AE Severity Distribution (bar chart)
# Plot 2: AEs by Treatment Group; Top 10 Most Frequent AEs with 95% Clopper-Pearson CIs
# --------------------------------------------------------------------------------
rm(list = ls()) # Clears the environment to ensure code runs properly from the top

# --------------------------------------------------------------------------------
### Libraries ####
# --------------------------------------------------------------------------------
library(tidyverse)        # Data manipulation packages + ggplot2
library(pharmaverseadam)  # Contains ADaM datasets
library(here)             # contributes to export reproduceability, sets project root


# datasets
adsl <- pharmaverseadam::adsl
adae <- pharmaverseadam::adae

# --------------------------------------------------------------------------------
### Load Data ####
# --------------------------------------------------------------------------------
# Load fresh — this is a separate script from Part 1
# Cannot reuse Part 1's adae object: distinct() dropped AESEV and other columns

adsl <- adsl %>%
  filter(SAFFL == "Y")           # Safety population

adae <- adae %>%
  filter(TRTEMFL == "Y")         # TEAEs only


# --------------------------------------------------------------------------------
### Plot 1: AE Severity Distribution by Treatment - stacked bar chart ####
# --------------------------------------------------------------------------------
adae_severity <- adae %>%
  filter(!is.na(AESEV)) %>% # removes missing values
  mutate(AESEV = factor(AESEV, levels = c("MILD", "MODERATE", "SEVERE"))) %>% # orders the variable levels
  count(ACTARM, AESEV, name = "n_aes") # number of AEs by arm

plot1 <- ggplot(adae_severity, aes(x = ACTARM, y = n_aes, fill = AESEV)) +
  geom_col(position = "stack") +  # stacks bars on top of each other by treatment
  scale_fill_brewer(
    palette = "Dark2",  # color palette good against grays scale/colorblind friendly
    name   = "Severity/Intensity") +
  labs(
    title = "Figure 1. AE Severity Distribution by Treatment",
    x     = "Treatment Arm",
    y     = "Count of AEs"
  ) + theme_bw() + # easy to read theme for display
  theme(text = element_text(face = "bold")) # bolds labels
plot1

# --------------------------------------------------------------------------------
### Exporting Figure 1 as PNG ####
# --------------------------------------------------------------------------------
ggsave(here("question_3_tlg", "ae_severity_by_treatment.png"), width = 7, height = 6) # better dimensions for scale readability


# --------------------------------------------------------------------------------
### Plot 2: Top 10 Most Frequent AEs with 95% Clopper-Pearson CIs ####
# --------------------------------------------------------------------------------

# --------------------------------------------------------------------------------
### Filtering for the top 10 most frequent AEs, calculating 95% CIs ####
# --------------------------------------------------------------------------------
# Total subjects for CI denominator
N_total <- n_distinct(adsl$USUBJID)

# Selecting top 10 most frequent AEs, calculating 95% CIs
adae_top10 <- adae |>
  distinct(USUBJID, AETERM) |>   # one row per subject per AE term
  group_by(AETERM) |>
  summarise(n_subjects = n_distinct(USUBJID), .groups = "drop") |>  # Groups by AE term, produces single summary row
  mutate(                                                           # Drops the grouping structure
    N        = N_total,
    rate_pct = (n_subjects / N) * 100,   # Incidence Rate
    # Clopper-Pearson CI: map2 applies binom.test() to each row without rowwise()
    ci       = map2(n_subjects, N, ~ binom.test(.x, .y)$conf.int),
    ci_lower = map_dbl(ci, 1) * 100,
    ci_upper = map_dbl(ci, 2) * 100
  ) |>
  select(-ci) |>  # drops ci column, not needed
  arrange(desc(rate_pct)) |>  # sorts from highest to lowest incidence rate
  slice_head(n = 10) |>    # selects top 10
  mutate(AETERM = factor(AETERM, levels = rev(AETERM)))  # highest rate at top

# --------------------------------------------------------------------------------
### Creating the plot ####
# --------------------------------------------------------------------------------
plot2 <- ggplot(adae_top10, aes(x = rate_pct, y = AETERM)) +
  geom_point(size = 3) + 
  geom_errorbar(aes(xmin = ci_lower, xmax = ci_upper), width = 0.25) +
  scale_x_continuous(
    labels = function(x) paste0(x, "%"),  # adds "%" to x-axis values
    breaks = seq(0, ceiling(max(adae_top10$ci_upper) / 5) * 5, by = 5)  # every 5%
  ) +
  labs(
    title    = "Figure 2. Top 10 Most Frequent Adverse Events",
    subtitle = paste0("n = ", N_total, " subjects"),
    x        = "Percentage of Patients (%)",
    y        = NULL,
    caption  = paste0(
      "Population: Safety Analysis Set (all randomised subjects who received ≥1 dose).\n",
      "Error bars represent 95% Clopper-Pearson exact confidence intervals for incidence rates.\n"
    )
  ) +
  theme_bw() +
  theme(text = element_text(face = "bold"),
        plot.caption = element_text(face = "plain"))
plot2

# --------------------------------------------------------------------------------
### Exporting Figure 2 as a PNG ####
# --------------------------------------------------------------------------------
ggsave(here("question_3_tlg", "top_10_AEs.png"), width = 7, height = 6) # better dimensions for scale readability
