# ============================================================
# EGARCH simulation plots and output helpers
# ============================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(scales)
  library(tidyr)
})

publication_palette <- c(
  "Normal" = "#005AB5",
  "Student-t" = "#B64000",
  "GED" = "#007A3D",
  "Skewed Student-t" = "#8F2D74",
  "Skewed GED" = "#9C6500"
)

publication_linetypes <- c(
  "Normal" = "solid",
  "Student-t" = "longdash",
  "GED" = "dotdash",
  "Skewed Student-t" = "twodash",
  "Skewed GED" = "dotted"
)

publication_shapes <- c(
  "Normal" = 16,
  "Student-t" = 17,
  "GED" = 15,
  "Skewed Student-t" = 18,
  "Skewed GED" = 8
)

publication_theme <- function(base_size = 17) {
  theme_bw(base_size = base_size, base_family = "sans") +
    theme(
      plot.title = element_text(face = "bold", size = rel(1.18), margin = margin(b = 9)),
      plot.subtitle = element_text(color = "grey5", size = rel(0.94), margin = margin(b = 12)),
      axis.title = element_text(face = "bold", size = rel(1.08), color = "black"),
      axis.text = element_text(color = "black", face = "bold", size = rel(0.96)),
      axis.text.x = element_text(margin = margin(t = 5)),
      axis.text.y = element_text(margin = margin(r = 5)),
      axis.line = element_line(color = "black", linewidth = 0.8),
      axis.ticks = element_line(color = "black", linewidth = 0.75),
      axis.ticks.length = unit(5, "pt"),
      panel.border = element_rect(color = "black", fill = NA, linewidth = 1.15),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "grey74", linewidth = 0.45),
      panel.grid.major.x = element_blank(),
      panel.spacing = unit(1.55, "lines"),
      strip.text = element_text(face = "bold", color = "black", size = rel(1.04), margin = margin(8, 8, 8, 8)),
      strip.background = element_rect(fill = "grey80", color = "black", linewidth = 1.05),
      legend.position = "bottom",
      legend.title = element_text(face = "bold", size = rel(1.02)),
      legend.text = element_text(color = "black", face = "bold", size = rel(0.96)),
      legend.key.width = unit(2.05, "lines"),
      legend.key.height = unit(1.3, "lines"),
      plot.caption = element_text(color = "grey10", hjust = 0),
      plot.margin = margin(18, 22, 18, 18)
    )
}

format_sample_size <- function(x) {
  label_number(big.mark = ",")(as.numeric(x))
}

facet_columns <- function(panel_count, default = 2L) {
  if (panel_count == 3L) {
    return(3L)
  }

  default
}

make_selection_plot <- function(data, criterion_label) {
  ggplot(
    dplyr::filter(data, !is.na(selection_rate)),
    aes(
      x = factor(n),
      y = selection_rate,
      fill = assumed_dist_label
    )
    ) +
    geom_col(
      position = position_dodge2(width = 0.84, preserve = "single"),
      width = 0.72,
      color = "grey15",
      linewidth = 0.55
    ) +
    facet_wrap(
      ~ true_dist_label,
      ncol = facet_columns(dplyr::n_distinct(data$true_dist_label), default = 3L)
    ) +
    scale_y_continuous(
      labels = label_percent(accuracy = 1),
      limits = c(0, 1),
      expand = expansion(mult = c(0, 0.04))
    ) +
    scale_fill_manual(values = publication_palette, drop = FALSE) +
    labs(
      x = "Sample size",
      y = paste(criterion_label, "selection rate"),
      fill = "Assumed distribution",
      title = paste(criterion_label, "model selection frequency"),
      subtitle = "Higher bars indicate how often each assumed innovation distribution is selected for a given data-generating distribution."
    ) +
    guides(fill = guide_legend(nrow = 2, byrow = TRUE)) +
    publication_theme()
}

