#!/usr/bin/env bash
#SBATCH --job-name=egarch-sim
#SBATCH --output=logs/egarch-%A_%a.out
#SBATCH --error=logs/egarch-%A_%a.err
#SBATCH --array=1-200
#SBATCH --time=1-24:00:00
#SBATCH --cpus-per-task=1
#SBATCH --qos=long
#SBATCH --mem=16G

set -euo pipefail


PROJECT_DIR="${PROJECT_DIR:-$PWD}"
cd "$PROJECT_DIR"

mkdir -p logs

# Uncomment and adjust these lines if your cluster uses environment modules.
# module purge
# module load R
module load r-rocker-ml-verse/4.4.0+apptainer

export EGARCH_REPS="${EGARCH_REPS:-5000}"
export EGARCH_SAMPLE_SIZES="${EGARCH_SAMPLE_SIZES:-100,1000,5000, 8000}"
export EGARCH_OUTPUT_DIR="${EGARCH_OUTPUT_DIR:-results/batch}"
export EGARCH_TASK_ID="${SLURM_ARRAY_TASK_ID}"
export EGARCH_TASK_COUNT="${SLURM_ARRAY_TASK_COUNT}"

#Rscript -e 'if (requireNamespace("renv", quietly = TRUE)) renv::restore(prompt = FALSE)'
Rscript R/batch_run.R
