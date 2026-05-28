#!/usr/bin/env bash
#SBATCH --job-name=egarch-rerun
#SBATCH --output=logs/egarch-rerun-%A_%a.out
#SBATCH --error=logs/egarch-rerun-%A_%a.err
#SBATCH --array=4,123,124,125,162
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G

set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-$PWD}"
cd "$PROJECT_DIR"

mkdir -p logs

# The UMass cluster currently exposes R through this Apptainer-backed module.
# Override at submit time with R_MODULE=<module-name> if your cluster changes it.
if command -v module >/dev/null 2>&1; then
  module purge
  module load "${R_MODULE:-r-rocker-ml-verse/4.4.0+apptainer}"
fi

export EGARCH_REPS="${EGARCH_REPS:-5000}"
export EGARCH_SAMPLE_SIZES="${EGARCH_SAMPLE_SIZES:-100,1000,5000,8000}"
export EGARCH_VARIANCE_MODEL="${EGARCH_VARIANCE_MODEL:-eGARCH}"
export EGARCH_OUTPUT_DIR="${EGARCH_OUTPUT_DIR:-results/batch}"
export EGARCH_FIT_TIMEOUT_SECONDS="${EGARCH_FIT_TIMEOUT_SECONDS:-120}"
export EGARCH_MAX_SIM_RETRIES="${EGARCH_MAX_SIM_RETRIES:-3}"
export EGARCH_TASK_ID="${SLURM_ARRAY_TASK_ID}"

# Keep this equal to the original full array size. For the sparse rerun array,
# SLURM_ARRAY_TASK_COUNT would be 5, which would create incompatible chunks.
export EGARCH_TASK_COUNT="${EGARCH_TASK_COUNT:-200}"

Rscript R/batch_run.R
