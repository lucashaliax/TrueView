#!/bin/zsh
# Checks how much an installed app costs while idle: memory, CPU, wakeups, threads and leaks.
# Runs automatically at the end of build.sh. Usage: tools/check_resources.sh [App.app]
#
# Fails (exit 1) on leaks or high idle CPU; warns on high memory or frequent wakeups.
set -uo pipefail

APP="${1:-/Applications/TrueView.app}"
NAME=$(basename "$APP" .app)
SAMPLE=${SAMPLE_SECONDS:-10}
MAX_MB=${MAX_FOOTPRINT_MB:-60}      # warn above this footprint, per process
MAX_CPU=${MAX_IDLE_CPU:-1.0}         # fail above this idle CPU %, per process
MAX_WAKEUPS=${MAX_WAKEUPS_PER_S:-5}  # warn above this many idle wakeups per second

pgrep -f "$APP/Contents/MacOS/" >/dev/null || { open -g "$APP"; sleep 5; }

# The app plus anything it embeds (extensions, helpers) that is running.
pids=(${(f)"$(pgrep -f "$APP/Contents/")"})
(( ${#pids} )) || { echo "✗ $NAME is not running"; exit 1; }

echo "Measuring $NAME for ${SAMPLE}s while idle…"
args=(); for p in $pids; do args+=(-pid $p); done
top_out=$(top -l 2 -s $SAMPLE -stats pid,cpu,idlew $args 2>/dev/null)

fail=0
printf "\n%-24s %9s %9s %8s %8s %7s\n" "Process" "Memory" "Peak" "CPU %" "Wake/s" "Leaks"
for p in $pids; do
  label=$(ps -o comm= -p $p); label=${label:t}
  fp=$(footprint $p 2>/dev/null)
  mem=$(echo "$fp" | sed -n 's/.*Footprint: \([0-9.]* [KMG]*B\).*/\1/p' | head -1)
  peak=$(echo "$fp" | sed -n 's/.*phys_footprint_peak: \([0-9.]* [KMG]*B\).*/\1/p' | head -1)
  # top prints two samples; the second one covers the measuring interval.
  lines=(${(f)"$(echo "$top_out" | awk -v p=$p '$1==p')"})
  cpu=$(echo "${lines[-1]}" | awk '{print $2}')
  w1=$(echo "${lines[1]}" | awk '{print $3}'); w2=$(echo "${lines[-1]}" | awk '{print $3}')
  wakes=$(echo "scale=1; (${w2:-0} - ${w1:-0}) / $SAMPLE" | bc)
  leaked=$(leaks $p 2>/dev/null | sed -n 's/.*: \([0-9]*\) leaks for.*/\1/p')
  printf "%-24s %9s %9s %8s %8s %7s\n" "$label" "${mem:-?}" "${peak:-?}" "${cpu:-?}" "$wakes" "${leaked:-?}"

  mb=$(echo "$mem" | awk '{v=$1; if ($2=="KB") v/=1024; if ($2=="GB") v*=1024; print int(v)}')
  (( ${mb:-0} > MAX_MB )) && echo "  ! $label uses ${mem}, above ${MAX_MB} MB"
  (( $(echo "${cpu:-0} > $MAX_CPU" | bc) )) && { echo "  ✗ $label uses ${cpu}% CPU while idle"; fail=1; }
  (( $(echo "$wakes > $MAX_WAKEUPS" | bc) )) && echo "  ! $label wakes up ${wakes} times per second while idle"
  (( ${leaked:-0} > 0 )) && { echo "  ✗ $label has ${leaked} leaks (run: leaks $p)"; fail=1; }
done

echo
(( fail )) && echo "✗ Resource check failed" || echo "✓ Resource check passed"
exit $fail
