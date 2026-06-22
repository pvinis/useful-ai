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

## Skills

- [`skills/trim-ios-simulator/`](./skills/trim-ios-simulator) — Clean up an iOS
  Simulator's home screen by uninstalling the apps you don't need, keeping only
  the ones relevant to your work. macOS + Xcode.
