# bridge, design

A skill that turns whichever coding-agent session you already opened into a single
point of contact: it gathers the context for a piece of work, spawns specialist
agents to think about it and then to build it, relays their questions to you, and
reports back. You talk to one agent for the whole session.

The bridge is where you stand to command, not where the work happens. Invoked as
`/bridge`.

## The crew

| Role | Called | What it does |
|---|---|---|
| you | **captain** | Sets the goal, approves the plan, owns every release decision |
| liaison | **bosun** | Your single point of contact. Runs the working crew and reports to the captain. Does not edit code |
| designer | **navigator** | Plots the course: turns the brief into a plan |
| reviewer | **surveyor** | Independently inspects the course and reports defects |
| implementers | **hands** | Do the work, one per worktree |
| recon | **lookout** | Cheap read-only answers: what's in this repo, what does this ticket say |

A working sequence: the navigator plots a course, the surveyor tries to sink it,
the captain approves, the bosun puts the hands to work, and a lookout answers
cheap questions along the way.

(A real bosun works the deck rather than the bridge. "Mate" is the literal bridge
role, and is avoided here only because firstmate is the tool being replaced and
the collision would be confusing later.)

## What it is not

It is not an agent distro. [firstmate](https://github.com/kunchenguid/firstmate)
is the reference for that shape and it is a genuinely impressive piece of work:
a 62KB `AGENTS.md`, 123 helper scripts, its own tmux session backend, its own
state directory, and it clones your repositories into `firstmate/projects/` so it
operates on a copy. That replaces your setup instead of sitting on top of it.

The one idea worth taking wholesale is its `config/crew-dispatch.json`: rules that
map a kind of task to a harness, model, and effort, with a default. That is the
configurability layer, and it is about thirty lines of JSON.

## Shape

Three moving parts.

- **The bosun** is your ordinary session, in whatever workspace you opened
  (Conductor, a plain terminal, anything). It holds the conversation.
- **The crew** are detached CLI processes, each in its own git worktree, each with
  a log and a status file. `claude` for Claude-side roles, `codex exec` for
  codex-side roles.
- **State** is files under `~/crew/`, so a finished hand's worktree can be deleted
  without losing the trail, and so a bosun that gets restarted or compacted can
  pick the thread back up by reading the disk.

Conductor is not involved in spawning and does not need to be. Its CLI manages
cloud workspaces only; local workspaces are created by the Mac app. A process the
bosun launches is just a process, and it works in whatever directory it is
pointed at.

## Models and effort

Model choices follow the published capability tiers and effort guidance rather
than taste. Fable 5 is the top tier ("most capable widely released", $10/$50 per
MTok); Opus 5 is explicitly "half the cost of Fable 5" and aimed at complex
agentic coding ($5/$25); Sonnet 5 is near-Opus on coding and agentic work at
$3/$15.

| Role | Harness / model | Effort | Why |
|---|---|---|---|
| bosun | claude / Sonnet 5 | medium | Intake, dispatch, relay. Low and medium effort mean fewer, more consolidated tool calls and terser confirmations, which is what makes a contact point feel responsive. Sonnet 5 at medium also scopes work to what was asked, which is what stops a bosun from quietly doing the job itself. Raise to high if it starts mis-routing. |
| navigator | claude / Fable 5 | xhigh | Design and outline. Minimum recommended effort for intelligence-sensitive work is high; xhigh for the hard end. |
| surveyor | codex / gpt-5.6-sol | xhigh | A different provider attacking the plan, so it is not reviewed by the family that wrote it. |
| hand, hard | claude / Opus 5 | xhigh | Multi-file features, refactors, visual or UI judgment, anything ambiguous or risky. Opus 5 is documented as strongest on difficult tasks and as completing them rather than leaving stubs. |
| hand, mechanical | codex / gpt-5.6-terra | medium | Formatting, renames, dependency metadata, routine test maintenance. |
| lookout | claude / Sonnet 5 | low | Read-only: grep the repo, read a ticket, summarize. No worktree needed. |

Effort is a per-role knob in config, not a constant. The docs are clear that
`low` is the right setting for subagents and simple tasks, and that effort
defaults carried over from a previous model are usually wrong.

## Lifecycle

1. **Session start.** A `SessionStart` hook prints a short nudge telling the
   session it is the bosun and to load this skill. See "Bosun first" below.
2. **Intake.** You say what you want, usually a Linear ticket ID or a Slack
   thread. The bosun pulls the ticket, its comments, linked PRs, and any Slack
   thread, and writes them to `~/crew/<repo>/<slug>/brief.md`. This is the step
   where the bosun earns its keep: one message from you becomes a full context
   pack. Lookouts can fan out here for read-only repo questions.
3. **Course.** The bosun spawns the navigator on the brief, and the surveyor on
   the navigator's output. Both run detached. The bosun polls and relays.
4. **Approval gate.** The bosun brings you the plan and the surveyor's
   objections. Nothing is built until you say so. This gate is not optional and
   not configurable.
5. **Work.** The bosun splits the plan into tasks, dispatches each to a hand by
   the dispatch rules, and runs them in parallel in separate worktrees.
6. **Report.** As each hand finishes, the bosun reports what landed: the branch,
   the draft PR link, whether checks passed.
7. **Close.** `/bridge close` removes finished worktrees and archives the state
   directory.

## Spawn mechanics

Verified on 2026-08-06 against claude 2.1.223 and codex-cli 0.146.0, in a scratch
repository. Facts below marked *verified* were actually run; the rest come from
`--help` and are flagged.

### Two revisions made while building

The design above was written before the script existed. Two things changed, both
simplifications:

1. **`crew spawn` creates worktrees itself with plain `git worktree add`, outside
   the repository**, at `~/crew/<repo>/<slug>/<role>/wt`, on a branch
   `crew/<slug>-<role>`. It does not use `claude -w`. This gives one mechanism for
   both harnesses, adds nothing to the repo being worked on (no `.claude/worktrees`
   to exclude, no chance of committing a worktree as an embedded repo), avoids
   Claude Code's worktree locks entirely, and puts the worktree next to its own
   state. The cost is that the `.worktreeinclude` copying has to be done by hand,
   which the script does explicitly for the `.env*` and `.envrc` family.
2. **`--bg` is not used.** The open question about whether it composes with `-p`
   is now moot: the script runs `-p` under `nohup` with its own redirect, pid file,
   and status file, because it needs exactly that for codex anyway. One code path
   instead of two, and the open question disappears rather than getting answered.

The rest of this section is the verified reference behind those choices, and still
applies to anyone using `claude -w` directly.

### Claude-side hand

`claude -p -w <slug>` works, and creates the worktree itself (*verified*):

- The worktree lands at `<repo>/.claude/worktrees/<slug>`.
- Its branch is auto-named `worktree-<slug>`.
- It branches from `origin/<default-branch>` by default, or from local `HEAD`,
  controlled by the `worktreeBaseRef` setting (`fresh` / `head`). Per task: a hand
  starting clean wants `fresh`, a hand extending your current branch wants
  `head`.
- **Gitignored files are NOT copied unless a `.worktreeinclude` exists**
  (*verified, and it contradicts what I first assumed*). With a
  `.worktreeinclude` containing `.env*`, a gitignored `.env.local` is copied in
  (*verified*). Without it, nothing is. So a repo whose hands need `.envrc` or
  `.env.local` needs that file, or the spawn script copies them itself.
- **Claude Code locks its worktrees** with a lock reason naming the session pid
  (*verified*). Cleanup needs `git worktree remove -f -f`, or an unlock first. A
  plain `--force` fails.
- `--tmux` (with `--worktree`) puts each hand in an iTerm2 native pane, which is
  the escape hatch when you want to watch or type into one.

One flag is still unverified: whether `--bg` composes with `-p`. `--bg` returns
immediately and is managed by `claude agents --json`, which reads like an
alternative to `-p` rather than a companion. The fallback is certain: run `-p`
detached with output redirected, which is the shape the spawn script wants
anyway. Resolve this in the first build step and pick one.

### Codex-side hand

`codex exec` in a fresh worktree needed no trust prompt and no interactive step
(*verified*):

```sh
codex exec -C <worktree> -m gpt-5.6-terra -c model_reasoning_effort=medium \
  --json -o <state>/last.txt "<task>" < /dev/null
```

- `-C` sets the working root, `-m` the model, `-c model_reasoning_effort=` the
  effort, `--json` gives a JSONL event stream, `-o` writes the final message to a
  file (*all verified*).
- **`< /dev/null` is required** when detached. Without a tty it prints "Reading
  additional input from stdin..." and waits (*verified*).
- The first JSON event carries `thread_id`. That is the handle for
  `codex exec resume <thread_id>`, which is how the relay sends an answer back.
- Repo-local `.codex/config.toml` and hooks are silently ignored in an untrusted
  project, and a trust entry must name the project root exactly (a parent
  directory entry does not cover subdirectories). If a hand needs repo-local
  codex config, the spawn script writes a `[projects."<worktree path>"]` entry.
  Nothing is needed for a hand that only needs the user-level config.

### Both

- **Config inheritance is env passthrough.** Export the bosun's own
  `CLAUDE_CONFIG_DIR` or `CODEX_HOME` and the child inherits MCP servers, skills,
  hooks, permissions, and model defaults. That is the whole mechanism. Both
  accounts on this machine are per-CLI-home
  (`~/.claude-leanscaper`, `~/.codex-leanscaper`), so a bosun launched under one
  keeps its crew in the same account.
- **direnv.** Non-interactive shells do not load direnv, so every crew member
  runs under `direnv exec <worktree> <command>`.
- **`.claude/worktrees/` must be excluded**, in `.git/info/exclude` so it stays
  local. Otherwise it shows as untracked and a stray `git add -A` commits an
  entire worktree into the repository as an embedded git repo. I did this to
  myself while testing.

## State layout

```
~/crew/<repo>/<slug>/
  brief.md          intake: ticket, comments, Slack, links
  course.md         navigator output, then the approved version
  survey.md         surveyor output
  notes.md          navigator's own scratch memory (see below)
  tasks/<n>.md      one task per hand
  <role>/
    wt/             that member's worktree, on branch crew/<slug>-<role>
    status          running | asking | done | failed | died
    meta.json       harness, model, effort, slug, repo, worktree, session id
    log             raw stdout/stderr
    pid, exit-code  liveness and outcome
    run.sh          the exact command that was launched, for debugging
    task.md         what it was asked to do
    ask.md          present only while a question is unanswered
    asked-N.md      archived questions
    answer.md       the captain's last answer
    result.md       final message
```

`~/crew` is overridable with `CREW_HOME`, and `<slug>` is the ticket ID when there
is one. The repo key comes from the shared git dir, so every worktree of one
repository maps to a single state directory rather than one per Conductor
workspace.

`status` is a file, but `crew status` reports an *effective* status: an unanswered
`ask.md` outranks `running`, and a `running` status whose pid is dead reports as
`died` rather than lying.

## The relay

A crew member that needs a decision writes `ask.md` and exits, or blocks. The
bosun notices on its next poll, surfaces the question to you with the context it
needs to be answerable on its own, writes your answer to `answer.md`, and resumes:

- claude: `claude -p --resume <session-id> "<answer>"`, with `--session-id` set
  at spawn so the id is known in advance.
- codex: `codex exec resume <thread-id> "<answer>"`.

Claude also has `--brief`, which gives a session a `SendUserMessage` tool for
talking to a human directly. Worth trying for the navigator, where the back and
forth is the point. The file protocol stays as the mechanism that works for both
harnesses.

## Config

`~/crew/config.json`, read by the bosun at session start.

```json
{
  "stateDir": "~/crew",
  "roles": {
    "bosun":     { "harness": "claude", "model": "sonnet",      "effort": "medium" },
    "navigator": { "harness": "claude", "model": "fable",       "effort": "xhigh" },
    "surveyor":  { "harness": "codex",  "model": "gpt-5.6-sol", "effort": "xhigh" },
    "lookout":   { "harness": "claude", "model": "sonnet",      "effort": "low" }
  },
  "dispatch": {
    "default": { "harness": "codex", "model": "gpt-5.6-terra", "effort": "high" },
    "rules": [
      {
        "when": "Mobile or web UI implementation, visual design judgment, accessibility, animation, layout, visual verification, unusually ambiguous debugging, or a risky implementation.",
        "use": { "harness": "claude", "model": "opus", "effort": "xhigh" }
      },
      {
        "when": "A narrow mechanical change: formatting, renaming, dependency metadata, straightforward docs, routine test maintenance.",
        "use": { "harness": "codex", "model": "gpt-5.6-terra", "effort": "medium" }
      }
    ]
  },
  "autonomy": { "push": true, "openDraftPr": true, "merge": false }
}
```

The `bosun` entry is documentation, not control: a skill cannot change the model
of the session it is running in. That is set when you launch, by Conductor's
per-workspace setting, `claudel --model sonnet --effort medium`, or the `model`
key in the config directory's `settings.json`.

## Bosun first

A `SessionStart` hook injects a one-line nudge telling the session to load this
skill and act as bosun. Claude reads it from `settings.json`, codex from
`hooks.json`; both files already exist in these config directories, so it is an
additive edit.

The hook must exit early when `CREW_ROLE` is set, or every spawned crew member
will also decide it is a bosun and start spawning its own crew.

## Prompt templates

Each role gets a prompt file, and they differ in more than tone, because the
models have documented and opposite failure modes.

**Navigator (Fable 5).** State the goal and the constraints, then get out of the
way. Prompts written for earlier models are too prescriptive for Fable and
measurably reduce its output quality, so this template is deliberately shorter
than the hand template. Two consequences to design around:

- A single Fable request at high effort can run for many minutes; a fifteen
  minute turn is documented as normal. The bosun must never block on it. Poll,
  report, and let you keep talking.
- Fable performs notably better with somewhere to write learnings, even a plain
  markdown file. That is what `notes.md` is for, and the template tells it the
  format: one lesson per entry, one-line summary first, record corrections and
  confirmed approaches with the reason, update rather than duplicate, delete what
  turns out wrong.

**Hand (Opus 5).** Counter the documented behaviors, each of which has a known
fix:

- Over-verification. The fix is to *delete* verification instructions, not add
  them. Opus 5 verifies its own work unprompted, and telling it to double-check
  causes redundant work.
- Scope expansion. Add an explicit scope-discipline instruction: deliver what was
  asked, make routine judgment calls, flag a concern in a sentence and keep
  going, finish the whole task and only report completion when it is actually
  done.
- Over-delegation. Opus 5 reaches for subagents readily, which multiplies cost.
  Cap it: no subagent for work finishable in a handful of tool calls, and never
  for verification.
- Length. It writes longer files and longer responses than asked. Ask for
  deliverable length matched to the task.

**Bosun.** Do not edit code in the main checkout. Never merge, never run anything
release-shaped. Bring questions up with enough context to be answerable without
scrollback.

## Autonomy and safety

Hands commit, push a branch, and open a **draft** PR. They never merge, never
push to a long-lived branch, and never run anything that publishes. In the
repository this was designed against, every push to the JS accumulator branch
auto-publishes a staging OTA, which is exactly the class of action a crew must
not be able to take by accident.

Release steps stay with the captain, every time, as they already do.

This design uses git worktrees throughout, which overrides the standing "don't
use worktrees unless I say so" rule. That override was given explicitly for this
tool and is scoped to crew members; it does not extend to ordinary work.

## Deliberately out of scope

Named so they do not get rebuilt by accident: no cloud workspaces, no tmux or
zellij session backend, no cloning projects into a directory the tool owns, no
persistent second-tier bosuns on other hosts, no public chat surface, no cost
accounting beyond what the CLIs already report.

## Install

### 1. Link the skill

Canonical location is `~/.agents/skills/<name>`, an absolute symlink to the repo
directory, then a relative symlink from each config directory. Version
independent, so it cannot rot when a tool version moves.

```sh
ln -sfn ~/useful-ai/skills/bridge ~/.agents/skills/bridge
for d in ~/.claude ~/.claude-leanscaper ~/.codex ~/.codex-leanscaper; do
  [ -d "$d" ] && mkdir -p "$d/skills" && ln -sfn ../../.agents/skills/bridge "$d/skills/bridge"
done
```

### 2. Create the config

```sh
~/.agents/skills/bridge/scripts/crew init     # writes ~/crew/config.json
```

Optionally put `crew` on PATH so the bosun does not have to use an absolute path:

```sh
ln -sfn ~/.agents/skills/bridge/scripts/crew ~/.local/bin/crew
```

### 3. Always starting on the bridge

A `SessionStart` hook injects the bosun nudge. **Add to the existing
`SessionStart` array, do not replace it**, since both config directories already
have hooks registered.

Claude, in `~/.claude-leanscaper/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear",
        "hooks": [
          { "type": "command",
            "command": "/Users/pavlos/.agents/skills/bridge/hooks/bosun-nudge.sh",
            "timeout": 10 }
        ]
      }
    ]
  }
}
```

Use an absolute path, not `~`. Codex is the same shape in
`~/.codex-leanscaper/hooks.json` under a `SessionStart` key; codex additionally
tracks a `trusted_hash` per hook in `config.toml`, so the first run after adding
it will ask you to trust the hook once.

Two escape hatches are built into the nudge: it exits immediately when
`CREW_ROLE` is set (which is how spawned crew members avoid recursively becoming
bosuns) and when `CREW_NO_NUDGE=1` is exported (for a session that should just be
a normal session).

### 4. The bosun's own model

A skill cannot change the model of the session running it, so this is a
launch-time choice:

- Per session: `claudel --model sonnet --effort medium`
- Per Conductor workspace: the workspace's model setting
- As the default for every session: the `model` key in the config directory's
  `settings.json`

The third one changes every session, not just bridge sessions. Worth knowing
before setting it, since the current default in this config is Fable.
