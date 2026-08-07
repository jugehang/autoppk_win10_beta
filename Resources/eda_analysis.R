#!/usr/bin/env Rscript
# ============================================================
# EDA (Exploratory Data Analysis) for PopPK Dataset
# ============================================================
# Usage: Rscript eda_analysis.R <csv_file> [output_prefix]
#
# Features:
#   - Dataset structure summary (subjects, observations, dosing records)
#   - Column-wise statistics (numeric & categorical)
#   - Missing data pattern analysis
#   - Dose distribution visualization
#   - Covariate distribution plots
#   - Correlation matrix heatmap
#   - Time-concentration overview (spaghetti plot)
# ============================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(gridExtra)
  library(scales)
})

args <- commandArgs(trailingOnly = TRUE)
csv_file   <- if (length(args) >= 1) args[1] else "dataset.csv"
out_prefix <- if (length(args) >= 2) args[2] else "eda"

# ---- 1. Robust CSV read ----
d <- tryCatch(
  read.csv(csv_file, stringsAsFactors = FALSE, na.strings = c(".", "", "NA")),
  error = function(e) stop("Cannot read: ", csv_file)
)

# Normalize column names to uppercase
names(d) <- toupper(names(d))

# NONMEM encodes many categorical covariates as numbers (SEX=0/1, ADA=0/1,
# STUDY=1..6, ROUTE/CMT/EVID/MDV codes). Detect them explicitly so numeric
# histograms are not drawn for category variables.
is_categorical_col <- function(x, col) {
  known_categorical <- c(
    "SEX", "ADA", "STUDY", "STUD", "STUDYID", "STUDYNO", "ROUTE",
    "BQL", "EVID", "MDV", "CMT", "RACE", "TRT", "ARM", "REGION",
    "TYPE", "GROUP", "COHORT", "TREATMENT", "SEXG", "SEX_GROUP"
  )
  if (col %in% known_categorical) return(TRUE)
  if (is.numeric(x)) {
    vals <- x[!is.na(x)]
    if (length(vals) == 0) return(FALSE)
    return(length(unique(vals)) <= 6)
  }
  return(TRUE)
}

# ---- 2. Basic structure ----
required <- c("ID", "TIME", "DV")
missing_cols <- setdiff(required, names(d))
if (length(missing_cols) > 0) {
  stop("Missing columns: ", paste(missing_cols, collapse = ", "))
}

n_subjects <- length(unique(d$ID))
n_total    <- nrow(d)

# Detect dosing / observation
has_evid <- "EVID" %in% names(d)
has_mdv  <- "MDV"  %in% names(d)
has_amt  <- "AMT"  %in% names(d)
has_dose <- "DOSE" %in% names(d)

if (has_evid) {
  n_dosing <- sum(d$EVID %in% c(1, 4), na.rm = TRUE)
  n_obs    <- sum(d$EVID == 0 | is.na(d$EVID), na.rm = TRUE)
} else if (has_mdv) {
  n_dosing <- sum(d$MDV == 1, na.rm = TRUE)
  n_obs    <- sum(d$MDV == 0, na.rm = TRUE)
} else {
  n_dosing <- NA
  n_obs    <- sum(!is.na(d$DV) & d$DV > 0, na.rm = TRUE)
}

# Dose column
dose_col <- if (has_dose) "DOSE" else if (has_amt) "AMT" else NULL

# ---- 3. Numeric summary ----
numeric_cols <- names(d)[sapply(d, is.numeric)]
numeric_cols <- setdiff(numeric_cols, c("ID"))  # Exclude ID from stats

num_summary <- NULL
if (length(numeric_cols) > 0) {
  num_summary <- data.frame(
    Column = numeric_cols,
    N = sapply(d[numeric_cols], function(x) sum(!is.na(x))),
    Missing = sapply(d[numeric_cols], function(x) sum(is.na(x))),
    Mean = sapply(d[numeric_cols], function(x) round(mean(x, na.rm = TRUE), 4)),
    SD = sapply(d[numeric_cols], function(x) round(sd(x, na.rm = TRUE), 4)),
    Median = sapply(d[numeric_cols], function(x) round(median(x, na.rm = TRUE), 4)),
    Min = sapply(d[numeric_cols], function(x) round(min(x, na.rm = TRUE), 4)),
    Max = sapply(d[numeric_cols], function(x) round(max(x, na.rm = TRUE), 4)),
    stringsAsFactors = FALSE
  )
}

