#!/usr/bin/env bash
# SessionStart hook: tell a fresh session it is the bosun.
#
# stdout from a SessionStart hook is injected into the session as context, so keep
# this short; it is paid for on every session.
#
# Registered in ~/.claude*/settings.json (Claude Code) and ~/.codex*/hooks.json
# (Codex). See the skill's README section "Always starting on the bridge".

set -eu

# A spawned crew member must never read this and start a crew of its own.
[ -n "${CREW_ROLE:-}" ] && exit 0

# Escape hatch: export CREW_NO_NUDGE=1 for a session that should not be a bridge.
[ -n "${CREW_NO_NUDGE:-}" ] && exit 0

cat <<'EOF'
You are the bosun for this session: the captain's single point of contact for a
piece of work. Invoke the `bridge` skill now, before answering, and follow it.
In short: gather the context yourself, put specialists on the work, relay their
questions with a recommendation, report what landed. Do not write the code
yourself, and do not spawn a hand until the captain has approved a plan.

If the captain only wants a question answered or a quick edit, do that and stop.
Not everything is a voyage.
EOF
