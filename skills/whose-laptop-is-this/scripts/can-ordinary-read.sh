#!/bin/sh
# can-ordinary-read — the permission gate for whose-laptop-is-this (POSIX).
#
# Answers *could an ordinary principal read this path?* — not *can I read it?*
#
#   can-ordinary-read <path>
#
#   exit 0  an ordinary principal could read it
#   exit 1  denied — a mode bit says no (reason on stdout)
#   exit 2  usage error
#   exit 3  path does not exist, or its permissions are not evaluable
#
# The rule: the target's mode has o+r, and every parent directory up to / has
# o+x. Mode bits are read directly. `test -r` is never used — it reports the
# *effective* answer and so silently passes for root, which is exactly the
# behaviour this gate exists to prevent. The answer does not change when the
# caller is root.
#
# Metadata only. This script never opens a file, and never prints its contents.

set -u

usage() {
	echo "usage: can-ordinary-read <path>" >&2
	exit 2
}

[ $# -eq 1 ] || usage
case $1 in
-h | --help) usage ;;
'') usage ;;
esac

# ── canonicalize ────────────────────────────────────────────────────────────
# Resolve to a symlink-free absolute path so that every directory actually
# traversed gets its mode checked. A symlink is mode 0777 and would otherwise
# hand back a free pass to whatever it points at.
#
# `readlink` reads the link target, which is metadata, not file contents.

canonicalize() {
	_rest=${1#/}
	_out=''
	_guard=0

	while [ -n "$_rest" ]; do
		_guard=$((_guard + 1))
		if [ "$_guard" -gt 256 ]; then
			echo "unresolvable: too many symlink hops in $1" >&2
			return 1
		fi

		case $_rest in
		*/*)
			_comp=${_rest%%/*}
			_rest=${_rest#*/}
			;;
		*)
			_comp=$_rest
			_rest=''
			;;
		esac

		case $_comp in
		'' | .) continue ;;
		..)
			_out=${_out%/*}
			continue
			;;
		esac

		_cur="$_out/$_comp"

		if _target=$(readlink "$_cur" 2>/dev/null); then
			case $_target in
			/*)
				_out=''
				_rest="${_target#/}${_rest:+/$_rest}"
				;;
			*)
				_rest="${_target}${_rest:+/$_rest}"
				;;
			esac
			continue
		fi

		_out=$_cur
	done

	printf '%s\n' "${_out:-/}"
}

# ── mode bits ───────────────────────────────────────────────────────────────
# GNU coreutils and BSD/macOS stat disagree on everything except being called
# stat. Try both, take whichever answers. `%OLp` on BSD, not `%Lp`: the `O`
# forces octal, and without it the number can come back decimal, which would
# make every arithmetic test below quietly wrong.
#
# Both are asked to follow symlinks (`-L`), though canonicalize() has already
# removed them — belt and braces, since a wrong answer here fails open.
#
# Anything that is not three or four octal digits is refused rather than
# guessed at. This gate fails closed.

mode_of() {
	_m=$(stat -L -c '%a' "$1" 2>/dev/null) ||
		_m=$(stat -L -f '%OLp' "$1" 2>/dev/null) ||
		return 1

	case $_m in
	[0-7][0-7][0-7] | [0-7][0-7][0-7][0-7]) ;;
	*) return 1 ;;
	esac

	printf '%s\n' "$_m"
}

has_bit() { # has_bit <mode> <octal-bit>
	[ $((0$1 & $2)) -ne 0 ]
}

# ── walk ────────────────────────────────────────────────────────────────────

path=$1
case $path in
/*) ;;
*) path="${PWD}/${path}" ;;
esac

target=$(canonicalize "$path") || exit 3

# Every parent directory, root first, needs o+x for an ordinary principal to
# traverse it. `/` itself is checked like any other.
walked=''
remainder=${target#/}
while :; do
	case $remainder in
	*/*)
		component=${remainder%%/*}
		remainder=${remainder#*/}
		;;
	*)
		break
		;;
	esac

	walked="$walked/$component"

	mode=$(mode_of "$walked") || {
		echo "unreadable: $walked does not exist or its mode is not evaluable"
		exit 3
	}

	if ! has_bit "$mode" 1; then
		echo "denied: $walked is mode $mode — no o+x, an ordinary principal cannot traverse it"
		exit 1
	fi
done

mode=$(mode_of "$target") || {
	echo "unreadable: $target does not exist or its mode is not evaluable"
	exit 3
}

if ! has_bit "$mode" 4; then
	echo "denied: $target is mode $mode — no o+r, an ordinary principal cannot read it"
	exit 1
fi

# A directory also needs o+x to be listed usefully, but o+r alone is enough to
# answer the question this gate is asked, so it is not required here.

echo "ok: $target is mode $mode and every parent is traversable"
exit 0
