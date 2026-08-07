#!/usr/bin/env Rscript
# ============================================================
# Concentration-Time Curve Plots for PopPK Dataset
# ============================================================
# Usage: Rscript ct_curves_plot.R <csv_file> [output_prefix]
#
# Generates three panels:
#   1. Individual C-T curves (faceted by subject)
#   2. Population C-T curves stratified by dose group
#   3. Dose-normalized population C-T curves
# ============================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(gridExtra)
  library(scales)
})

args <- commandArgs(trailingOnly = TRUE)
csv_file   <- if (length(args) >= 1) args[1] else "dataset.csv"
out_prefix <- if (length(args) >= 2) args[2] else "ct_curves"

# ---- 1. Robust CSV read ----
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

# EVID / MDV availability
has_evid <- "EVID" %in% names(d)
has_mdv  <- "MDV"  %in% names(d)
has_route <- "ROUTE" %in% names(d)

# ---- 2b. Defensive numeric coercion ----
# NONMEM-style CSVs can be read with a column as character/factor when ANY row
# contains a stray non-numeric token (e.g. "Pending Reassay Selection" in DV).
# This would later break `DV / DOSE_ACTUAL`. Coerce the numeric columns up front.
numeric_cols <- c("DV", "TIME", "ID", if (!is.null(dose_col)) dose_col else character(0))
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

# ---- 3. Extract ACTUAL dose per observation (true dose normalization) ----
# Divide each individual's DV by THAT individual's ACTUAL administered dose
# (NOT a global maximum dose). Priority:
#   1) If a per-record DOSE column is populated on observation rows, use it directly.
#   2) Otherwise derive the actual dose per subject from dosing records (AMT/DOSE).
obs_mask <- if (has_evid) {
  is.na(d$EVID) | d$EVID == 0
} else if (has_mdv) {
  !is.na(d$MDV) & d$MDV == 0
} else {
  !is.na(d$DV) & !is.na(d$TIME) & d$TIME >= 0
}

dose_src <- NULL
if (!is.null(dose_col)) {
  if (has_dose) {
    n_obs      <- sum(obs_mask, na.rm = TRUE)
    n_obs_dose <- sum(obs_mask & !is.na(d$DOSE), na.rm = TRUE)
    if (n_obs > 0 && n_obs_dose > 0.5 * n_obs) {
      d <- d %>% mutate(DOSE_ACTUAL = DOSE)
      dose_src <- "DOSE_ACTUAL"
    }
  }
  if (is.null(dose_src)) {
    if (has_evid) {
      dose_rows <- d %>% filter(!is.na(EVID) & EVID %in% c(1, 4)) %>% filter(!is.na(.data[[dose_col]]))
    } else if (has_mdv) {
      dose_rows <- d %>% filter(!is.na(MDV) & MDV == 1) %>% filter(!is.na(.data[[dose_col]]))
    } else {
      dose_rows <- d %>% filter(!is.na(.data[[dose_col]]) & .data[[dose_col]] > 0)
    }
    if (nrow(dose_rows) > 0) {
      subj_dose <- dose_rows %>%
        group_by(ID) %>%
        summarise(DOSE_ACTUAL = max(.data[[dose_col]], na.rm = TRUE), .groups = "drop")
      d <- d %>% left_join(subj_dose, by = "ID")
      dose_src <- "DOSE_ACTUAL"
    }
  }
}
if (is.null(dose_src)) {
  d$DOSE_ACTUAL <- NA
} else if (!is.numeric(d[[dose_src]])) {
  d[[dose_src]] <- suppressWarnings(as.numeric(d[[dose_src]]))
}

# ---- 4. Filter to observation records ----
if (has_evid) {
  d_obs <- d %>% filter(is.na(EVID) | EVID == 0)
} else if (has_mdv) {
  d_obs <- d %>% filter(!is.na(MDV) & MDV == 0)
} else {
  d_obs <- d %>% filter(!is.na(DV) & !is.na(TIME) & TIME >= 0)
}
d_obs <- d_obs %>% filter(!is.na(DV) & DV > 0)