make_selection_heatmap <- function(data, criterion_label) {
  plot_data <- data %>%
    dplyr::mutate(
      label = ifelse(is.na(selection_rate), "", label_percent(accuracy = 1)(selection_rate)),
      label_color = ifelse(!is.na(selection_rate) & selection_rate >= 0.55, "white", "black")
    )

  n_panels <- dplyr::n_distinct(plot_data$n)

  plot <- ggplot(
    plot_data,
    aes(
      x = assumed_dist_label,
      y = true_dist_label,
      fill = selection_rate
    )
  ) +
    geom_tile(color = "grey20", linewidth = 0.65) +
    geom_text(
      aes(label = label, color = label_color),
      size = 5,
      fontface = "bold"
    ) +
    facet_wrap(
      ~ n,
      ncol = facet_columns(dplyr::n_distinct(plot_data$n), default = 2L),
      labeller = labeller(n = function(x) paste("n =", format_sample_size(x)))
    ) +
    scale_fill_gradient(
      low = "#F0F7FF",
      high = "#003D7A",
      limits = c(0, 1),
      labels = label_percent(accuracy = 1),
      na.value = "grey90"
    ) +
    scale_color_identity() +
    labs(
      x = "Assumed distribution",
      y = "True distribution",
      fill = "Selection rate",
      title = paste(criterion_label, "selection accuracy map"),
      subtitle = "Diagonal cells show correct distribution recovery; off-diagonal cells reveal systematic misspecification."
    ) +
    publication_theme(base_size = 17) +
    theme(
      axis.text.x = element_text(angle = 35, hjust = 1, vjust = 1),
      panel.grid = element_blank()
    )

  attr(plot, "plot_dims") <- if (n_panels == 3L) {
    c(width = 16, height = 6.8)
  } else {
    c(width = 13, height = 9.5)
  }

  plot
}

line_layer_if_multiple_samples <- function(data, linewidth = 1) {
  if (dplyr::n_distinct(stats::na.omit(data$n)) < 2L) {
    return(NULL)
  }

  geom_line(linewidth = linewidth)
}

make_parameter_heatmap <- function(data, parameter_label = NULL) {
  parameter_count <- dplyr::n_distinct(data$parameter)
  facet_layer <- if (parameter_count > 1L) {
    facet_grid(
      parameter ~ n,
      scales = "free",
      labeller = labeller(n = function(x) paste("n =", format_sample_size(x)))
    )
  } else {
    facet_wrap(
      ~ n,
      ncol = facet_columns(dplyr::n_distinct(data$n), default = 2L),
      labeller = labeller(n = function(x) paste("n =", format_sample_size(x)))
    )
  }

  plot_title <- if (is.null(parameter_label)) {
    "Common-parameter RMSE map"
  } else {
    paste("Common-parameter RMSE map:", parameter_label)
  }

  plot_subtitle <- if (is.null(parameter_label)) {
    "Only EGARCH parameters common to all innovation distributions are shown: mu, omega, alpha1, beta1, and gamma1."
  } else {
    "Lower values indicate more accurate recovery for this EGARCH parameter across true and assumed innovation distributions."
  }

  plot_data <- data %>%
    dplyr::mutate(
      label = label_number(accuracy = 0.001)(parameter_rmse),
      label_color = ifelse(
        parameter_rmse >= 0.55 * max(parameter_rmse, na.rm = TRUE),
        "white",
        "black"
      )
    )

  n_sample_panels <- dplyr::n_distinct(plot_data$n)

  plot <- ggplot(
    plot_data,
    aes(
      x = assumed_dist_label,
      y = true_dist_label,
      fill = parameter_rmse
    )
  ) +
    geom_tile(color = "grey15", linewidth = 0.75) +
    geom_text(
      aes(label = label, color = label_color),
      size = 4.35,
      fontface = "bold"
    ) +
    facet_layer +
    scale_fill_gradient(
      low = "#FFF5F0",
      high = "#7F0000",
      trans = "sqrt",
      labels = label_number(accuracy = 0.001)
    ) +
    scale_color_identity() +
    labs(
      x = "Assumed distribution",
      y = "True distribution",
      fill = "RMSE",
      title = plot_title,
      subtitle = plot_subtitle
    ) +
    publication_theme(base_size = 16) +
    theme(
      axis.text.x = element_text(angle = 35, hjust = 1, vjust = 1),
      panel.grid = element_blank()
    )

  attr(plot, "plot_dims") <- if (parameter_count == 1L && n_sample_panels == 3L) {
    c(width = 16, height = 6.8)
  } else if (parameter_count > 1L && n_sample_panels == 3L) {
    c(width = 16, height = 12)
  } else if (parameter_count > 1L) {
    c(width = 14.5, height = 11.5)
  } else {
    c(width = 13, height = 9.5)
  }

  plot
}

