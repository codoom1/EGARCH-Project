# EGARCH Error Distribution Simulation

This project runs a Monte Carlo simulation study for EGARCH(1,1) models under several innovation distributions and compares model recovery across sample sizes.

The detailed simulation methodology is documented in [docs/simulation-procedure.md](docs/simulation-procedure.md). Cluster batch instructions are documented in [docs/cluster-batch.md](docs/cluster-batch.md).

## Project Structure

```text
.
├── R/
│   ├── simulation_config.R      # Monte Carlo design and true parameters
│   ├── simulation_functions.R   # EGARCH simulation and model fitting
│   ├── simulation_summaries.R   # AIC/BIC selection and recovery metrics
│   ├── simulation_plots.R       # Plot and output helpers
│   ├── simulations.R            # Main local runner
│   ├── batch_run.R              # One cluster batch chunk
│   └── combine_batch_results.R  # Combine batch chunks
├── data/                        # Optional local inputs, if added later
├── docs/                        # Project documentation and methodology notes
├── scripts/                     # SLURM and batch helper scripts
│   └── make-paper-latex-tables.R # Convert paper-style CSV tables to LaTeX
├── results/                     # Generated tables, plots, and saved outputs
├── README.md
└── renv.lock                    # Reproducible R package environment
```

## Requirements

- R 4.4.0 or later
- `renv`

The main analysis uses:

- `rugarch`
- `dplyr`
- `tidyr`
- `purrr`
- `ggplot2`

## Setup

Restore the R environment with:

```r
renv::restore()
```

If `renv` is not installed yet:

```r
install.packages("renv")
renv::restore()
```

## Run the Simulation

From the project root:

```r
source("R/simulations.R")
```

The default design follows [docs/simulation-procedure.md](docs/simulation-procedure.md): 5000 replications, sample sizes 50, 500, 1000, and 2000, five true innovation distributions, and five fitted candidate distributions for each simulated series. This is a large run.

For cluster execution, use the batch workflow in [docs/cluster-batch.md](docs/cluster-batch.md).

## Quick Test Run

Use environment variables to run a smaller version without editing the code:

```sh
EGARCH_REPS=1 EGARCH_SAMPLE_SIZES=50 EGARCH_OUTPUT_DIR=results/smoke-test Rscript R/simulations.R
```

You can also load the functions without running the full simulation:

```r
options(egarch.run_on_source = FALSE)
source("R/simulations.R")
```

## Outputs

Simulation outputs are written to `results/` by default:

- `sim_results.csv`
- `fit_summary.csv`
- `aic_selection_frequency.csv`
- `bic_selection_frequency.csv`
- `parameter_summary.csv`
- `simulation_outputs.rds`
- plot PNG and PDF files, including `aic_selection`, `bic_selection`, `convergence_rate`, `information_criteria`, `parameter_rmse`, `parameter_rmse_heatmap*`, `rmse_distribution`, `volatility_rmse`, and `volatility_rmse_large_n`

Paper-style summary tables are written to `results/paper_tables/`, with LaTeX exports and a combined preview bundle in `results/paper_tables/latex/`.

To regenerate the LaTeX tables from the CSV inputs, run:

```r
source("scripts/make-paper-latex-tables.R")
```

## Notes

- Generated outputs should be saved under `results/`.
- Large intermediate files, local data, and rendered output are ignored by Git by default.
- `rugarch` uses a positive skew parameter where `1` is symmetry. The documented skew value of `-0.5` is implemented as `0.5`, representing moderate left-skewness in `rugarch`.
