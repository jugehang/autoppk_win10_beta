args <- commandArgs(trailingOnly = TRUE)
run_id <- if (length(args) > 0) args[1] else "001"
data_hint <- if (length(args) > 1) args[2] else NULL
fig_dir <- if (length(args) > 2) args[3] else "Figures"

eta_file <- if (file.exists(paste0("run", run_id, ".ETA"))) {
  paste0("run", run_id, ".ETA")
} else if (file.exists(paste0("eta_cov", run_id))) {
  paste0("eta_cov", run_id)
} else {
  paste0("000", run_id, ".ETA")
}

if (!file.exists(eta_file)) {
  stop("ETA table not found: ", eta_file)
}

lines <- readLines(eta_file, warn = FALSE)
header_idx <- which(grepl("^\\s*ID\\s+ETA", lines))[1]
if (is.na(header_idx)) stop("Could not find ETA table header in ", eta_file)

headers <- strsplit(trimws(lines[header_idx]), "\\s+")[[1]]
data_lines <- lines[(header_idx + 1):length(lines)]
data_lines <- data_lines[trimws(data_lines) != ""]

dat <- read.table(text = data_lines, header = FALSE, stringsAsFactors = FALSE, fill = TRUE)
names(dat) <- headers
dat <- dat[grepl("^[0-9.Ee+-]+$", as.character(dat$ID)), ]
dat$ID <- as.numeric(dat$ID)
dat <- dat[!is.na(dat$ID), ]

eta_cols <- grep("^ETA[0-9]+$", names(dat), value = TRUE)
if (length(eta_cols) == 0) stop("No ETA columns found in ", eta_file)

mod <- readLines(paste0("run", run_id, ".mod"), warn = FALSE)
eta_map <- setNames(eta_cols, eta_cols)
for (line in mod) {
  m <- regexec("([A-Za-z][A-Za-z0-9_]*)\\s*=.*ETA\\s*\\(\\s*([0-9]+)\\s*\\)", line)
  parts <- regmatches(line, m)[[1]]
  if (length(parts) == 3) {
    eta_col <- paste0("ETA", parts[3])
    if (eta_col %in% eta_cols) eta_map[[eta_col]] <- parts[2]
  }
}

# Locate the modeling dataset. The ETA table only contains ID + ETA columns, so
# covariates must be merged back from the dataset by subject ID.
data_path <- NULL
if (!is.null(data_hint)) {
  candidate <- data_hint
  if (!grepl("^/", candidate) && file.exists(file.path(getwd(), candidate))) {
    candidate <- file.path(getwd(), candidate)
  }
  if (file.exists(candidate)) data_path <- candidate
}

for (line in mod) {
  m <- regexec("^\\s*\\$DATA\\s+(\\S+)", line)
  parts <- regmatches(line, m)[[1]]
  if (length(parts) == 2) {
    candidate <- parts[2]
    if (!grepl("^/", candidate) && file.exists(file.path(getwd(), candidate))) {
      candidate <- file.path(getwd(), candidate)
    }
    if (file.exists(candidate)) {
      data_path <- candidate
      break
    }
  }
}

if (is.null(data_path) && file.exists("project_config.json")) {
  cfg <- paste(readLines("project_config.json", warn = FALSE), collapse = "\n")
  m <- regexec('"data_file"\\s*:\\s*"([^"]+)"', cfg)
  parts <- regmatches(cfg, m)[[1]]
  if (length(parts) == 2 && file.exists(parts[2])) {
    data_path <- parts[2]
  } else if (length(parts) == 2 && file.exists(file.path(getwd(), parts[2]))) {
    data_path <- file.path(getwd(), parts[2])
  }
}

if (is.null(data_path)) {
  for (candidate in c("NM_dat_new.csv", "NM_dat.csv", "dataset.csv", "data.csv")) {
    if (file.exists(candidate)) {
      data_path <- candidate
      break
    }
  }
}

if (is.null(data_path)) stop("Could not locate the modeling dataset for ETA-covariate screening")

