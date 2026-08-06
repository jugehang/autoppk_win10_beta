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

# ---- 0. Verify required packages ----
pkg_errors <- c()
if (!requireNamespace("ggplot2", quietly = TRUE)) pkg_errors <- c(pkg_errors, "ggplot2")
if (!requireNamespace("dplyr", quietly = TRUE))   pkg_errors <- c(pkg_errors, "dplyr")
if (!requireNamespace("scales", quietly = TRUE))  pkg_errors <- c(pkg_errors, "scales")
if (length(pkg_errors) > 0) {
  stop("Missing R packages: ", paste(pkg_errors, collapse = ", "),
       ". Install with: install.packages(c('", paste(pkg_errors, collapse = "','"), "'))")
}

args <- commandArgs(trailingOnly = TRUE)
csv_file   <- if (length(args) >= 1) args[1] else "NM_dat_new.csv"
out_prefix <- if (length(args) >= 2) args[2] else "ct_plot"
# Optional unit args (passed from Swift/Python app when available)
dose_unit  <- if (length(args) >= 3) args[3] else "mg"
conc_unit  <- if (length(args) >= 4) args[4] else "µg/mL"
time_unit  <- if (length(args) >= 5) args[5] else "h"

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

# ---- 2b. Defensive numeric coercion ----
# NONMEM-style CSVs can be read with a column as character/factor when ANY row
# contains a stray non-numeric token. This would later break `DV / DOSE_ACTUAL`
# with "non-numeric argument to binary operator". Coerce the numeric columns
# up front and warn about any values that had to be dropped.
numeric_cols <- c("DV", "TIME", "ID", dose_col)
for (col in numeric_cols) {
  if (col %in% names(d) && !is.numeric(d[[col]])) {
    orig <- d[[col]]
    conv <- suppressWarnings(as.numeric(orig))
    n_bad <- sum(is.na(conv) & !is.na(orig))
    if (n_bad > 0) {
      bad_samples <- unique(as.character(orig)[is.na(conv) & !is.na(orig)])
      warning(sprintf("Column '%s' had %d non-numeric value(s); coerced to NA. Examples: %s",
                      col, n_bad, paste(bad_samples[1:5], collapse = ", ")))
    }
    d[[col]] <- conv
  }
}

# Guard: if DV or the dose column is still non-numeric, fail with a clear message
if (!is.numeric(d$DV)) {
  stop("DV column is non-numeric even after coercion. Check the dataset for text values in DV.")
}
if (!is.numeric(d[[dose_col]])) {
  stop(sprintf("Dose column '%s' is non-numeric even after coercion.", dose_col))
}


# EVID / CMT / MDV availability
has_evid <- "EVID" %in% names(d)
has_cmt  <- "CMT"  %in% names(d)
has_mdv  <- "MDV"  %in% names(d)
has_ada  <- "ADA"  %in% names(d)  # Anti-drug antibody flag
has_route <- "ROUTE" %in% names(d)
has_rate  <- "RATE" %in% names(d)
has_dur   <- "DUR" %in% names(d)

# ---- 3. Extract ACTUAL dose per observation (true dose normalization) ----
# KEY: dose normalization divides each individual's DV by THAT individual's
# ACTUAL administered dose — NOT a global maximum dose (that would not be
# normalization). Priority:
#   1) If a per-record DOSE column exists and is populated on observation rows,
#      use it directly:  DV_NORM = DV / DOSE
#   2) Otherwise pull the actual dose from AMT (or DOSE) on dosing records and
#      attach it per subject:  DV_NORM = DV / AMT
# This makes dose-normalized C-T curves directly reveal how C-T changes with
# the administered dose.

# Observation mask (used to decide whether a per-record DOSE column is usable)
obs_mask <- if (has_evid) {
  is.na(d$EVID) | d$EVID == 0
} else if (has_mdv) {
  !is.na(d$MDV) & d$MDV == 0
} else {
  !is.na(d$DV) & !is.na(d$TIME) & d$TIME >= 0
}

dose_src <- NULL   # resolved name of the column holding each obs's actual dose

if (has_dose) {
  # Is DOSE populated on observation rows? Use it directly when mostly present.
  n_obs     <- sum(obs_mask, na.rm = TRUE)
  n_obs_dose <- sum(obs_mask & !is.na(d$DOSE), na.rm = TRUE)
  if (n_obs > 0 && n_obs_dose > 0.5 * n_obs) {
    d <- d %>% mutate(DOSE_ACTUAL = DOSE)
    dose_src <- "DOSE_ACTUAL"
  }
}

if (is.null(dose_src)) {
  # Fallback: derive actual dose per subject from dosing records (AMT preferred).
  if (has_evid) {
    dose_rows <- d %>% filter(!is.na(EVID) & EVID %in% c(1, 4)) %>% filter(!is.na(.data[[dose_col]]))
} else if (has_amt) {
    dose_rows <- d %>% filter(!is.na(.data[[dose_col]]) & .data[[dose_col]] > 0)
} else if (has_cmt) {
    dose_rows <- d %>% filter(!is.na(CMT) & CMT %in% c(1, 2)) %>%
      filter(!is.na(.data[[dose_col]]) & .data[[dose_col]] > 0)
} else {
    dose_rows <- d %>% filter(!is.na(.data[[dose_col]]) & .data[[dose_col]] > 0)
  }
  if (nrow(dose_rows) == 0) {
    stop("No dosing records found. Check EVID/CMT/AMT columns.")
  }
  # Use the actual dose given to each subject (max if repeated/loading dosing).
  subj_dose <- dose_rows %>%
    group_by(ID) %>%
    summarise(DOSE_ACTUAL = max(.data[[dose_col]], na.rm = TRUE), .groups = "drop")
  d <- d %>% left_join(subj_dose, by = "ID")
  if (all(is.na(d$DOSE_ACTUAL))) {
    stop("Dose merge failed: no matching IDs between dose records and observations.")
  }
  dose_src <- "DOSE_ACTUAL"
}

