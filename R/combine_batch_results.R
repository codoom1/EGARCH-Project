# ============================================================
# Combine EGARCH batch chunks and create final summaries
# ============================================================

source("R/simulation_config.R")
source("R/simulation_summaries.R")
source("R/simulation_plots.R")

called_from_source <- function() {
  any(vapply(
    sys.calls(),
    function(call) identical(call[[1]], quote(source)),
    logical(1)
  ))
}

combine_batch_results <- function(config = simulation_config) {
  chunk_dir <- Sys.getenv(
    "EGARCH_CHUNK_DIR",
    unset = file.path(config$output_dir, "batch/chunks")
  )

  chunk_files <- sort(list.files(
    chunk_dir,
    pattern = "^chunk-[0-9]{4}-of-[0-9]{4}[.]rds$",
    full.names = TRUE
  ))

  if (length(chunk_files) == 0L) {
    stop("No batch chunk RDS files found in: ", chunk_dir, call. = FALSE)
  }

  message("Combining ", length(chunk_files), " chunk files from ", chunk_dir)

  chunks <- lapply(chunk_files, readRDS)
  task_counts <- unique(vapply(chunks, `[[`, integer(1), "task_count"))

  if (length(task_counts) != 1L) {
    stop("Chunk files have inconsistent task counts.", call. = FALSE)
  }

  expected_task_count <- task_counts[[1]]

  if (length(chunk_files) != expected_task_count) {
    warning(
      "Found ", length(chunk_files), " chunk files, but expected ",
      expected_task_count, ". Combining available chunks only.",
      call. = FALSE
    )
  }

  sim_results <- dplyr::bind_rows(lapply(chunks, `[[`, "sim_results"))
  summaries <- make_all_summaries(sim_results, config)
  plots <- make_simulation_plots(summaries, sim_results)

  save_simulation_outputs(
    sim_results = sim_results,
    summaries = summaries,
    plots = plots,
    output_dir = config$output_dir
  )

  message("Wrote combined simulation outputs to ", config$output_dir)
  invisible(config$output_dir)
}

if (!called_from_source()) {
  combine_batch_results()
}