raw <- read.csv(data_path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = c("NA", "", "."))
raw_names <- toupper(names(raw))
names(raw) <- raw_names
if (!"ID" %in% names(raw)) stop("Dataset has no ID column: ", data_path)
raw$ID <- as.numeric(raw$ID)
raw <- raw[!is.na(raw$ID), ]

excluded <- c(
  "C", "ID", "TIME", "NTIME", "DV", "AMT", "RATE", "DUR", "CMT",
  "MDV", "EVID", "BQL", "TYPE", "CYCLE", "DAY", "OCC", "II", "ADDL",
  "SS", "LDOS", "IPRED", "PRED", "RES", "WRES", "CWRES", "IWRES", "IRES"
)
known_continuous <- c("WT", "AGE", "BSA", "HB", "ALB", "CLCR", "EGFR", "BMI", "DOSE")
known_categorical <- c("SEX", "STUDY", "STUD", "RACE", "GROUP", "FORM", "ROUTE")

continuous_covs <- intersect(known_continuous, setdiff(names(raw), excluded))
categorical_covs <- intersect(known_categorical, setdiff(names(raw), excluded))

for (col in setdiff(names(raw), c(excluded, continuous_covs, categorical_covs))) {
  vals <- raw[[col]]
  nums <- suppressWarnings(as.numeric(as.character(vals)))
  n_numeric <- sum(!is.na(nums))
  n_unique_numeric <- length(unique(nums[!is.na(nums)]))
  if (n_numeric > 0 && n_unique_numeric > 6) {
    continuous_covs <- c(continuous_covs, col)
  } else if (length(unique(vals[!is.na(vals) & vals != ""])) > 1) {
    categorical_covs <- c(categorical_covs, col)
  }
}

all_covs <- unique(c(continuous_covs, categorical_covs))
if (length(all_covs) == 0) stop("No usable covariates found in dataset: ", data_path)

# Keep one covariate row per subject, preferring the first non-missing value.
cov_sub <- raw[, c("ID", all_covs), drop = FALSE]
cov_sub <- cov_sub[order(cov_sub$ID), ]
cov_sub_split <- split(cov_sub, cov_sub$ID)
one_per_id <- do.call(rbind, lapply(cov_sub_split, function(x) {
  out <- x[1, , drop = FALSE]
  for (nm in all_covs) {
    vals <- x[[nm]]
    vals <- vals[!is.na(vals) & vals != ""]
    if (length(vals) > 0) out[[nm]] <- vals[1]
  }
  out
}))
rownames(one_per_id) <- NULL

dat <- merge(dat, one_per_id, by = "ID", all.x = TRUE)
continuous_covs <- intersect(continuous_covs, names(dat))
categorical_covs <- intersect(categorical_covs, names(dat))

results <- list()
for (eta_col in eta_cols) {
  eta_param <- eta_map[[eta_col]]
  for (cov in continuous_covs) {
    eta_num <- suppressWarnings(as.numeric(dat[[eta_col]]))
    cov_num <- suppressWarnings(as.numeric(dat[[cov]]))
    valid <- is.finite(eta_num) & is.finite(cov_num)
    if (sum(valid) < 3 || length(unique(cov_num[valid])) < 2) next
    fit <- lm(eta_num[valid] ~ cov_num[valid])
    s <- summary(fit)
    if (nrow(s$coefficients) < 2) next
    estimate <- s$coefficients[2, 1]
    p_value <- s$coefficients[2, 4]
    cor_value <- sqrt(s$r.squared) * sign(estimate)
    results[[length(results) + 1]] <- data.frame(
      ETA = eta_col,
      Parameter = eta_param,
      Covariate = cov,
      Type = "Continuous",
      Estimate = estimate,
      Correlation = cor_value,
      P.Value = p_value,
      Significant = p_value < 0.05,
      stringsAsFactors = FALSE
    )
  }
  for (cov in categorical_covs) {
    eta_num <- suppressWarnings(as.numeric(dat[[eta_col]]))
    cat_val <- as.character(dat[[cov]])
    valid <- is.finite(eta_num) & !is.na(cat_val) & cat_val != ""
    if (sum(valid) < 3 || length(unique(cat_val[valid])) < 2) next
    kt <- kruskal.test(eta_num[valid], as.factor(cat_val[valid]))
    results[[length(results) + 1]] <- data.frame(
      ETA = eta_col,
      Parameter = eta_param,
      Covariate = cov,
      Type = "Categorical",
      Estimate = NA,
      Correlation = NA,
      P.Value = kt$p.value,
      Significant = kt$p.value < 0.05,
      stringsAsFactors = FALSE
    )
  }
}

