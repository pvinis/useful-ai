# useful-ai

A small collection of reusable prompts you can hand to an AI coding agent
(Claude Code, Codex, pi, Cursor, etc.) to have it do a useful piece of setup or
work for you.

Each file in [`prompts/`](./prompts) is self-contained: just link it to your agent, or copy-paste it into
your agent, and it will ask you the questions it needs, confirm a plan, and then
execute.

## Prompts

- [`prompts/multi-account-cli-setup.md`](./prompts/multi-account-cli-setup.md) —
  Run two (or more) accounts of an AI CLI on one machine, each fully isolated,
  with convenient per-account launcher commands and a bare-command account
  chooser. Works for Claude Code, OpenAI Codex, pi, and any CLI that has a
  config-directory environment variable.