make_parameter_heatmaps_by_parameter <- function(data) {
  parameter_names <- sort(unique(data$parameter))
  heatmaps <- lapply(
    parameter_names,
    function(parameter_name) {
      make_parameter_heatmap(
        dplyr::filter(data, parameter == parameter_name),
        parameter_label = parameter_name
      )
    }
  )

  names(heatmaps) <- paste0("parameter_rmse_heatmap_", parameter_names)
  heatmaps
}

make_simulation_plots <- function(summaries, sim_results = NULL) {
  if (!is.null(sim_results) &&
      all(c("true_dist", "assumed_dist") %in% names(sim_results)) &&
      !all(c("true_dist_label", "assumed_dist_label") %in% names(sim_results))) {
    sim_results <- add_distribution_labels(sim_results)
  }

  fit_summary_long <- summaries$fit_summary %>%
    tidyr::pivot_longer(
      cols = c(mean_sigma_rmse, mean_variance_rmse),
      names_to = "target",
      values_to = "rmse"
    ) %>%
    dplyr::mutate(
      target = dplyr::recode(
        target,
        mean_sigma_rmse = "Conditional standard deviation",
        mean_variance_rmse = "Conditional variance"
      )
    )

  information_criteria <- summaries$fit_summary %>%
    tidyr::pivot_longer(
      cols = c(mean_AIC, mean_BIC),
      names_to = "criterion",
      values_to = "mean_value"
    ) %>%
    dplyr::mutate(criterion = sub("^mean_", "", criterion))

  common_parameters <- names(simulation_config$true_base_pars)

  parameter_summary_plot <- summaries$parameter_summary %>%
    dplyr::filter(
      parameter %in% common_parameters,
      !is.na(true_value),
      is.finite(parameter_rmse)
    )

  plots <- list(
    aic_selection = make_selection_plot(
      summaries$aic_selection_frequency,
      "AIC"
    ),
    bic_selection = make_selection_plot(
      summaries$bic_selection_frequency,
      "BIC"
    ),
    aic_selection_heatmap = make_selection_heatmap(
      summaries$aic_selection_frequency,
      "AIC"
    ),
    bic_selection_heatmap = make_selection_heatmap(
      summaries$bic_selection_frequency,
      "BIC"
    ),
    volatility_rmse = ggplot(
      fit_summary_long,
      aes(
        x = n,
        y = rmse,
        color = assumed_dist_label,
        linetype = assumed_dist_label,
        shape = assumed_dist_label,
        group = assumed_dist_label
      )
    ) +
      line_layer_if_multiple_samples(fit_summary_long, linewidth = 1.7) +
      geom_point(size = 4.4, stroke = 0.7) +
      facet_grid(target ~ true_dist_label, scales = "free_y") +
      scale_x_continuous(labels = format_sample_size) +
      scale_color_manual(values = publication_palette, drop = FALSE) +
      scale_linetype_manual(values = publication_linetypes, drop = FALSE) +
      scale_shape_manual(values = publication_shapes, drop = FALSE) +
      labs(
        x = "Sample size",
        y = "Mean RMSE",
        color = "Assumed distribution",
        linetype = "Assumed distribution",
        shape = "Assumed distribution",
        title = "Volatility-path recovery",
        subtitle = "Lower values indicate more accurate recovery of the simulated EGARCH volatility process."
      ) +
      guides(
        color = guide_legend(nrow = 2, byrow = TRUE),
        linetype = guide_legend(nrow = 2, byrow = TRUE),
        shape = guide_legend(nrow = 2, byrow = TRUE)
      ) +
      publication_theme(),
    information_criteria = ggplot(
      information_criteria,
      aes(
        x = n,
        y = mean_value,
        color = assumed_dist_label,
        linetype = assumed_dist_label,
        shape = assumed_dist_label,
        group = assumed_dist_label
      )
    ) +
      line_layer_if_multiple_samples(information_criteria, linewidth = 1.7) +
      geom_point(size = 4.4, stroke = 0.7) +
      facet_grid(criterion ~ true_dist_label, scales = "free_y") +
      scale_x_continuous(labels = format_sample_size) +
      scale_color_manual(values = publication_palette, drop = FALSE) +
      scale_linetype_manual(values = publication_linetypes, drop = FALSE) +
      scale_shape_manual(values = publication_shapes, drop = FALSE) +
      labs(
        x = "Sample size",
        y = "Mean criterion value",
        color = "Assumed distribution",
        linetype = "Assumed distribution",
        shape = "Assumed distribution",
        title = "Information-criterion profiles",
        subtitle = "Panels compare how AIC and BIC rank candidate innovation distributions across sample sizes."
      ) +
      guides(
        color = guide_legend(nrow = 2, byrow = TRUE),
        linetype = guide_legend(nrow = 2, byrow = TRUE),
        shape = guide_legend(nrow = 2, byrow = TRUE)
      ) +
      publication_theme(),
    convergence_rate = ggplot(
      summaries$fit_summary,
      aes(
        x = factor(n),
        y = convergence_rate,
        fill = assumed_dist_label
      )
    ) +
      geom_col(
        position = position_dodge2(width = 0.84, preserve = "single"),
        width = 0.72,
        color = "grey15",
        linewidth = 0.55
      ) +
      facet_wrap(
        ~ true_dist_label,
        ncol = facet_columns(dplyr::n_distinct(summaries$fit_summary$true_dist_label), default = 3L)
      ) +
      scale_y_continuous(
        labels = label_percent(accuracy = 1),
        limits = c(0, 1),
        expand = expansion(mult = c(0, 0.04))
      ) +
      scale_fill_manual(values = publication_palette, drop = FALSE) +
      labs(
        x = "Sample size",
        y = "Convergence rate",
        fill = "Assumed distribution",
        title = "Estimator convergence by specification",
        subtitle = "Convergence diagnostics are essential for judging whether selection and error summaries are reliable."
      ) +
      guides(fill = guide_legend(nrow = 2, byrow = TRUE)) +
      publication_theme(),
    parameter_rmse = ggplot(
      parameter_summary_plot,
      aes(
        x = n,
        y = parameter_rmse,
        color = assumed_dist_label,
        linetype = assumed_dist_label,
        shape = assumed_dist_label,
        group = assumed_dist_label
      )
    ) +
      line_layer_if_multiple_samples(parameter_summary_plot, linewidth = 1.55) +
      geom_point(size = 3.8, stroke = 0.65) +
      facet_grid(parameter ~ true_dist_label, scales = "free_y") +
      scale_x_continuous(labels = format_sample_size) +
      scale_color_manual(values = publication_palette, drop = FALSE) +
      scale_linetype_manual(values = publication_linetypes, drop = FALSE) +
      scale_shape_manual(values = publication_shapes, drop = FALSE) +
      labs(
        x = "Sample size",
        y = "Parameter RMSE",
        color = "Assumed distribution",
        linetype = "Assumed distribution",
        shape = "Assumed distribution",
        title = "EGARCH parameter recovery",
        subtitle = "Panels use parameter-specific vertical scales to keep small and large estimation errors readable."
      ) +
      guides(
        color = guide_legend(nrow = 2, byrow = TRUE),
        linetype = guide_legend(nrow = 2, byrow = TRUE),
        shape = guide_legend(nrow = 2, byrow = TRUE)
      ) +
      publication_theme(base_size = 15) +
      theme(strip.text.y = element_text(angle = 0)),
    parameter_rmse_heatmap = make_parameter_heatmap(parameter_summary_plot)
  )

  plots <- c(
    plots,
    make_parameter_heatmaps_by_parameter(parameter_summary_plot)
  )

  if (!is.null(sim_results)) {
    plots$rmse_distribution <- sim_results %>%
      dplyr::filter(
        converged,
        !is.na(RMSE),
        !is.na(true_dist_label),
        !is.na(assumed_dist_label)
      ) %>%
      dplyr::mutate(
        true_dist_label = factor(true_dist_label, levels = unique(summaries$fit_summary$true_dist_label)),
        assumed_dist_label = factor(assumed_dist_label, levels = names(publication_palette))
      ) %>%
      ggplot(
        aes(
          x = assumed_dist_label,
          y = RMSE,
          fill = assumed_dist_label
        )
      ) +
      geom_boxplot(
        width = 0.66,
        outlier.alpha = 0.5,
        outlier.size = 1.55,
        linewidth = 1
      ) +
      facet_grid(
        n ~ true_dist_label,
        scales = "free_y",
        labeller = labeller(n = function(x) paste("n =", format_sample_size(x)))
      ) +
      scale_fill_manual(values = publication_palette, drop = FALSE) +
      labs(
        x = "Assumed distribution",
        y = "Volatility RMSE",
        fill = "Assumed distribution",
        title = "Distribution of volatility recovery errors",
        subtitle = "Boxplots expose Monte Carlo dispersion and outliers that mean RMSE curves can hide."
      ) +
      publication_theme(base_size = 15) +
      theme(
        axis.text.x = element_text(angle = 35, hjust = 1, vjust = 1),
        legend.position = "none"
      )
  }

  plots
}

