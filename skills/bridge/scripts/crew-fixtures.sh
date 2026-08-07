#!/usr/bin/env bash
# crew-fixtures.sh — build a scratch CREW_HOME of adversarial crew state and run
# the acceptance checks for `crew status` and `crew status --json`.
#
#   skills/bridge/scripts/crew-fixtures.sh [scratch-dir]
#
# Every check runs with CREW_HOME= pointed at the fixtures, so the real ~/crew is
# never read or written. The byte-identical check for the default `crew status`
# compares against the script at $CREW_BASELINE_REF (default origin/main).
#
# The live member's pid is this script's own, so it is "running" for the length
# of the run and "died" afterwards. Re-run to refresh it.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
crew="$here/crew"
repo_root="$(cd "$here/../../.." && pwd)"
scratch="${1:-$(mktemp -d -t crew-fixtures)}"

home="$scratch/crew"       # CREW_HOME for every check
src="$scratch/src"         # throwaway repo the fixture worktrees come from
empty="$scratch/empty"     # a CREW_HOME with no state at all
gone="$scratch/gone"       # a CREW_HOME that does not exist

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; }

# ------------------------------------------------------------------- fixtures

mk() {   # mk <repo> <slug> <role> — make a member state dir, echo its path
  local d="$home/$1/$2/$3"
  mkdir -p "$d"
  printf '%s' "$d"
}

meta() { # meta <dir> <harness> <model> <worktree> <session_id> <base>
  local d="$1"
  jq -n --arg h "$2" --arg m "$3" --arg w "$4" --arg sid "$5" --arg b "$6" \
        --arg r "$(basename "$d")" --arg s "$(basename "$(dirname "$d")")" \
        --arg repo "$(basename "$(dirname "$(dirname "$d")")")" \
        --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '{harness:$h, model:$m, effort:"high", role:$r, slug:$s, repo:$repo,
       worktree:$w, session_id:$sid, spawned_at:$at, base:$b,
       config_dir:"", grants:[]}' > "$d/meta.json"
}

wt_for() {  # wt_for <dir> <branch> <commits>
  local d="$1" br="$2" n="$3" i
  git -C "$src" worktree add -q -b "$br" "$d/wt" HEAD
  for ((i = 1; i <= n; i++)); do
    printf 'change %d\n' "$i" >> "$d/wt/a.txt"
    git -C "$d/wt" commit -qam "commit $i on $br"
  done
}

rm -rf "$home" "$src" "$empty"
mkdir -p "$home" "$src" "$empty"

git -C "$src" init -q -b main
git -C "$src" config user.email fixtures@example.invalid
git -C "$src" config user.name fixtures
printf 'one\n' > "$src/a.txt"
git -C "$src" add a.txt
git -C "$src" commit -qm 'base commit'
base="$(git -C "$src" rev-parse HEAD)"

# a live claude member with commits and a dirty file, plus a finished codex one
d="$(mk demo normal hand-1)"
meta "$d" claude opus "$d/wt" 11111111-1111-4111-8111-111111111111 "$base"
wt_for "$d" fx/normal-1 3
printf 'scratch\n' > "$d/wt/dirty.txt"
echo running > "$d/status"; echo $$ > "$d/pid"

d="$(mk demo normal hand-2)"
meta "$d" codex gpt-5.6-terra "$d/wt" "" "$base"
wt_for "$d" fx/normal-2 1
echo done > "$d/status"; echo 0 > "$d/exit-code"
printf 'Landed the retry queue.\n' > "$d/result.md"
printf '{"type":"item.completed","item":{"type":"command_execution","command":"pnpm test"}}\n' \
  > "$d/log"
mkdir -p "$home/demo/normal/tasks"; printf 'one task\n' > "$home/demo/normal/tasks/1.md"

# the same slug in a second clone directory — must render adjacent, not merged
d="$(mk demo2 normal hand-1)"
meta "$d" claude opus "" 1a111111-1111-4111-8111-111111111111 ""
echo done > "$d/status"; echo 0 > "$d/exit-code"
printf 'Nothing to do here.\n' > "$d/result.md"

# running status, pid nothing can hold
d="$(mk demo dead-pid hand-1)"
meta "$d" claude opus "$d/wt" 22222222-2222-4222-8222-222222222222 "$base"
wt_for "$d" fx/dead 0
echo running > "$d/status"; echo 2147480000 > "$d/pid"

# closed slug whose worktrees were removed while meta.json still records them,
# with one member left running: renders flagged rather than disappearing
d="$(mk demo closed-live hand-1)"
meta "$d" claude opus "$d/wt" 33333333-3333-4333-8333-333333333333 "$base"
wt_for "$d" fx/closed-1 2
echo done > "$d/status"; echo 0 > "$d/exit-code"
git -C "$src" worktree remove --force "$d/wt"
d="$(mk demo closed-live hand-2)"
meta "$d" claude opus "$d/wt" 44444444-4444-4444-8444-444444444444 "$base"
wt_for "$d" fx/closed-2 0
echo running > "$d/status"; echo $$ > "$d/pid"
date -u +%Y-%m-%dT%H:%M:%SZ > "$home/demo/closed-live/closed-at"

