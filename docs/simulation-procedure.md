# Simulation Procedure

This document describes the Monte Carlo simulation used to evaluate EGARCH(1,1) models under alternative innovation distributions. The study compares model estimation, model selection, and volatility recovery when the true innovation distribution is known but the fitted model is allowed to use any one of five competing distributions.

## Study Objective

The goal is to determine how sensitive EGARCH(1,1) performance is to the assumed innovation distribution. The simulation varies:

- the true innovation distribution used to generate returns
- the sample size
- the fitted innovation distribution used during estimation

For every simulated return series, five EGARCH(1,1) models are fitted. Their performance is compared using likelihood-based criteria, volatility recovery errors, convergence rates, and parameter recovery metrics.

## EGARCH(1,1) Data-Generating Model

Each simulated return series is generated from a univariate EGARCH(1,1) process:

```text
r_t = mu + epsilon_t
epsilon_t = z_t * sqrt(h_t)
log(h_t) = omega
         + beta * log(h_{t-1})
         + alpha * (|z_{t-1}| - E|z_{t-1}|)
         + gamma * z_{t-1}
```

where:

- `r_t` is the simulated return at time `t`.
- `epsilon_t` is the innovation term.
- `h_t` is the conditional variance.
- `sqrt(h_t)` is the conditional volatility.
- `z_t` is the standardized innovation drawn from one of the candidate distributions.
- `omega` is the variance intercept.
- `alpha` controls the magnitude effect of shocks.
- `beta` controls volatility persistence.
- `gamma` controls the asymmetric or leverage effect.

The model is implemented with `rugarch::ugarchspec()` using `model = "eGARCH"` and `garchOrder = c(1, 1)`. The mean model is an intercept-only return equation with `armaOrder = c(0, 0)` and `include.mean = TRUE`.

## True Parameter Values

The same EGARCH parameter values are used for all true innovation distributions:

| Parameter | Value | Meaning |
|---|---:|---|
| `mu` | `0.000` | Mean return |
| `omega` | `-0.10` | Variance equation intercept |
| `alpha1` | `0.15` | Shock magnitude effect |
| `beta1` | `0.90` | Volatility persistence |
| `gamma1` | `0.10` | Asymmetric shock effect |

These values are defined in `R/simulation_config.R`.

## Innovation Distributions

Five true innovation distributions are used to generate the simulated return series. The same five distributions are also used as competing fitted models.

| Code | Distribution | True distribution parameters |
|---|---|---|
| `norm` | Normal | Standard normal |
| `std` | Student-t | Shape/degrees of freedom `8` |
| `ged` | Generalized Error Distribution | Shape `1.5` |
| `sstd` | Skewed Student-t | Shape/degrees of freedom `8`, left-skewed |
| `sged` | Skewed Generalized Error Distribution | Shape `1.5`, left-skewed |

The procedure document describes skewness as `-0.5` to indicate moderate left-skewness. In `rugarch`, the skew parameter is positive and `1` represents symmetry, so the implemented left-skewed value is `0.5`.

## Monte Carlo Design

The full simulation design is:

| Component | Setting |
|---|---|
| Replications | `5000` |
| Sample sizes | `50`, `500`, `1000`, `2000` |
| True distributions | `norm`, `std`, `ged`, `sstd`, `sged` |
| Fitted distributions | `norm`, `std`, `ged`, `sstd`, `sged` |

For each replication, sample size, and true distribution:

1. An EGARCH(1,1) specification is created with fixed true parameters.
2. A return series is simulated with `rugarch::ugarchpath()`.
3. The true conditional volatility path is saved from the simulation.
4. Five EGARCH(1,1) models are fitted to the same simulated return series, one under each competing innovation distribution.
5. For every fitted model, convergence status, likelihood-based criteria, volatility recovery errors, and parameter estimates are recorded.

This produces one fitted-model result for each combination of:

```text
replication x sample size x true distribution x assumed distribution
```

Under the full design, this equals:

```text
5000 x 4 x 5 x 5 = 500,000 fitted EGARCH models
```

Because this is computationally heavy, development and smoke testing should use smaller values for `EGARCH_REPS` and `EGARCH_SAMPLE_SIZES`.

## Reproducibility

Each simulated series receives a deterministic seed based on the replication number, sample size, and true distribution:

```text
seed = seed_base + rep_id + 1000 * distribution_index + sample_size
```

The default `seed_base` is `100000`. This makes runs reproducible while ensuring that different design cells receive different random seeds.

## Model Fitting

For each simulated return series, the fitted EGARCH(1,1) models use the same variance and mean structure as the data-generating process. Only the assumed innovation distribution changes.

The fitted models are estimated with:

```r
rugarch::ugarchfit(
  spec = spec,
  data = y,
  solver = "hybrid",
  solver.control = list(trace = 0)
)
```

If fitting fails, the result row is retained with `converged = FALSE` and metric values set to `NA`. This keeps the simulation design balanced and allows convergence rates to be summarized directly.

## Metrics

For each fitted model, the simulation records convergence, log-likelihood, AIC, BIC, MSE, RMSE, and MAE. The MSE/RMSE/MAE metrics compare estimated conditional volatility against the true simulated conditional volatility.

For each time point:

```text
volatility_error_t = estimated_sigma_t - true_sigma_t
```

The volatility recovery metrics are:

```text
MSE  = mean(volatility_error_t^2)
RMSE = sqrt(MSE)
MAE  = mean(|volatility_error_t|)
```

The code also stores analogous variance-error metrics using:

```text
variance_error_t = estimated_sigma_t^2 - true_sigma_t^2
```

## Fit Summary

The file `fit_summary.csv` aggregates fitted-model quality by sample size, true distribution, and assumed distribution. It includes:

- convergence rate
- mean and standard deviation of AIC
- mean and standard deviation of BIC
- mean log-likelihood
- mean and median MSE
- mean and median RMSE
- mean and median MAE
- mean and median volatility RMSE
- mean and median variance RMSE

## AIC and BIC Selection Frequencies

For each replication, sample size, and true distribution, the fitted model with the lowest AIC is selected as the AIC winner. The same process is repeated for BIC. Selection frequencies are then computed as:

```text
selection_rate = number of times an assumed distribution is selected
               / total successful selections in that design cell
```

These summaries are saved as:

- `aic_selection_frequency.csv`
- `bic_selection_frequency.csv`

They show how often each candidate distribution is selected when the true data-generating distribution is known.

## Parameter Recovery

The simulation evaluates parameter recovery for:

- `mu`
- `omega`
- `alpha1`
- `beta1`
- `gamma1`
- `shape`
- `skew`

For each parameter, the code computes:

```text
error = estimate - true_value
bias = mean(error)
mean_abs_error = mean(|error|)
parameter_mse = mean(error^2)
parameter_rmse = sqrt(parameter_mse)
```

The parameter summaries are saved to `parameter_summary.csv`.

## Plots

The run creates four default plots:

- `aic_selection.png`: AIC selection rates by sample size and true distribution.
- `bic_selection.png`: BIC selection rates by sample size and true distribution.
- `volatility_rmse.png`: Mean volatility RMSE by sample size.
- `parameter_rmse.png`: Parameter RMSE by sample size.
