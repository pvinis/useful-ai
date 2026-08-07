#!/bin/bash
#
# crew HUD acceptance suite — SPEC.md §8, hand 2.
#
#   bash skills/bridge/tests/hud/run.sh
#
# Renders every §7 row from the fixture documents in ./fixtures and asserts
# every bell transition against bell.log. Nothing here touches ~/.cache or
# ~/crew: the plugin is pointed at a scratch cache under ./.work, and
# CREW_HUD_SILENT=1 diverts notifications into notify.log so they can be
# counted instead of posted. The one notification the captain confirms by eye
# is fired by hand, see ../../README.md.
#
# The fixture path is passed through CREW_HUD_STATUS_CMD, which word-splits, so
# the checkout must not live under a path containing spaces.
#
# Where each §7 row is covered:
#
#   closed slug, worktree removed      closed-skipped.json, asserted absent
#   close skipped a running member     closed-running.json
#   dead pid                           normal.json, and the bell's died edge
#   empty status / pid write races     broken.json, and the two-poll confirm
#   malformed meta.json                broken.json
#   claude member, no transcript       normal.json (lookout) / broken.json (hand-2)
#   transcript unreadable              broken.json (hand-3)
#   transcript stale after resume      broken.json (hand-4)
#   partial JSONL last line            collector-side; the document is normal
#   zero crew / no ~/crew              zero.json
#   collector crash                    invalid.json, and a missing fixture file
#   poll overlap                       lock held, previous output re-printed
#   cache deleted                      b-cold-done.json, b-cold-ask.json
#   reboot                             b-mass-died.json, one summary
#   Mac asleep at ask time             b-cold-ask.json — asking is a level

set -uo pipefail

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$HERE/../../scripts/crew-hud-swiftbar.sh"
FIX="$HERE/fixtures"
WORK="$HERE/.work"

C_ASK='#FF9500,#FF9F0A'
C_BAD='#FF3B30,#FF453A'
C_DIM='#8E8E93,#98989D'

export CREW_HUD_SILENT=1
export CREW_HOME="$WORK/crew"

passed=0
failed=0

ok()   { passed=$((passed + 1)); printf '  ok   %s\n' "$1"; }
no()   { failed=$((failed + 1)); printf '  FAIL %s\n' "$1"
         if [[ $# -gt 1 ]]; then printf '       %s\n' "$2"; fi; }
same() { if [[ "$2" == "$3" ]]; then ok "$1"; else no "$1" "want [$3] got [$2]"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) no "$1" "missing [$3]" ;; esac; }
hasnt(){ case "$2" in *"$3"*) no "$1" "found [$3]" ;; *) ok "$1" ;; esac; }

fresh() { rm -rf "$WORK"; mkdir -p "$WORK"; export CREW_HUD_CACHE="$WORK"; }
render() { CREW_HUD_STATUS_CMD="cat $FIX/$1" bash "$PLUGIN"; }
poll()   { render "$1" >/dev/null; }

nth()   { printf '%s\n' "$2" | sed -n "$1p"; }
lineof(){ printf '%s\n' "$2" | grep -m1 -- "$1"; }
count() { local n; [[ -f "$2" ]] || { printf '0'; return; }
          n="$(grep -c -- "$1" "$2" 2>/dev/null)"; printf '%s' "${n:-0}"; }
lines() { [[ -f "$1" ]] || { printf '0'; return; }; awk 'END{print NR}' "$1"; }
maxpipes() { printf '%s\n' "$1" | awk -F'|' 'NF-1>m{m=NF-1} END{print m+0}'; }

# ---------------------------------------------------------------- render ----

printf '\n§7 zero crew / no ~/crew\n'
fresh
out="$(render zero.json)"
same 'bar is the dim lone anchor' "$(nth 1 "$out")" "⚓ | color=$C_DIM"
has 'dropdown says there is no crew' "$out" "No crew | color=$C_DIM"
has 'footer opens the crew root' "$out" "bash=/usr/bin/open param1=\"$CREW_HOME\" terminal=false"

printf '\n§4 bar and dropdown, full document\n'
fresh
out="$(render normal.json)"
same 'bar counts come from .bar only' "$(nth 1 "$out")" '⚓ 1❓ 2▶ ✗1'
same 'attention slug sorts first' "$(nth 3 "$out")" "mobile-app4 · LS-6648 — work | color=$C_DIM"
has 'the two LS-6648 clones sit adjacent, unmerged' "$out" "mobile-app · LS-6648 | color=$C_DIM"
hasnt 'phase is omitted when null' "$(lineof 'mobile-app · LS-6648' "$out")" '—'
same 'members sort asking, bad, running' \
  "$(printf '%s\n' "$out" | sed -n '4,6p' | awk '{print $1}' | tr -d '\n')" '❓✗▶'
has 'asking line carries the ask orange' "$(lineof '^❓' "$out")" "color=$C_ASK"
has 'died line carries the bad red' "$(lineof '^✗' "$out")" "color=$C_BAD"
has 'done line carries the dim grey' "$(lineof '^✓' "$out")" "color=$C_DIM"
hasnt 'running line keeps the default colour' "$(lineof 'hand-1 — 12m' "$out")" 'color='
has 'member click opens its state directory' "$(lineof 'hand-1 — 12m' "$out")" \
  'bash=/usr/bin/open param1="/Users/pavlos/crew/mobile-app4/LS-6648/hand-1" terminal=false'
has 'stale running member is marked' "$(lineof 'hand-1 — 22m' "$out")" '⚠ | '
has 'stale marker takes the ask orange' "$(lineof 'hand-1 — 22m' "$out")" "color=$C_ASK"
has 'unknown member renders with the ellipsis glyph' "$out" '… lookout — unknown 1m'
has 'footer refreshes' "$out" 'Refresh | refresh=true sfimage=arrow.clockwise'

