#!/usr/bin/env Rscript
# ============================================================
# Dose-Normalized C-T Curves + mAb TMDD / ADA Screening
# ============================================================
# Usage: Rscript dose_normalized_ct_plot.R <csv_file> [output_prefix]
#
# Features:
#   - Robust NONMEM-style CSV parsing (. = NA)
#   - Auto-detects DOSE / AMT column
#   - Detects ADA column → stratified by ADA status
#   - TMDD screening via dose-normalized curve overlay analysis
#   - Works for small molecules (linear) and mAb (potentially nonlinear/TMDD)
# ============================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
})

args <- commandArgs(trailingOnly = TRUE)
csv_file   <- if (length(args) >= 1) args[1] else "NM_dat_new.csv"
out_prefix <- if (length(args) >= 2) args[2] else "ct_plot"

# ---- 1. Robust CSV read: treat NONMEM "." as NA ----
d <- tryCatch(
  read.csv(csv_file, stringsAsFactors = FALSE, na.strings = c(".", "", "NA")),
  error = function(e) stop("Cannot read: ", csv_file)
)

# Normalize column names to uppercase
names(d) <- toupper(names(d))

# ---- 2. Column detection ----
required <- c("ID", "TIME", "DV")
missing_cols <- setdiff(required, names(d))
if (length(missing_cols) > 0) {
  stop("Missing columns: ", paste(missing_cols, collapse = ", "))
}

# Dose column: prefer DOSE, fall back to AMT
has_dose <- "DOSE" %in% names(d)
has_amt  <- "AMT"  %in% names(d)
dose_col <- if (has_dose) "DOSE" else if (has_amt) "AMT" else NULL

if (is.null(dose_col)) {
  stop("No DOSE or AMT column found in dataset")
}

# EVID / CMT / MDV availability
has_evid <- "EVID" %in% names(d)
has_cmt  <- "CMT"  %in% names(d)
has_mdv  <- "MDV"  %in% names(d)
has_ada  <- "ADA"  %in% names(d)  # Anti-drug antibody flag

# ---- 3. Extract per-subject dose ----
# For NONMEM datasets, dosing records have EVID=1 (or 4) and CMT=1
# We extract the dose amount per subject from these records.
if (has_evid) {
  dose_rows <- d %>%
    filter(!is.na(EVID) & EVID %in% c(1, 4)) %>%
    filter(!is.na(.data[[dose_col]]))
} else if (has_cmt) {
  dose_rows <- d %>%
    filter(!is.na(CMT) & CMT == 1) %>%
    filter(!is.na(.data[[dose_col]]))
} else {
  # Fallback: any row with positive dose amount
  dose_rows <- d %>%
    filter(!is.na(.data[[dose_col]]) & .data[[dose_col]] > 0)
}

if (nrow(dose_rows) == 0) {
  stop("No dosing records found. Check EVID/CMT/AMT columns.")
}

# Per-subject dose (use max in case of repeated dosing)
subj_dose <- dose_rows %>%
  group_by(ID) %>%
  summarise(DOSE_MAX = max(.data[[dose_col]], na.rm = TRUE), .groups = "drop")

# Merge dose back
d <- d %>%
  left_join(subj_dose, by = "ID")

# Check merge success
if (all(is.na(d$DOSE_MAX))) {
  stop("Dose merge failed: no matching IDs between dose records and observations.")
}

# Dose group (factor for coloring)
d <- d %>%
  mutate(DOSE_GROUP = factor(round(DOSE_MAX, 2)))

# ---- 4. Filter to observation records ----
if (has_evid) {
  d_obs <- d %>% filter(is.na(EVID) | EVID == 0)
} else if (has_mdv) {
  d_obs <- d %>% filter(!is.na(MDV) & MDV == 0)
} else {
  # Fallback: rows with non-missing DV and TIME >= 0
  d_obs <- d %>% filter(!is.na(DV) & !is.na(TIME) & TIME >= 0)
}