if (nrow(d_obs) == 0) {
  stop("No observation records found after filtering.")
}

n_subjects <- length(unique(d_obs$ID))

# Dose group (factor for coloring) = each individual's actual dose
if (!is.null(dose_col) && !all(is.na(d_obs$DOSE_ACTUAL))) {
  d_obs <- d_obs %>%
    mutate(DOSE_GROUP = factor(round(DOSE_ACTUAL, 2)))
} else {
  d_obs$DOSE_GROUP <- factor("All")
}

# ---- 5. Color palette ----
dose_colors <- c(
  "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3",
  "#FF7F00", "#FFFF33", "#A65628", "#F781BF"
)

# ---- 6. Panel 1: Individual C-T Curves ----
# Limit to first 16 subjects for readability
ids_to_plot <- sort(unique(d_obs$ID))
if (length(ids_to_plot) > 16) {
  ids_to_plot <- ids_to_plot[1:16]
}
d_ind <- d_obs %>% filter(ID %in% ids_to_plot)

p_individual <- ggplot(d_ind, aes(x = TIME, y = DV, group = ID)) +
  geom_line(alpha = 0.6, color = "steelblue") +
  geom_point(size = 1.5, color = "steelblue", alpha = 0.7) +
  facet_wrap(~ID, ncol = 4, scales = "free_y") +
  scale_y_log10(
    labels = function(x) format(x, scientific = FALSE, digits = 3, trim = TRUE),
    breaks = trans_breaks("log10", function(x) 10^x)
  ) +
  labs(
    title = "Individual Concentration-Time Curves",
    subtitle = paste0("First ", length(ids_to_plot), " of ", n_subjects, " subjects"),
    x = "Time",
    y = "Concentration"
  ) +
  theme_bw(base_size = 11) +
  theme(
    strip.background = element_rect(fill = "#F0F8FF"),
    strip.text = element_text(face = "bold", size = 9),
    panel.grid.minor = element_blank()
  )

# ---- 7. Panel 2: Population C-T by Dose Group ----
p_population <- ggplot(d_obs, aes(x = TIME, y = DV, color = DOSE_GROUP, group = DOSE_GROUP)) +
  geom_point(alpha = 0.25, size = 1) +
  stat_summary(fun = median, geom = "line", linewidth = 1.2, aes(group = DOSE_GROUP)) +
  scale_y_log10(
    labels = function(x) format(x, scientific = FALSE, digits = 3, trim = TRUE),
    breaks = trans_breaks("log10", function(x) 10^x)
  ) +
  scale_color_manual(values = dose_colors, name = "Dose") +
  scale_fill_manual(values = dose_colors, name = "Dose") +
  labs(
    title = "Population Concentration-Time Curves by Dose",
    subtitle = paste0("N = ", n_subjects, " subjects  |  Median"),
    x = "Time",
    y = "Concentration"
  ) +
  theme_bw(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "right",
    legend.title = element_text(size = 10, face = "bold")
  )

# ---- 8. Panel 3: Dose-Normalized Population C-T ----
if (!is.null(dose_col) && !all(is.na(d_obs$DOSE_ACTUAL))) {
  d_norm <- d_obs %>%
    mutate(DV_NORM = DV / DOSE_ACTUAL) %>%
    filter(DV_NORM > 0 & !is.na(DV_NORM))

  p_normalized <- ggplot(d_norm, aes(x = TIME, y = DV_NORM, color = DOSE_GROUP, group = DOSE_GROUP)) +
    geom_point(alpha = 0.25, size = 1) +
    stat_summary(fun = median, geom = "line", linewidth = 1.2) +
    scale_y_log10(
      labels = function(x) format(x, scientific = FALSE, digits = 3, trim = TRUE),
      breaks = trans_breaks("log10", function(x) 10^x)
    ) +
    scale_color_manual(values = dose_colors, name = "Dose") +
    scale_fill_manual(values = dose_colors, name = "Dose") +
    labs(
      title = "Dose-Normalized Population C-T Curves",
      subtitle = paste0("N = ", n_subjects, " subjects  |  Median  |  Semi-log y"),
      x = "Time",
      y = "Dose-Normalized Concentration"
    ) +
    theme_bw(base_size = 12) +
    theme(
      panel.grid.minor = element_blank(),
      legend.position = "right",
      legend.title = element_text(size = 10, face = "bold")
    )
} else {
  # No dose column: show message plot
  p_normalized <- ggplot() +
    annotate("text", x = 0.5, y = 0.5,
             label = "No DOSE/AMT column found\nDose-normalized plot not available",
             size = 5, hjust = 0.5) +
    theme_void()
}