# Guard: actual dose must be numeric and strictly positive where used
if (!is.numeric(d[[dose_src]])) {
  d[[dose_src]] <- suppressWarnings(as.numeric(d[[dose_src]]))
}
if (!is.numeric(d[[dose_src]])) {
  stop(sprintf("Resolved dose source '%s' is non-numeric even after coercion.", dose_src))
}

# Dose group (factor for coloring) = each individual's actual dose
d <- d %>%
  mutate(DOSE_GROUP = factor(round(.data[[dose_src]], 2)))

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

# Dose-normalized concentration: divide by EACH individual's actual dose
d_obs <- d_obs %>% mutate(DV_NORM = DV / .data[[dose_src]])

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

  # --- Spread across dose groups (how much do the normalized curves REALLY differ) ---
  # A single low/high ratio can be driven by a single outlier dose group. We also
  # quantify the overall dispersion of dose-group medians as a ratio-of-IQRs style
  # "fold difference", which is more robust to inter-individual variability.
  # Principle (clinical): dose-normalized curves need NOT perfectly overlap — some
  # spread is expected from IIV. Only when the curves are clearly separated (well
  # beyond normal IIV) do we suspect dose saturation / nonlinear (TMDD) PK.
  grp_meds <- overall_medians$median_dv_norm
  grp_meds <- grp_meds[is.finite(grp_meds) & grp_meds > 0]
  if (length(grp_meds) >= 2) {
    # Robust fold difference: use Q3/Q1 of group medians instead of max/min.
    # This captures the "typical spread" across dose groups and is far less
    # sensitive to a single outlier group or stray early-timepoint points.
    q1 <- quantile(grp_meds, 0.25, na.rm = TRUE)
    q3 <- quantile(grp_meds, 0.75, na.rm = TRUE)
    fold_diff <- if (q1 > 0) q3 / q1 else max(grp_meds) / min(grp_meds)
  } else {
    fold_diff <- decision_ratio
  }

  # Thresholds — deliberately tolerant of normal inter-individual variability.
  #   ratio <= 2.0  : curves are "close enough" → linear PK (no meaningful saturation)
  #   ratio >  2.0  : mild separation (suggestive, but still within IIV-like range)
  #   ratio >  3.0  : clear separation → moderate TMDD signal
  #   ratio >  5.0  : strong TMDD signal
  # We require BOTH the low/high ratio AND the overall fold difference to be elevated
  # before flagging TMDD, so that ordinary IIV does not trip a false positive.
  has_tmdd <- decision_ratio > 2.0 && fold_diff > 2.0
  tmdd_strength <- if (decision_ratio > 5.0 || fold_diff > 5.0) "Strong"
                   else if (decision_ratio > 3.0 || fold_diff > 3.0) "Moderate"
                   else "None"

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
    sprintf("=== TMDD Decision (weighted ratio = %.2f, overall fold diff = %.2f) ===", decision_ratio, fold_diff),
    sprintf("  TMDD signal: %s (%s)", tmdd_strength,
            ifelse(has_tmdd,
                   "nonlinear PK suspected — normalized curves clearly separated beyond IIV",
                   "linear PK supported — normalized curves are close enough; residual spread is within normal inter-individual variability"))
  )

  return(list(
    has_tmdd = has_tmdd,
    ratio = decision_ratio,
    fold_diff = fold_diff,
    overall_ratio = overall_ratio,
    strength = tmdd_strength,
    detail = paste(detail_lines, collapse = "\n"),
    overall_medians = overall_medians
  ))
}

