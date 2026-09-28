#!/bin/bash
# Kill only the build daemons THIS job started.
#
# `skip verify` drives a real Gradle build, and Gradle leaves two long-lived
# daemons behind: the Gradle daemon and the Kotlin compile daemon. On a
# self-hosted runner they outlive the job -- observed on this host at ~1.4 GB
# resident and ~440% CPU, still running long after the workflow had finished,
# with 8 GB of swap in use. Every later job on this box then starts into a host
# that is already thrashing, which is how an unrelated change comes back red.
#
# The obvious fix (`pkill -f KotlinCompileDaemon`) is wrong here and actively
# dangerous: all three audiobookphile runners AND the developer's own work share
# this one macOS host, so a blanket pkill from a CI job reaches straight into
# someone else's in-flight Gradle build. Killing that would look exactly like a
# corrupted Android toolchain on their side.
#
# So instead of pattern-killing, this script kills the DELTA: the daemons that
# appeared while the job was running. Anything already running when the job
# started belongs to someone else and is left alone.
#
# Usage:
#   ./scripts/reap-daemons.sh --snapshot          # record the current set
#   ./scripts/reap-daemons.sh --reap [snapshot]   # kill only the new ones
set -uo pipefail

SNAPSHOT_DEFAULT="${RUNNER_TEMP:-/tmp}/audiobookphile-daemons-before.$$"

# Daemons that leak past a finished build. `KotlinCompileServer` is the older
# spelling of the same Kotlin daemon; both appear depending on the Kotlin
# version Gradle resolves.
daemon_pids() {
  ps -A -o pid=,command= 2>/dev/null \
    | grep -E 'KotlinCompileDaemon|KotlinCompileServer|GradleDaemon|org\.gradle\.launcher\.daemon' \
    | grep -v grep \
    | awk '{print $1}' \
    | sort -n
}

case "${1:---reap}" in
  --snapshot)
    out="${2:-$SNAPSHOT_DEFAULT}"
    daemon_pids > "$out"
    count="$(wc -l < "$out" | tr -d ' ')"
    echo "📸 ${count} build daemon(s) already running; snapshot -> $out"
    [ -s "$out" ] && sed 's/^/     /' "$out"
    exit 0
    ;;

  --reap)
    snapshot="${2:-$SNAPSHOT_DEFAULT}"
    # No snapshot means this job never got as far as recording what was already
    # running, so "the delta" is unknowable. Guessing "everything is new" would
    # kill every daemon on a host this job does not own, so refuse instead. A
    # leaked daemon is a slow problem; killing another session's build is a
    # corrupt-toolchain problem.
    if [ ! -f "$snapshot" ]; then
      echo "🛡️  No daemon snapshot at $snapshot -- refusing to reap."
      echo "    Cannot tell this job's daemons from the host's pre-existing ones."
      exit 0
    fi
    before=" $(tr '\n' ' ' < "$snapshot") "
    new_pids=()
    for pid in $(daemon_pids); do
      case "$before" in *" $pid "*) continue ;; esac
      new_pids+=("$pid")
    done

    if [ "${#new_pids[@]}" -eq 0 ]; then
      echo "🧹 No new build daemons to reap (pre-existing daemons left untouched)."
      exit 0
    fi

    echo "🧹 Reaping ${#new_pids[@]} build daemon(s) started by this job: ${new_pids[*]}"
    for pid in "${new_pids[@]}"; do
      # SIGTERM first so the daemon flushes and exits cleanly.
      kill -TERM "$pid" 2>/dev/null || true
    done
    sleep 2
    for pid in "${new_pids[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then
        echo "   pid $pid ignored SIGTERM; sending SIGKILL"
        kill -KILL "$pid" 2>/dev/null || true
      fi
    done
    echo "   done. Daemons that predate this job were not touched."
    exit 0
    ;;

  *)
    echo "usage: $0 [--snapshot [file] | --reap [file]]" >&2
    exit 2
    ;;
esac
