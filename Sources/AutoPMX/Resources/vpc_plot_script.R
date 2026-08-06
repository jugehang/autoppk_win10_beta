# =================================================================
# Duxact PopPK 自动化诊断站 - VPC 绘图引擎 V4.3
# 功能：物理级列名去噪 + 原始数据直连 + 剂量组分面对齐 + 直观数字轴
# =================================================================
library(tidyverse)
library(jsonlite)
library(scales)

# --- 1. 物理级列名清洗函数：确保 dplyr 流程不因空列名崩溃 ---
robust_clean_names <- function(df) {
  df <- df[, !is.na(colnames(df)) & colnames(df) != "", drop = FALSE]
  clean_names <- trimws(gsub("[\"\\\n]", "", colnames(df)))
  valid_idx <- which(clean_names != "")
  df <- df[, valid_idx, drop = FALSE]
  colnames(df) <- make.unique(clean_names[valid_idx])
  return(df)
}

# --- 2. 环境准备与配置加载 ---
args <- commandArgs(trailingOnly = TRUE)
mod_index <- if(length(args) > 0) args[1] else "41"
mod_file <- paste0("run", mod_index, ".mod")
vpc_res_path <- file.path(paste0("vpc_dir_", mod_index), "vpc_results.csv")
config_file <- "project_config.json"

if (!file.exists(vpc_res_path)) stop("❌ 找不到结果文件")

# 加载配置（缺失时使用内置默认值）
if (file.exists(config_file)) {
  proj_cfg <- fromJSON(config_file)
} else {
  message("⚠️ project_config.json 未找到，使用内置默认配置")
  proj_cfg <- list(grouping = list(factor = "STUDY", labels = list()))
}
configured_factor <- proj_cfg$grouping$factor
group_factor <- configured_factor
group_labels <- proj_cfg$grouping$labels
group_labels_vec <- unlist(group_labels)
resolve_actual_col <- function(df, wanted) {
  upper <- toupper(colnames(df))
  idx <- match(toupper(wanted), upper)
  if (is.na(idx)) NA_character_ else colnames(df)[idx]
}

route_label <- function(values) {
  values <- as.character(values)
  out <- values
  out[values %in% c("1", "IV", "IV INFUSION", "INTRAVENOUS", "I.V.")] <- "IV"
  out[values %in% c("2", "SC", "SQ", "SUBCUTANEOUS", "S.C.")] <- "SC"
  out[values %in% c("3", "ORAL", "PO")] <- "Oral"
  out
}

dose_unit_text <- function() {
  unit <- "mg"
  if (!is.null(proj_cfg$units$dose)) unit <- as.character(proj_cfg$units$dose)
  data_key <- basename(raw_data_path)
  if (!is.null(proj_cfg$units_data[[data_key]]$dose)) {
    unit <- as.character(proj_cfg$units_data[[data_key]]$dose)
  }
  unit
}

dose_label <- function(values) {
  values <- unique(as.character(values[!is.na(values) & values != ""]))
  if (length(values) == 0) return("Overall")
  nums <- suppressWarnings(as.numeric(values))
  if (!any(is.na(nums))) {
    fmt_num <- function(x) format(x, scientific = FALSE, trim = TRUE, drop0trailing = TRUE)
    if (length(nums) > 1) {
      return(paste0("Dose ", fmt_num(min(nums)), "-", fmt_num(max(nums)), " ", dose_unit_text()))
    }
    return(paste0("Dose ", fmt_num(nums[1]), " ", dose_unit_text()))
  }
  paste0("Dose ", paste(values, collapse = "/"), " ", dose_unit_text())
}

label_stratum <- function(values, factor) {
  values <- as.character(values)
  factor <- toupper(factor)
  if (factor == "ROUTE") return(route_label(values))
  if (factor == "DOSE") return(dose_label(values))
  if (length(group_labels_vec) > 0 && toupper(configured_factor) == factor) {
    mapped <- unname(group_labels_vec[values])
    out <- ifelse(is.na(mapped), values, as.character(mapped))
    return(as.character(out))
  }
  values
}