# ---- 8b. Route / categorical faceted C-T plots ----
facet_candidates <- c("ROUTE", "SEX", "STUDY", "ADA", "BQL", "TYPE",
                      "RACE", "GROUP", "COHORT", "TREATMENT")
valid_facets <- intersect(facet_candidates, names(d_obs))
valid_facets <- valid_facets[sapply(valid_facets, function(col) {
  vals <- d_obs[[col]]
  vals <- vals[!is.na(vals) & trimws(as.character(vals)) != ""]
  length(unique(vals)) >= 2 && length(vals) >= 10
})]
if (length(valid_facets) > 6) valid_facets <- valid_facets[1:6]

has_norm_plot <- !is.null(dose_col) && !all(is.na(d_obs$DOSE_ACTUAL))

for (facet_col in valid_facets) {
  p_pop_facet <- ggplot(d_obs,
    aes(x = TIME, y = DV, color = DOSE_GROUP, group = DOSE_GROUP)) +
    geom_point(alpha = 0.25, size = 1) +
    stat_summary(fun = median, geom = "line", linewidth = 1.2) +
    facet_wrap(as.formula(paste("~", facet_col)), scales = "free_y") +
    scale_y_log10(
      labels = function(x) format(x, scientific = FALSE, digits = 3, trim = TRUE),
      breaks = trans_breaks("log10", function(x) 10^x)
    ) +
    scale_color_manual(values = dose_colors, name = "Dose") +
    scale_fill_manual(values = dose_colors, name = "Dose") +
    labs(
      title = paste("Population C-T by", facet_col),
      subtitle = paste0("N = ", n_subjects, " subjects  |  Median"),
      x = "Time",
      y = "Concentration"
    ) +
    theme_bw(base_size = 11) +
    theme(panel.grid.minor = element_blank(), legend.position = "bottom")

  facet_plots <- list(p_pop_facet)
  if (has_norm_plot) {
    d_norm_facet <- d_obs %>%
      mutate(DV_NORM = DV / DOSE_ACTUAL) %>%
      filter(DV_NORM > 0 & !is.na(DV_NORM))
    p_norm_facet <- ggplot(d_norm_facet,
      aes(x = TIME, y = DV_NORM, color = DOSE_GROUP, group = DOSE_GROUP)) +
      geom_point(alpha = 0.25, size = 1) +
      stat_summary(fun = median, geom = "line", linewidth = 1.2) +
      facet_wrap(as.formula(paste("~", facet_col)), scales = "free_y") +
      scale_y_log10(
        labels = function(x) format(x, scientific = FALSE, digits = 3, trim = TRUE),
        breaks = trans_breaks("log10", function(x) 10^x)
      ) +
      scale_color_manual(values = dose_colors, name = "Dose") +
      scale_fill_manual(values = dose_colors, name = "Dose") +
      labs(
        title = paste("Dose-Normalized C-T by", facet_col),
        subtitle = paste0("N = ", n_subjects, " subjects  |  Median"),
        x = "Time",
        y = "Dose-Normalized Concentration"
      ) +
      theme_bw(base_size = 11) +
      theme(panel.grid.minor = element_blank(), legend.position = "bottom")
    facet_plots[[2]] <- p_norm_facet
  }

  out_facet <- paste0(out_prefix, "_by_", tolower(gsub("[^A-Za-z0-9]+", "_", facet_col)), ".png")
  png(out_facet, width = 14, height = if (length(facet_plots) > 1) 10 else 6,
      units = "in", res = 150)
  do.call(grid.arrange, c(facet_plots, ncol = 1))
  dev.off()
  cat(sprintf(">>> Faceted C-T plot saved: %s\n", out_facet))
}