# ---- 4. Categorical summary ----
cat_cols <- names(d)[sapply(names(d), function(col) is_categorical_col(d[[col]], col))]
cat_summary <- list()
for (col in cat_cols) {
  tab <- table(d[[col]], useNA = "ifany")
  cat_summary[[col]] <- data.frame(
    Value = names(tab),
    Count = as.integer(tab),
    Pct = round(100 * as.integer(tab) / sum(tab), 1),
    stringsAsFactors = FALSE
  )
}

# ---- 5. Missing data pattern ----
missing_pattern <- data.frame(
  Column = names(d),
  MissingCount = sapply(d, function(x) sum(is.na(x))),
  MissingPct = round(100 * sapply(d, function(x) sum(is.na(x))) / nrow(d), 2),
  stringsAsFactors = FALSE
) %>% arrange(desc(MissingPct))

# ---- 6. Console output summary ----
cat("\n")
cat("╔══════════════════════════════════════════════════════════════╗\n")
cat("║        EDA (Exploratory Data Analysis) Summary               ║\n")
cat("╠══════════════════════════════════════════════════════════════╣\n")
cat(sprintf("║  Dataset:             %-38s ║\n", basename(csv_file)))
cat(sprintf("║  Subjects:            %-38d ║\n", n_subjects))
cat(sprintf("║  Total records:       %-38d ║\n", n_total))
cat(sprintf("║  Dosing records:      %-38s ║\n", ifelse(is.na(n_dosing), "N/A", n_dosing)))
cat(sprintf("║  Observation records: %-38s ║\n", ifelse(is.na(n_obs), "N/A", n_obs)))
cat(sprintf("║  Columns:             %-38d ║\n", ncol(d)))
cat(sprintf("║  Dose column:         %-38s ║\n", ifelse(is.null(dose_col), "N/A", dose_col)))
cat("╚══════════════════════════════════════════════════════════════╝\n")

cat("\n--- Numeric Columns Summary ---\n")
if (!is.null(num_summary)) {
  print(num_summary, row.names = FALSE)
} else {
  cat("No numeric columns found.\n")
}

cat("\n--- Missing Data Pattern ---\n")
print(missing_pattern, row.names = FALSE)

cat("\n--- Categorical Columns Summary ---\n")
if (length(cat_summary) > 0) {
  for (col in names(cat_summary)) {
    cat(sprintf("\n%s:\n", col))
    print(cat_summary[[col]], row.names = FALSE)
  }
} else {
  cat("No categorical columns found.\n")
}

# ---- 7. Plotting ----
plot_list <- list()

# 7a. Dose distribution (if dose column exists)
if (!is.null(dose_col)) {
  dose_data <- d %>%
    filter(!is.na(.data[[dose_col]])) %>%
    distinct(ID, .keep_all = TRUE)

  if (nrow(dose_data) > 0) {
    p_dose <- ggplot(dose_data, aes(x = .data[[dose_col]])) +
      geom_histogram(bins = 15, fill = "steelblue", color = "white", alpha = 0.8) +
      geom_density(aes(y = after_stat(count)), color = "darkred", linewidth = 1) +
      labs(title = "Dose Distribution", x = dose_col, y = "Count") +
      theme_bw(base_size = 12)
    plot_list[["dose_dist"]] <- p_dose
  }
}

# 7b. Covariate distributions (WT, AGE, SEX, etc.)
covariate_candidates <- c("WT", "AGE", "SEX", "RACE", "HT", "BMI", "CRCL")
available_covs <- intersect(covariate_candidates, names(d))

for (cov in available_covs) {
  cov_data <- d %>% distinct(ID, .keep_all = TRUE)
  if (is.numeric(cov_data[[cov]]) && !is_categorical_col(cov_data[[cov]], cov)) {
    p_cov <- ggplot(cov_data, aes(x = .data[[cov]])) +
      geom_histogram(bins = 12, fill = "seagreen", color = "white", alpha = 0.8) +
      labs(title = paste(cov, "Distribution"), x = cov, y = "Count") +
      theme_bw(base_size = 11)
  } else {
    p_cov <- ggplot(cov_data, aes(x = factor(.data[[cov]]))) +
      geom_bar(fill = "coral", color = "white", alpha = 0.8) +
      labs(title = paste(cov, "Distribution"), x = cov, y = "Count") +
      theme_bw(base_size = 11) +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
  }
  plot_list[[paste0("cov_", cov)]] <- p_cov
}

# 7b2. Demographic statistics / distribution grouped by dose or route
demographic_candidates <- c("WT", "AGE", "SEX", "RACE", "HT", "BMI", "CRCL", "ADA", "STUDY", "STUD")
demographic_covs <- intersect(demographic_candidates, names(d))
group_candidates <- c("DOSE", "ROUTE")
valid_groups <- intersect(group_candidates, names(d))
valid_groups <- valid_groups[sapply(valid_groups, function(col) {
  vals <- d[[col]]
  vals <- vals[!is.na(vals) & trimws(as.character(vals)) != ""]
  length(unique(vals)) >= 2 && length(vals) >= 10
})]

