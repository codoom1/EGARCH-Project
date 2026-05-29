# ============================================================
# Create publication-ready LaTeX tables from paper-style CSVs
# ============================================================

input_dir <- Sys.getenv("EGARCH_PAPER_TABLE_DIR", unset = "results/paper_tables")
output_dir <- Sys.getenv(
  "EGARCH_LATEX_TABLE_DIR",
  unset = file.path(input_dir, "latex")
)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

dist_order <- c("norm", "ged", "sged", "std", "sstd")
dist_labels <- c(
  norm = "NORM",
  ged = "GED",
  sged = "SGED",
  std = "STD",
  sstd = "SSTD"
)
dist_names <- c(
  norm = "normal",
  ged = "GED",
  sged = "SGED",
  std = "Student's t",
  sstd = "skewed Student's t"
)

format_number <- function(x, digits = 3) {
  ifelse(
    is.na(x),
    "--",
    formatC(as.numeric(x), format = "f", digits = digits)
  )
}

make_group_rows <- function(data) {
  rows <- character()

  for (dist in dist_order) {
    block <- data[data$assumed_dist == dist, , drop = FALSE]

    if (nrow(block) == 0L) {
      next
    }

    rows <- c(rows, paste0("\\multicolumn{15}{l}{\\textbf{", dist_labels[[dist]], "}}"))

    for (i in seq_len(nrow(block))) {
      row <- block[i, , drop = FALSE]
      values <- c(
        row$n,
        format_number(row$standard_error_omega),
        format_number(row$standard_error_alpha),
        format_number(row$standard_error_beta),
        format_number(row$standard_error_gamma),
        format_number(row$MSE_omega),
        format_number(row$MSE_alpha),
        format_number(row$MSE_beta),
        format_number(row$MSE_gamma),
        format_number(row$MAE_omega),
        format_number(row$MAE_alpha),
        format_number(row$MAE_beta),
        format_number(row$MAE_gamma),
        format_number(row$AIC),
        format_number(row$BIC)
      )

      rows <- c(rows, paste(values, collapse = " & "))
    }
  }

  paste0(rows, " \\\\")
}

make_latex_table <- function(data, true_dist, table_number = NULL) {
  caption <- paste0(
    "The average of the estimated standard error, MSE, MAE, AIC, and BIC ",
    "for EGARCH model with different error distributions and sample sizes. ",
    "The true error distribution was assumed to be ", dist_names[[true_dist]], "."
  )

  rows <- make_group_rows(data)

  c(
    "% Requires \\usepackage{booktabs}",
    "\\begin{table}[!htbp]",
    "\\centering",
    "\\scriptsize",
    "\\setlength{\\tabcolsep}{3pt}",
    paste0("\\caption{", caption, "}"),
    paste0("\\label{tab:egarch-", true_dist, "}"),
    "\\begin{tabular}{lrrrrrrrrrrrrrr}",
    "\\toprule",
    " & \\multicolumn{4}{c}{Standard error} & \\multicolumn{4}{c}{MSE} & \\multicolumn{4}{c}{MAE} & & \\\\",
    "\\cmidrule(lr){2-5} \\cmidrule(lr){6-9} \\cmidrule(lr){10-13}",
    "Sample size & $\\Omega$ & $\\alpha$ & $\\beta$ & $\\gamma$ & $\\Omega$ & $\\alpha$ & $\\beta$ & $\\gamma$ & $\\Omega$ & $\\alpha$ & $\\beta$ & $\\gamma$ & AIC & BIC \\\\",
    "\\midrule",
    rows,
    "\\bottomrule",
    "\\end{tabular}",
    "\\end{table}",
    ""
  )
}

table_files <- sort(list.files(
  input_dir,
  pattern = "^table_true_(norm|ged|sged|std|sstd)[.]csv$",
  full.names = TRUE
))

if (length(table_files) == 0L) {
  stop("No paper table CSV files found in: ", input_dir, call. = FALSE)
}

written_files <- character()

for (table_file in table_files) {
  true_dist <- sub("^table_true_([^.]+)[.]csv$", "\\1", basename(table_file))
  data <- read.csv(table_file)
  data$assumed_dist <- factor(data$assumed_dist, levels = dist_order)
  data <- data[order(data$assumed_dist, data$n), , drop = FALSE]

  latex <- make_latex_table(
    data = data,
    true_dist = true_dist,
    table_number = match(true_dist, dist_order)
  )

  output_file <- file.path(output_dir, paste0("table_true_", true_dist, ".tex"))
  writeLines(latex, output_file)
  written_files <- c(written_files, output_file)
}

combined_output <- file.path(output_dir, "egarch_paper_tables.tex")
writeLines(unlist(lapply(written_files, readLines)), combined_output)

preview_output <- file.path(output_dir, "egarch_paper_tables_preview.tex")
writeLines(
  c(
    "\\documentclass[11pt]{article}",
    "\\usepackage[margin=0.6in]{geometry}",
    "\\usepackage{booktabs}",
    "\\usepackage{caption}",
    "\\captionsetup[table]{labelfont=bf, labelsep=period}",
    "\\begin{document}",
    "\\input{egarch_paper_tables.tex}",
    "\\end{document}"
  ),
  preview_output
)

cat("Wrote LaTeX tables to:\n")
cat(paste0("  ", c(written_files, combined_output, preview_output), collapse = "\n"), "\n")
