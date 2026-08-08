#!/usr/bin/env bash
# Preview only. Writes nothing.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./config.sh
acquire_output_lock

./encoder_params.sh "${ENCODER_ARGS[@]}" -n "$INPUT_DIR"