# closed slug, every member terminal, worktree gone: skipped entirely
d="$(mk demo closed-done hand-1)"
meta "$d" claude opus "$d/wt" 55555555-5555-4555-8555-555555555555 "$base"
wt_for "$d" fx/closed-done 1
echo done > "$d/status"; echo 0 > "$d/exit-code"
printf 'All green.\n' > "$d/result.md"
git -C "$src" worktree remove --force "$d/wt"
date -u +%Y-%m-%dT%H:%M:%SZ > "$home/demo/closed-done/closed-at"

# worktree in a repo with no origin/HEAD and no recorded base: count is null.
# Also the one live codex member, so `doing` comes off a real event stream whose
# last line is truncated mid-write.
d="$(mk demo no-origin hand-1)"
meta "$d" codex gpt-5.6-terra "$d/wt" "" ""
wt_for "$d" fx/no-origin 2
echo running > "$d/status"; echo $$ > "$d/pid"
{ printf '%s\n' '{"thread_id":"th_1","type":"thread.started"}'
  printf '%s\n' '{"type":"item.completed","item":{"type":"command_execution","command":"pnpm test"}}'
  printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1}}'
  printf '%s\n' '{"type":"item.started","item":{"type":"file_change","path":"src/b.ts"}}'
  printf '%s' '{"type":"item.st'; } > "$d/log"

# malformed meta.json
d="$(mk demo broken hand-1)"
printf '{ "harness": "claude",\n' > "$d/meta.json"
echo running > "$d/status"; echo $$ > "$d/pid"

# write races: an empty status file, and an empty pid file under "running"
d="$(mk demo races hand-1)"
meta "$d" claude opus "" 77777777-7777-4777-8777-777777777777 ""
: > "$d/status"
d="$(mk demo races hand-2)"
meta "$d" claude opus "" 88888888-8888-4888-8888-888888888888 ""
echo running > "$d/status"; : > "$d/pid"

# an ask that is multibyte, contains a pipe, and is longer than the 80-codepoint
# truncation
d="$(mk demo ask hand-1)"
meta "$d" claude opus "" 99999999-9999-4999-8999-999999999999 ""
echo running > "$d/status"; echo $$ > "$d/pid"
printf '%s\n' 'Ναυπηγός | ⚓ bump the version? αβγδεζηθικλμνξοπρστυφχψω ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ tail' \
  > "$d/ask.md"
printf 'the brief\n' > "$home/demo/ask/brief.md"

# a --no-worktree member: meta.worktree is the repo, so git is never probed, and
# a done claude member's final message comes from the log
d="$(mk demo lookout lookout)"
meta "$d" claude sonnet "$src" aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa ""
echo done > "$d/status"; echo 0 > "$d/exit-code"
printf 'Three call sites, all in src/upload.\n' > "$d/log"

printf 'fixtures in %s\n\n' "$scratch"

# ------------------------------- 1. default `crew status` is byte-identical

ref="${CREW_BASELINE_REF:-origin/main}"
baseline="$scratch/crew.baseline"
printf 'byte-identical `crew status` against %s\n' "$ref"
if git -C "$repo_root" show "$ref:skills/bridge/scripts/crew" > "$baseline" 2>/dev/null; then
  chmod +x "$baseline"
  diff_case() {  # diff_case <label> <crew-home> [args...]
    local label="$1" ch="$2"; shift 2
    local a b
    a="$(CREW_HOME="$ch" "$baseline" status "$@" 2>/dev/null || true)"
    b="$(CREW_HOME="$ch" "$crew" status "$@" 2>/dev/null || true)"
    if [ "$a" = "$b" ]; then ok "$label"; else
      bad "$label"; diff <(printf '%s\n' "$a") <(printf '%s\n' "$b") || true
    fi
  }
  # The whole-home table stops at the malformed meta.json, in both versions
  # identically — `crew status` has always died there and this change does not
  # touch it. The per-slug cases carry the coverage past that point.
  diff_case "all fixtures"   "$home"
  diff_case "normal slug"    "$home" --slug normal
  diff_case "closed slug"    "$home" --slug closed-live
  diff_case "closed, done"   "$home" --slug closed-done
  diff_case "multibyte ask"  "$home" --slug ask
  diff_case "broken meta"    "$home" --slug broken
  diff_case "dead pid"       "$home" --slug dead-pid
  diff_case "no origin/HEAD" "$home" --slug no-origin
  diff_case "write races"    "$home" --slug races
  diff_case "--no-worktree"  "$home" --slug lookout
  diff_case "zero state"     "$empty"
  diff_case "absent home"    "$gone"
else
  printf '  skip  no %s:skills/bridge/scripts/crew to compare against\n' "$ref"
fi

# ------------------------------------- 2. `status --json` on every fixture

