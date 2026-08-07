#!/bin/bash
#
# <bitbar.title>crew HUD</bitbar.title>
# <bitbar.version>v1.0</bitbar.version>
# <bitbar.author>pvinis</bitbar.author>
# <bitbar.author.github>pvinis</bitbar.author.github>
# <bitbar.desc>Menu bar view of the crew: who is asking, running, dead, done.</bitbar.desc>
# <bitbar.dependencies>jq</bitbar.dependencies>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
#
# crew HUD — renders `crew status --json` (schema v1) and rings a bell on
# changes. Install instructions live in ../README.md.
#
# It is a renderer. The only thing it writes is the cache directory
# (default ~/.cache/crew-hud), never anything under ~/crew:
#
#   snapshot.json    per-member confirmed + candidate status, and rung ask keys
#   bell.log         audit trail, one TAB-separated line per event:
#                      <iso8601>  <key>  <transition>  <body>
#                    a poll with more than 3 events appends one extra line
#                      <iso8601>  *  summary  crew: N events — …
#                    and posts that one notification instead of N
#   last-output.txt  last successful render, reprinted when a poll overlaps
#   error.txt        collector stderr, opened from the error dropdown
#   lock/            mkdir-lock, removed on exit
#
# Environment (all optional; the last three exist for the test suite):
#   CREW_HOME             crew state root, for the footer link (default ~/crew)
#   CREW_HUD_CACHE        cache directory (default ~/.cache/crew-hud)
#   CREW_HUD_STATUS_CMD   command printing the document (default: ./crew status --json)
#   CREW_HUD_SILENT       1 = post nothing; append what would have been posted
#                         to notify.log instead, so the test suite can count it

set -uo pipefail
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export PATH

# Apple system colors, light,dark pairs. Defined once, passed to jq below.
C_ASK='#FF9500,#FF9F0A'
C_BAD='#FF3B30,#FF453A'
C_DIM='#8E8E93,#98989D'

