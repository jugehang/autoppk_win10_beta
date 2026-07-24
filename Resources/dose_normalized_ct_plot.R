#!/usr/bin/env Rscript
# ============================================================
# dose_normalized_ct_plot.R
# Dose-normalized concentration-time curves + absorption lag detection
# Usage: Rscript dose_normalized_ct_plot.R <csv_file> [output_prefix]
# ============================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
})

args <- commandArgs(trailingOnly = TRUE)
csv_file  <- if (length(args) >= 1) args[1] else "NM_dat_new.csv"
out_prefix <- if (length(args) >= 2) args[2] else "ct_plot"

# ---- Read data ----
d <- tryCatch(
  read.csv(csv_file, stringsAsFactors = FALSE),
  error = function(e) stop("Cannot read: ", csv_file)
)

# Normalize column names to uppercase
names(d) <- toupper(names(d))

# Required columns
required <- c("ID", "TIME", "DV")
missing_cols <- setdiff(required, names(d))
if (length(missing_cols) > 0) {
  stop("Missing columns: ", paste(missing_cols, collapse = ", "))
}

# Detect dose column
dose_col <- if ("DOSE" %in% names(d)) "DOSE"
           else if ("AMT"  %in% names(d)) "AMT"
           else stop("No DOSE or AMT column found")

# Detect CMT/EVID for dosing records
has_cmt  <- "CMT"  %in% names(d)
has_evid <- "EVID" %in% names(d)

# ---- Dose-normalization ----
# Get per-subject dose (first dosing record)
if (has_evid) {
  dose_records <- d[!is.na(d$EVID) & d$EVID %in% c(1, 4), ]
} else if (has_cmt) {
  dose_records <- d[!is.na(d$CMT) & d$CMT == 1 & !is.na(d[[dose_col]]) & d[[dose_col]] > 0, ]
} else {
  dose_records <- d[!is.na(d[[dose_col]]) & d[[dose_col]] > 0, ]
}

# Per-subject dose
subj_dose <- aggregate(dose_records[[dose_col]], by = list(ID = dose_records$ID), FUN = max)
names(subj_dose)[2] <- "DOSE_MAX"

d <- merge(d, subj_dose, by = "ID", all.x = TRUE)
d$DV_NORM <- d$DV / d$DOSE_MAX
d$DOSE_GROUP <- as.factor(round(d$DOSE_MAX, 2))

# ---- Plot ----
# Filter to observations only (DV > 0, exclude dosing records)
d_obs <- d[!is.na(d$DV) & d$DV > 0 & d$TIME >= 0, ]
if (has_evid) d_obs <- d_obs[is.na(d_obs$EVID) | d_obs$EVID == 0, ]

p <- ggplot(d_obs, aes(x = TIME, y = DV_NORM, color = DOSE_GROUP, group = DOSE_GROUP)) +
  geom_point(alpha = 0.4, size = 1) +
  stat_summary(fun = median, geom = "line", linewidth = 1.2) +
  stat_summary(fun.data = function(x) {
    data.frame(ymin = quantile(x, 0.25), ymax = quantile(x, 0.75))
  }, geom = "ribbon", alpha = 0.15, color = NA) +
  scale_y_log10(labels = function(x) format(x, scientific = FALSE, digits = 3)) +
  labs(
    x = "Time",
    y = "Dose-Normalized Concentration",
    color = "Dose",
    title = "Dose-Normalized Concentration-Time Curves",
    subtitle = paste0("Data: ", basename(csv_file), " (N = ", length(unique(d$ID)), ")")
  ) +
  theme_minimal(base_size = 12)

ggsave(paste0(out_prefix, "_dose_norm_ct.png"), p, width = 10, height = 6, dpi = 150)
cat(sprintf("Plot saved: %s_dose_norm_ct.png\n", out_prefix))

# ---- Lag detection ----
# Check if absorption lag exists:
# For extravascular routes, look at the first post-dose time points.
# If median DV is 0 or near 0 at the earliest time(s), there's likely a lag.

detect_lag <- function(data, threshold = 0.001, max_lag_points = 3) {
  # Sort by TIME
  obs <- data[order(data$TIME), ]
  unique_times <- unique(obs$TIME[obs$TIME > 0])
  if (length(unique_times) < 2) return(list(has_lag = FALSE, lag_time = 0, detail = "Not enough time points"))

  # Check first N time points
  check_times <- head(unique_times, max_lag_points)
  lag_detail <- c()

  for (t in check_times) {
    at_t <- obs[obs$TIME == t, "DV"]
    median_dv <- median(at_t, na.rm = TRUE)
    nonzero_pct <- mean(at_t > 0, na.rm = TRUE) * 100
    lag_detail <- c(lag_detail, sprintf("  T=%.4g: median_DV=%.4g, samples>0=%.0f%%", t, median_dv, nonzero_pct))
  }

  # Lag exists if first time point has < 50% samples with measurable DV
  first_t <- check_times[1]
  first_dv <- obs[obs$TIME == first_t, "DV"]
  first_nonzero <- mean(first_dv > 0, na.rm = TRUE)

  if (first_nonzero < 0.5) {
    return(list(
      has_lag = TRUE,
      lag_time = first_t,
      detail = paste(lag_detail, collapse = "\n"),
      recommendation = "Consider adding ALAG or TLAG to the absorption model. Use ALAG1 for ADVAN2/ADVAN4, or TLAG with $PK for ADVAN13."
    ))
  }
  return(list(
    has_lag = FALSE,
    lag_time = 0,
    detail = paste(lag_detail, collapse = "\n"),
    recommendation = "No absorption lag detected."
  ))
}

lag_result <- detect_lag(d_obs)

# ---- Route detection ----
route_info <- "IV"
if (has_evid) {
  dosing <- d[!is.na(d$EVID) & d$EVID %in% c(1, 4) & !is.na(d$AMT) & d$AMT > 0, ]
  if (nrow(dosing) > 0) {
    if (has_cmt && any(dosing$CMT == 2, na.rm = TRUE)) route_info <- "Extravascular (CMT=2 dosing)"
  }
}

# ---- Output summary ----
cat("\n=== C-T Analysis Summary ===\n")
cat(sprintf("  Subjects: %d\n", length(unique(d$ID))))
cat(sprintf("  Observations: %d\n", nrow(d_obs)))
cat(sprintf("  Dose groups: %s\n", paste(levels(d_obs$DOSE_GROUP), collapse = ", ")))
cat(sprintf("  Route: %s\n", route_info))
cat(sprintf("  Absorption lag: %s\n", ifelse(lag_result$has_lag, "YES", "NO")))
cat(sprintf("  Lag time (first non-zero T): %.4g\n", lag_result$lag_time))
cat(sprintf("  Lag details:\n%s\n", lag_result$detail))
cat(sprintf("  Recommendation: %s\n", lag_result$recommendation))

# Write structured output for AutoPMX parser
out_txt <- paste0(out_prefix, "_analysis.txt")
writeLines(c(
  paste0("SUBJECTS=", length(unique(d$ID))),
  paste0("OBS=", nrow(d_obs)),
  paste0("ROUTE=", route_info),
  paste0("HAS_LAG=", ifelse(lag_result$has_lag, "YES", "NO")),
  paste0("LAG_TIME=", lag_result$lag_time),
  paste0("LAG_RECOMMENDATION=", lag_result$recommendation)
), out_txt)
cat(sprintf("\nAnalysis written to: %s\n", out_txt))
