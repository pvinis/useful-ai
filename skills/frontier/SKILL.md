---
name: frontier
description: Put a Claude on every takeable ticket of a /wayfinder map, each in its own Orca worktree, so the user walks between workspaces instead of working tickets one session at a time. Use after a wayfinder charting session has produced a map and its tickets, or when the user says "spawn the frontier", "fan out the wayfinder tickets", "put an agent on each ticket", or asks what the frontier looks like right now. Requires Orca and a repo whose issue tracker holds a wayfinder map.
---

# frontier

A `/wayfinder` charting session ends by design: it draws the map and stops,
having resolved nothing. What it leaves behind is the **frontier** — the open,
unblocked, unclaimed tickets, the ones takeable right now. This skill puts a
Claude on each of them, one Orca worktree per ticket, each session already
holding the map and its ticket.

You are the dispatcher. You do not resolve tickets yourself.

## What Orca changes

Each spawned agent gets its **own git checkout and branch**, not a pane in a
shared one. That is the whole difference, and it cuts both ways:

- Agents cannot collide in the working tree, and a research ticket that wants a
  throwaway branch for its findings already has one.
- Every spawn costs a checkout on disk and a run of the repo's setup hook
  (`bun install` and friends). Three tickets means three installs. Say this
  before you fan out; "a tab" and "a checkout" are not the same price.

## The one rule that does not bend

**A spawned session must never rewrite the map issue body.**

Wayfinder's resolution step has each session append a line to the map's
*Decisions so far*. That section lives in the issue **body**, a single field. How
badly that goes depends on the tracker, and the difference matters:

- **Whole-body trackers (GitHub Issues).** Edits are last-write-wins. Two
  sessions closing tickets a minute apart silently overwrite each other's line,
  and nothing surfaces the loss. Here the rule is absolute.
