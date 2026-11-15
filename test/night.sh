#!/bin/sh
# The night run of docs.yml draws the time of the next night. Each case states the decision for a given time and a given slot of the last night run.
set -eu
. "$1"
wrong=0
expect() {
  if [ "$1" != "$2" ]; then
    echo "expected '$1', got '$2' for: $3" >&2
    wrong=1
  fi
}
expect run "$(night_decision 2026-11-16 00:13 '' '')" "no artifact"
expect skip "$(night_decision 2026-11-16 01:43 2026-11-16 02:13)" "a tick before the slot"
expect run "$(night_decision 2026-11-16 02:13 2026-11-16 02:13)" "the tick of the slot"
expect run "$(night_decision 2026-11-16 02:43 2026-11-16 02:13)" "a tick after the slot"
expect skip "$(night_decision 2026-11-15 04:43 2026-11-16 02:13)" "the night has run, the slot is the next night"
expect run "$(night_decision 2026-11-18 00:13 2026-11-16 02:13)" "the slot passed with no run"
expect "2026-11-16 00:13" "$(night_draw 2026-11-15 0)" "draw 0"
expect "2026-11-16 03:43" "$(night_draw 2026-11-15 7)" "draw 7"
expect "2026-11-16 00:13" "$(night_draw 2026-11-15 8)" "draw 8"
expect "2026-12-01 01:43" "$(night_draw 2026-11-30 3)" "the end of a month"
for n in 0 1 2 3 4 5 6 7; do
  slot=$(night_draw 2026-11-15 "$n")
  time=${slot#* }
  case "$time" in
    00:13|00:43|01:13|01:43|02:13|02:43|03:13|03:43) ;;
    *) echo "the slot $slot is not a tick of the cron line between 00:00 and 04:00" >&2; wrong=1 ;;
  esac
done
exit "$wrong"
