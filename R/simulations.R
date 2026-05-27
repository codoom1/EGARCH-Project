# ============================================================
# Simulation study: EGARCH error distributions by sample size
# ============================================================

source("R/simulation_config.R")
source("R/simulation_functions.R")
source("R/simulation_summaries.R")
source("R/simulation_plots.R")

run_simulation_study <- function(
  config = simulation_config,
  save_outputs = TRUE
) {
  sim_results <- run_simulation_results(config)
  summaries <- make_all_summaries(sim_results, config)
  plots <- make_simulation_plots(summaries, sim_results)

  if (isTRUE(save_outputs)) {
    save_simulation_outputs(
      sim_results = sim_results,
      summaries = summaries,
      plots = plots,
      output_dir = config$output_dir
    )
  }

  list(
    config = config,
    sim_results = sim_results,
    fit_summary = summaries$fit_summary,
    aic_selection_frequency = summaries$aic_selection_frequency,
    bic_selection_frequency = summaries$bic_selection_frequency,
    parameter_summary = summaries$parameter_summary,
    plots = plots
  )
}

if (isTRUE(getOption("egarch.run_on_source", TRUE))) {
  simulation_outputs <- run_simulation_study()

  sim_results <- simulation_outputs$sim_results
  fit_summary <- simulation_outputs$fit_summary
  aic_selection_frequency <- simulation_outputs$aic_selection_frequency
  bic_selection_frequency <- simulation_outputs$bic_selection_frequency
  parameter_summary <- simulation_outputs$parameter_summary
  plots <- simulation_outputs$plots
}