- **Anchored-patch trackers (Linear's `save_issue --patch`).** A patch applies
  against current content by exact-match anchor, so a race either inserts both
  lines (benign, possibly out of order) or fails loudly with an anchor that no
  longer matches. Recoverable, but only if sessions patch rather than resend the
  whole `description` — and an agent that resends the body is back to silent loss.

So spawned sessions comment and close their own ticket — which is per-ticket and
safe on every tracker — and report the Decisions-so-far line back instead of
writing it. Folding those lines into the map is the user's job, or yours once the
workspaces are quiet. `scripts/frontier-spawn` bakes this instruction into every
prompt it sends; if you spawn by hand, carry it over verbatim.

Note what this rules out: sending a bare `/wayfinder <ticket-url>` as the prompt.
That invokes wayfinder's normal resolution path, which ends by editing the map
body — exactly the thing this rule exists to prevent.

## Before you spawn

- **Resolve the Orca executable once**, and reuse it for every command:
  `$ORCA_CLI_COMMAND` if set; else `orca-dev` in a dev checkout exposing
  `ORCA_DEV_REPO_ROOT`; else on Linux `orca-ide`, **never** bare `orca` (outside
  Orca's own terminals that is usually the GNOME screen reader and it starts
  speech on the user's machine); else `orca`.
- **Confirm Orca is running**: `<orca> status --json`, and `<orca> open --json`
  if it is not. You do not need to be *inside* an Orca session to drive one, but
  the app does have to be up.
- **You need the map's issue number or URL.** Ask if the user did not give it.
- **Confirm the list before spawning.** Show what you are about to spawn, with
  the disk-and-install cost named, and wait for a yes.

## Steps

### 1. Find the frontier

The tracker is repo-specific. Resolve the repo's issue-tracker doc through the
pointer in its `CLAUDE.md` / `AGENTS.md` and read the **Wayfinding operations**
section — it defines how that repo expresses the map, sub-issues, blocking, and
the frontier query.

For GitHub Issues, `scripts/frontier-scan` implements that query:

```bash
scripts/frontier-scan <map-number> -v
```

It prints one TSV row per takeable ticket — number, type, title — and with `-v`
reports every excluded ticket and why on stderr. Read that stderr aloud to the
user. A frontier of two out of eleven tickets means something different from a
map with two tickets on it, and only the exclusions tell them which they have.

For a non-GitHub tracker, run the frontier query the tracker doc gives you and
produce the same three columns by hand. On Linear that is `list_issues` by
`parentId`, filtered to open `statusType`s and no assignee, then
`get_issue --includeRelations` on the survivors to drop any with an open blocker.

### 2. Decide what is worth spawning

Ticket type decides this, and the types behave nothing alike:

- **`research`** — AFK. Spawn all of them. They run to completion with nobody
  watching, and their reading never lands in anyone's context. This is where
  almost all the value of fanning out is.
- **`grilling`** and **`prototype`** — HITL. These reach a waiting state within a
  minute and sit there. Spawning them buys pre-warmed context, not throughput,
  and two grilling sessions on adjacent tickets will ask the user overlapping
  questions because they share no context. **Cap these at two**, and prefer
  tickets that are obviously unrelated to each other.
- **`task`** — read the ticket before deciding. AFK ones spawn fine. HITL ones
  are a checklist for the user and are usually better handed over directly.

Say plainly what each spawned agent will and will not do, so nobody comes back to
a wall of waiting workspaces expecting finished work.

### 3. Spawn

```bash
scripts/frontier-spawn <map-number> <ticket> [<ticket>...]
```

Per ticket it re-checks the claim, assigns the ticket, and creates an Orca
worktree named `wf-<n>` with a Claude already running in its first terminal,
pre-loaded with the ticket and the map-body rule. Pass `--dry-run` first if the
user wants to see the plan.

Details worth knowing, because each is load-bearing:

- **The claim happens at spawn time, not inside the session.** That is what makes
  a second run of this skill skip tickets already in flight instead of creating a
  duplicate worktree for one.
- **The prompt goes in through `worktree create --agent claude --prompt`**, in the
  same call that creates the worktree — not through a later `terminal send`.
  Typing a string beginning with `/` into a running Claude opens the slash-command
  menu, and the Enter that `terminal send --enter` appends may pick from that menu
  rather than submit.
- **One call does the whole spawn.** `worktree create --agent` puts the agent in
  the worktree's first terminal. Do not create the worktree and then
  `terminal create` the agent: without configured default tabs that leaves an
  extra unused shell alongside the agent.
- **`--no-parent` and no `--base-branch`.** Frontier tickets are independent of
  each other and of whatever branch you are standing on, so each worktree should
  branch from the repo default base. Passing neither flag risks stacking every
  agent on your current feature branch.

Verify the spawn rather than trusting it: the create response carries
`startupTerminal.spawned` and `agentTerminalHandle`, and one
`terminal read --terminal <handle> --json` confirms the agent is alive and moving.
A brand-new worktree path has never been trusted before, so Claude may open on its
folder-trust prompt; the session is alive but parked until someone accepts it. The
script reports that case and keeps the claim. Any *other* start failure releases
the claim and removes the worktree, so the ticket returns to the frontier. Report
those; do not quietly leave them out.

### 4. Report, then get out of the way

Give the user the ticket → worktree → branch mapping, and how to move around:

```bash
<orca> worktree ps --json      # every workspace, with status and live terminals
```

Two shape gotchas when you read that JSON, both of which will bite:

- `worktree ps` calls the identifier **`worktreeId`**; `worktree list` calls the
  same value **`id`**. Do not reuse a field name across the two.
- The per-entry `agents` array is **empty** even while a Claude is running in the
  worktree. Use `status` (`working`) and `liveTerminalCount` instead.

Ask each spawned agent to keep its own status current, which surfaces in Orca's
workspace list without anyone reading a terminal:

```bash
<orca> worktree set --worktree active --comment "<short progress note>" --json
<orca> worktree set --worktree active --workspace-status in-review --json
```

Send the user into a workspace to talk to a waiting agent; do not try to relay a
grilling conversation through this session.

## Afterwards

When the workspaces go quiet, collect the reported Decisions-so-far lines and
append them to the map body in **one** edit. That is the serialization point the
whole design is built around.

Cleanup needs asking every time, and it is far more destructive than closing a
pane. An Orca worktree is a checkout with a branch and possibly uncommitted work;
`worktree rm --force` destroys all of it. A research ticket's answer usually lives
in its tracker comment, but its working notes may only exist in that checkout.
Never remove a worktree you did not create, and never remove one you did without
confirming its work is recorded somewhere else first.
