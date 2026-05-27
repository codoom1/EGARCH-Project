# ============================================================
# Run one batch chunk of the EGARCH simulation design
# ============================================================

source("R/simulation_config.R")
source("R/simulation_functions.R")

batch_integer_env <- function(name, default = NA_integer_) {
  value <- Sys.getenv(name, unset = NA_character_)

  if (is.na(value) || !nzchar(value)) {
    return(default)
  }

  as.integer(value)
}

chunk_design <- function(design, task_id, task_count) {
  if (is.na(task_id) || task_id < 1) {
    stop("Batch task id must be a positive integer.", call. = FALSE)
  }

  if (is.na(task_count) || task_count < 1) {
    stop("Batch task count must be a positive integer.", call. = FALSE)
  }

  if (task_id > task_count) {
    stop("Batch task id cannot exceed batch task count.", call. = FALSE)
  }

  design$batch_task_id <- ((seq_len(nrow(design)) - 1L) %% task_count) + 1L
  design[design$batch_task_id == task_id, c("rep_id", "n", "true_dist")]
}

called_from_source <- function() {
  any(vapply(
    sys.calls(),
    function(call) identical(call[[1]], quote(source)),
    logical(1)
  ))
}

run_batch_chunk <- function(config = simulation_config) {
  task_id <- batch_integer_env(
    "EGARCH_TASK_ID",
    batch_integer_env("SLURM_ARRAY_TASK_ID", 1L)
  )

  task_count <- batch_integer_env(
    "EGARCH_TASK_COUNT",
    batch_integer_env("SLURM_ARRAY_TASK_COUNT", 1L)
  )

  output_dir <- config$output_dir
  chunk_dir <- file.path(output_dir, "chunks")
  dir.create(chunk_dir, recursive = TRUE, showWarnings = FALSE)

  full_design <- simulation_design(config)
  design_chunk <- chunk_design(full_design, task_id, task_count)

  message(
    "Running EGARCH batch task ", task_id, " of ", task_count,
    " with ", nrow(design_chunk), " design rows."
  )

  chunk_results <- run_simulation_design(
    design = design_chunk,
    config = config
  )

  chunk_stub <- sprintf("chunk-%04d-of-%04d", task_id, task_count)
  chunk_rds <- file.path(chunk_dir, paste0(chunk_stub, ".rds"))
  chunk_csv <- file.path(chunk_dir, paste0(chunk_stub, ".csv"))

  saveRDS(
    list(
      task_id = task_id,
      task_count = task_count,
      design = design_chunk,
      sim_results = chunk_results
    ),
    chunk_rds
  )

  write.csv(chunk_results, chunk_csv, row.names = FALSE)

  message("Wrote batch chunk results to ", chunk_rds)
  invisible(chunk_rds)
}

if (!called_from_source()) {
  run_batch_chunk()
}