if (length(results) == 0) stop("No usable ETA-covariate comparisons could be computed.")
res <- do.call(rbind, results)
res$P.Value <- round(res$P.Value, 6)
res$Estimate <- ifelse(is.na(res$Estimate), "-", round(res$Estimate, 6))
res$Correlation <- ifelse(is.na(res$Correlation), "-", round(res$Correlation, 4))

summary_tsv <- paste0("eta_covariate_screening_", run_id, ".tsv")
write.table(res, summary_tsv, sep = "\t", row.names = FALSE, quote = FALSE)

if (!requireNamespace("ggplot2", quietly = TRUE) ||
    !requireNamespace("dplyr", quietly = TRUE) ||
    !requireNamespace("tidyr", quietly = TRUE)) {
  cat("Skipping plots: ggplot2/dplyr/tidyr not installed.\n")
  quit(save = "no", status = 0)
}

library(ggplot2)
library(dplyr)
library(tidyr)
library(gridExtra)

plot_covs <- c(continuous_covs, categorical_covs)
if (length(plot_covs) > 0) {
  long <- dat %>%
    select(all_of(c("ID", eta_cols, plot_covs))) %>%
    pivot_longer(all_of(eta_cols), names_to = "ETA", values_to = "ETA.Value") %>%
    mutate(Parameter = eta_map[ETA])

  plot_list <- list()
  for (cov in continuous_covs) {
    p <- ggplot(long, aes(.data[[cov]], ETA.Value)) +
      geom_point(alpha = 0.35, size = 1.5, color = "#1f6feb") +
      geom_smooth(method = "lm", se = TRUE, color = "#d94f70", fill = "#d94f7040", linewidth = 0.7) +
      facet_wrap(~Parameter, scales = "free_y", ncol = min(2, length(unique(long$Parameter)))) +
      labs(title = paste0("ETA vs ", cov, " (linear regression)"), x = cov, y = "EBE") +
      theme_minimal(base_size = 9) +
      theme(plot.title = element_text(face = "bold"))
    plot_list[[length(plot_list) + 1]] <- p
  }
  for (cov in categorical_covs) {
    p <- ggplot(long, aes(as.factor(.data[[cov]]), ETA.Value, fill = as.factor(.data[[cov]]))) +
      geom_boxplot(alpha = 0.65, outlier.alpha = 0.45) +
      geom_jitter(width = 0.12, alpha = 0.25, size = 1.2) +
      facet_wrap(~Parameter, scales = "free_y", ncol = min(2, length(unique(long$Parameter)))) +
      labs(title = paste0("ETA by ", cov, " (Kruskal-Wallis)"), x = cov, y = "EBE") +
      theme_minimal(base_size = 9) +
      theme(plot.title = element_text(face = "bold"), legend.position = "none")
    plot_list[[length(plot_list) + 1]] <- p
  }

  if (length(plot_list) > 0) {
    dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
    png_file <- file.path(fig_dir, paste0("ETA_Covariate_Screening_", run_id, ".png"))
    png(png_file, width = 1600, height = 900, res = 120)
    ncol <- min(3, max(1, ceiling(sqrt(length(plot_list)))))
    do.call(grid.arrange, c(plot_list, list(ncol = ncol)))
    dev.off()
    cat("Plot written:", png_file, "\n")
  }
}

cat("ETA covariate screening summary written:", summary_tsv, "\n")
