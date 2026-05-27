#!/usr/bin/env bash
#SBATCH --job-name=egarch-sim
#SBATCH --output=logs/egarch-%A_%a.out
#SBATCH --error=logs/egarch-%A_%a.err
#SBATCH --array=1-100
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G

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
export EGARCH_SAMPLE_SIZES="${EGARCH_SAMPLE_SIZES:-50,500,1000,2000}"
export EGARCH_OUTPUT_DIR="${EGARCH_OUTPUT_DIR:-results/batch}"
export EGARCH_TASK_ID="${SLURM_ARRAY_TASK_ID}"
export EGARCH_TASK_COUNT="${SLURM_ARRAY_TASK_COUNT}"

#Rscript -e 'if (requireNamespace("renv", quietly = TRUE)) renv::restore(prompt = FALSE)'
Rscript R/batch_run.R
