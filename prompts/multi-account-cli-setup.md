# Prompt: set up multiple accounts for an AI CLI on one machine

Copy everything below the line and give it to your AI coding agent. It works for
Claude Code, OpenAI Codex, pi, and any other CLI that lets you relocate its
config directory with an environment variable. The agent will ask you what you
want, confirm a plan, and only then make changes.

---

You are helping me run **more than one account** of one or more AI CLI tools on a
single machine, each account fully isolated (separate credentials, settings, MCP
servers, skills, history), with convenient launcher commands. Follow this whole
process. **Do not edit any files until I have explicitly confirmed the plan.**

## How the isolation works

Each of these CLIs stores everything under one config directory, and lets you
relocate that directory with an environment variable. Point each account at its
own directory and the accounts become fully independent — you can even run them
side by side in different terminals. Known tools:

| Tool | Config-dir env var | Default directory | Notes |
|------|--------------------|-------------------|-------|
| Claude Code (`claude`) | `CLAUDE_CONFIG_DIR` | `~/.claude` | also writes a sibling `~/.claude.json` outside the dir; credentials may be in macOS Keychain or `.credentials.json` |
| OpenAI Codex (`codex`) | `CODEX_HOME` | `~/.codex` | login + config + sessions in `auth.json` / `config.toml` |
| pi (`@earendil-works/pi-coding-agent`) | `PI_CODING_AGENT_DIR` | `~/.pi/agent` | login in `auth.json`; `~/.config/pi` (extensions/backups) is separate and stays shared |

If I ask for a tool **not** in this table, discover its config-dir variable
before doing anything else:

1. Check `<tool> --help` and the official docs for a `*_HOME`, `*_CONFIG_DIR`,
   or `XDG_CONFIG_HOME`-style option.
2. If it's a Node package, resolve the binary
   (`readlink -f $(command -v <tool>)`) and grep the package's `dist`/source for
   env-var names like `grep -rhoE '[A-Z_]+_(HOME|CONFIG_DIR)|XDG_[A-Z_]+'`.
3. Confirm the variable actually relocates **credentials/login** (not just
   cache) by checking where the auth/token file lands. State your evidence.
   If you cannot find a config-dir variable, tell me — this approach won't work
   cleanly for that tool and we'll need another plan.

## Step 1 — gather requirements (ask me)

Ask me, and wait for answers:

1. **Which tool(s)** do you want set up? (e.g. claude, codex, pi)
2. **How many accounts** and **what are they** — give each a short label
   (e.g. `personal`, `work`, or a company name like `acme`).
3. **What should the launcher commands be called?** A common scheme is a short
   prefix/suffix per account, e.g. `claudep` / `claudew` (personal / work). I'll
   suggest names but you decide.
4. **What should the bare command do** (typing `claude` with no suffix)?
   - **Chooser (recommended):** prints a one-keypress prompt asking which
     account, then runs the tool with all your original flags passed through.
   - **Auto-redirect:** always launches one default account.
   - **Plain message:** prints a reminder and runs nothing.
5. **Logins:** start each account with a **fresh login** (cleanest, default), or
   seed one account by copying an existing login so I skip one sign-in?
6. **The default/legacy config dir** (`~/.claude`, `~/.codex`, `~/.pi/agent`).
   Once every account has its own dir, the bare command no longer uses the
   default. What should happen to it?
   - **Leave it in place** (default): still reachable via `command <tool>`, a
     handy fallback login.
   - **Back it up**: rename the default config dir *and any sibling config file*
     to `*.bak` so the default location starts clean (e.g. `~/.claude` ->
     `~/.claude.bak` **and** `~/.claude.json` -> `~/.claude.json.bak`). Nothing
     is deleted; restore by renaming back.

## Step 2 — check the environment

- Detect my shell and the right rc file (`~/.zshrc`, `~/.bashrc`/`~/.bash_profile`,
  or `~/.config/fish/config.fish`).
- For every command name you intend to define, run `command -v <name>` to check
  for collisions and tell me about any. **Known trap:** `pip` collides with
  Python's pip, and `pp` / `pl` are often taken by system binaries — don't use
  them. Suggest collision-free alternatives.
- Note whether the tool's default config dir already has a login (the "legacy"
  account). Leave it untouched unless I ask otherwise (see requirement 6 if I
  want it backed up instead).

## Step 3 — present the plan and get confirmation

Show me a compact summary: every command you'll add, each account's config
directory, what the bare command does, which rc file you'll edit, and which
directories you'll create. **Stop and wait for my explicit "yes" before editing.**

## Step 4 — execute (only after I confirm)

1. If I chose to back up the default (requirement 6): rename the default config
   dir and any sibling config file to `*.bak`. **Rename, never delete.** For
   Claude Code that is **both** `~/.claude` and `~/.claude.json`. Confirm the
   default location is clean before continuing.
