# =================================================================
# PopPK 通用 GOF 绘图引擎  - 增强稳定性版
# =================================================================
library(tidyverse)
library(ggpubr)
library(jsonlite)
library(RColorBrewer)

# 1. 获取参数
args <- commandArgs(trailingOnly = TRUE)
mod_index <- if(length(args) > 0) args[1] else "41"
# 第二个参数为真实 sdtab 文件名（由 Python 层从 $TABLE FILE= 检测）
sdtab_name <- if(length(args) > 1) args[2] else paste0("sdtab", mod_index)

config_file <- "project_config.json"

if (!file.exists(sdtab_name))  stop(paste0("❌ 错误：未找到数据文件 ", sdtab_name))

# 加载配置（缺失时使用内置默认值）
if (file.exists(config_file)) {
  config <- fromJSON(config_file)
} else {
  message("⚠️ project_config.json 未找到，使用内置默认配置")
  config <- list(
    grouping = list(factor = "STUDY", labels = list())
  )
}

# 2. 增强的数据读取：处理可能出现的重复标题行
raw_data <- read.table(sdtab_name, skip = 1, header = TRUE, stringsAsFactors = FALSE) %>%
  filter(ID != "ID") # 过滤掉可能重复出现的标题行

# 3. 动态识别残差列名 (兼容 IWRES, CIWRES, IRES)
get_res_col <- function(df, preferred) {
  cols <- colnames(df)
  if (preferred %in% cols) return(preferred)
  # 自动寻找替代品
  fallbacks <- c("CIWRES", "IWRES", "IRES", "WRES")
  for (f in fallbacks) {
    if (f %in% cols) return(f)
  }
  return(NULL)
}

iwres_col <- get_res_col(raw_data, "IWRES")
cwres_col <- get_res_col(raw_data, "CWRES")

# 4. 数据清洗与分组映射
group_labels <- config$grouping$labels
if (length(group_labels) > 0) {
  map_df <- data.frame(
    RAW_VALUE = as.numeric(names(group_labels)),
    LABEL = unlist(group_labels)
  )
} else {
  map_df <- data.frame(RAW_VALUE = numeric(0), LABEL = character(0))
}

group_col <- config$grouping$factor
if (!is.null(group_col) && !(group_col %in% colnames(raw_data))) {
  fallback_candidates <- c("ROUTE", "SEX", "ADA", "STUDY", "STUDYID",
                           "STUDYNO", "ARM", "DOSE", "TRT", "RACE", "REGION")
  group_col <- fallback_candidates[fallback_candidates %in% colnames(raw_data)][1]
  if (length(group_col) == 0 || is.na(group_col)) group_col <- NULL
}

sdtab <- raw_data %>% filter(MDV != 1)
group_values <- if (!is.null(group_col)) sdtab[[group_col]] else NULL
sdtab <- sdtab %>% mutate(across(everything(), ~as.numeric(as.character(.)))) # 强制转数字，防止 non-numeric 报错

if (!is.null(group_col)) {
  sdtab[[group_col]] <- group_values
  use_labels <- length(group_labels) > 0 && is.numeric(group_values)
  if (use_labels) {
    sdtab <- sdtab %>%
      left_join(map_df, by = setNames("RAW_VALUE", group_col)) %>%
      mutate(GROUP = factor(LABEL, levels = unlist(group_labels)))
  } else {
    sdtab <- sdtab %>% mutate(GROUP = factor(.data[[group_col]]))
  }
} else {
  sdtab <- sdtab %>% mutate(GROUP = factor("All"))
}

# 5. 绘图样式
colors <- brewer.pal(name="Dark2", 8)
theme_gof <- theme_bw(base_size = 18) +
             theme(panel.grid = element_blank(), legend.position = "none")

# 6. 增强版绘图函数
plot_gof_panel <- function(data, x_col, y_col, xlab, ylab, title, is_qq=FALSE, is_abs=FALSE) {
  if (is.null(y_col) || !(y_col %in% colnames(data))) {
    return(ggplot() + annotate("text", x=0.5, y=0.5, label=paste("Missing:", y_col)) + theme_void())
  }

  if(is_qq) {
    p <- ggplot(data, aes(sample = .data[[y_col]])) +
         geom_qq(size=2, color="darkblue", alpha=0.8) + geom_qq_line(linewidth=1)
  } else {
    # 核心修正：确保取绝对值前是数字
    plot_y_data <- if(is_abs) abs(as.numeric(data[[y_col]])) else as.numeric(data[[y_col]])

    p <- ggplot(data, aes(x = .data[[x_col]], y = plot_y_data, color = GROUP)) +
         geom_point(shape=16, size=2) +
         scale_color_manual(values = colors) +
         geom_smooth(method = "loess", se = FALSE, span=1, color="red", linewidth=1.5, linetype = "dashed")

    if(y_col == "DV") p <- p + geom_abline(intercept = 0, slope = 1, linewidth=1, color="black")
    if(grepl("RES", y_col) && !is_abs) p <- p + geom_hline(yintercept = 0, linewidth=1, color="black")
  }
  p + theme_gof + labs(x = xlab, y = ylab, title = title)
}

# 7. 生成 6 宫格
p1 <- plot_gof_panel(sdtab, "IPRED", "DV", "Individual Predictions", "Observations", "A)")
p2 <- plot_gof_panel(sdtab, "PRED", "DV", "Population Predictions", "Observations", "B)")
p3 <- plot_gof_panel(sdtab, "TIME", cwres_col, "Time (h)", "CWRES", "C)")
p4 <- plot_gof_panel(sdtab, "PRED", cwres_col, "Population Predictions", "CWRES", "D)")
p5 <- plot_gof_panel(sdtab, "IPRED", iwres_col, "Individual Predictions", "｜IWRES｜", "E)", is_abs=TRUE)
p6 <- plot_gof_panel(sdtab, "CWRES", cwres_col, "Quantiles of Normal", "CWRES", "F)", is_qq=TRUE)

final_gof <- ggarrange(p1, p2, p3, p4, p5, p6, ncol = 2, nrow = 3, common.legend = TRUE, legend="bottom")

output_name <- paste0("GOF_mod", mod_index, ".jpg")
jpeg(filename = output_name, width = 3000, height = 4500, res=300)
print(final_gof)
dev.off()
message(paste0(">>> 绘图成功：", output_name))