build_strata_label <- function(primary_factor, primary_values,
                               secondary_factor = NA_character_,
                               secondary_values = NULL) {
  primary_factor <- toupper(primary_factor)
  secondary_factor <- if (is.na(secondary_factor)) NA_character_ else toupper(secondary_factor)
  primary_values <- unique(as.character(primary_values[!is.na(primary_values) & primary_values != ""]))
  if (length(primary_values) == 0) return("Overall")

  if (primary_factor == "DOSE") {
    label <- dose_label(primary_values)
    if (!is.na(secondary_factor) && secondary_factor == "ROUTE" && !is.null(secondary_values)) {
      routes <- sort(unique(route_label(secondary_values)))
      label <- paste0(label, " (", paste(routes, collapse = "+"), ")")
    }
    return(label)
  }

  if (primary_factor == "ROUTE") {
    label <- paste(sort(unique(route_label(primary_values))), collapse = "+")
    if (!is.na(secondary_factor) && secondary_factor == "DOSE" && !is.null(secondary_values)) {
      label <- paste0(label, " (", dose_label(secondary_values), ")")
    }
    return(label)
  }

  label_stratum(primary_values, primary_factor)
}

# --- 3. 解析 .mod 获取原始数据散点 [cite: 110, 118] ---
mod_lines <- readLines(mod_file, warn = FALSE)
data_line <- mod_lines[grep("^\\$DATA", mod_lines, ignore.case = TRUE)][1]
raw_data_path <- str_match(data_line, "(?i)^\\$DATA\\s+([^\\s,]+)")[2]
raw_data_path <- gsub("[\"']", "", raw_data_path)

message(paste0(">>> 🚀 正在读取原始数据集散点: ", raw_data_path))

raw_obs_data <- read.csv(raw_data_path, check.names = FALSE, stringsAsFactors = FALSE)
raw_obs_clean <- robust_clean_names(raw_obs_data)
time_col <- resolve_actual_col(raw_obs_clean, "TIME")
if (is.na(time_col)) time_col <- resolve_actual_col(raw_obs_clean, "TAD")
dv_col <- resolve_actual_col(raw_obs_clean, "DV")
if (is.na(dv_col)) dv_col <- resolve_actual_col(raw_obs_clean, "CONC")
raw_obs_clean <- raw_obs_clean %>%
  mutate(
    TIME_VAL = as.numeric(as.character(!!sym(time_col))),
    DV_VAL   = as.numeric(as.character(!!sym(dv_col)))
  ) %>%
  filter(!is.na(DV_VAL), DV_VAL > 0)

# 使用 PsN 实际分层列，缺失时再从 $INPUT / 配置里挑选可用列。
input_line <- mod_lines[grep("^\\$INPUT", mod_lines, ignore.case = TRUE)][1]
input_tokens <- if (!is.na(input_line)) strsplit(gsub("(?i)^\\$INPUT\\s+", "", input_line), "\\s+")[[1]] else character(0)
input_cols <- setdiff(toupper(sub("=.*", "", input_tokens)), c("C", "INPUT"))

configured_group <- c(
  if (!is.null(proj_cfg$psn_settings$vpc_stratify)) as.character(proj_cfg$psn_settings$vpc_stratify),
  if (!is.null(proj_cfg$psn_settings$stratify_var)) as.character(proj_cfg$psn_settings$stratify_var),
  if (!is.null(proj_cfg$grouping$factor)) as.character(proj_cfg$grouping$factor),
  "STUDY"
)
priority_group <- c("DOSE", "STUDY", "STUDYID", "STUDYNO", "ARM",
                    "ROUTE", "TRT", "RACE", "REGION", "SEX", "ADA", "TYPE", "CMT", "EVID")