printf '\nvalid JSON from every fixture\n'
doc() {  # doc <crew-home> [args...] — echo the document, empty on failure
  local ch="$1"; shift
  CREW_HOME="$ch" "$crew" status --json "$@" 2>"$scratch/stderr.txt" || true
}
json_case() {  # json_case <label> <crew-home> [args...]
  local label="$1" ch="$2"; shift 2
  local out; out="$(doc "$ch" "$@")"
  if [ -n "$out" ] && printf '%s' "$out" | jq -e 'type == "object"' >/dev/null 2>&1; then
    ok "$label"
  else
    bad "$label"; sed -n '1,5p' "$scratch/stderr.txt"
  fi
}
json_case "all fixtures"        "$home"
json_case "live member"         "$home" --slug normal
json_case "dead pid"            "$home" --slug dead-pid
json_case "closed, wt removed"  "$home" --slug closed-live
json_case "closed, all done"    "$home" --slug closed-done
json_case "no origin/HEAD"      "$home" --slug no-origin
json_case "malformed meta"      "$home" --slug broken
json_case "empty status + pid"  "$home" --slug races
json_case "multibyte ask"       "$home" --slug ask
json_case "--no-worktree"       "$home" --slug lookout
json_case "zero crew"           "$empty"
json_case "absent CREW_HOME"    "$gone"

# --------------------------------------------- 3. the document says what §7 says

printf '\nthe document matches the failure matrix\n'
all="$(doc "$home")"
assert() {  # assert <label> <jq filter>
  if printf '%s' "$all" | jq -e "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi
}
member='def m($s;$r): .slugs[] | select(.slug == $s) | .members[] | select(.role == $r);'

assert "v and bar are present" \
  '.v == 1 and (.bar | has("asking") and has("running") and has("bad") and has("done"))'
assert "every member carries the whole contract" \
  '[.slugs[].members[] | keys_unsorted | sort]
   | all(. == (["ask","commits","doing","effort","exit_code","glyph","harness","label",
                "model","paths","pid_alive","quiet_s","result_snippet","role","since_s",
                "stale","status","transcript"] | sort))'
assert "closed and all-terminal slug is skipped" \
  '[.slugs[].slug] | index("closed-done") == null'
assert "closed slug with a running member survives, flagged" \
  '[.slugs[] | select(.slug == "closed-live")] | length == 1 and (.[0].closed and .[0].attention)'
assert "removed worktree gives commits null, never a crash" \
  "$member"' [m("closed-live";"hand-1")] | length == 1 and .[0].commits == null'
assert "live member counts its commits and its dirt" \
  "$member"' [m("normal";"hand-1")] | .[0].commits.count == 3 and .[0].commits.dirty == 1'
assert "no origin/HEAD and no base gives a null count, not a null commits" \
  "$member"' [m("no-origin";"hand-1")]
             | .[0].commits != null and .[0].commits.count == null'
assert "a codex member with no session_id still resolves its own worktree" \
  "$member"' [m("normal";"hand-2")] | .[0].commits.count == 1'
assert "a live codex member reads its doing past a truncated last line" \
  "$member"' [m("no-origin";"hand-1")] | .[0].doing == "file_change src/b.ts"'
assert "a claude member with no transcript says so instead of looking calm" \
  "$member"' [m("normal";"hand-1")] | .[0].transcript == "absent"
                                      and .[0].doing == null and .[0].stale == false'
assert "--no-worktree member is never probed" \
  "$member"' [m("lookout";"lookout")] | .[0].commits == null'
assert "a done claude member falls back to its log" \
  "$member"' [m("lookout";"lookout")] | .[0].result_snippet | test("call sites")'
assert "dead pid reads as died" \
  "$member"' [m("dead-pid";"hand-1")] | .[0].status == "died" and .[0].glyph == "✗"'
assert "empty status reads as unknown" \
  "$member"' [m("races";"hand-1")] | .[0].status == "unknown" and .[0].glyph == "…"'
assert "empty pid under running reads as died" \
  "$member"' [m("races";"hand-2")] | .[0].status == "died"'
assert "malformed meta renders, never fatally" \
  "$member"' [m("broken";"hand-1")] | .[0].glyph == "‼" and .[0].label == "broken meta.json"'
assert "the ask snippet keeps its pipe and stops at 80 codepoints" \
  "$member"' [m("ask";"hand-1")] | .[0].ask.snippet | test("\\|") and (length <= 80)'
assert "the ask carries its mtime, the bell's question key" \
  "$member"' [m("ask";"hand-1")] | .[0].ask.mtime > 0'
assert "one slug in two repos renders as two adjacent blocks" \
  '[.slugs[] | select(.slug == "normal") | .repo] == ["demo", "demo2"]'
assert "bar counts only what is rendered, and never the broken member" \
  '.bar == {asking: 1, running: 3, bad: 2, done: 4}'
assert "phase is derived where the convention files exist, null where not" \
  '([.slugs[] | select(.slug == "normal" and .repo == "demo") | .phase] == ["work"])
   and ([.slugs[] | select(.slug == "ask") | .phase] == ["intake"])
   and ([.slugs[] | select(.slug == "races") | .phase] == [null])'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
