#!/bin/sh
set -eu
# Technical CI artifacts are explicit and never accepted as store submissions.
if [ "${KABE_TECHNICAL_PILOT:-}" = true ]; then
  echo 'TECHNICAL PILOT: review assets allowed; not a production release.'
  exit 0
fi
if [ -z "${KABE_RELEASE_EVIDENCE_DIR:-}" ]; then
  echo 'Production blocked: set KABE_RELEASE_EVIDENCE_DIR to real reviewed evidence outside Git.' >&2
  exit 2
fi
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
python3 "$repo_dir/tools/release_preflight.py" --content-only --evidence-dir "$KABE_RELEASE_EVIDENCE_DIR"
