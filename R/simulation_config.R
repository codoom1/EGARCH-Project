# ============================================================
# EGARCH simulation configuration
# ============================================================

parse_integer_env <- function(name, default) {
  value <- Sys.getenv(name, unset = NA_character_)

  if (is.na(value) || !nzchar(value)) {
    return(default)
  }

  as.integer(value)
}

parse_integer_vector_env <- function(name, default) {
  value <- Sys.getenv(name, unset = NA_character_)

  if (is.na(value) || !nzchar(value)) {
    return(default)
  }

  as.integer(strsplit(value, ",", fixed = TRUE)[[1]])
}

candidate_dists <- c("norm", "std", "ged", "sstd", "sged")

dist_labels <- c(
  norm = "Normal",
  std  = "Student-t",
  ged  = "GED",
  sstd = "Skewed Student-t",
  sged = "Skewed GED"
)

true_base_pars <- list(
  mu     = 0.000,
  omega  = -0.10,
  alpha1 = 0.15,
  beta1  = 0.90,
  gamma1 = 0.10
)

simulation_config <- list(
  candidate_dists = candidate_dists,
  dist_labels = dist_labels,
  sample_sizes = parse_integer_vector_env(
    "EGARCH_SAMPLE_SIZES",
    c(50, 500, 1000, 2000)
  ),
  replications = parse_integer_env("EGARCH_REPS", 5000),
  true_base_pars = true_base_pars,
  student_t_shape = 8,
  ged_shape = 1.5,
  documented_skew = -0.5,
  rugarch_left_skew = 0.5,
  seed_base = 100000,
  output_dir = Sys.getenv("EGARCH_OUTPUT_DIR", unset = "results")
)

get_true_pars <- function(true_dist, config = simulation_config) {
  pars <- config$true_base_pars

  if (true_dist %in% c("std", "sstd")) {
    pars$shape <- config$student_t_shape
  }

  if (true_dist %in% c("ged", "sged")) {
    pars$shape <- config$ged_shape
  }

  if (true_dist %in% c("sstd", "sged")) {
    # rugarch uses a positive skew parameter with 1 as symmetry.
    # The procedure specifies -0.5 to indicate moderate left-skewness;
    # 0.5 is the corresponding left-skewed rugarch setting.
    pars$skew <- config$rugarch_left_skew
  }

  pars
}

true_parameter_table <- function(config = simulation_config) {
  purrr::map_dfr(
    config$candidate_dists,
    function(true_dist) {
      pars <- get_true_pars(true_dist, config)

      tibble::tibble(
        true_dist = true_dist,
        parameter = names(pars),
        true_value = unname(unlist(pars))
      )
    }
  )
}
