#!/bin/bash
# Wonderland Jenkins entrypoint. Stages the per-player flag as a root-only file in the controller's
# home directory (~/flag5.txt) — WITHOUT the flag ever being an image layer, a spec value or a
# process environment variable. The flag is NOT a Jenkins credential: it is a file on the
# controller's filesystem, reachable only by a process running on the controller as root (i.e. a
# pipeline pinned to the Built-In Node), which is exactly the Cheshire Cat challenge.
#
# Isoloom mounts the per-player input as a read-only file at /run/lab/secrets/flag5. When it is empty
# (an offline start — local, CI) the inert development placeholder is staged instead, so the lab
# still comes up and is solvable.
set -eu

DEV='cc-dev-flag-not-a-real-secret-0000'
SRC_FLAG='/run/lab/secrets/flag5'
DEST="${HOME:-/root}/flag5.txt"

if [ -s "$SRC_FLAG" ]; then
  tr -d '\r\n' < "$SRC_FLAG" > "$DEST"
else
  printf '%s' "$DEV" > "$DEST"
fi
chown root:root "$DEST" 2>/dev/null || true
chmod 0400 "$DEST"

exec /usr/bin/tini -- /usr/local/bin/jenkins.sh "$@"