printf '\n§4 pipe neutralisation\n'
has 'pipe in a commit subject becomes U+2223, text intact' "$out" \
  '"Add retry to upload ∣ queue" 2m ago'
has 'pipe in an ask snippet becomes U+2223, text intact' "$out" \
  'Ποιο branch να χρησιμοποιήσω: A ∣ B;'
has 'pipe in a doing line becomes U+2223, text intact' "$out" \
  'quiet 14m · Edit src/upload∣queue.ts'
same 'no rendered line has more than one real pipe' "$(maxpipes "$out")" '1'

printf '\n§7 malformed meta, unknown status, transcript states\n'
fresh
out="$(render broken.json)"
has 'broken meta.json renders, never fatal' "$out" '‼ broken meta.json'
has 'empty status file renders as unknown' "$out" '… hand-2 — unknown 0m'
has 'unreadable transcript is shown, not rendered as calm' "$out" 'transcript unreadable'
has 'stale transcript is shown' "$out" 'resumed, transcript stale'
same 'no line has more than one real pipe' "$(maxpipes "$out")" '1'

printf '\n§7 closed slugs\n'
fresh
out="$(render closed-running.json)"
has 'close that skipped a running member is flagged' "$out" \
  "mobile-app4 · LS-6648 — work — closed but running | color=$C_BAD"
out="$(render closed-skipped.json)"
hasnt 'closed all-terminal slug is absent from the glass' "$out" 'LS-6648'

printf '\n§7 collector failure\n'
fresh
good="$(render normal.json)"
out="$(render invalid.json)"
same 'invalid JSON renders the error bar' "$(nth 1 "$out")" "⚓ ✱ | color=$C_BAD"
has 'error dropdown opens error.txt' "$out" \
  "collector error — click for details | color=$C_BAD bash=/usr/bin/open param1=\"$WORK/error.txt\" terminal=false"
same 'a failed render does not overwrite last-output.txt' "$(cat "$WORK/last-output.txt")" "$good"
out="$(render does-not-exist.json)"
same 'a crashing collector renders the error bar' "$(nth 1 "$out")" "⚓ ✱ | color=$C_BAD"
has 'stderr is captured for the captain' "$(cat "$WORK/error.txt")" 'does-not-exist.json'

printf '\n§7 poll overlap\n'
fresh
poll b-running.json
before="$(cat "$WORK/last-output.txt")"
bell_before="$(lines "$WORK/bell.log")"
mkdir "$WORK/lock"
out="$(render b-ask1.json)"
same 'a poll that finds the lock reprints the last output' "$out" "$before"
same 'and leaves the bell untouched' "$(lines "$WORK/bell.log")" "$bell_before"
rmdir "$WORK/lock"

# ------------------------------------------------------------------ bell ----

printf '\n§5 bell — ask is a level keyed by question identity\n'
fresh
poll b-running.json
same 'cold cache seeds the running member silently' "$(lines "$WORK/bell.log")" '0'
poll b-ask1.json
same 'a new ask rings once' "$(count 'crew-hud/hand-1#1000' "$WORK/bell.log")" '1'
same 'and posts one notification' "$(lines "$WORK/notify.log")" '1'
poll b-ask1.json
same 'the same question does not ring again' "$(count 'crew-hud/hand-1#1000' "$WORK/bell.log")" '1'
poll b-ask2.json
same 'a second question with a new mtime rings' "$(count 'crew-hud/hand-1#2000' "$WORK/bell.log")" '1'
poll b-ask2.json
same 'and rings only once' "$(count 'crew-hud/hand-1#2000' "$WORK/bell.log")" '1'
poll b-running.json
poll b-ask2.json
same 'an answered ask never re-rings' "$(count 'crew-hud/hand-1#2000' "$WORK/bell.log")" '1'
same 'two questions, two notifications, no more' "$(lines "$WORK/notify.log")" '2'

printf '\n§5 bell — terminal states are edges, confirmed across two polls\n'
poll b-running.json
poll b-running.json
poll b-done.json
same 'first sighting of done is a candidate, silent' "$(count '→done' "$WORK/bell.log")" '0'
poll b-done.json
same 'the confirm poll rings running→done' "$(count 'running→done' "$WORK/bell.log")" '1'
poll b-done.json
same 'and does not ring again' "$(count '→done' "$WORK/bell.log")" '1'

printf '\n§5 bell — cold cache\n'
fresh
poll b-cold-done.json
same 'old done and died members seed silently' "$(lines "$WORK/bell.log")" '0'
fresh
poll b-cold-ask.json
same 'a live ask rings from a cold cache' "$(count 'asking' "$WORK/bell.log")" '1'
same 'and nothing else does' "$(lines "$WORK/bell.log")" '1'

printf '\n§5 bell — more than three rings collapse to one summary\n'
fresh
poll b-mass-running.json
poll b-mass-died.json
same 'the first poll after the mass death is silent' "$(lines "$WORK/bell.log")" '0'
poll b-mass-died.json
same 'five deaths are five audit lines' "$(count '→died' "$WORK/bell.log")" '5'
same 'plus one summary line' "$(count 'summary' "$WORK/bell.log")" '1'
has 'summarised by kind and slug' "$(cat "$WORK/bell.log")" 'crew: 5 events — 5 died · LS-6648, crew-hud'
same 'and exactly one notification is posted' "$(lines "$WORK/notify.log")" '1'

# ----------------------------------------------------------------- total ----

rm -rf "$WORK"
printf '\n%s passed, %s failed\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