plot_dimensions <- list(
  aic_selection = c(width = 14, height = 9),
  bic_selection = c(width = 14, height = 9),
  aic_selection_heatmap = c(width = 13, height = 9.5),
  bic_selection_heatmap = c(width = 13, height = 9.5),
  volatility_rmse = c(width = 14.5, height = 9.5),
  information_criteria = c(width = 14.5, height = 9.5),
  convergence_rate = c(width = 14, height = 9),
  parameter_rmse = c(width = 15.5, height = 13),
  parameter_rmse_heatmap = c(width = 14.5, height = 11.5),
  rmse_distribution = c(width = 15.5, height = 11)
)

save_publication_plot <- function(plot, name, output_dir) {
  dims <- attr(plot, "plot_dims", exact = TRUE)

  if (is.null(dims)) {
    dims <- plot_dimensions[[name]]
  }

  if (is.null(dims)) {
    if (grepl("^parameter_rmse_heatmap_", name)) {
      dims <- c(width = 13, height = 9.5)
    } else {
      dims <- c(width = 10, height = 7)
    }
  }

  ggsave(
    filename = file.path(output_dir, paste0(name, ".png")),
    plot = plot,
    width = dims[["width"]],
    height = dims[["height"]],
    dpi = 600,
    bg = "white"
  )

  ggsave(
    filename = file.path(output_dir, paste0(name, ".pdf")),
    plot = plot,
    width = dims[["width"]],
    height = dims[["height"]],
    device = cairo_pdf,
    bg = "white"
  )
}

save_simulation_outputs <- function(
  sim_results,
  summaries,
  plots,
  output_dir = simulation_config$output_dir
) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  write.csv(sim_results, file.path(output_dir, "sim_results.csv"), row.names = FALSE)
  write.csv(summaries$fit_summary, file.path(output_dir, "fit_summary.csv"), row.names = FALSE)
  write.csv(
    summaries$aic_selection_frequency,
    file.path(output_dir, "aic_selection_frequency.csv"),
    row.names = FALSE
  )
  write.csv(
    summaries$bic_selection_frequency,
    file.path(output_dir, "bic_selection_frequency.csv"),
    row.names = FALSE
  )
  write.csv(
    summaries$parameter_summary,
    file.path(output_dir, "parameter_summary.csv"),
    row.names = FALSE
  )

  saveRDS(
    list(
      sim_results = sim_results,
      summaries = summaries,
      plots = plots
    ),
    file.path(output_dir, "simulation_outputs.rds")
  )

  purrr::iwalk(
    plots,
    function(plot, name) {
      save_publication_plot(plot, name, output_dir)
    }
  )

  invisible(output_dir)
}
