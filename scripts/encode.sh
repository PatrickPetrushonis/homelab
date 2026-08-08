#!/usr/bin/env bash
# Concurrent runs against the same OUTPUT_DIR are blocked by acquire_output_lock
# in config.sh (encoder_params.sh itself has no internal lock)
# a second run will exit immediately with an error instead of racing.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./config.sh
acquire_output_lock

./encoder_params.sh "${ENCODER_ARGS[@]}" "$INPUT_DIR"