# ── Multi-compartment shape detection from semi-log curves ──
# On a semi-log plot, a 1-compartment model shows a single straight
# elimination line. Multi-compartment models (≥2 compartments) show a
# curved decline: the early distribution phase is steeper, the later
# elimination phase is shallower. We detect this by comparing the
# log-linear slope early vs late in the post-peak elimination phase.
detect_multi_compartment <- function(data, time_col = "TIME", dv_col = "DV_NORM") {
  data <- data %>% filter(.data[[dv_col]] > 0)
  if (nrow(data) < 10) {
    return(list(suspected = NA, detail = "Insufficient data for multi-compartment shape assessment."))
  }
  results <- list()
  for (grp in levels(data$DOSE_GROUP)) {
    grp_data <- data %>% filter(DOSE_GROUP == grp)
    if (nrow(grp_data) < 5) next
    medians <- grp_data %>%
      group_by(.data[[time_col]]) %>%
      summarise(MDV = median(.data[[dv_col]], na.rm = TRUE), .groups = "drop") %>%
      filter(MDV > 0)
    if (nrow(medians) < 5) next
    medians$LMDV <- log10(medians$MDV)
    # Find Tmax (peak concentration time)
    tmax_idx <- which.max(medians$MDV)
    if (tmax_idx >= nrow(medians)) next  # peak at last point, no elimination data
    post_peak <- medians %>% slice((tmax_idx + 1):n())
    if (nrow(post_peak) < 3) next
    n <- nrow(post_peak)
    half_n <- max(floor(n / 2), 2)
    early <- post_peak %>% slice(1:half_n)
    late  <- post_peak %>% slice((n - half_n + 1):n())
    if (nrow(early) < 2 || nrow(late) < 2) next
    lm_early <- lm(LMDV ~ TIME, data = early)
    lm_late  <- lm(LMDV ~ TIME, data = late)
    slope_early <- coef(lm_early)[2]
    slope_late  <- coef(lm_late)[2]
    if (is.na(slope_early) || is.na(slope_late)) next
    if (slope_early < 0 && slope_late < 0) {
      results[[as.character(grp)]] <- list(
        slope_early = unname(slope_early),
        slope_late  = unname(slope_late),
        ratio = unname(slope_early / slope_late),
        r2_early = summary(lm_early)$r.squared,
        r2_late  = summary(lm_late)$r.squared
      )
    }
  }
  if (length(results) == 0) {
    return(list(suspected = FALSE, detail = "Semi-log curve shape consistent with 1-compartment kinetics (linear decline on log scale)."))
  }
  ratios <- sapply(results, `[[`, "ratio")
  median_ratio <- median(ratios, na.rm = TRUE)
  n_grp <- sum(!is.na(ratios))
  # Ratio > 1.3: early (distribution) phase is notably steeper than terminal phase → multi-compartment
  # Ratio < 1.2: slopes similar → 1-compartment
  suspected <- !is.na(median_ratio) && median_ratio > 1.3
  if (suspected) {
    detail <- sprintf(
      "Multi-compartment kinetics SUSPECTED from semi-log curve shape: early elimination phase is %.1f× steeper than terminal phase (median of %d dose group(s)). The log-scale curvature is characteristic of a distribution phase (α) followed by a shallower elimination phase (β).",
      median_ratio, n_grp
    )
  } else {
    detail <- sprintf(
      "Semi-log curve shape is consistent with 1-compartment kinetics: early vs terminal log-linear slopes are similar (ratio = %.2f, %d dose group(s)).",
      median_ratio, n_grp
    )
  }
  return(list(suspected = suspected, ratio = median_ratio, n_grp = n_grp, detail = detail))
}

tmdd_result <- screen_tmdd(d_obs_plot)

# ── Multi-compartment shape analysis from semi-log dose-normalized curves ──
compartment_result <- detect_multi_compartment(d_obs_plot)

# ---- 6. Plotting ----
# Nature Publishing Group (NPG) palette — up to 10 dose groups
nature_colors <- c(
  "#E64B35", "#4DBBD5", "#00A087", "#3C5488",
  "#F39B7F", "#8491B4", "#91D1C2", "#DC0000",
  "#7E6148", "#B09C85"
)