pick_group <- function(candidates, cols) {
  parts <- trimws(unlist(strsplit(as.character(candidates), ",")))
  hit <- parts[toupper(parts) %in% cols]
  if (length(hit) > 0) toupper(hit[1]) else NA_character_
}

lines <- readLines(vpc_res_path, warn = FALSE)
strata_headers <- grep("VPC results strata", lines, ignore.case = TRUE, value = TRUE)
group_factor_upper <- NA_character_
group_factor <- NA_character_
if (length(strata_headers) > 0) {
  m <- str_match(strata_headers[1], "strata\\s+([A-Za-z0-9_]+)\\s*=")
  if (!is.na(m[2])) group_factor_upper <- toupper(m[2])
}
if (is.na(group_factor_upper) || !(group_factor_upper %in% input_cols)) {
  group_factor_upper <- pick_group(configured_group, input_cols)
}
if (is.na(group_factor_upper)) {
  group_factor_upper <- pick_group(priority_group, input_cols)
}
if (is.na(group_factor_upper)) {
  message("⚠️ 模型 $INPUT 中没有可用分层列，VPC 将按 Overall 绘制。")
} else {
  message(paste0(">>> VPC 分层变量: ", group_factor_upper))
}

group_factor <- resolve_actual_col(raw_obs_clean, group_factor_upper)
if (!is.na(group_factor_upper) && is.na(group_factor)) {
  message("⚠️ 模型声明的分层列未出现在原始数据中，VPC 将按 Overall 绘制。")
  group_factor_upper <- NA_character_
}

if (is.na(group_factor_upper)) {
  raw_obs_clean <- raw_obs_clean %>% mutate(STRAT_ID = "Overall")
} else {
  raw_obs_clean <- raw_obs_clean %>% mutate(STRAT_ID = as.character(!!sym(group_factor)))
}
raw_obs_clean <- raw_obs_clean %>%
  mutate(STRAT_LABEL = label_stratum(STRAT_ID, group_factor_upper))

vpctab_path <- file.path(paste0("vpc_dir_", mod_index), paste0("vpctab", mod_index))
strata_value_map <- NULL
strata_label_map <- NULL
raw_label_map <- NULL
if (file.exists(vpctab_path) && !is.na(group_factor_upper)) {
  vpctab <- read.csv(vpctab_path, check.names = FALSE, stringsAsFactors = FALSE)
  primary_col <- resolve_actual_col(vpctab, group_factor_upper)
  secondary_col <- if (group_factor_upper == "DOSE") {
    resolve_actual_col(vpctab, "ROUTE")
  } else if (group_factor_upper == "ROUTE") {
    resolve_actual_col(vpctab, "DOSE")
  } else {
    NA_character_
  }
  secondary_factor_upper <- if (group_factor_upper == "DOSE") "ROUTE" else if (group_factor_upper == "ROUTE") "DOSE" else NA_character_
  strata_secondary <- list()
  if (!is.na(secondary_factor_upper)) {
    raw_id_col <- resolve_actual_col(raw_obs_clean, "ID")
    raw_secondary_col <- resolve_actual_col(raw_obs_clean, secondary_factor_upper)
    if (!is.na(raw_id_col) && !is.na(raw_secondary_col) && "ID" %in% names(vpctab)) {
      raw_secondary <- unique(raw_obs_clean[c(raw_id_col, raw_secondary_col)])
      names(raw_secondary) <- c("ID", "SECONDARY")
      id_strata <- unique(vpctab[c("ID", "strata_no")])
      sec_strata <- merge(id_strata, raw_secondary, by = "ID", all.x = TRUE)
      sec_strata <- sec_strata[!is.na(sec_strata$SECONDARY) & sec_strata$SECONDARY != "", , drop = FALSE]
      if (nrow(sec_strata) > 0) {
        strata_secondary <- split(as.character(sec_strata$SECONDARY), as.character(sec_strata$strata_no))
      }
    }
  }
  if ("strata_no" %in% names(vpctab) && !is.na(primary_col)) {
    keep_cols <- c("strata_no", primary_col)
    if (!is.na(secondary_col)) keep_cols <- c(keep_cols, secondary_col)
    map_df <- unique(vpctab[keep_cols])
    names(map_df) <- c("strata_no", "PRIMARY", if (!is.na(secondary_col)) "SECONDARY")
    map_df <- map_df[!is.na(map_df$PRIMARY) & map_df$PRIMARY != "", , drop = FALSE]
    if (nrow(map_df) > 0) {
      strata_label_map <- vapply(
        split(map_df, as.character(map_df$strata_no)),
        function(part) {
          build_strata_label(
            group_factor_upper,
            part$PRIMARY,
            secondary_factor_upper,
            if (!is.null(strata_secondary[[as.character(part$strata_no[1])]])) {
              strata_secondary[[as.character(part$strata_no[1])]]
            } else if (!is.na(secondary_col)) {
              part$SECONDARY
            } else {
              NULL
            }
          )
        },
        character(1)
      )
      primary_to_strata <- setNames(as.character(map_df$strata_no), as.character(map_df$PRIMARY))
      raw_label_map <- setNames(strata_label_map[primary_to_strata], names(primary_to_strata))
      strata_value_map <- setNames(as.character(map_df$PRIMARY), as.character(map_df$strata_no))
    }
  }
}
if (!is.null(raw_label_map)) {
  mapped <- unname(raw_label_map[raw_obs_clean$STRAT_ID])
  raw_obs_clean$STRAT_LABEL <- ifelse(is.na(mapped), raw_obs_clean$STRAT_LABEL, mapped)
}

