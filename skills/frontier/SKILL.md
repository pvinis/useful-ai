---
name: frontier
description: Put a Claude on every takeable ticket of a /wayfinder map, each pre-loaded in its own herdr tab, so the user walks between panes instead of working tickets one session at a time. Use after a wayfinder charting session has produced a map and its tickets, or when the user says "spawn the frontier", "fan out the wayfinder tickets", "put an agent on each ticket", or asks what the frontier looks like right now. Requires herdr and a repo whose issue tracker holds a wayfinder map.
---

# frontier

A `/wayfinder` charting session ends by design: it draws the map and stops,
having resolved nothing. What it leaves behind is the **frontier** — the open,
unblocked, unclaimed tickets, the ones takeable right now. This skill puts a
Claude on each of them, one herdr tab per ticket, each session already holding
the map and its ticket.

You are the dispatcher. You do not resolve tickets yourself.

## The one rule that does not bend

**A spawned session must never edit the map issue body.**

Wayfinder's resolution step has each session append a line to the map's
*Decisions so far*. That section lives in the issue **body**, a single field,
and body edits are last-write-wins. Two sessions closing tickets a minute apart
will silently overwrite each other's line, and nothing surfaces the loss. It is
the only place in this whole design where work can actually disappear.

So spawned sessions comment and close their own ticket — which is per-ticket and
safe — and report the Decisions-so-far line back instead of writing it. Folding
those lines into the map is the user's job, or yours once the panes are quiet.
`scripts/frontier-spawn` bakes this instruction into every prompt it sends; if
you spawn by hand, carry it over verbatim.

## Before you spawn

- **You must be inside herdr.** Check `test "${HERDR_ENV:-}" = 1`. If it fails,
  say so and stop; do not drive a herdr session from outside one.
- **You need the map's issue number.** Ask if the user did not give it.
- **Confirm the list before spawning.** Each ticket costs a tab and a live
  agent. Show what you are about to spawn and wait for a yes.

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
produce the same three columns by hand.

### 2. Decide what is worth spawning

Ticket type decides this, and the types behave nothing alike:

- **`research`** — AFK. Spawn all of them. They run to completion with nobody
  watching, and their reading never lands in anyone's context. This is where
  almost all the value of fanning out is.
- **`grilling`** and **`prototype`** — HITL. These reach `blocked` within a
  minute and wait for the user. Spawning them buys pre-warmed context, not
  throughput, and two grilling sessions on adjacent tickets will ask the user
  overlapping questions because they share no context. **Cap these at two**, and
  prefer tickets that are obviously unrelated to each other.
- **`task`** — read the ticket before deciding. AFK ones spawn fine. HITL ones
  are a checklist for the user and are usually better handed over directly.

Say plainly what each spawned agent will and will not do, so nobody comes back
to a wall of `blocked` panes expecting finished work.

### 3. Spawn

```bash
scripts/frontier-spawn <map-number> <ticket> [<ticket>...]
```

Per ticket it re-checks the claim, assigns the ticket, opens a herdr tab labelled
`wf-<n>`, and starts a Claude in it pre-loaded with `/wayfinder` for that ticket
and the map-body rule. Pass `--dry-run` first if the user wants to see the plan.

Two details worth knowing, because both are load-bearing:

- **The claim happens at spawn time, not inside the session.** That is what makes
  a second run of this skill skip tickets already in flight instead of opening a
  duplicate pane on one.
- **The prompt goes in as Claude's initial argument** (`herdr agent start ... --
  "/wayfinder ..."`), not through `herdr agent prompt` afterwards. Typing a
  string beginning with `/` into a running Claude opens the slash-command menu,
  and the Enter that `agent prompt` sends may pick from that menu rather than
  submit.

One startup case is not a failure: if the spawn cwd has never been trusted,
Claude opens on its folder-trust prompt and herdr reports `agent_not_ready` even
though the session is alive. The script detects that, keeps the claim, and tells
the user which tab to accept it in — the session picks up its ticket by itself
afterwards. Any *other* start failure releases the claim and closes the tab, so
the ticket returns to the frontier. Report those; do not quietly leave them out.

### 4. Report, then get out of the way

Give the user the ticket → agent-name → tab mapping, and how to move around:

```bash
herdr agent list            # who is working, blocked, or done
herdr agent focus wf-<n>    # walk into one
```

`blocked` means that pane is waiting on the user. `done` means it finished while
nobody was looking. Reading a pane with `herdr agent read` is unreliable here —
Claude runs on the alternate screen, so scrollback cannot be recovered — but
`herdr agent get` reports state correctly regardless. Send the user to the pane;
do not try to relay a grilling conversation through this session.

## Afterwards

When the panes go quiet, collect the reported Decisions-so-far lines and append
them to the map body in **one** edit. That is the serialization point the whole
design is built around.

Do not close tabs you did not create, and do not close the ones you did without
asking — a `blocked` pane is a conversation the user has not had yet.
