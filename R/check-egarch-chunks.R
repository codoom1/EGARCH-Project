source("R/simulation_config.R")
source("R/simulation_functions.R")
source("R/batch_run.R")

chunk_dir <- Sys.getenv(
  "EGARCH_CHUNK_DIR",
  unset = file.path(simulation_config$output_dir, "batch/chunks")
)

task_count <- as.integer(Sys.getenv("EGARCH_TASK_COUNT", unset = "200"))

chunk_files <- sort(list.files(
  chunk_dir,
  pattern = "^chunk-[0-9]{4}-of-[0-9]{4}[.]rds$",
  full.names = TRUE
))

if (length(chunk_files) == 0L) {
  stop("No chunk RDS files found in: ", chunk_dir, call. = FALSE)
}

chunks <- lapply(chunk_files, readRDS)
chunk_task_counts <- unique(vapply(chunks, `[[`, integer(1), "task_count"))

if (!identical(chunk_task_counts, task_count)) {
  warning(
    "Chunk task_count values are: ",
    paste(chunk_task_counts, collapse = ", "),
    "; expected ", task_count,
    call. = FALSE
  )
}

expected_design <- simulation_design(simulation_config)
expected_design$batch_task_id <- ((seq_len(nrow(expected_design)) - 1L) %% task_count) + 1L

expected_keys <- expected_design |>
  dplyr::mutate(key = paste(rep_id, n, true_dist, sep = "|")) |>
  dplyr::select(key, rep_id, n, true_dist, batch_task_id)

observed_design <- dplyr::bind_rows(lapply(chunks, function(chunk) {
  chunk$design |>
    dplyr::mutate(
      chunk_task_id = chunk$task_id,
      chunk_task_count = chunk$task_count
    )
}))

observed_keys <- observed_design |>
  dplyr::mutate(key = paste(rep_id, n, true_dist, sep = "|")) |>
  dplyr::select(key, rep_id, n, true_dist, chunk_task_id, chunk_task_count)

missing_keys <- dplyr::anti_join(expected_keys, observed_keys, by = "key")
unexpected_keys <- dplyr::anti_join(observed_keys, expected_keys, by = "key")
duplicate_keys <- observed_keys |>
  dplyr::count(key, rep_id, n, true_dist, name = "count") |>
  dplyr::filter(count > 1L)
wrong_task_keys <- observed_keys |>
  dplyr::left_join(
    expected_keys |> dplyr::select(key, expected_task_id = batch_task_id),
    by = "key"
  ) |>
  dplyr::filter(!is.na(expected_task_id), chunk_task_id != expected_task_id)

cat("Chunk files:", length(chunk_files), "\n")
cat("Expected design rows:", nrow(expected_keys), "\n")
cat("Observed design rows:", nrow(observed_keys), "\n")
cat("Missing rows:", nrow(missing_keys), "\n")
cat("Unexpected rows:", nrow(unexpected_keys), "\n")
cat("Duplicate rows:", nrow(duplicate_keys), "\n")
cat("Rows in wrong task:", nrow(wrong_task_keys), "\n")

if (nrow(missing_keys) > 0L) {
  cat("\nMissing rows by task/n/true_dist:\n")
  print(
    missing_keys |>
      dplyr::count(batch_task_id, n, true_dist, name = "missing_rows") |>
      dplyr::arrange(batch_task_id, n, true_dist),
    n = 50
  )
}

if (nrow(duplicate_keys) > 0L) {
  cat("\nDuplicate rows:\n")
  print(duplicate_keys, n = 50)
}

if (nrow(wrong_task_keys) > 0L) {
  cat("\nRows assigned to the wrong task:\n")
  print(wrong_task_keys, n = 50)
}

if (nrow(missing_keys) > 0L ||
    nrow(unexpected_keys) > 0L ||
    nrow(duplicate_keys) > 0L ||
    nrow(wrong_task_keys) > 0L) {
  quit(status = 1L)
}

cat("\nChunk design validation passed.\n")