# --- 4. 深度解析 vpc_results.csv (统计线) [cite: 110, 114] ---
header_indices <- grep("median.idv", lines)
strata_pattern <- if (!is.na(group_factor_upper)) paste0("strata\\s+", group_factor_upper, "\\s*=\\s*([0-9.]+)") else NULL
strata_indices <- if (!is.null(strata_pattern)) grep(strata_pattern, lines, ignore.case = TRUE) else integer(0)
# 核心修正：锁定第一个诊断信息位置，解决 6 elements 警告
diag_indices <- grep("Diagnostics VPC", lines)
global_end <- if(length(diag_indices) > 0) diag_indices[1] else length(lines)

all_strata_stats <- list()
for (i in seq_along(header_indices)) {
  start_ln <- header_indices[i]
  next_ln <- if (i < length(header_indices)) header_indices[i+1] else global_end

  prev_strata_ln <- tail(strata_indices[strata_indices < start_ln], 1)
  current_id <- if (length(prev_strata_ln) > 0) {
    as.character(str_match(lines[prev_strata_ln], strata_pattern)[2])
  } else "Overall"
  current_value <- if (!is.null(strata_value_map) && current_id %in% names(strata_value_map)) {
    unname(strata_value_map[current_id])
  } else current_id
  current_label <- if (!is.null(strata_label_map) && current_id %in% names(strata_label_map)) {
    unname(strata_label_map[current_id])
  } else if (!is.null(raw_label_map) && current_id %in% names(raw_label_map)) {
    unname(raw_label_map[current_id])
  } else {
    label_stratum(current_value, group_factor_upper)
  }

  block <- read.csv(text = lines[start_ln:(next_ln-1)], header = TRUE, check.names = FALSE)
  block <- robust_clean_names(block)

  stratum_clean <- block %>%
    filter(!grepl("median", `median.idv`)) %>%
    transmute(
      bin_mid = as.numeric(`median.idv`),
      obs_med = as.numeric(`50% real`), med_med = as.numeric(`50% sim`),
      med_low = as.numeric(`95%CI for 50% from`), med_hi = as.numeric(`95%CI for 50% to`),
      obs_lo  = as.numeric(`5% real`), lo_med = as.numeric(`5% sim`),
      lo_low  = as.numeric(`95%CI for 5% from`), lo_hi  = as.numeric(`95%CI for 5% to`),
      obs_hi  = as.numeric(`95% real`), hi_med = as.numeric(`95% sim`),
      hi_low  = as.numeric(`95%CI for 95% from`), hi_hi  = as.numeric(`95%CI for 95% to`),
      STRAT_ID = current_id
    ) %>%
    filter(!is.na(bin_mid)) %>%
    mutate(STRAT_LABEL = current_label)
  all_strata_stats[[i]] <- stratum_clean
}
vpc_stats <- bind_rows(all_strata_stats)
message(paste0(">>> VPC 分层标签: ", paste(sort(unique(vpc_stats$STRAT_LABEL)), collapse = " | ")))

