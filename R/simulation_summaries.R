# ============================================================
# EGARCH simulation summaries
# ============================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(tibble)
})

add_distribution_labels <- function(data, config = simulation_config) {
  data %>%
    mutate(
      true_dist_label = unname(config$dist_labels[true_dist]),
      assumed_dist_label = unname(config$dist_labels[assumed_dist])
    )
}

make_fit_summary <- function(sim_results, config = simulation_config) {
  sim_results %>%
    group_by(n, true_dist, assumed_dist) %>%
    summarise(
      convergence_rate = mean(converged, na.rm = TRUE),
      mean_AIC = mean(AIC, na.rm = TRUE),
      sd_AIC = sd(AIC, na.rm = TRUE),
      mean_BIC = mean(BIC, na.rm = TRUE),
      sd_BIC = sd(BIC, na.rm = TRUE),
      mean_loglik = mean(loglik, na.rm = TRUE),
      mean_MSE = mean(MSE, na.rm = TRUE),
      mean_RMSE = mean(RMSE, na.rm = TRUE),
      mean_MAE = mean(MAE, na.rm = TRUE),
      median_MSE = median(MSE, na.rm = TRUE),
      median_RMSE = median(RMSE, na.rm = TRUE),
      median_MAE = median(MAE, na.rm = TRUE),
      mean_sigma_rmse = mean(sigma_rmse, na.rm = TRUE),
      median_sigma_rmse = median(sigma_rmse, na.rm = TRUE),
      mean_variance_rmse = mean(variance_rmse, na.rm = TRUE),
      median_variance_rmse = median(variance_rmse, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    add_distribution_labels(config)
}

make_selection_frequency <- function(sim_results, criterion, config = simulation_config) {
  selection_grid <- tidyr::expand_grid(
    n = sort(unique(sim_results$n)),
    true_dist = config$candidate_dists,
    assumed_dist = config$candidate_dists
  )

  winners <- sim_results %>%
    filter(converged, !is.na(.data[[criterion]])) %>%
    group_by(rep_id, n, true_dist) %>%
    slice_min(.data[[criterion]], n = 1, with_ties = FALSE) %>%
    ungroup()

  winner_counts <- winners %>%
    count(n, true_dist, assumed_dist, name = "selected_count") %>%
    group_by(n, true_dist) %>%
    mutate(
      selected_total = sum(selected_count)
    ) %>%
    ungroup()

  selection_grid %>%
    left_join(winner_counts, by = c("n", "true_dist", "assumed_dist")) %>%
    mutate(
      selected_count = tidyr::replace_na(selected_count, 0L),
      selected_total = tidyr::replace_na(selected_total, 0L),
      selection_rate = if_else(
        selected_total > 0,
        selected_count / selected_total,
        NA_real_
      ),
      criterion = criterion
    ) %>%
    add_distribution_labels(config)
}

make_parameter_summary <- function(sim_results, config = simulation_config) {
  true_values <- true_parameter_table(config)

  sim_results %>%
    select(
      rep_id, n, true_dist, assumed_dist,
      mu, omega, alpha1, beta1, gamma1, shape, skew
    ) %>%
    pivot_longer(
      cols = c(mu, omega, alpha1, beta1, gamma1, shape, skew),
      names_to = "parameter",
      values_to = "estimate"
    ) %>%
    left_join(true_values, by = c("true_dist", "parameter")) %>%
    mutate(
      error = estimate - true_value,
      abs_error = abs(error),
      squared_error = error^2
    ) %>%
    group_by(n, true_dist, assumed_dist, parameter) %>%
    summarise(
      true_value = first(true_value),
      mean_estimate = mean(estimate, na.rm = TRUE),
      bias = mean(error, na.rm = TRUE),
      mean_abs_error = mean(abs_error, na.rm = TRUE),
      parameter_mse = mean(squared_error, na.rm = TRUE),
      parameter_rmse = sqrt(parameter_mse),
      .groups = "drop"
    ) %>%
    add_distribution_labels(config)
}

make_all_summaries <- function(sim_results, config = simulation_config) {
  list(
    fit_summary = make_fit_summary(sim_results, config),
    aic_selection_frequency = make_selection_frequency(
      sim_results,
      criterion = "AIC",
      config = config
    ),
    bic_selection_frequency = make_selection_frequency(
      sim_results,
      criterion = "BIC",
      config = config
    ),
    parameter_summary = make_parameter_summary(sim_results, config)
  )
}