# Resolve through the symlink SwiftBar runs, so `crew` is found next to us.
self="${BASH_SOURCE[0]}"
while [[ -L "$self" ]]; do
  self_dir="$(cd -P "$(dirname "$self")" && pwd)"
  self="$(readlink "$self")"
  [[ "$self" == /* ]] || self="$self_dir/$self"
done
SCRIPT_DIR="$(cd -P "$(dirname "$self")" && pwd)"

CREW_ROOT="${CREW_HOME:-$HOME/crew}"
CREW_DISP="${CREW_ROOT/#$HOME/~}"
CACHE="${CREW_HUD_CACHE:-$HOME/.cache/crew-hud}"
SNAP="$CACHE/snapshot.json"
BELL_LOG="$CACHE/bell.log"
LAST_OUT="$CACHE/last-output.txt"
ERR="$CACHE/error.txt"
LOCK="$CACHE/lock"

if [[ -n "${CREW_HUD_STATUS_CMD:-}" ]]; then
  # shellcheck disable=SC2206  # word splitting is the point of this seam
  STATUS_CMD=( ${CREW_HUD_STATUS_CMD} )
else
  STATUS_CMD=( "$SCRIPT_DIR/crew" status --json )
fi

# ---------------------------------------------------------------- render ----

# sb_escape is the one escaping routine, applied to every dynamic string that
# reaches SwiftBar. SwiftBar parses `title | key=value`, so a `|` anywhere in a
# commit subject, a doing line or an ask snippet would eat the rest of the line:
# it becomes U+2223 DIVIDES. Control characters go; truncation is by codepoint,
# which jq's string slicing gives us for free.
read -r -d '' RENDER_JQ <<'JQ' || true
def sb_escape($max):
  (if . == null then "" else tostring end)
  | gsub("[[:cntrl:]]"; "")
  | gsub("\\|"; "∣")
  | if (length > $max) then (.[0:$max-1] + "…") else . end;
def text: sb_escape(140);
def path: sb_escape(1024);

def line($title; $params):
  ($params | map(select(. != null))) as $p
  | ($title | text) + (if ($p | length) == 0 then "" else " | " + ($p | join(" ")) end);

def open_action($p): "bash=/usr/bin/open param1=\"" + ($p | path) + "\" terminal=false";

def member_color:
  if .stale == true then $c_ask
  elif .status == "asking" then $c_ask
  elif .status == "died" or .status == "failed" then $c_bad
  elif .status == "done" then $c_dim
  else null end;

def member_rank:
  if . == "asking" then 0
  elif . == "died" or . == "failed" then 1
  elif . == "running" then 2
  elif . == "done" then 3
  else 4 end;

def member_line:
  . as $m
  | (($m.glyph // "…") + " " + ($m.label // $m.role // "?")
     + (if $m.stale == true then " ⚠" else "" end)) as $title
  | line($title;
         [ (($m | member_color) | if . == null then null else "color=" + . end),
           (if ($m.paths.dir // null) == null then null
            else open_action($m.paths.dir) end) ]);

def slug_block:
  . as $s
  | (($s.repo // "?") + " · " + ($s.slug // "?")) as $h
  | (if ($s.phase // null) == null then $h else $h + " — " + $s.phase end) as $h
  | (if $s.closed == true then $h + " — closed but running" else $h end) as $h
  | [ line($h; [ "color=" + (if $s.closed == true then $c_bad else $c_dim end) ]) ]
    + (($s.members // [])
       | sort_by([ ((.status // "unknown") | member_rank), (.role // "") ])
       | map(member_line));

(.bar // {}) as $bar
| [ (if (($bar.asking  // 0) > 0) then "\($bar.asking)❓"  else empty end),
    (if (($bar.running // 0) > 0) then "\($bar.running)▶"  else empty end),
    (if (($bar.bad     // 0) > 0) then "✗\($bar.bad)"      else empty end) ] as $seg
| (if ($seg | length) == 0 then line("⚓"; [ "color=" + $c_dim ])
   else "⚓ " + ($seg | join(" ")) end) as $bar_line
| ((.slugs // [])
   | sort_by([ (if .attention == true then 0 else 1 end), (.slug // ""), (.repo // "") ])
   | map(slug_block)) as $blocks
| [ $bar_line, "---" ]
  + (if ($blocks | length) == 0 then [ line("No crew"; [ "color=" + $c_dim ]) ]
     else $blocks[0] + (($blocks[1:] | map([ "---" ] + .)) | add // []) end)
  + [ "---",
      line("Refresh"; [ "refresh=true", "sfimage=arrow.clockwise" ]),
      line("Open " + $crew_disp; [ open_action($crew_root), "sfimage=folder" ]) ]
| .[]
JQ

render_error() {
  printf '⚓ ✱ | color=%s\n' "$C_BAD"
  printf -- '---\n'
  printf 'collector error — click for details | color=%s bash=/usr/bin/open param1="%s" terminal=false\n' \
    "$C_BAD" "$ERR"
  printf -- '---\n'
  printf 'Refresh | refresh=true sfimage=arrow.clockwise\n'
}

print_cached() {
  if [[ -s "$LAST_OUT" ]]; then
    cat "$LAST_OUT"
  else
    printf '⚓ | color=%s\n' "$C_DIM"
  fi
}

# ------------------------------------------------------------------ bell ----

# asking is a level keyed by question identity, so it rings once per question
# and rings from a cold cache too — attention is due whenever we notice it.
# died/failed/done are edges, confirmed across two consecutive polls, which is
# what filters the empty-file write races; from a cold cache they seed silently.
read -r -d '' BELL_JQ <<'JQ' || true
def clean($max):
  (if . == null then "" else tostring end)
  | gsub("[[:cntrl:]]"; " ")
  | if (length > $max) then (.[0:$max-1] + "…") else . end;

def terminal: . == "died" or . == "failed" or . == "done";

def member_of: . as $s | ($s | rindex("#")) as $i
  | if $i == null then $s else $s[0:$i] end;

[ (.slugs // [])[] as $s
  | (($s.members // [])[] | {
      repo:   (($s.repo // "?") | clean(60)),
      slug:   (($s.slug // "?") | clean(60)),
      role:   ((.role  // "?") | clean(60)),
      status: (.status // "unknown"),
      snippet: (if (.ask // null) == null then null
                else ((.ask.snippet? // .ask.text? // (.ask | strings) // "") | clean(120)) end),
      ask_id: (if (.ask // null) == null then null
               else ((.ask.mtime? // .ask.snippet? // (.ask | strings) // "?") | tostring | clean(80)) end) }) ]
| map(. + { key: "\(.repo)/\(.slug)/\(.role)" })
| map(. + { ask_key: (if .ask_id == null then null else "\(.key)#\(.ask_id)" end) })
| . as $m
| ($snap | if type == "object" then . else null end) as $prev
| ($prev == null) as $cold
| (($prev.confirmed // {})) as $conf
| (($prev.candidate // {})) as $cand
| ((($prev.asks // []) | map({ (.): true }) | add) // {}) as $rung

| ($m
   | map(select(.ask_key != null and (($rung[.ask_key] // false) | not)))
   | map({ key: .ask_key, ask_key: .ask_key, kind: "asking", transition: "asking",
           title: "crew · asking", subtitle: .key,
           body: (if (.snippet // "") == "" then "asking" else .snippet end) })) as $ask_ev

| (if $cold then []
   else [ $m[] | . as $x
          | ($conf[$x.key] // null) as $lc
          | ($cand[$x.key] // null) as $cd
          | select(($x.status | terminal) and $x.status != $lc and $cd == $x.status)
          | { key: $x.key, ask_key: null, kind: $x.status,
              transition: "\($lc // "new")→\($x.status)",
              title: "crew", subtitle: $x.key,
              body: "\($x.role) \($x.status)" } ]
   end) as $status_ev

| (if $cold then (($m | map({ (.key): .status }) | add) // {})
   else (($m | map(. as $x
          | ($conf[$x.key] // null) as $lc
          | ($cand[$x.key] // null) as $cd
          | { (.key): (if $x.status == $lc then $lc
                       elif $cd == $x.status then $x.status
                       else $lc end) }) | add) // {})
   end) as $new_conf

| (if $cold then {}
   else (($m | map(. as $x
          | ($conf[$x.key] // null) as $lc
          | ($cand[$x.key] // null) as $cd
          | { (.key): (if $x.status == $lc then null
                       elif $cd == $x.status then null
                       else $x.status end) }) | add) // {})
   end) as $new_cand

| (($m | map({ (.key): true }) | add) // {}) as $live
| (((($prev.asks // []) | map(select(($live[(. | member_of)] // false))))
    + ($ask_ev | map(.ask_key)))
   | if length > 200 then .[-200:] else . end) as $new_asks

| ($ask_ev + $status_ev) as $ev
| ($ev | length) as $n
| { snapshot: { v: 1, confirmed: $new_conf, candidate: $new_cand, asks: $new_asks },
    events: $ev,
    summary:
      (if $n > 3 then
         ([ "asking", "died", "failed", "done" ]
          | map(. as $k | ($ev | map(select(.kind == $k)) | length) as $c
                | if $c > 0 then "\($c) \($k)" else empty end)
          | join(", ")) as $kinds
         | ($ev | map(.key | split("/")[1]) | unique) as $slugs
         | ($slugs | if length > 4 then (.[0:4] + [ "…" ]) else . end) as $slugs
         | "crew: \($n) events — \($kinds) · \($slugs | join(", "))"
       else null end) }
JQ

notify() {
  if [[ "${CREW_HUD_SILENT:-}" == "1" ]]; then
    printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$CACHE/notify.log"
    return 0
  fi
  osascript -e 'on run argv' \
            -e 'display notification (item 3 of argv) with title (item 1 of argv) subtitle (item 2 of argv)' \
            -e 'end run' -- "$1" "$2" "$3" >/dev/null 2>&1 || true
}

ring_bell() {
  local doc="$1" snap_json result n ts summary
  snap_json="$(cat "$SNAP" 2>/dev/null)"
  if ! printf '%s' "$snap_json" | jq -e 'type == "object"' >/dev/null 2>&1; then
    snap_json='null'
  fi
  result="$(printf '%s' "$doc" | jq -c --argjson snap "$snap_json" "$BELL_JQ" 2>>"$ERR")"
  [[ -n "$result" ]] || return 0

  printf '%s' "$result" | jq -c '.snapshot' > "$SNAP.tmp" 2>/dev/null \
    && mv -f "$SNAP.tmp" "$SNAP" 2>/dev/null

  n="$(printf '%s' "$result" | jq -r '.events | length' 2>/dev/null)"
  [[ "${n:-0}" -gt 0 ]] || return 0

  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s' "$result" \
    | jq -r --arg ts "$ts" '.events[] | [ $ts, .key, .transition, .body ] | @tsv' \
    >> "$BELL_LOG"

  if [[ "$n" -gt 3 ]]; then
    summary="$(printf '%s' "$result" | jq -r '.summary')"
    printf '%s\t*\tsummary\t%s\n' "$ts" "$summary" >> "$BELL_LOG"
    notify "crew" "" "$summary"
  else
    while IFS=$'\t' read -r title subtitle body; do
      notify "$title" "$subtitle" "$body"
    done < <(printf '%s' "$result" | jq -r '.events[] | [ .title, .subtitle, .body ] | @tsv')
  fi
}

# ------------------------------------------------------------------ main ----

acquire_lock() {
  local now mtime
  mkdir "$LOCK" 2>/dev/null && return 0
  now="$(date +%s)"
  mtime="$(stat -f %m "$LOCK" 2>/dev/null || echo 0)"
  if [[ "$mtime" -gt 0 && $(( now - mtime )) -lt 60 ]]; then
    return 1
  fi
  rm -rf "$LOCK" 2>/dev/null
  mkdir "$LOCK" 2>/dev/null || return 1
}

if ! command -v jq >/dev/null 2>&1; then
  printf '⚓ ✱ | color=%s\n' "$C_BAD"
  printf -- '---\n'
  printf 'jq not found on PATH — the HUD needs it | color=%s\n' "$C_BAD"
  exit 0
fi

mkdir -p "$CACHE" 2>/dev/null

if ! acquire_lock; then
  print_cached
  exit 0
fi
trap 'rm -rf "$LOCK" 2>/dev/null' EXIT

doc="$( "${STATUS_CMD[@]}" 2>"$ERR" )"
rc=$?

if [[ $rc -ne 0 ]] || ! printf '%s' "$doc" | jq -e 'type == "object" and (.slugs | type) == "array"' >/dev/null 2>&1; then
  {
    printf '\n[%s] crew status --json failed (exit %s). First 500 bytes of stdout:\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rc"
    printf '%s\n' "${doc:0:500}"
  } >> "$ERR" 2>/dev/null
  render_error
  exit 0
fi

out="$(printf '%s' "$doc" | jq -r \
        --arg c_ask "$C_ASK" --arg c_bad "$C_BAD" --arg c_dim "$C_DIM" \
        --arg crew_root "$CREW_ROOT" --arg crew_disp "$CREW_DISP" \
        "$RENDER_JQ" 2>>"$ERR")"

if [[ -z "$out" ]]; then
  render_error
  exit 0
fi

printf '%s\n' "$out"
printf '%s\n' "$out" > "$LAST_OUT.tmp" 2>/dev/null && mv -f "$LAST_OUT.tmp" "$LAST_OUT" 2>/dev/null

ring_bell "$doc"
exit 0