if (length(demographic_covs) > 0 && length(valid_groups) > 0) {
  subj_dem <- d %>% distinct(ID, .keep_all = TRUE)
  for (group_col in valid_groups) {
    if (group_col %in% names(subj_dem)) {
      subj_dem[[paste0("GRP_", group_col)]] <- factor(subj_dem[[group_col]])
    }
    for (cov in demographic_covs) {
      if (!cov %in% names(subj_dem)) next
      grp_var <- paste0("GRP_", group_col)
      valid_rows <- subj_dem %>% filter(!is.na(.data[[cov]]), !is.na(.data[[grp_var]]))
      if (nrow(valid_rows) == 0 || length(unique(valid_rows[[grp_var]])) < 2) next
      if (is.numeric(valid_rows[[cov]]) && !is_categorical_col(valid_rows[[cov]], cov)) {
        p_dem <- ggplot(valid_rows, aes(x = .data[[grp_var]], y = .data[[cov]], fill = .data[[grp_var]])) +
          geom_boxplot(alpha = 0.75, outlier.size = 1.2) +
          geom_jitter(width = 0.18, alpha = 0.35, size = 0.9, color = "gray20") +
          stat_summary(fun = median, geom = "point", shape = 18, size = 3, color = "black") +
          labs(
            title = paste(cov, "by", group_col),
            subtitle = paste0("Subject-level demographic distribution"),
            x = group_col,
            y = cov
          ) +
          theme_bw(base_size = 11) +
          theme(legend.position = "none")
      } else {
        p_dem <- ggplot(valid_rows, aes(x = .data[[cov]], fill = .data[[grp_var]])) +
          geom_bar(position = "fill", color = "white", alpha = 0.85) +
          scale_y_continuous(labels = percent_format()) +
          labs(
            title = paste(cov, "Composition by", group_col),
            subtitle = paste0("Subject-level proportions"),
            x = cov,
            y = "Proportion"
          ) +
          theme_bw(base_size = 11) +
          theme(axis.text.x = element_text(angle = 35, hjust = 1))
      }
      plot_list[[paste0("dem_", cov, "_by_", group_col)]] <- p_dem
    }
  }

  dem_export_cols <- c("ID", demographic_covs, valid_groups)
  dem_export_cols <- intersect(dem_export_cols, names(d))
  dem_export <- d %>%
    distinct(ID, .keep_all = TRUE) %>%
    select(any_of(dem_export_cols))
  if (nrow(dem_export) > 0) {
    dem_csv <- paste0(out_prefix, "_demographics.csv")
    write.csv(dem_export, dem_csv, row.names = FALSE)
    cat(sprintf(">>> Demographics table saved: %s\n", dem_csv))
  }
}

# 7c. Spaghetti plot (DV vs TIME)
d_obs <- d %>% filter(!is.na(DV) & !is.na(TIME) & DV > 0)
if (nrow(d_obs) > 0) {
  # Detect if log scale is appropriate
  dv_range <- range(d_obs$DV, na.rm = TRUE)
  use_log <- dv_range[2] / dv_range[1] > 100

  p_spag <- ggplot(d_obs, aes(x = TIME, y = DV, group = ID)) +
    geom_line(alpha = 0.45, linewidth = 0.45, color = "gray40") +
    geom_point(alpha = 0.5, size = 0.9, color = "steelblue") +
    labs(
      title = "Concentration-Time Spaghetti Plot",
      subtitle = paste0("N = ", n_subjects, " subjects"),
      x = "Time",
      y = "Concentration (DV)"
    ) +
    theme_bw(base_size = 12)

  if (use_log) {
    p_spag <- p_spag + scale_y_log10()
  }
  plot_list[["spaghetti"]] <- p_spag

  # Facet C-T by route and categorical variables when available.
  facet_candidates <- c("ROUTE", "SEX", "STUDY", "ADA", "BQL", "TYPE",
                        "RACE", "GROUP", "COHORT", "TREATMENT")
  valid_facets <- intersect(facet_candidates, names(d_obs))
  valid_facets <- valid_facets[sapply(valid_facets, function(col) {
    vals <- d_obs[[col]]
    vals <- vals[!is.na(vals) & trimws(as.character(vals)) != ""]
    length(unique(vals)) >= 2 && length(vals) >= 10
  })]
  if (length(valid_facets) > 6) valid_facets <- valid_facets[1:6]
  for (col in valid_facets) {
    p_facet <- p_spag +
      facet_wrap(as.formula(paste("~", col)), scales = "free_y") +
      labs(title = paste("Concentration-Time by", col))
    plot_list[[paste0("ct_by_", col)]] <- p_facet
  }
}