# Base plot — dose-group median curves (no SD ribbon)
gg <- ggplot(d_obs_plot, aes(x = TIME, y = DV_NORM, color = DOSE_GROUP, group = DOSE_GROUP)) +
  geom_point(alpha = 0.8, size = 0.8, color = "black", show.legend = FALSE) +
  stat_summary(fun = median, geom = "line", linewidth = 0.8, alpha = 0.8) +
  scale_y_log10(
    labels = function(x) format(x, scientific = FALSE, digits = 3, trim = TRUE),
    breaks = scales::trans_breaks("log10", function(x) 10^x),
    minor_breaks = scales::trans_breaks("log10", function(x) 10^x / 2)
  ) +
  scale_color_manual(values = nature_colors, name = "Dose") +
  scale_fill_manual(values = nature_colors, name = "Dose") +
  labs(
    x = paste0("Time (", time_unit, ")"),
    y = paste0("Dose-Normalized Conc. (", conc_unit, "/", dose_unit, ")"),
    title = "Dose-Normalized Concentration–Time (dose-group median)",
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
      geom_point(alpha = 0.8, size = 0.8, color = "black", show.legend = FALSE) +
      stat_summary(fun = median, geom = "line", linewidth = 0.8, alpha = 0.8) +
      facet_wrap(~ADA_STATUS, ncol = 2) +
      scale_y_log10(labels = function(x) format(x, scientific = FALSE, digits = 3, trim = TRUE)) +
      scale_color_manual(values = nature_colors, name = "Dose") +
      scale_fill_manual(values = nature_colors, name = "Dose") +
      labs(
      x = paste0("Time (", time_unit, ")"),
      y = paste0("Dose-Normalized Conc. (", conc_unit, "/", dose_unit, ")"),
      title = "Dose-Normalized C-T by ADA Status (dose-group median)",
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

# ---- 7b. Route / categorical faceted C-T plots ----
facet_candidates <- c("ROUTE", "SEX", "STUDY", "ADA", "BQL", "TYPE",
                      "RACE", "GROUP", "COHORT", "TREATMENT")
available_facets <- intersect(facet_candidates, names(d_obs_plot))
available_facets <- available_facets[sapply(available_facets, function(col) {
  vals <- d_obs_plot[[col]]
  vals <- vals[!is.na(vals) & trimws(as.character(vals)) != ""]
  length(unique(vals)) >= 2 && length(vals) >= 10
})]
if (length(available_facets) > 6) available_facets <- available_facets[1:6]

for (facet_col in available_facets) {
  p_facet <- ggplot(d_obs_plot,
    aes(x = TIME, y = DV_NORM, color = DOSE_GROUP, group = DOSE_GROUP)) +
    geom_point(alpha = 0.8, size = 0.8, color = "black", show.legend = FALSE) +
    stat_summary(fun = median, geom = "line", linewidth = 0.8, alpha = 0.8) +
    facet_wrap(as.formula(paste("~", facet_col)), scales = "free_y") +
    scale_y_log10(
      labels = function(x) format(x, scientific = FALSE, digits = 3, trim = TRUE),
      breaks = scales::trans_breaks("log10", function(x) 10^x)
    ) +
    scale_color_manual(values = nature_colors, name = "Dose") +
    scale_fill_manual(values = nature_colors, name = "Dose") +
    labs(
      x = paste0("Time (", time_unit, ")"),
      y = paste0("Dose-Normalized Conc. (", conc_unit, "/", dose_unit, ")"),
      title = paste("Dose-Normalized C-T by", facet_col),
      subtitle = paste0("Data: ", basename(csv_file),
                        "  |  N = ", length(unique(d_obs_plot$ID)), " subjects")
    ) +
    theme_bw(base_size = 12) +
    theme(
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      strip.text = element_text(face = "bold", size = 10)
    )
  out_facet <- paste0(out_prefix, "_by_", tolower(gsub("[^A-Za-z0-9]+", "_", facet_col)), ".png")
  ggsave(out_facet, p_facet, width = 12, height = 6, dpi = 150, bg = "white")
  cat(sprintf(">>> Plot saved: %s\n", out_facet))
}

# ---- 8. Save plot ----
out_png <- paste0(out_prefix, "_dose_norm_ct.png")
ggsave(out_png, gg, width = 10, height = 6, dpi = 150, bg = "white")
cat(sprintf(">>> Plot saved: %s  (%d x %d px)\n", out_png, 10 * 150, 6 * 150))

# ---- 8b. First-dose sub-plots (multi-dose clarity) ----
# When a study uses multiple doses, steady-state accumulation and
# dose-stacking overlay the terminal elimination phase and make the true
# half-life hard to read. We isolate each subject's FIRST dosing interval
# and plot (a) the raw first-dose C-T and (b) the first-dose dose-normalized
# C-T against time-since-first-dose, so absorption and elimination are
# unambiguous.
cat(sprintf(">>> Building first-dose sub-plots (n_subjects=%d)...\n", length(unique(d$ID))))

# Per-subject dosing-event times (EVID==1 or EVID==4 with AMT>0).
dose_event_times <- if (has_evid) {
  d %>% filter(EVID %in% c(1, 4) & !is.na(AMT) & AMT > 0) %>%
    group_by(ID) %>%
    summarise(FIRST_DOSE_TIME = min(TIME),
              ALL_DOSE_TIMES = list(sort(unique(TIME))), .groups = "drop")
} else {
  # No EVID: treat the single per-subject AMT>0 time (or TIME==0) as dosing,
  # and use each subject's full span as the "first dose" window.
  d %>% group_by(ID) %>%
    summarise(FIRST_DOSE_TIME = min(TIME[!is.na(AMT) & AMT > 0], na.rm = TRUE),
              ALL_DOSE_TIMES = list(sort(unique(TIME))), .groups = "drop") %>%
    mutate(FIRST_DOSE_TIME = if_else(is.na(FIRST_DOSE_TIME),
                                     min(d$TIME[d$TIME >= 0], na.rm = TRUE), FIRST_DOSE_TIME))
}

dose_event_times <- dose_event_times %>%
  mutate(DOSE_INTERVAL = sapply(ALL_DOSE_TIMES, function(times) {
    if (length(times) >= 2) median(diff(times)) else NA_real_
  }))

single_dose_span <- d %>% group_by(ID) %>% summarise(MAX_T = max(TIME), .groups = "drop")

d_first <- d %>%
  left_join(dose_event_times %>% select(ID, FIRST_DOSE_TIME, DOSE_INTERVAL), by = "ID") %>%
  left_join(single_dose_span, by = "ID") %>%
  mutate(
    TREL = TIME - FIRST_DOSE_TIME,
    WINDOW = if_else(!is.na(DOSE_INTERVAL) & DOSE_INTERVAL > 1,
                     DOSE_INTERVAL - 1,   # truncate 1 hour before next dose
                     MAX_T - FIRST_DOSE_TIME + 1e-6),
    IN_FIRST = (TIME >= FIRST_DOSE_TIME - 1e-6) & (TIME <= FIRST_DOSE_TIME + WINDOW)
  ) %>%
  filter(IN_FIRST)

n_first <- length(unique(d_first$ID))
is_multi_dose <- any(!is.na(dose_event_times$DOSE_INTERVAL) & dose_event_times$DOSE_INTERVAL > 0)
cat(sprintf(">>> first-dose subjects=%d/%d, multi-dose=%s\n",
            n_first, length(unique(d$ID)), is_multi_dose))

# (a) First-dose raw C-T — dose-group mean ± SD
# Filter to observation records within the first-dose window
d_first_obs <- if (has_evid) {
  d_first %>% filter(is.na(EVID) | EVID == 0)
} else if (has_mdv) {
  d_first %>% filter(!is.na(MDV) & MDV == 0)
} else {
  d_first %>% filter(!is.na(DV) & !is.na(TREL) & TREL >= 0)
}
if (n_first > 0 && nrow(d_first_obs) > 0) {
  p_first_raw <- ggplot(d_first_obs,
    aes(x = TREL, y = DV, color = DOSE_GROUP, group = DOSE_GROUP)) +
    geom_point(alpha = 0.8, size = 0.8, color = "black", show.legend = FALSE) +
    stat_summary(fun = median, geom = "line", linewidth = 0.8, alpha = 0.8) +
    scale_y_log10(
      labels = function(x) format(x, scientific = FALSE, digits = 3, trim = TRUE),
      breaks = scales::trans_breaks("log10", function(x) 10^x)
    ) +
    scale_color_manual(values = nature_colors, name = "Dose") +
    scale_fill_manual(values = nature_colors, name = "Dose") +
    labs(
      title = "First-Dose Concentration–Time (dose-group median)",
      x = paste0("Time since first dose (", time_unit, ")"),
      y = paste0("Concentration (", conc_unit, ")"),
      color = "Dose Group"
    ) +
    theme_bw(base_size = 13) +
    theme(panel.grid.minor = element_blank(),
          axis.text.x = element_text(size = 9),
          plot.title = element_text(size = 12, face = "bold"),
          legend.position = "bottom")
  out_first_raw <- paste0(out_prefix, "_firstdose_ct.png")
  ggsave(out_first_raw, p_first_raw, width = 9, height = 6, dpi = 150, bg = "white")
  cat(sprintf(">>> Plot saved: %s\n", out_first_raw))
}

# (b) First-dose dose-normalized C-T — dose-group mean ± SD
# Normalize each point by its own dose so within-subject first-dose dose groups
# align on the same scale (avoids fragile joins on identical TIME values).
first_norm <- d_first %>%
  mutate(DV_NORM_FIRST = DV / .data[[dose_col]])
# Filter to observations for plotting
first_norm_obs <- if (has_evid) {
  first_norm %>% filter(is.na(EVID) | EVID == 0)
} else if (has_mdv) {
  first_norm %>% filter(!is.na(MDV) & MDV == 0)
} else {
  first_norm %>% filter(!is.na(DV) & !is.na(TREL) & TREL >= 0)
}
if (n_first > 0 && nrow(first_norm_obs) > 0) {
  p_first_dn <- ggplot(first_norm_obs,
    aes(x = TREL, y = DV_NORM_FIRST, color = DOSE_GROUP, group = DOSE_GROUP)) +
    geom_point(alpha = 0.8, size = 0.8, color = "black", show.legend = FALSE) +
    stat_summary(fun = median, geom = "line", linewidth = 0.8, alpha = 0.8) +
    scale_y_log10(
      labels = function(x) format(x, scientific = FALSE, digits = 3, trim = TRUE),
      breaks = scales::trans_breaks("log10", function(x) 10^x)
    ) +
    scale_color_manual(values = nature_colors, name = "Dose") +
    scale_fill_manual(values = nature_colors, name = "Dose") +
    labs(
      title = "First-Dose Dose-Normalized C-T (dose-group median)",
      x = paste0("Time since first dose (", time_unit, ")"),
      y = paste0("C / Dose (", conc_unit, "/", dose_unit, ")"),
      color = "Dose Group"
    ) +
    theme_bw(base_size = 13) +
    theme(panel.grid.minor = element_blank(),
          axis.text.x = element_text(size = 9),
          plot.title = element_text(size = 12, face = "bold"),
          legend.position = "bottom")
  out_first_dn <- paste0(out_prefix, "_firstdose_dose_norm_ct.png")
  ggsave(out_first_dn, p_first_dn, width = 9, height = 6, dpi = 150, bg = "white")
  cat(sprintf(">>> Plot saved: %s\n", out_first_dn))
}

# Default (overwritten after estimate_halflife is defined, below).
firstdose_elim <- list(similar = NA, n_reliable = 0, detail = "No first-dose data.",
                       has_assess = FALSE, half_lives = c(), r2 = c(), reliable_mask = c())

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

# ---- 9b. Elimination (terminal-phase) assessment ----
# Fit a log-linear terminal phase per dose group and estimate the half-life.
# Compare terminal-phase half-lives ACROSS dose groups: if they are similar,
# elimination is dose-independent (consistent with linear PK). Large
# differences suggest dose-dependent clearance (e.g., saturable/TMDD).
#
# CRITICAL: only use half-life estimates with R^2 >= 0.5. mAb sparse-sampling
# datasets often produce terminal fits with R^2 near zero — those are pure
# noise and must NOT influence the linear-PK verdict.
estimate_halflife <- function(times, concs) {
  # Use only the terminal 3+ points with positive concentration
  idx <- which(concs > 0 & times > 0)
  if (length(idx) < 3) return(list(half_life = NA, k = NA, r2 = NA, n = length(idx), reliable = FALSE))
  tt <- times[idx]; cc <- concs[idx]
  ord <- order(tt)
  tt <- tt[ord]; cc <- cc[ord]
  # Terminal 50% of points (at least 3) for the linear fit on log scale
  n_term <- max(3, ceiling(length(tt) / 2))
  tt_t <- tt[(length(tt) - n_term + 1):length(tt)]
  cc_t <- cc[(length(cc) - n_term + 1):length(cc)]
  logc <- log(cc_t)
  fit <- tryCatch({
    m <- lm(logc ~ tt_t)
    list(coef = coef(m), r2 = summary(m)$r.squared)
  }, error = function(e) NULL)
  if (is.null(fit)) return(list(half_life = NA, k = NA, r2 = NA, n = length(tt_t), reliable = FALSE))
  slope <- as.numeric(fit$coef[2])
  if (slope >= 0) return(list(half_life = NA, k = slope, r2 = fit$r2, n = length(tt_t), reliable = FALSE))
  k <- -slope
  half_life <- log(2) / k
  reliable <- !is.na(fit$r2) && fit$r2 >= 0.5
  list(half_life = half_life, k = k, r2 = fit$r2, n = length(tt_t), reliable = reliable)
}

screen_elimination <- function(data) {
  groups <- levels(data$DOSE_GROUP)
  if (length(groups) < 1) {
    return(list(has_assess = FALSE, half_lives = c(), similar = NA,
                detail = "No dose groups for elimination assessment."))
  }
  hl <- c()
  hl_r2 <- c()
  hl_reliable <- c()
  for (g in groups) {
    sub <- data %>% filter(DOSE_GROUP == g)
    res <- estimate_halflife(sub$TIME, sub$DV)
    hl <- c(hl, if (is.na(res$half_life)) NA else res$half_life)
    r2_val <- if (is.na(res$r2)) NA else res$r2
    hl_r2 <- c(hl_r2, r2_val)
    hl_reliable <- c(hl_reliable, isTRUE(res$reliable))
  }
  names(hl) <- groups
  names(hl_r2) <- groups
  names(hl_reliable) <- groups

  # Only reliable fits count for cross-dose-group comparison
  valid <- hl[hl_reliable]
  n_reliable <- sum(hl_reliable)
  if (n_reliable < 1) {
    return(list(has_assess = FALSE, half_lives = hl, r2 = hl_r2,
                similar = NA, n_reliable = 0,
                detail = paste0("Insufficient reliable terminal-phase data to estimate half-life. ",
                                "All dose groups have R^2 < 0.5 — terminal sampling too sparse for meaningful comparison. ",
                                "Elimination similarity cannot be assessed.")))
  }
  # Similarity: coefficient of variation across groups < 30% (require >= 2 reliable groups)
  similar <- NA
  if (n_reliable >= 2) {
    cv <- sd(valid) / mean(valid)
    similar <- cv < 0.30
  }
  # Build detail
  detail_lines <- c(
    "=== Terminal-phase half-life by dose group ==="
  )
  for (g in groups) {
    if (!is.na(hl[g])) {
      status <- if (isTRUE(hl_reliable[g])) "reliable" else "UNRELIABLE (R^2 too low — excluded from comparison)"
      detail_lines <- c(detail_lines,
        sprintf("  Dose %s: t1/2 = %.3g  (R^2 = %.2f, %s)", g, hl[g], hl_r2[g], status))
    } else {
      detail_lines <- c(detail_lines,
        sprintf("  Dose %s: t1/2 = N/A (insufficient terminal data)", g))
    }
  }
  if (!is.na(similar)) {
    cv <- sd(valid) / mean(valid)
    detail_lines <- c(detail_lines,
      sprintf("  Between-group CV of reliable t1/2 = %.0f%%  ->  %s",
              cv * 100, ifelse(similar, "similar elimination (dose-independent CL)",
                               "DIFFERENT elimination across doses (dose-dependent CL)"))
    )
  } else {
    detail_lines <- c(detail_lines,
      sprintf("  Only %d/%d dose group(s) had reliable terminal fits (R^2 >= 0.5) — elimination similarity cannot be assessed.",
              n_reliable, length(groups))
    )
  }
  list(
    has_assess = TRUE,
    half_lives = hl,
    r2 = hl_r2,
    reliable_mask = hl_reliable,
    similar = similar,
    n_reliable = n_reliable,
    detail = paste(detail_lines, collapse = "\n")
  )
}

elim_result <- screen_elimination(d_obs_plot)

# ---- First-dose terminal-phase half-life (uses TREL as x) ----
# Preferred over the all-dose estimate when the study is multi-dose because
# accumulation masks the true terminal phase. estimate_halflife() is now defined.
if (n_first > 0 && "DOSE_GROUP" %in% names(first_norm)) {
  groups_f <- levels(first_norm$DOSE_GROUP)
  hl_f <- c(); hl_r2_f <- c(); hl_rel_f <- c()
  for (g in groups_f) {
    sub <- first_norm %>% filter(DOSE_GROUP == g)
    res <- estimate_halflife(sub$TREL, sub$DV_NORM_FIRST)
    hl_f <- c(hl_f, if (is.na(res$half_life)) NA else res$half_life)
    hl_r2_f <- c(hl_r2_f, if (is.na(res$r2)) NA else res$r2)
    hl_rel_f <- c(hl_rel_f, isTRUE(res$reliable))
  }
  names(hl_f) <- groups_f; names(hl_r2_f) <- groups_f; names(hl_rel_f) <- groups_f
  valid_f <- hl_f[hl_rel_f]
  n_rel_f <- sum(hl_rel_f)
  similar_f <- NA
  if (n_rel_f >= 2) similar_f <- (sd(valid_f) / mean(valid_f)) < 0.30
  dlines <- c("=== First-Dose terminal-phase half-life by dose group ===")
  for (g in groups_f) {
    if (!is.na(hl_f[g])) {
      st <- if (isTRUE(hl_rel_f[g])) "reliable" else "UNRELIABLE (R^2 too low)"
      dlines <- c(dlines, sprintf("  Dose %s: t1/2 = %.3g (R^2 = %.2f, %s)", g, hl_f[g], hl_r2_f[g], st))
    } else {
      dlines <- c(dlines, sprintf("  Dose %s: t1/2 = N/A (insufficient terminal data)", g))
    }
  }
  if (!is.na(similar_f)) {
    cv <- sd(valid_f) / mean(valid_f)
    dlines <- c(dlines, sprintf("  Between-group CV of reliable t1/2 = %.0f%% -> %s",
                                cv * 100, ifelse(similar_f, "similar elimination (dose-independent CL)",
                                                 "DIFFERENT elimination across doses (dose-dependent CL)")))
  } else {
    dlines <- c(dlines, sprintf("  Only %d/%d dose group(s) had reliable terminal fits — first-dose elimination similarity cannot be assessed.",
                                n_rel_f, length(groups_f)))
  }
  firstdose_elim <- list(similar = similar_f, n_reliable = n_rel_f, detail = paste(dlines, collapse = "\n"),
                         has_assess = (n_rel_f >= 1), half_lives = hl_f, r2 = hl_r2_f, reliable_mask = hl_rel_f)
  cat("\n--- First-Dose Elimination Detail ---\n")
  cat(firstdose_elim$detail)
  cat("\n")
}

# ---- 9c. Dose-normalized exposure similarity (linear PK verdict) ----
# Synthesise the lag / TMDD / elimination findings into a single exposure-
# similarity verdict that is directly useful for model structuring.
#   Linear PK  : dose-normalized curves overlap (TMDD ratio <= 2.0) AND
#                (elimination is similar OR elimination is unassessable due to sparse data).
#   Nonlinear  : either TMDD ratio > 2.0 OR reliable elimination data shows dose-dependent CL.
n_groups <- length(unique(d_obs_plot$DOSE_GROUP))
exposure_similar <- NA
linear_pk <- NA
exposure_detail <- ""
if (n_groups >= 2) {
  tmdd_flag <- tmdd_result$has_tmdd
  # elim_flag: TRUE only when elimination is RELIABLY assessed AND shows dose-dependent CL.
  # When similar is NA (unreliable/sparse data), we do NOT penalize — we just note it.
  elim_flag  <- isTRUE(elim_result$similar == FALSE)
  linear_pk <- !(tmdd_flag || elim_flag)
  exposure_similar <- linear_pk
  reasons <- c()
  if (tmdd_flag) reasons <- c(reasons, sprintf("dose-normalized exposure clearly separated across doses (low/high ratio = %.2f, fold diff = %.2f)",
                                                 tmdd_result$ratio, tmdd_result$fold_diff))
  if (elim_flag) reasons <- c(reasons, "terminal half-life differs reliably across doses (dose-dependent clearance)")
  if (length(reasons) == 0) {
    note <- if (is.na(elim_result$similar)) "(terminal elimination data too sparse for assessment)" else "(half-lives comparable)"
    exposure_detail <- paste0("Dose-normalized curves are close enough across dose groups ",
                              "(TMDD ratio = ", round(tmdd_result$ratio, 2),
                              ", fold diff = ", round(tmdd_result$fold_diff, 2),
                              ") ", note, " → residual spread within normal IIV, linear PK supported.")
  } else {
    note <- if (is.na(elim_result$similar)) " (elimination data insufficient — verdict based on TMDD screening only)" else ""
    exposure_detail <- paste0("Dose-normalized exposure is clearly separated across dose groups → nonlinear PK suspected. Reasons: ",
                              paste(reasons, collapse = "; "), ".", note)
  }
} else {
  exposure_detail <- "Only one dose group — exposure similarity across doses cannot be assessed."
  linear_pk <- NA
  exposure_similar <- NA
}

# ---- 10. Route detection ----
route_info <- "Unknown"
if (has_route) {
  route_vals <- unique(d$ROUTE[!is.na(d$ROUTE) & trimws(as.character(d$ROUTE)) != ""])
  route_info <- if (length(route_vals) > 0) paste(route_vals, collapse = "+") else "Unknown"
}

if (route_info == "Unknown") {
  if (has_evid) {
    dosing <- d %>% filter(!is.na(EVID) & EVID %in% c(1, 4) & !is.na(AMT) & AMT > 0)
  } else if (has_amt) {
    dosing <- d %>% filter(!is.na(AMT) & AMT > 0)
  } else if (has_cmt) {
    dosing <- d %>% filter(!is.na(CMT) & !is.na(AMT) & AMT > 0)
  } else {
    dosing <- data.frame()
  }

  obs_rows <- if (has_evid) {
    d %>% filter(is.na(EVID) | EVID == 0)
  } else if (has_mdv) {
    d %>% filter(!is.na(MDV) & MDV == 0)
  } else {
    d %>% filter(!is.na(DV))
  }

  if (has_cmt && nrow(dosing) > 0) {
    if (any(dosing$CMT == 2, na.rm = TRUE)) {
      route_info <- "Extravascular"
    } else if (nrow(obs_rows) > 0 &&
               any(obs_rows$CMT == 2, na.rm = TRUE) &&
               !any(obs_rows$CMT == 1, na.rm = TRUE)) {
      route_info <- "Extravascular"
    } else if (any(dosing$CMT == 1, na.rm = TRUE)) {
      dose_rows_cmt1 <- dosing %>% filter(!is.na(CMT) & CMT == 1)
      has_infusion <- (has_rate && any(dose_rows_cmt1$RATE > 0, na.rm = TRUE)) ||
                      (has_dur && any(dose_rows_cmt1$DUR > 0, na.rm = TRUE))
      route_info <- if (isTRUE(has_infusion)) "IV Infusion" else "IV Bolus"
    } else {
      route_info <- "Unknown"
    }
  } else if (nrow(dosing) > 0) {
    route_info <- "IV Bolus"
  }
}

# ---- 10b. Absorption lag detection (skip for IV routes) ----
# For intravenous administration, there is no absorption process, so lag/absorption
# detection is not applicable. Only extravascular (e.g. oral, SC) routes are evaluated.
is_iv_only <- grepl("IV|BOLUS|INFUS|INTRAVENOUS", toupper(route_info)) &&
              !grepl("SC|ORAL|EXTRAVASCULAR|PO|SUBQ", toupper(route_info))
if (is_iv_only) {
  lag_result <- list(
    has_lag = FALSE,
    lag_time = 0,
    detail = paste0(route_info, " administration — absorption lag not applicable (no absorption process)."),
    recommendation = ""
  )
} else {
  lag_result <- detect_lag(d_obs_plot)
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
cat("╠══════════════════════════════════════════════════════════════╣\n")
cat("║  Elimination (terminal-phase)                                ║\n")
if (elim_result$has_assess && elim_result$n_reliable > 0) {
  valid_hl <- elim_result$half_lives[!is.na(elim_result$half_lives)]
  reliable_hl <- elim_result$half_lives[isTRUE(elim_result$reliable_mask)]
  cat(sprintf("║    t1/2 (median reliable):%-34s ║\n",
              ifelse(length(reliable_hl) > 0, paste0(round(median(reliable_hl, na.rm = TRUE), 3)), "N/A")))
  cat(sprintf("║    Reliable groups:     %d/%d%-23s ║\n",
              elim_result$n_reliable, length(elim_result$half_lives), ""))
  cat(sprintf("║    t1/2 similar:        %-38s ║\n",
              ifelse(is.na(elim_result$similar),
                     "UNASSESSABLE (R^2 too low)",
                     ifelse(elim_result$similar, "YES (dose-independent CL)", "NO (dose-dependent CL)"))))
} else {
  cat(sprintf("║    %-59s ║\n", "t1/2: N/A (all fits unreliable R^2 < 0.5)"))
}
cat("╠══════════════════════════════════════════════════════════════╣\n")
cat("║  Dose-Normalized Exposure Similarity                         ║\n")
cat(sprintf("║    Linear PK:         %-38s ║\n",
            ifelse(is.na(linear_pk), "N/A (single dose group)",
                   ifelse(linear_pk, "YES ✓", "NO ⚠"))))
cat(sprintf("║    Exposure similar:  %-38s ║\n",
            ifelse(is.na(exposure_similar), "N/A",
                   ifelse(exposure_similar, "YES ✓", "NO ⚠"))))
cat("╠══════════════════════════════════════════════════════════════╣\n")
cat("║  Multi-Compartment Shape (semi-log curve)                     ║\n")
cat(sprintf("║    Multi-compartment: %-37s ║\n",
            ifelse(is.na(compartment_result$suspected), "N/A (insufficient data)",
                   ifelse(compartment_result$suspected, "YES ⚠", "NO ✓"))))
cat("╚══════════════════════════════════════════════════════════════╝\n")
cat("\n--- TMDD Detail ---\n")
cat(tmdd_result$detail)
cat("\n")
cat("\n--- Elimination Detail ---\n")
cat(elim_result$detail)
cat("\n")
cat("\n--- Exposure Similarity Verdict ---\n")
cat(exposure_detail)
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
  paste0("TMDD_FOLD_DIFF=", ifelse(is.na(tmdd_result$fold_diff), "NA", round(tmdd_result$fold_diff, 3))),
  paste0("TMDD_DETAIL=", gsub("\n", " | ", tmdd_result$detail)),
  paste0("HAS_ADA=", ifelse(has_ada, "YES", "NO")),
  # --- Elimination / half-life ---
  paste0("HAS_ELIM=", ifelse(elim_result$has_assess, "YES", "NO")),
  paste0("ELIM_HALFLIFE_SIMILAR=", ifelse(is.na(elim_result$similar), "NA", ifelse(elim_result$similar, "YES", "NO"))),
  paste0("ELIM_N_RELIABLE=", elim_result$n_reliable),
  paste0("ELIM_HALFLIFE_VALUES=", paste(sprintf("%s:%.4g", names(elim_result$half_lives), elim_result$half_lives), collapse = ", ")),
  paste0("ELIM_DETAIL=", gsub("\n", " | ", elim_result$detail)),
  # --- First-dose terminal-phase elimination (preferred for multi-dose) ---
  paste0("FIRSTDOSE_ELIM_HALFLIFE_SIMILAR=", ifelse(is.na(firstdose_elim$similar), "NA", ifelse(firstdose_elim$similar, "YES", "NO"))),
  paste0("FIRSTDOSE_ELIM_N_RELIABLE=", firstdose_elim$n_reliable),
  paste0("FIRSTDOSE_ELIM_HALFLIFE_VALUES=", paste(sprintf("%s:%.4g", names(firstdose_elim$half_lives), firstdose_elim$half_lives), collapse = ", ")),
  paste0("FIRSTDOSE_ELIM_DETAIL=", gsub("\n", " | ", firstdose_elim$detail)),
  paste0("MULTI_DOSE=", ifelse(is_multi_dose, "YES", "NO")),
  # --- Dose-normalized exposure similarity / linear PK verdict ---
  paste0("LINEAR_PK=", ifelse(is.na(linear_pk), "NA", ifelse(linear_pk, "YES", "NO"))),
  paste0("EXPOSURE_SIMILAR=", ifelse(is.na(exposure_similar), "NA", ifelse(exposure_similar, "YES", "NO"))),
  paste0("EXPOSURE_DETAIL=", exposure_detail),
  # --- Multi-compartment shape detection ---
  paste0("COMPARTMENT_SHAPE_SUSPECTED=", ifelse(is.na(compartment_result$suspected), "NA", ifelse(compartment_result$suspected, "YES", "NO"))),
  paste0("COMPARTMENT_SHAPE_DETAIL=", gsub("\n", " | ", compartment_result$detail))
), out_txt)
cat(sprintf(">>> Analysis written to: %s\n", out_txt))
