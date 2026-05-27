#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-$PWD}"
cd "$PROJECT_DIR"

export EGARCH_OUTPUT_DIR="${EGARCH_OUTPUT_DIR:-results/batch}"

Rscript R/combine_batch_results.R
