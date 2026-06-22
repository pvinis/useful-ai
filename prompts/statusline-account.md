# Prompt: show which AI-CLI account is active in the statusline

Copy everything below the line and give it to your AI coding agent. It's most
useful after you've set up multiple accounts (see
[`multi-account-cli-setup.md`](./multi-account-cli-setup.md)) and keep losing
track of which one a given window is running. The agent will confirm a plan,
then wire it up.

---

I run more than one account of my AI CLI, each pinned to its own config
directory via an environment variable (e.g. Claude Code uses
`CLAUDE_CONFIG_DIR`, Codex uses `CODEX_HOME`). I keep forgetting which account a
given terminal is running, so I want the **active account shown in the
statusline**. Set this up for me. **Confirm the plan before editing anything.**

## How it works

The statusline command runs as a subprocess of the CLI and inherits its
environment, so it can read the same config-dir variable that selects the
account, derive a short label from the directory name, and print it. No login
or network needed.

## Step 1 — figure out the mapping (ask me if unclear)

- Identify the config-dir variable for the tool (`CLAUDE_CONFIG_DIR` for Claude
  Code). The active directory is its value, or the tool's default if unset
  (Claude Code default: `~/.claude`).
- Derive the label from the directory's basename. With my convention
  `~/.claude-personal` → `personal`, `~/.claude-leanscaper` → `leanscaper`, and a
  bare `~/.claude` → `default`. Confirm these labels read the way I want; ask if
  my directory names don't make the label obvious.

## Step 2 — inspect what's there

- Read the right `settings.json` for this tool/account (for Claude Code:
  `"$CLAUDE_CONFIG_DIR/settings.json"`, or `~/.claude/settings.json`).
- If a `statusLine` is already configured, **augment** it — prepend the account
  label, don't throw away what's there. If it points to a script file, edit that
  script; if it's an inline command, extend it. Show me the before/after.

## Step 3 — present the plan, then (after I confirm) implement

For Claude Code, the statusline is `settings.json` → `statusLine` with
`{ "type": "command", "command": "<shell>" }`. The command receives a JSON blob
on stdin (model, cwd, etc.) and inherits the environment, so the account comes
from `$CLAUDE_CONFIG_DIR`. A minimal standalone version:

```bash
# prints e.g. "[leanscaper]  my-project"
dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
label="${dir##*/.claude-}"; [ "$label" = "$dir" ] && label="default"
input=$(cat)
cwd=$(printf '%s' "$input" | /usr/bin/python3 -c 'import sys,json,os;print(os.path.basename(json.load(sys.stdin).get("workspace",{}).get("current_dir","")))' 2>/dev/null)
printf '[%s]  %s' "$label" "$cwd"
```

Notes for the implementation:
- Put the logic in a small script (e.g. `"$CLAUDE_CONFIG_DIR/statusline.sh"`),
  `chmod +x` it, and point `settings.json` at it — easier to extend later than a
  long inline command. **Write the script into each account's config dir** (or a
  shared path that reads the env var at runtime) so every account picks it up.
- Keep it fast and dependency-light; the statusline runs on every refresh. Don't
  call the network or anything slow.
- Color is nice if my terminal/statusline supports it (e.g. a distinct color per
  account) but optional.
- After writing, tell me how to see it (it shows on the next prompt; for Claude
  Code I can also check with `/statusline` or by reloading).

When done, summarize what you changed and confirm each account shows its label.