# ---- 9. Save combined plot ----
out_png <- paste0(out_prefix, "_ct_curves.png")
png(out_png, width = 16, height = 14, units = "in", res = 150)
grid.arrange(
  p_individual, p_population, p_normalized,
  ncol = 1,
  heights = c(1.2, 1, 1),
  top = paste0("Concentration-Time Analysis  |  ", basename(csv_file), "  |  N = ", n_subjects)
)
dev.off()
cat(sprintf(">>> Combined C-T plot saved: %s\n", out_png))

# ---- 10. Save individual panels ----
ggsave(paste0(out_prefix, "_individual_ct.png"), p_individual, width = 12, height = 8, dpi = 150, bg = "white")
ggsave(paste0(out_prefix, "_population_ct.png"), p_population, width = 10, height = 6, dpi = 150, bg = "white")
if (!is.null(dose_col) && !all(is.na(d_obs$DOSE_ACTUAL))) {
  ggsave(paste0(out_prefix, "_dose_norm_ct.png"), p_normalized, width = 10, height = 6, dpi = 150, bg = "white")
}
cat(sprintf(">>> Individual panels saved: %s_*.png\n", out_prefix))

# ---- 11. Console summary ----
cat("\n")
cat("╔══════════════════════════════════════════════════════════════╗\n")
cat("║     Concentration-Time Curve Analysis Summary                ║\n")
cat("╠══════════════════════════════════════════════════════════════╣\n")
cat(sprintf("║  Subjects:            %-38d ║\n", n_subjects))
cat(sprintf("║  Observations:        %-38d ║\n", nrow(d_obs)))
cat(sprintf("║  Dose groups:         %-38s ║\n", paste(levels(d_obs$DOSE_GROUP), collapse = ", ")))
cat(sprintf("║  Dose column used:    %-38s ║\n", ifelse(is.null(dose_col), "N/A", dose_col)))
cat(sprintf("║  Time range:          %-38s ║\n", paste0(round(min(d_obs$TIME, na.rm = TRUE), 2), " - ", round(max(d_obs$TIME, na.rm = TRUE), 2))))
cat(sprintf("║  DV range:            %-38s ║\n", paste0(round(min(d_obs$DV, na.rm = TRUE), 2), " - ", round(max(d_obs$DV, na.rm = TRUE), 2))))
cat("╚══════════════════════════════════════════════════════════════╝\n")

# ---- 12. Write structured output ----
out_txt <- paste0(out_prefix, "_ct_summary.txt")
writeLines(c(
  paste0("SUBJECTS=", n_subjects),
  paste0("OBSERVATIONS=", nrow(d_obs)),
  paste0("DOSE_GROUPS=", paste(levels(d_obs$DOSE_GROUP), collapse = ", ")),
  paste0("DOSE_COLUMN=", ifelse(is.null(dose_col), "N/A", dose_col)),
  paste0("TIME_MIN=", round(min(d_obs$TIME, na.rm = TRUE), 4)),
  paste0("TIME_MAX=", round(max(d_obs$TIME, na.rm = TRUE), 4)),
  paste0("DV_MIN=", round(min(d_obs$DV, na.rm = TRUE), 4)),
  paste0("DV_MAX=", round(max(d_obs$DV, na.rm = TRUE), 4))
), out_txt)
cat(sprintf(">>> C-T summary written to: %s\n", out_txt))