# Remove any residual dosing rows that slipped through
d_obs <- d_obs %>% filter(!is.na(DV))

if (nrow(d_obs) == 0) {
  stop("No observation records found after filtering.")
}

# Dose-normalized concentration
d_obs <- d_obs %>% mutate(DV_NORM = DV / DOSE_MAX)

# Remove zero/negative dose-normalized values for log scale
d_obs_plot <- d_obs %>% filter(DV_NORM > 0 & !is.na(DV_NORM))

# ---- 5. TMDD Screening Logic ----
# Linear PK: dose-normalized curves from different dose groups should overlap.
# TMDD (Target-Mediated Drug Disposition):
#   Low-dose groups show HIGHER dose-normalized concentrations because
#   TMDD clearance is NOT saturated → more drug is cleared via TMDD pathway.
#   High-dose groups show LOWER dose-normalized concentrations because
#   TMDD clearance IS saturated → proportionally less drug is cleared.
#
# For mAb with sparse sampling, we use TWO complementary strategies:
#   A) Overall median comparison across all time points
#   B) Time-window comparison (early / middle / late) when sufficient data exists

screen_tmdd <- function(data) {
  n_groups <- length(unique(data$DOSE_GROUP))
  if (n_groups < 2) {
    return(list(has_tmdd = FALSE, ratio = NA, detail = "Only one dose group — cannot assess TMDD."))
  }

  t_max <- max(data$TIME, na.rm = TRUE)

  # --- Strategy A: Overall median across all time points ---
  overall_medians <- data %>%
    group_by(DOSE_GROUP) %>%
    summarise(
      n = n(),
      median_dv_norm = median(DV_NORM, na.rm = TRUE),
      mean_dv_norm = mean(DV_NORM, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(DOSE_GROUP)

  low_median  <- overall_medians$median_dv_norm[1]
  high_median <- overall_medians$median_dv_norm[nrow(overall_medians)]

  if (is.na(low_median) || is.na(high_median) || high_median <= 0) {
    return(list(has_tmdd = FALSE, ratio = NA, detail = "Insufficient data for TMDD assessment."))
  }

  overall_ratio <- low_median / high_median

  # --- Strategy B: Time-window comparison ---
  # For sparse mAb data: use last N unique time points as "elimination window"
  unique_times <- sort(unique(data$TIME))
  n_times <- length(unique_times)

  time_window_results <- list()
  has_window_data <- FALSE

  if (n_times >= 5) {
    # Define windows by time quantiles
    q33 <- quantile(data$TIME, 0.33, na.rm = TRUE)
    q67 <- quantile(data$TIME, 0.67, na.rm = TRUE)

    windows <- list(
      early = data %>% filter(TIME <= q33),
      middle = data %>% filter(TIME > q33 & TIME <= q67),
      late = data %>% filter(TIME > q67)
    )

    for (wname in names(windows)) {
      wdata <- windows[[wname]]
      if (nrow(wdata) >= 5) {
        w_med <- wdata %>%
          group_by(DOSE_GROUP) %>%
          summarise(median_dv_norm = median(DV_NORM, na.rm = TRUE), .groups = "drop") %>%
          arrange(DOSE_GROUP)
        w_ratio <- w_med$median_dv_norm[1] / w_med$median_dv_norm[nrow(w_med)]
        time_window_results[[wname]] <- list(medians = w_med, ratio = w_ratio, n = nrow(wdata))
        has_window_data <- TRUE
      }
    }
  }

  # --- Decision: combine overall ratio with late-phase ratio (if available) ---
  # For mAb: late-phase is most informative for TMDD
  decision_ratio <- overall_ratio
  if (has_window_data && "late" %in% names(time_window_results)) {
    # Weight late-phase more heavily (TMDD most visible in elimination)
    late_ratio <- time_window_results[["late"]]$ratio
    decision_ratio <- 0.4 * overall_ratio + 0.6 * late_ratio
  }

  # Thresholds
  #  > 1.5 : suggestive of TMDD (conservative)
  #  > 2.0 : strong TMDD signal
  has_tmdd <- decision_ratio > 1.5
  tmdd_strength <- if (decision_ratio > 2.5) "Strong" else if (decision_ratio > 1.5) "Moderate" else "None"

  # Build detailed report
  detail_lines <- c(
    "=== Overall (all time points) ===",
    paste(capture.output(print(as.data.frame(overall_medians))), collapse = "\n"),
    sprintf("  Low-dose / High-dose ratio = %.2f", overall_ratio)
  )

  if (has_window_data) {
    for (wname in names(time_window_results)) {
      wr <- time_window_results[[wname]]
      detail_lines <- c(detail_lines, "",
        sprintf("=== %s phase (n=%d) ===", toupper(wname), wr$n),
        paste(capture.output(print(as.data.frame(wr$medians))), collapse = "\n"),
        sprintf("  Ratio = %.2f", wr$ratio)
      )
    }
  } else {
    detail_lines <- c(detail_lines, "",
      "Note: Sparse sampling — time-window comparison not possible.",
      "      Overall median comparison used as primary TMDD indicator."
    )
  }

  detail_lines <- c(detail_lines, "",
    sprintf("=== TMDD Decision (weighted ratio = %.2f) ===", decision_ratio),
    sprintf("  TMDD signal: %s (%s)", tmdd_strength, ifelse(has_tmdd, "nonlinear PK suspected", "linear PK consistent"))
  )

  return(list(
    has_tmdd = has_tmdd,
    ratio = decision_ratio,
    overall_ratio = overall_ratio,
    strength = tmdd_strength,
    detail = paste(detail_lines, collapse = "\n"),
    overall_medians = overall_medians
  ))
}

tmdd_result <- screen_tmdd(d_obs_plot)

# ---- 6. Plotting ----
# Color palette (up to 8 dose groups)
dose_colors <- c(
  "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3",
  "#FF7F00", "#FFFF33", "#A65628", "#F781BF"
)

# Base plot
gg <- ggplot(d_obs_plot, aes(x = TIME, y = DV_NORM, color = DOSE_GROUP, group = DOSE_GROUP)) +
  geom_point(alpha = 0.35, size = 1.2) +
  stat_summary(fun = median, geom = "line", linewidth = 1.3, aes(group = DOSE_GROUP)) +
  stat_summary(fun.data = function(x) {
    data.frame(ymin = quantile(x, 0.25, na.rm = TRUE), ymax = quantile(x, 0.75, na.rm = TRUE))
  }, geom = "ribbon", alpha = 0.12, color = NA, aes(fill = DOSE_GROUP)) +
  scale_y_log10(
    labels = function(x) format(x, scientific = FALSE, digits = 3, trim = TRUE),
    breaks = scales::trans_breaks("log10", function(x) 10^x),
    minor_breaks = scales::trans_breaks("log10", function(x) 10^x / 2)
  ) +
  scale_color_manual(values = dose_colors, name = "Dose") +
  scale_fill_manual(values = dose_colors, name = "Dose") +
  labs(
    x = "Time",
    y = "Dose-Normalized Concentration",
    title = "Dose-Normalized Concentration-Time Curves",
    subtitle = paste0(
      "Data: ", basename(csv_file),
      "  |  N = ", length(unique(d_obs_plot$ID)),
      " subjects  |  Dose groups: ", paste(levels(d_obs_plot$DOSE_GROUP), collapse = ", ")
    )
  ) +
  theme_bw(base_size = 13) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "right",
    legend.title = element_text(size = 10, face = "bold"),
    plot.subtitle = element_text(size = 10, color = "gray30")
  )

# ---- 7. ADA stratification (if ADA column exists) ----
if (has_ada) {
  # Ensure ADA is a clean factor
  d_obs_plot <- d_obs_plot %>%
    mutate(ADA = as.character(ADA),
           ADA_STATUS = ifelse(ADA %in% c("1", "YES", "Y", "POS", "POSITIVE"), "ADA+",
                        ifelse(ADA %in% c("0", "NO", "N", "NEG", "NEGATIVE"), "ADA-", "Unknown")))

  ada_counts <- d_obs_plot %>%
    group_by(ADA_STATUS) %>%
    summarise(n_subj = length(unique(ID)), .groups = "drop")

  if (nrow(ada_counts) >= 2 && all(ada_counts$n_subj >= 3)) {
    # Facet by ADA status
    gg <- ggplot(d_obs_plot, aes(x = TIME, y = DV_NORM, color = DOSE_GROUP, group = DOSE_GROUP)) +
      geom_point(alpha = 0.35, size = 1) +
      stat_summary(fun = median, geom = "line", linewidth = 1.2) +
      stat_summary(fun.data = function(x) {
        data.frame(ymin = quantile(x, 0.25, na.rm = TRUE), ymax = quantile(x, 0.75, na.rm = TRUE))
      }, geom = "ribbon", alpha = 0.1, color = NA, aes(fill = DOSE_GROUP)) +
      facet_wrap(~ADA_STATUS, ncol = 2) +
      scale_y_log10(labels = function(x) format(x, scientific = FALSE, digits = 3, trim = TRUE)) +
      scale_color_manual(values = dose_colors, name = "Dose") +
      scale_fill_manual(values = dose_colors, name = "Dose") +
      labs(
        x = "Time",
        y = "Dose-Normalized Concentration",
        title = "Dose-Normalized C-T Curves by ADA Status",
        subtitle = paste0(
          "Data: ", basename(csv_file),
          "  |  N = ", length(unique(d_obs_plot$ID)),
          "  |  ", paste(paste(ada_counts$ADA_STATUS, ada_counts$n_subj, sep = "="), collapse = "  |  ")
        )
      ) +
      theme_bw(base_size = 12) +
      theme(panel.grid.minor = element_blank(), legend.position = "bottom")
  }
}

# ---- 8. Save plot ----
out_png <- paste0(out_prefix, "_dose_norm_ct.png")
ggsave(out_png, gg, width = 10, height = 6, dpi = 150, bg = "white")
cat(sprintf(">>> Plot saved: %s  (%d x %d px)\n", out_png, 10 * 150, 6 * 150))

# ---- 9. Absorption lag detection ----
# For extravascular: check early time points for near-zero DV
# For IV infusion: typically no lag; skip or flag if early points are zero

detect_lag <- function(data, max_lag_points = 3) {
  obs <- data %>% arrange(TIME)
  unique_times <- unique(obs$TIME[obs$TIME > 0])

  if (length(unique_times) < 2) {
    return(list(has_lag = FALSE, lag_time = 0, detail = "Not enough early time points."))
  }

  check_times <- head(unique_times, max_lag_points)
  details <- c()

  for (t in check_times) {
    at_t <- obs %>% filter(TIME == t) %>% pull(DV)
    if (length(at_t) == 0) next
    median_dv <- median(at_t, na.rm = TRUE)
    nonzero_pct <- mean(at_t > 0, na.rm = TRUE) * 100
    details <- c(details, sprintf("  T=%.4g: median_DV=%.4g, nonzero=%.0f%%", t, median_dv, nonzero_pct))
  }

  first_t <- check_times[1]
  first_dv <- obs %>% filter(TIME == first_t) %>% pull(DV)
  first_nonzero <- if (length(first_dv) > 0) mean(first_dv > 0, na.rm = TRUE) else 1

  has_lag <- first_nonzero < 0.5
  recommendation <- if (has_lag) {
    "Consider adding ALAG/TLAG for extravascular absorption."
  } else {
    "No absorption lag detected."
  }

  list(
    has_lag = has_lag,
    lag_time = if (has_lag) first_t else 0,
    detail = paste(details, collapse = "\n"),
    recommendation = recommendation
  )
}

lag_result <- detect_lag(d_obs_plot)

# ---- 10. Route detection ----
route_info <- "Unknown"
if (has_evid) {
  dosing <- d %>% filter(!is.na(EVID) & EVID %in% c(1, 4) & !is.na(AMT) & AMT > 0)
  if (nrow(dosing) > 0) {
    if (has_cmt && any(dosing$CMT == 2, na.rm = TRUE)) {
      route_info <- "Extravascular"
    } else {
      route_info <- "IV Infusion"
    }
  }
} else if (has_cmt) {
  if (any(d$CMT == 2, na.rm = TRUE)) route_info <- "Extravascular"
  else route_info <- "IV Infusion"
}

# ---- 11. Console output summary ----
cat("\n")
cat("╔══════════════════════════════════════════════════════════════╗\n")
cat("║        Dose-Normalized C-T Analysis Summary                  ║\n")
cat("╠══════════════════════════════════════════════════════════════╣\n")
cat(sprintf("║  Subjects:           %-39s ║\n", length(unique(d$ID))))
cat(sprintf("║  Observations:       %-39s ║\n", nrow(d_obs_plot)))
cat(sprintf("║  Dose groups:        %-39s ║\n", paste(levels(d_obs_plot$DOSE_GROUP), collapse = ", ")))
cat(sprintf("║  Route:              %-39s ║\n", route_info))
cat(sprintf("║  Dose column used:   %-39s ║\n", dose_col))
cat(sprintf("║  Absorption lag:     %-39s ║\n", ifelse(lag_result$has_lag, paste0("YES (Tlag ≈ ", round(lag_result$lag_time, 3), ")"), "NO")))
cat("╠══════════════════════════════════════════════════════════════╣\n")
cat("║  TMDD Screening                                              ║\n")
cat(sprintf("║    Nonlinear PK sign: %-38s ║\n", ifelse(tmdd_result$has_tmdd, "YES ⚠", "NO ✓")))
cat(sprintf("║    Strength:          %-38s ║\n", tmdd_result$strength))
cat(sprintf("║    Low/High ratio:   %-38s ║\n", ifelse(is.na(tmdd_result$ratio), "N/A", round(tmdd_result$ratio, 2))))
cat("╚══════════════════════════════════════════════════════════════╝\n")
cat("\n--- TMDD Detail ---\n")
cat(tmdd_result$detail)
cat("\n")

# ---- 12. Write structured output for AutoPMX parser ----
out_txt <- paste0(out_prefix, "_analysis.txt")
writeLines(c(
  paste0("SUBJECTS=", length(unique(d$ID))),
  paste0("OBS=", nrow(d_obs_plot)),
  paste0("ROUTE=", route_info),
  paste0("DOSE_COLUMN=", dose_col),
  paste0("DOSE_GROUPS=", paste(levels(d_obs_plot$DOSE_GROUP), collapse = ", ")),
  paste0("HAS_LAG=", ifelse(lag_result$has_lag, "YES", "NO")),
  paste0("LAG_TIME=", lag_result$lag_time),
  paste0("LAG_RECOMMENDATION=", lag_result$recommendation),
  paste0("HAS_TMDD=", ifelse(tmdd_result$has_tmdd, "YES", "NO")),
  paste0("TMDD_RATIO=", ifelse(is.na(tmdd_result$ratio), "NA", round(tmdd_result$ratio, 3))),
  paste0("TMDD_DETAIL=", gsub("\n", " | ", tmdd_result$detail)),
  paste0("HAS_ADA=", ifelse(has_ada, "YES", "NO"))
), out_txt)
cat(sprintf(">>> Analysis written to: %s\n", out_txt))
