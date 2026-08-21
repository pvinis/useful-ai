# useful-ai

A small collection of reusable prompts and skills you can hand to an AI coding
agent (Claude Code, Codex, pi, Cursor, etc.) to have it do a useful piece of
setup or work for you.

Everything here is self-contained. For a **prompt**, just link it to your agent,
or copy-paste it in — it will ask the questions it needs, confirm a plan, and
then execute. A **skill** is structured for tools that support skills (e.g.
Claude Code): drop it into your skills directory and the agent picks it up when
the task matches.

## Prompts

- [`prompts/multi-account-cli-setup.md`](./prompts/multi-account-cli-setup.md) —
  Run two (or more) accounts of an AI CLI on one machine, each fully isolated,
  with per-account launcher commands and a bare-command account chooser. Works
  for Claude Code, OpenAI Codex, pi, and any CLI with a config-directory
  environment variable.
- [`prompts/statusline-account.md`](./prompts/statusline-account.md) —
  Show which account is active in the statusline, so you never lose track of
  which one a terminal is running. Pairs with the multi-account setup.
- [`prompts/mac-charging-wattage.md`](./prompts/mac-charging-wattage.md) —
  Report how many watts your Mac is charging at right now, using built-in macOS
  power tooling. Read-only.
- [`prompts/custom-icon-font.md`](./prompts/custom-icon-font.md) —
  Add your own icons to a font you already use — a mini nerd-font with only
  the glyphs you need, at pinned codepoints — so they render inline in a
  SwiftBar menu bar item, terminal, or anywhere else you can name a font.
- [`prompts/sims-loading-verbs.md`](./prompts/sims-loading-verbs.md) —
  Replace your CLI's spinner words with the loading-screen messages from the
  old Maxis sims, so a long tool call reads `Reticulating Splines…` or
  `Calculating Llama Expectoration Trajectory…`. Native setting in Claude Code,
  a hook in Codex.

## Skills

- [`skills/bridge/`](./skills/bridge) — Talk to one agent and ship with a crew.
  The session you open becomes the **bosun**: it gathers the context for a piece
  of work, puts a **navigator** on the plan and a **surveyor** on tearing it
  apart, waits for your go-ahead, then runs **hands** in isolated git worktrees
  and reports back with draft PRs. Roles, models, and effort levels are
  configurable; works across Claude Code and Codex in one crew.
- [`skills/frontier/`](./skills/frontier) — Put a Claude on every takeable
  ticket of a `/wayfinder` map, each in its own [Orca](https://orca.computer)
  worktree, so you walk between workspaces instead of working the map one
  session at a time. Reads the frontier from the repo's issue tracker, claims
  each ticket before spawning so reruns don't duplicate, and keeps every session
  off the map body — the one field where parallel writes can overwrite each
  other.
- [`skills/model-doctor/`](./skills/model-doctor) — Audit the AI model
  references in a repo or config directory, check them against official
  provider docs, and propose upgrades. Read-only by default: it reports what's
  outdated or deprecated and edits only what you explicitly approve.
- [`skills/trim-ios-simulator/`](./skills/trim-ios-simulator) — Clean up an iOS
  Simulator's home screen by uninstalling the apps you don't need, keeping only
  the ones relevant to your work. macOS + Xcode.
- [`skills/whose-laptop-is-this/`](./skills/whose-laptop-is-this) — You found a
  laptop and want to give it back. Run this **on that machine** and it hands you
  a **return card**: who it belongs to, and every read-only way to reach them,
  best first. Changes nothing, never enters a locked account, and gates every
  read against what an *ordinary* account could see — so holding root changes
  its behaviour nowhere. macOS, Windows, Linux, and a POSIX floor for everything
  else.

## Data

Data files the prompts pull from, usable on their own. See
[`data/README.md`](./data/README.md).

- [`data/sims-loading-messages.txt`](./data/sims-loading-messages.txt) — 595
  loading-screen messages from The Sims through The Sims 3, plus SimCity 4. Flat
  list, one per line, and the same set grouped by game in
  [`.json`](./data/sims-loading-messages.json).
