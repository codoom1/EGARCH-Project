# Cluster Batch Processing

The full simulation fits 500,000 EGARCH models, so it is better suited to a cluster than to an interactive local R session. This project includes a chunked batch workflow for array jobs.

## Files

- `R/batch_run.R`: runs one chunk of the simulation design.
- `R/combine_batch_results.R`: combines all chunk files and creates summaries and plots.
- `scripts/slurm-egarch-array.sh`: SLURM array-job template.
- `scripts/combine-egarch-batch.sh`: helper script for combining completed chunks.

## How The Batch Split Works

The full design is the grid:

```text
replication x sample size x true distribution
```

Each design row simulates one return series and fits all five candidate distributions to that same series. The batch runner assigns design rows across array tasks using the task id and total number of tasks:

```text
batch_task_id = ((design_row - 1) %% task_count) + 1
```

Each array task writes one RDS file and one CSV file under:

```text
results/batch/chunks/
```

The combine step reads the chunk RDS files, binds them into one `sim_results` table, computes all summaries, and writes the final outputs under `results/batch/`.

## SLURM Usage

From the project root, submit the array job:

```sh
mkdir -p logs
sbatch scripts/slurm-egarch-array.sh
```

The script loads the newest non-CUDA R module currently available on the UMass cluster:

```sh
module load r-rocker-ml-verse/4.4.0+apptainer
```

The cluster also provides R 4.5.1 through CUDA-tagged images:

```text
r-rocker-ml-verse/4.5.1_cuda11.8.0+apptainer
r-rocker-ml-verse/4.5.1_cuda12.8.1+apptainer
```

This simulation does not use GPUs, so the default SLURM script avoids CUDA modules. If you still want to run under the R 4.5.1 CUDA image, submit with:

```sh
R_MODULE="r-rocker-ml-verse/4.5.1_cuda12.8.1+apptainer" sbatch scripts/slurm-egarch-array.sh
```

To list available R module versions on the cluster:

```sh
module spider r-rocker-ml-verse
module avail r-rocker-ml-verse
```

The default script uses:

```text
#SBATCH --array=1-100
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
```

Adjust these values for your cluster and queue limits. A larger array has smaller chunks per task; a smaller array has larger chunks per task.

## Combine Completed Results

After every array task finishes, combine the results:

```sh
bash scripts/combine-egarch-batch.sh
```

Final outputs are written to:

```text
results/batch/
```

## Custom Run Size

You can override the design without editing R code:

```sh
EGARCH_REPS=5000 \
EGARCH_SAMPLE_SIZES=50,500,1000,2000 \
EGARCH_OUTPUT_DIR=results/batch \
sbatch scripts/slurm-egarch-array.sh
```

For a small cluster test:

```sh
EGARCH_REPS=2 \
EGARCH_SAMPLE_SIZES=50 \
EGARCH_OUTPUT_DIR=results/batch-test \
sbatch --array=1-2 scripts/slurm-egarch-array.sh
```

Then combine:

```sh
EGARCH_OUTPUT_DIR=results/batch-test bash scripts/combine-egarch-batch.sh
```

## Notes

- The SLURM script restores the `renv` environment before running the chunk.
- If your cluster does not allow internet access from compute nodes, run `renv::restore()` once on a login node or prepare the project library before submitting jobs.
- The local `renv.lock` was created with R 4.5.1. The default CPU module uses R 4.4.0, so `renv` may warn about the R version difference and still restore compatible package versions. If restoration fails, use one of the R 4.5.1 CUDA-tagged modules or regenerate the lockfile from the cluster R version.
- The scripts assume they are launched from the project root unless `PROJECT_DIR` is set.
