# Prompt: make your AI CLI say "Reticulating Splines" while it thinks

Copy everything below the line and give it to your AI coding agent. It swaps the
spinner text in your CLI for the loading-screen messages from the Maxis sims, so
waiting on a long tool call feels like waiting on a house to load. The agent will
confirm a plan, then wire it up.

The messages live in this repo at
[`data/sims-loading-messages.txt`](../data/sims-loading-messages.txt) — 595 of
them, from The Sims through The Sims 3 plus SimCity 4. See
[`data/README.md`](../data/README.md) for provenance and for why there is no
Sims 4 list.

---

I want my AI coding CLI to narrate its work with the loading-screen messages from
the old Maxis sims — `Reticulating Splines…`, `Calculating Llama Expectoration
Trajectory…`, `De-inviting Don Lothario…` — instead of its own spinner words. Set
this up for me. **Confirm the plan before editing anything.**

The messages are here, one per line, 595 of them:

```
https://raw.githubusercontent.com/pvinis/useful-ai/main/data/sims-loading-messages.txt
```

Grouped by game and expansion pack, if I'd rather run a single era:

```
https://raw.githubusercontent.com/pvinis/useful-ai/main/data/sims-loading-messages.json
```

## Step 1 — work out what you're configuring

- Which CLI am I using? Check what's installed and what config directories
  exist rather than assuming. Ask me if more than one is plausible.
- **If I run several accounts of the same CLI**, each pinned to its own config
  directory via an environment variable (`CLAUDE_CONFIG_DIR`, `CODEX_HOME` —
  see [`multi-account-cli-setup.md`](./multi-account-cli-setup.md)), write the
  config into **every** account directory, or into a shared path all of them
  read. Otherwise only one account gets the verbs and I'll assume it's broken.
- Read the existing config first and show me the before/after. **Merge, never
  overwrite** — these files hold the rest of my setup.

## Step 2 — Claude Code

Claude Code supports this directly. In `settings.json` (in the right config dir,
default `~/.claude/settings.json`):

```json
{
  "spinnerVerbs": {
    "mode": "replace",
    "verbs": ["Reticulating Splines", "Searching for Llamas", "Gesticulating Mimes"]
  }
}
```

- `mode: "replace"` uses only my verbs. `mode: "append"` keeps Claude Code's own
  list and adds mine — ask me which I want, and default to `"replace"`, since
  landing on `Lollygagging` or `Schlepping` half the time dilutes the bit.
- The CLI appends its own `…`, so the entries must **not** end in an ellipsis.
  The data file is already normalized this way; keep it that way.
- One verb is picked per turn, so the full list is not overkill. Use all 595
  unless I say otherwise.
- Put it in my **user** settings, not a project's `.claude/settings.json` — I
  want this everywhere, not in one repo. If the key turns out to be unknown in
  my version, tell me instead of inventing a workaround.

Build the JSON payload from the data file rather than retyping any of it:

```bash
curl -sSL https://raw.githubusercontent.com/pvinis/useful-ai/main/data/sims-loading-messages.txt \
  | python3 -c 'import sys, json; print(json.dumps({"spinnerVerbs": {"mode": "replace", "verbs": [l.strip() for l in sys.stdin if l.strip()]}}, indent=2, ensure_ascii=False))'
```

Then merge that key into my existing `settings.json` — keep every other key
exactly as it was, and preserve the file's formatting.

Optional, only if I say yes: `spinnerTipsOverride` replaces the hint text that
appears under the spinner on long turns, with the same shape
(`{"excludeDefault": true, "tips": ["…"]}`). The jokier one-off lines suit it
better than the verbs do.

## Step 3 — Codex

Codex has no equivalent setting: its status text is a fixed `Ready` / `Working` /
`Thinking`, and the status line only takes items from a built-in list. So use a
hook instead, which prints a message into the transcript on each turn.

Save the message list locally, e.g. `~/.codex/sims-loading-messages.txt`, then
add a hook script that emits one at random. Escape via a JSON library, not
`printf` — two of the messages contain double quotes:

```sh
#!/bin/sh
# ~/.codex/hooks/sims-verb.sh
exec /usr/bin/python3 -c '
import json, pathlib, random, sys
messages = [l.strip() for l in pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").splitlines() if l.strip()]
print(json.dumps({"systemMessage": random.choice(messages) + "…"}))
' "$HOME/.codex/sims-loading-messages.txt"
```

Wire it up in `~/.codex/config.toml` (`$CODEX_HOME/config.toml` if set):

```toml
[[hooks.UserPromptSubmit]]

[[hooks.UserPromptSubmit.hooks]]
type = "command"
command = "sh ~/.codex/hooks/sims-verb.sh"
timeout = 5
statusMessage = "Reticulating splines"
```

Things to get right, and to tell me about:

- `chmod +x` the script.
- **Codex will not run a new hook until I approve it.** Run `/hooks` in Codex to
  review and trust it. Trust is recorded against the script's hash, so editing
  the script means approving it again — mention this so I'm not confused when it
  goes quiet after a change.
- `statusMessage` is static text Codex shows *while the hook runs*, so it can
  only ever be one fixed line. The random message comes from `systemMessage` in
  the hook's output.
- `systemMessage` is intended for hook warnings, so depending on the Codex
  version it may render with a warning style rather than as neutral spinner
  text. Show me what it actually looks like and we'll decide whether it's worth
  keeping.
- `PreToolUse` instead of `UserPromptSubmit` gives a message per tool call
  rather than per turn. Closer to a real loading screen, but noisy. Ask me which
  I want; default to `UserPromptSubmit`.

## Step 4 — anything else

For any other agent (Gemini CLI, Cursor, pi, Amp), there is usually no spinner
hook at all. Two fallbacks, in order:

1. If the tool has hooks or a custom status line, use the same shape as above.
2. Otherwise add a line to my instructions file (`AGENTS.md`, `CLAUDE.md`,
   `GEMINI.md`) telling the agent to open each turn with one Maxis loading
   message and nothing else on that line. Be honest with me that this is the
   model choosing to play along, not real UI chrome, so it will drift and
   sometimes get skipped.

## Step 5 — verify, then report

- Restart the CLI and trigger a turn long enough to see the spinner. Tell me a
  message you actually observed. Don't call it done off the config alone.
- If nothing changed, check that you wrote to the config directory the running
  process actually uses (the multi-account trap from Step 1) and that the JSON or
  TOML still parses.

Then summarize: which files you touched, which tools are wired up, which fell
back to instructions-only, and anything I need to approve myself.