# --- 5. 绘图 (Log10 + 6 剂量组对齐) ---
p_vpc <- ggplot(vpc_stats, aes(x = bin_mid)) +
  # 阴影层
  geom_ribbon(aes(ymin = hi_low, ymax = hi_hi, fill = "5% & 95% CI (Sim)"), alpha = 0.2) +
  geom_ribbon(aes(ymin = lo_low, ymax = lo_hi, fill = "5% & 95% CI (Sim)"), alpha = 0.2) +
  geom_ribbon(aes(ymin = med_low, ymax = med_hi, fill = "Median CI (Sim)"), alpha = 0.2) +

  # 线条层
  geom_line(aes(y = hi_med, color = "5% & 95% Percentiles (Sim)"), linetype = "dashed", linewidth = 0.7) +
  geom_line(aes(y = lo_med, color = "5% & 95% Percentiles (Sim)"), linetype = "dashed", linewidth = 0.7) +
  geom_line(aes(y = med_med, color = "Median (Sim)"), linetype = "dashed", linewidth = 0.7) +
  geom_line(aes(y = obs_hi, color = "5% & 95% Percentiles (Obs)"), linewidth = 0.8) +
  geom_line(aes(y = obs_lo, color = "5% & 95% Percentiles (Obs)"), linewidth = 0.8) +
  geom_line(aes(y = obs_med, color = "Median (Obs)"), linewidth = 0.8) +

  # 黑色实测散点层 (保留航哥的微调设置)
  geom_point(data = raw_obs_clean, aes(x = TIME_VAL, y = DV_VAL), color = "black", alpha = 0.6, size = 0.8) +

  # 分层显示
  facet_wrap(~STRAT_LABEL, scales = "free", ncol = 2) +

  # --- 核心修正点：解决多重参数冲突并美化标签 [cite: 137] ---
  scale_y_log10(
    breaks = scales::log_breaks(),
    labels = function(x) format(x, scientific = FALSE, trim = TRUE, drop0trailing = TRUE)
  ) +

  scale_color_manual(name = "Percentiles", values = c(
    "Median (Obs)" = "#DD4B39", "Median (Sim)" = "#DD4B39",
    "5% & 95% Percentiles (Obs)" = "#3C8DBC", "5% & 95% Percentiles (Sim)" = "#3C8DBC"
  )) +
  scale_fill_manual(name = "Confidence Intervals", values = c(
    "Median CI (Sim)" = "#DD4B39", "5% & 95% CI (Sim)" = "#3C8DBC"
  )) +
  theme_bw(base_size = 14) +
  theme(legend.position = "bottom", legend.box = "vertical", panel.grid.minor = element_blank()) +
  labs(x = proj_cfg$units$time, y = proj_cfg$units$conc,
       title = paste0("Stratified Log-VPC (Run ", mod_index, ")"))

# 6. 保存
ggsave(paste0("VPC_Stratified_mod", mod_index, ".jpg"), plot = p_vpc, width = 12, height = 9, dpi = 300)
message(">>> ✅ VPC 任务闭环任务圆满成功！")