2. Create each account's config directory (e.g. `mkdir -p ~/.claude-personal`).
   Empty dir = fresh login on first launch. Do **not** copy credentials between
   accounts unless I chose to seed one.
3. Edit the rc file. Use the reference implementation below, adapted to my shell.
4. Syntax-check the rc file (`zsh -n ~/.zshrc`, `bash -n ~/.bashrc`, or
   `fish --no-execute ~/.config/fish/config.fish`).
5. If you can, verify the chooser actually captures a single keypress and
   dispatches correctly (e.g. a quick `pty` test in Python with stubbed
   commands) before declaring it done. A piped stdin will **not** exercise a
   single-keypress read — it needs a real terminal.
6. Tell me to reload the shell (new terminal or re-source) and log into each
   account once.

## Reference implementation (zsh)

Adapt names to my answers. This defines per-account launchers, one shared
account-chooser, and bare-command wrappers that pass all flags through.

```zsh
# ============= AI CLI multi-account =============
# Each account gets a fully isolated config dir. Per-tool the dir is set by a
# different env var (CLAUDE_CONFIG_DIR / CODEX_HOME / PI_CODING_AGENT_DIR).
# Need the raw binary directly? prefix with `command` (e.g. `command codex ...`).

# Per-account launchers (one pair per tool you set up)
claudep() { CLAUDE_CONFIG_DIR="$HOME/.claude-personal" command claude "$@"; }
claudew() { CLAUDE_CONFIG_DIR="$HOME/.claude-work"     command claude "$@"; }

# Account chooser: single keypress, p=personal / w=work, any other key cancels.
# Runs in the current shell (no subshell) and sets _acct; returns 1 on cancel.
_acct_pick() {
  local ans
  print -Pn "%F{yellow}Which account for $1?%f  %F{cyan}p%fersonal / %F{cyan}w%fork  (any other key cancels): "
  read -k 1 ans
  print  # newline after the single keypress
  case "$ans" in
    p|P) print -P "%F{green}-> personal%f"; _acct=personal ;;
    w|W) print -P "%F{green}-> work%f";     _acct=work ;;
    *)   print -P "%F{red}cancelled%f"; return 1 ;;
  esac
}

# Bare command asks which account, then runs with all original flags passed
# through. e.g. `claude --resume abc` -> pick -> runs it under the chosen dir.
claude() { local _acct; _acct_pick claude || return 1; if [[ $_acct == personal ]]; then claudep "$@"; else claudew "$@"; fi }
```

For a tool you only want reached via the chooser (no dedicated launchers), set
the env var inline instead of calling launcher functions:

```zsh
pi() {
  local _acct; _acct_pick pi || return 1
  if [[ $_acct == personal ]]; then PI_CODING_AGENT_DIR="$HOME/.pi-personal" command pi "$@"
  else                              PI_CODING_AGENT_DIR="$HOME/.pi-work"     command pi "$@"; fi
}
```

### Critical implementation details — do not skip

- **Use `command <tool>` inside the wrapper.** The wrapper function shadows the
  tool's name; without `command` it calls itself and recurses forever.
- **Pass `"$@"` through** so flags/subcommands work (`claude --resume X`,
  `codex login`, `pi -c`).
- **Dispatch with `if/else`, never `&&/||`.** `cond && a "$@" || b "$@"` will run
  `b` whenever `a` exits non-zero — so a tool exiting with an error code would
  wrongly launch the other account.
- **`read -k 1` must run in the current shell**, not a `$(...)` subshell, so it
  can set the caller's `local _acct` (zsh dynamic scope). A single-keypress read
  reads from the terminal, so it can't be tested by piping into stdin.
- **Don't isolate dirs that should stay shared** (e.g. pi's `~/.config/pi`
  extensions). Only the login/credentials + per-account data need their own dir.
- **Continue-session aliases** are a nice extra, per account, e.g.
  `alias cpr='claudep -c'` and `alias cwr='claudew -c'`.

### Other shells

- **bash:** same structure; replace `print -P` color codes with `printf` /
  `echo -e`, and use `read -rsn1 ans` for the single keypress.
- **fish:** use functions and `set -lx VAR value; command <tool> $argv`, and
  `read -n1 -P 'prompt: ' ans` for the keypress.

Once everything is in place, confirm what you changed and give me the exact
reload + per-account login commands.

## Optional next step — show the active account in the statusline

Once you're running multiple accounts it's easy to lose track of which one a
given terminal is using. If I want, set up a statusline indicator that shows the
active account, using the companion prompt
[`statusline-account.md`](./statusline-account.md). Offer this; don't do it
unless I say so.
