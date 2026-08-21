#!/bin/bash
#
# can-ordinary-read acceptance suite.
#
#   bash skills/whose-laptop-is-this/tests/gate/run.sh
#
# The gate is the one piece of this skill that is code rather than copy, and the
# whole elevation ban rests on it, so it gets a real suite. Everything runs
# against a scratch tree under ./.work — nothing here reads a real home.
#
# The case that matters most is `owner-only file, caller is the owner`: the
# caller *can* read it, and the gate must still say no. That is the same trap
# root falls into one step down, and it is exercisable without root.
#
# Root invariance itself needs a password on most machines. To check it by hand:
#
#   sudo bash skills/whose-laptop-is-this/tests/gate/run.sh
#
# Every assertion must produce identical results under sudo. If one flips, the
# gate is reading the effective answer somewhere.

set -uo pipefail

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$HERE/../../scripts/can-ordinary-read.sh"

# The scratch tree cannot live in the checkout: on any distro with HOME_MODE
# 0700 the home directory denies every path beneath it and the whole suite
# fails at the first traversal — correctly. Build it under TMPDIR instead, and
# make the root itself world-traversable so each case tests what it says it
# tests.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/can-ordinary-read.XXXXXX")" || exit 1

pass=0
fail=0

check() { # check <expected-rc> <label> <path>
	local want=$1 label=$2 path=$3 out rc
	out=$("$GATE" "$path" 2>&1)
	rc=$?
	if [ "$rc" -eq "$want" ]; then
		pass=$((pass + 1))
		printf '  ok    %-46s rc=%s\n' "$label" "$rc"
	else
		fail=$((fail + 1))
		printf '  FAIL  %-46s rc=%s want=%s\n        %s\n' "$label" "$rc" "$want" "$out"
	fi
}

trap 'chmod -R u+rwX "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
chmod 755 "$WORK"

# ── a world-readable file under world-traversable dirs ──────────────────────
mkdir -p "$WORK/open/sub"
chmod 755 "$WORK" "$WORK/open" "$WORK/open/sub"
echo 'x' >"$WORK/open/sub/public"
chmod 644 "$WORK/open/sub/public"

# ── a world-readable file inside a 0700 directory ───────────────────────────
mkdir -p "$WORK/private"
echo 'x' >"$WORK/private/gitconfig"
chmod 644 "$WORK/private/gitconfig"
chmod 700 "$WORK/private"

# ── a 0600 file in an open directory ────────────────────────────────────────
echo 'x' >"$WORK/open/secret"
chmod 600 "$WORK/open/secret"

# ── a 0750 directory: group-readable is still not world-readable ────────────
mkdir -p "$WORK/grouped"
echo 'x' >"$WORK/grouped/file"
chmod 644 "$WORK/grouped/file"
chmod 750 "$WORK/grouped"

# ── symlinks: the link's own 0777 mode must not launder the target ──────────
ln -s "$WORK/private/gitconfig" "$WORK/open/link-to-private"
ln -s "$WORK/open/sub/public" "$WORK/open/link-to-public"
ln -s "$WORK/nowhere" "$WORK/open/dangling"

echo "can-ordinary-read — running as uid $(id -u)"
echo

echo "passes:"
check 0 "world-readable file, open parents" "$WORK/open/sub/public"
check 0 "symlink to a world-readable file" "$WORK/open/link-to-public"
check 0 "a directory that is world-readable" "$WORK/open"
check 0 "/ itself" "/"

echo
echo "denials:"
check 1 "owner-only FILE in an open dir" "$WORK/open/secret"
check 1 "readable file inside a 0700 DIR" "$WORK/private/gitconfig"
check 1 "readable file inside a 0750 DIR" "$WORK/grouped/file"
check 1 "symlink INTO a 0700 dir" "$WORK/open/link-to-private"
check 1 "the 0700 directory itself" "$WORK/private"

echo
echo "not evaluable:"
check 3 "path that does not exist" "$WORK/open/sub/absent"
check 3 "dangling symlink" "$WORK/open/dangling"

echo
echo "usage:"
out=$("$GATE" 2>&1)
if [ $? -eq 2 ]; then
	pass=$((pass + 1))
	printf '  ok    %-46s rc=2\n' "no argument"
else
	fail=$((fail + 1))
	printf '  FAIL  %-46s\n' "no argument"
fi

# ── the trap, stated as an assertion ────────────────────────────────────────
# The caller owns $WORK/open/secret, so `test -r` passes. The gate must not.
echo
echo "the trap:"
if [ -r "$WORK/open/secret" ]; then
	if "$GATE" "$WORK/open/secret" >/dev/null 2>&1; then
		fail=$((fail + 1))
		echo "  FAIL  gate agreed with test -r on an owner-only file"
	else
		pass=$((pass + 1))
		echo "  ok    test -r says yes, the gate says no"
	fi
else
	echo "  skip  caller cannot read its own 0600 file — unusual environment"
fi

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
