# ============================================================
# EGARCH simulation and fitting functions
# ============================================================

suppressPackageStartupMessages({
  library(rugarch)
  library(dplyr)
  library(purrr)
  library(tibble)
})

make_egarch_spec <- function(distribution_model, fixed_pars = NULL) {
  ugarchspec(
    variance.model = list(
      model = "eGARCH",
      garchOrder = c(1, 1)
    ),
    mean.model = list(
      armaOrder = c(0, 0),
      include.mean = TRUE
    ),
    distribution.model = distribution_model,
    fixed.pars = fixed_pars
  )
}

simulate_egarch <- function(n, true_dist, seed, config = simulation_config) {
  spec <- make_egarch_spec(
    distribution_model = true_dist,
    fixed_pars = get_true_pars(true_dist, config)
  )

  sim <- ugarchpath(
    spec,
    n.sim = n,
    m.sim = 1,
    rseed = seed
  )

  tibble(
    t = seq_len(n),
    y = as.numeric(sim@path$seriesSim[, 1]),
    sigma_true = as.numeric(sim@path$sigmaSim[, 1]),
    variance_true = sigma_true^2,
    true_dist = true_dist,
    n = n
  )
}

get_coef_or_na <- function(coefs, name) {
  if (name %in% names(coefs)) {
    return(unname(coefs[[name]]))
  }

  NA_real_
}

get_ic_or_na <- function(ic, name) {
  if (name %in% rownames(ic)) {
    return(as.numeric(ic[name, 1]))
  }

  if (name %in% names(ic)) {
    return(as.numeric(ic[[name]]))
  }

  NA_real_
}

empty_fit_result <- function(assumed_dist) {
  tibble(
    assumed_dist = assumed_dist,
    converged = FALSE,
    loglik = NA_real_,
    AIC = NA_real_,
    BIC = NA_real_,
    MSE = NA_real_,
    RMSE = NA_real_,
    MAE = NA_real_,
    sigma_mse = NA_real_,
    sigma_rmse = NA_real_,
    sigma_mae = NA_real_,
    variance_mse = NA_real_,
    variance_rmse = NA_real_,
    variance_mae = NA_real_,
    mu = NA_real_,
    omega = NA_real_,
    alpha1 = NA_real_,
    beta1 = NA_real_,
    gamma1 = NA_real_,
    shape = NA_real_,
    skew = NA_real_
  )
}

fit_egarch <- function(y, sigma_true, assumed_dist) {
  spec <- make_egarch_spec(distribution_model = assumed_dist)

  fit <- tryCatch(
    ugarchfit(
      spec = spec,
      data = y,
      solver = "hybrid",
      solver.control = list(trace = 0)
    ),
    error = function(e) NULL
  )

  if (is.null(fit)) {
    return(empty_fit_result(assumed_dist))
  }

  coefs <- coef(fit)
  ic <- infocriteria(fit)
  sigma_hat <- as.numeric(sigma(fit))
  variance_hat <- sigma_hat^2
  variance_true <- sigma_true^2

  sigma_error <- sigma_hat - sigma_true
  variance_error <- variance_hat - variance_true

  sigma_mse <- mean(sigma_error^2, na.rm = TRUE)
  sigma_rmse <- sqrt(sigma_mse)
  sigma_mae <- mean(abs(sigma_error), na.rm = TRUE)
  variance_mse <- mean(variance_error^2, na.rm = TRUE)

  tibble(
    assumed_dist = assumed_dist,
    converged = fit@fit$convergence == 0,
    loglik = as.numeric(likelihood(fit)),
    AIC = get_ic_or_na(ic, "Akaike"),
    BIC = get_ic_or_na(ic, "Bayes"),
    MSE = sigma_mse,
    RMSE = sigma_rmse,
    MAE = sigma_mae,
    sigma_mse = sigma_mse,
    sigma_rmse = sigma_rmse,
    sigma_mae = sigma_mae,
    variance_mse = variance_mse,
    variance_rmse = sqrt(variance_mse),
    variance_mae = mean(abs(variance_error), na.rm = TRUE),
    mu = get_coef_or_na(coefs, "mu"),
    omega = get_coef_or_na(coefs, "omega"),
    alpha1 = get_coef_or_na(coefs, "alpha1"),
    beta1 = get_coef_or_na(coefs, "beta1"),
    gamma1 = get_coef_or_na(coefs, "gamma1"),
    shape = get_coef_or_na(coefs, "shape"),
    skew = get_coef_or_na(coefs, "skew")
  )
}

replication_seed <- function(rep_id, n, true_dist, config = simulation_config) {
  config$seed_base +
    rep_id +
    1000 * match(true_dist, config$candidate_dists) +
    n
}

run_one_rep <- function(rep_id, n, true_dist, config = simulation_config) {
  dat <- simulate_egarch(
    n = n,
    true_dist = true_dist,
    seed = replication_seed(rep_id, n, true_dist, config),
    config = config
  )

  map_dfr(
    config$candidate_dists,
    ~ fit_egarch(
      y = dat$y,
      sigma_true = dat$sigma_true,
      assumed_dist = .x
    )
  ) %>%
    mutate(
      rep_id = rep_id,
      n = n,
      true_dist = true_dist,
      .before = 1
    )
}

simulation_design <- function(config = simulation_config) {
  tidyr::expand_grid(
    rep_id = seq_len(config$replications),
    n = config$sample_sizes,
    true_dist = config$candidate_dists
  )
}

run_simulation_design <- function(design, config = simulation_config) {
  design <- design %>%
    mutate(design_row = row_number())

  total_rows <- nrow(design)

  pmap_dfr(
    design,
    function(rep_id, n, true_dist, design_row) {
      message(
        "Replication ", rep_id, "/", config$replications,
        " | n = ", n,
        " | true distribution = ", true_dist,
        " | design row ", design_row, "/", total_rows
      )

      run_one_rep(
        rep_id = rep_id,
        n = n,
        true_dist = true_dist,
        config = config
      )
    }
  )
}

run_simulation_results <- function(config = simulation_config) {
  run_simulation_design(
    design = simulation_design(config),
    config = config
  )
}