# 7d. Correlation heatmap (numeric covariates only)
if (length(available_covs) > 1) {
  cov_numeric <- available_covs[
    sapply(available_covs, function(col) is.numeric(d[[col]]) && !is_categorical_col(d[[col]], col))
  ]
  if (length(cov_numeric) >= 2) {
    cov_data <- d %>% distinct(ID, .keep_all = TRUE) %>% select(all_of(cov_numeric))
    cov_data <- cov_data %>% select(where(~sum(!is.na(.)) > 1))
    if (ncol(cov_data) >= 2) {
      cor_mat <- cor(cov_data, use = "pairwise.complete.obs")
      cor_df <- as.data.frame(cor_mat) %>%
        mutate(Var1 = rownames(cor_mat)) %>%
        pivot_longer(cols = -Var1, names_to = "Var2", values_to = "Correlation")

      p_cor <- ggplot(cor_df, aes(x = Var1, y = Var2, fill = Correlation)) +
        geom_tile(color = "white") +
        geom_text(aes(label = round(Correlation, 2)), size = 3) +
        scale_fill_gradient2(low = "blue", mid = "white", high = "red",
                             midpoint = 0, limits = c(-1, 1)) +
        labs(title = "Covariate Correlation Matrix") +
        theme_bw(base_size = 11) +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))
      plot_list[["correlation"]] <- p_cor
    }
  }
}

# 7e. Sampling schedule overview
sampling_summary <- d_obs %>%
  group_by(TIME) %>%
  summarise(N = n(), Subjects = length(unique(ID)), .groups = "drop")

if (nrow(sampling_summary) > 0) {
  sampling_time_range <- diff(range(sampling_summary$TIME, na.rm = TRUE))
  sampling_bar_width <- max(sampling_time_range / 80, 0.5)
  p_sample <- ggplot(sampling_summary, aes(x = TIME, y = N)) +
    geom_col(width = sampling_bar_width, fill = "mediumpurple", color = "white", alpha = 0.85) +
    geom_text(aes(label = N), vjust = -0.5, size = 3) +
    labs(
      title = "Sampling Schedule",
      subtitle = paste0("Unique time points: ", nrow(sampling_summary)),
      x = "Time",
      y = "Number of Observations"
    ) +
    theme_bw(base_size = 12)
  plot_list[["sampling"]] <- p_sample
}

# ---- 8. Save plots ----
if (length(plot_list) > 0) {
  n_plots <- length(plot_list)
  n_cols <- min(2, n_plots)
  n_rows <- ceiling(n_plots / n_cols)

  # Save combined plot
  out_png <- paste0(out_prefix, "_eda.png")
  png(out_png, width = 12 * n_cols, height = 5 * n_rows, units = "in", res = 150)
  do.call(grid.arrange, c(plot_list, ncol = n_cols))
  dev.off()
  cat(sprintf("\n>>> EDA plot saved: %s\n", out_png))

  # Also save individual plots
  for (name in names(plot_list)) {
    individual_png <- paste0(out_prefix, "_", name, ".png")
    ggsave(individual_png, plot_list[[name]], width = 8, height = 6, dpi = 150, bg = "white")
  }
  cat(sprintf(">>> Individual plots saved: %s_*\n", out_prefix))
} else {
  cat("\n>>> No plots generated (insufficient data).\n")
}

# ---- 9. Write structured output ----
out_txt <- paste0(out_prefix, "_eda_summary.txt")
writeLines(c(
  paste0("SUBJECTS=", n_subjects),
  paste0("OBSERVATIONS=", n_obs),
  paste0("DOSING_RECORDS=", ifelse(is.na(n_dosing), "N/A", n_dosing)),
  paste0("COLUMNS=", ncol(d)),
  paste0("DOSE_COLUMN=", ifelse(is.null(dose_col), "N/A", dose_col)),
  paste0("NUMERIC_COLS=", paste(numeric_cols, collapse = ", ")),
  paste0("CATEGORICAL_COLS=", paste(cat_cols, collapse = ", ")),
  paste0("COVARIATES_FOUND=", paste(available_covs, collapse = ", ")),
  paste0("MISSING_COLS=", paste(missing_pattern$Column[missing_pattern$MissingCount > 0], collapse = ", "))
), out_txt)
cat(sprintf(">>> EDA summary written to: %s\n", out_txt))
