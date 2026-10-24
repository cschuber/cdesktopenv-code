#!/usr/bin/env bash
# Capture output and preserve the command and tee exit codes.
set -uo pipefail
log="${1:?log path required}"
shift
"$@" 2>&1 | tee "$log"
statuses=("${PIPESTATUS[@]}")
printf '%s\n' "${statuses[0]}" > "$log.command-exit-status.txt" || exit 1
printf '%s\n' "${statuses[1]}" > "$log.logger-exit-status.txt" || exit 1
if test "${statuses[1]}" != 0; then
  printf 'Log capture failed: %s (tee exit %s)\n' "$log" "${statuses[1]}" >&2
  exit 1
fi
exit "${statuses[0]}"
