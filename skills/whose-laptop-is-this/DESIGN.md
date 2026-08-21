# whose-laptop-is-this — design & build spec

You are sitting at a laptop you found. It is unlocked, or partly so. You want to
give it back. You run this skill **on that machine**, and it hands you a **return
card**: who the laptop belongs to, and every read-only way to reach them, best
first.

This document is the **spec**, not the skill. It is implementation-ready: a
builder can write `SKILL.md` and its references from here without making another
design decision. Every decision below was locked by a ticket on
[Map: whose-laptop-is-this](https://github.com/pvinis/useful-ai/issues/9); the
provenance table at the end says which ticket owns which.

Build is a **follow-up session**. This document does not build anything.

## The guardrail — the rules that do not bend

This skill exists to return a device, not to snoop.

**In scope:** owner identity, contact channels, local account enumeration, and
explicit return-signals — the owner's lock-screen if-found message, OS
device-owner and registration fields, Find My / Activation Lock status.

**Out of scope, always:** message contents, browsing history, documents, saved
passwords, financial data. Lock bypass. Password cracking.

**Escalation and elevation are both out of scope.** Two words the guardrail was
conflating, now separated:

- **Escalation** — obtaining privilege you were not granted.
- **Elevation** — asserting privilege you legitimately hold: `sudo`, an
  Administrator shell, `reg load` of another user's `NTUSER.DAT`.

**The rule binds on the reach, not on the act.** Every read is gated by an
explicit permission check against an **ordinary principal**, not by whether the
read happens to succeed. A skill handed an already-root shell reads exactly what
it would read from a plain account. Where elevation is detected, disclose it:

> running elevated; reads are still limited to what an ordinary account could see.

The point of the rule: **admin rights change the skill's behaviour nowhere.**

**Reads extract named fields, never file bodies.** `git config --file <path>
--get user.email`, not `cat`. A `.gitconfig` carries private remote URLs,
`insteadOf` rewrites holding tokens, and signing-key ids; none of that enters the
agent's context. This applies to every source: `MobileMeAccounts` yields
`AccountID`, not the whole plist. It also makes the evidence trail exact — the
recorded command *is* the entirety of what was read.

**Nothing is written** to the machine unless the finder explicitly asks for the
handover file.

## Glossary

These terms carry into `SKILL.md` itself, not just this document. They are the
skill's working vocabulary and only do their job by repetition in the body.

- **Finder** — the person holding the laptop. Not the owner.
- **Owner account** — the one local account elected as the owner's. The identity
  spine.
- **Owner identity** — the person the card names. Owns one or more accounts (see
  *registration merge*), plus every machine-scope signal.
- **Machine-scope signal** — a signal belonging to the *machine*, not to an
  account: if-found message, device name, serial, MDM org, hostname. Attributed
  to the elected owner without needing a name match.
- **Return route** — a ranked contact channel. A route to the owner, *not
  necessarily the owner's own*: it carries a `whose` when it belongs to someone
  else.
- **Source family** — the independence bucket used for corroboration:
  `owner-authored` / `account-registration` / `app-config` / `inferred`. Two
  signals from one family are one source.
- **Election** — the ordered cascade that picks the owner account.
- **Vantage account** — the account the finder is sitting in. Evidence about the
  finder's luck, never about ownership.
- **Banner** — the *owner's* lock-screen if-found message (macOS
  `LoginwindowText`, Windows `legalnoticetext`, the Linux GDM greeter banner).
  Never used for anything else.
- **Reach line** — the card's own empty-state element, in the `⚑` slot. Distinct
  from a banner.
- **Shut out / blank** — a read was denied, versus everything was readable and
  empty. They look identical and mean opposite things.

## Repo layout

```
skills/whose-laptop-is-this/
├── SKILL.md                        the skill
├── DESIGN.md                       this document
├── references/
│   ├── macos.md                    ┐  per-OS gathering table, in-session
│   ├── windows.md                  │  whitelist, and gate invocation.
│   ├── linux.md                    │  Exactly one is read per run.
│   ├── unknown-os.md               ┘
│   └── online.md                   the opt-in enrichment branch
├── scripts/
│   ├── can-ordinary-read.sh        the permission gate, POSIX
│   └── can-ordinary-read.ps1       the permission gate, Windows
└── tests/fixtures/                 three fixture machines, the acceptance cases
```

`SKILL.md` carries everything **every run** needs: the preamble copy, the
guardrail, the glossary, OS detection, the election cascade, the whole render
spec, and both whitelists. Reference files carry only what **some** runs reach:
three of the four OS tables are dead weight on any given run, and enrichment
fires on a minority of runs.

The build also adds an entry to the repo's root `README.md`, under `## Skills`,
matching the existing three.

## Frontmatter

Model-invoked. The finder does not know a skill exists — they type *"I found a
laptop on the train, can you work out whose it is?"* — and this repo publishes to
strangers who will never read the README. Both point the same way, and all three
existing skills here are model-invoked.

The description binds on the **found-laptop premise**, not on identity lookup. A
bare *"who owns this machine"* while debugging must not fire it: the intent
confirmation is a conversation, so a misfire costs the finder a 119-word ethics
block they did not ask for, and that trains exactly the rubber-stamping the
preamble and the enrichment consent both work to avoid.

```yaml
---
name: whose-laptop-is-this
description: Identify the owner of a found laptop and rank every read-only way to reach them, so the machine can be returned. Runs on the found machine itself and changes nothing. Use when someone has found a laptop or device that isn't theirs and wants to return it, asks whose laptop this is, is about to hand a machine to lost property or the police, or wants to know how to contact the owner of a device in front of them. The premise is always a device the user does not own.
---
```

---

# The run

## 1. Open with the preamble

Before detecting the OS or reading anything, print the block below **verbatim**,
then wait for an answer. Do not re-tone it, expand it, or add to it — the wording
is the decision. Print it once per conversation; on a re-run, go straight to work.

    This skill helps return a found laptop to its owner. It reads this machine
    only — nothing is changed, nothing is uploaded.

    **What it reads:** the account names on this machine, any "if found" message
    on the lock screen, and contact details the owner has already put in their
    own settings.

    **What it doesn't:** messages, files, or saved passwords. It won't try to get
    around a lock or a password.

    The result is a short summary of who this laptop probably belongs to and the
    best ways to reach them. If a public lookup would help, it'll ask first, and
    nothing from the laptop is sent anywhere.

    This is a laptop you found and want to return to its owner — right?

This is **expectation-setting, not a consent gate**. The confirmation restates
the premise rather than asking readiness, so a "no" carries information.

The printed exclusion list is **three concrete nouns, not the full guardrail**.
The rules section enforces the boundary; this copy only has to be read and
believed, and eight exclusions get skimmed. The impersonal voice is deliberate:
it reads as policy rather than as a promise from whoever is talking.

**Route on the answer:**

- **Yes** → run.
- **It's my own machine / I administer these machines** → run. Read-only identity
  and contact work on a machine the user is entitled to use is a non-event.
- **No** → print this and stop:

      Stopping here, then. If you want to hand it in instead, a police station or
      the venue's lost property desk is the usual route.

- **Unclear** → ask once: "Just to check — is this a machine you found, or one
  you're entitled to use?" If it's still unclear, stop with the same line.

If the finder asks for something past the guardrail mid-run, decline in one line
and **keep going** — do not end the run. Most out-of-bounds asks are a finder
over-helping in good faith:

    That's past what this skill looks at; it stays on who owns the laptop and how
    to reach them. Continuing with the rest.

## 2. Detect the OS, then read one reference

Detect first; the promise the preamble makes is OS-independent, and "before it
does anything" beats "before it does anything except…".

| detected | read |
|---|---|
| macOS | `references/macos.md` |
| Windows | `references/windows.md` |
| Linux | `references/linux.md` |
| anything else | `references/unknown-os.md` |

The unknown-OS path is a **fixed POSIX floor** — hostname, account roster, admin
group, git identity — and nothing more. It fires on BSD, a ChromeOS shell, a
stripped container. The card renders normally and the reach line carries the
thinness. The agent does not go looking for "equivalents" of the known signals:
that is the runtime-extensible whitelist this spec bans, wearing a different hat.

## 3. Establish the vantage

Two vantages, and they gate different reads:

- **In-session** — the finder is inside the owner's own unlocked account. The
  machine was handed over open.
- **Cross-boundary** — the finder is at the login screen or in a second/guest
  account, and the owner's account is locked. **Never enter the locked account.**

Record which one applies; it goes in the handover file's header and drives the
whitelist split below.

## 4. Gather, through the gate

### The gate

Every read of a path outside the vantage account goes through
`scripts/can-ordinary-read`, which answers *could an ordinary principal read
this?* — not *can I read this?*

> **Contract.** `can-ordinary-read <path>` exits `0` when an ordinary principal
> could read the path, non-zero otherwise. It reads permission metadata only, and
> never the file. Its answer does not change when the caller is root or an
> Administrator.

**POSIX** (`can-ordinary-read.sh`): the file's mode has `o+r`, **and** every
parent directory up to `/` has `o+x`. Evaluate the mode bits themselves — never
`test -r`, which reports the *effective* answer and so silently passes for root.
This is what collapses the Linux cross-boundary surface to nothing under
`HOME_MODE` `0700`/`0750`, and to `~/.gitconfig` only on macOS, where homes are
`755` but `~/.ssh` and `~/Library` are `700`.

**Windows** (`can-ordinary-read.ps1`): `Get-Acl` on the path, then require an
Allow ACE granting read to `Everyone`, `BUILTIN\Users`, or `NT AUTHORITY\
Authenticated Users`, with no matching Deny. A grant to `Administrators` or
`SYSTEM` alone **fails the gate**. For registry paths, `HKEY_USERS\<other-SID>`
fails unconditionally — reaching it means loading `NTUSER.DAT`, which is
elevation.

"Attempt the read and see" is not an acceptable implementation. It fails the
elevated case, and it hard-codes permission assumptions that vary by OS version.

### The two whitelists

Both are **fixed and exhaustive**. Neither may be phrased as a category
("identity-shaped files") that an agent can extend at runtime. Every entry names
the field extracted, not just the path.

**Cross-boundary whitelist — git identity, and nothing else:**

| path | fields |
|---|---|
| `<home>/.gitconfig` | `user.name`, `user.email` |
| `<home>/.config/git/config` | `user.name`, `user.email` |

No globbing. No directory trawling. Nothing off-list even when readable. This is
kept, rather than flattened to a simpler "never read another account's home",
because the locked Mac is this skill's flagship case and the git email is the
only contactable channel it offers: `dscl` yields a name, `LoginwindowText` is
usually unset, and no email exists anywhere outside the account.

**In-session whitelist** — longer than the cross-boundary list, not looser:

| source | fields extracted |
|---|---|
| macOS Apple ID | `AccountID`, `AlternateEmailAddresses` from `MobileMeAccounts` |
| macOS Contacts "me" card | that record's name, email, phone only |
| Windows OneDrive | `UserEmail`, `UserName` |
| Windows MSA | the `IdentityCRL\UserExtendedProperties` subkey name |
| GNOME Online Accounts | `Provider`, `Identity`, `PresentationIdentity` |
| git identity | `user.name`, `user.email` |
| GitHub CLI | the `user:` line of `hosts.yml` |
| GPG | the UID lines of `--list-secret-keys` |
| SSH public keys | the trailing comment field of `*.pub` only |
| mail clients | configured account addresses and display names only |

**Asymmetry rule: cross-boundary → git identity only; in-session → this list.**

Never read, on any vantage or any OS: keyrings and token stores, `~/.ssh` private
keys, browser profiles (a signed-in browser holds an account email, but reading
it means parsing a store adjacent to browsing data and saved credentials), and
anything the guardrail excludes.

### Which homes get touched

Only accounts surviving a **first-pass** owner heuristic — admin group, plus
first-created (uid 501 / uid 1000 / RID 1001), plus most-recent use — at most the
top one or two. Never every human home on the machine.

The heuristic and the read are **mutually recursive by design**: the git name is
often what settles the ranking, so a strict "best candidate only" rule would be
circular. Hence two passes: rank on OS-given signals, read the top one or two,
then run the full election in step 5 with those reads in hand.

### Announce the crossing

No second confirmation prompt — the intent gate covers the run, and a prompt
whose only sensible answer is "yes" trains click-through. Instead announce at the
moment of the reach, **once**, and **cross-boundary only**. Announcing every read
turns the line into wallpaper.

    → Reading git name and email from /Users/john/.gitconfig — the only file
      opened outside this account.

Impersonal voice, matching the preamble. The path is named.

## 5. Collapse the signals into one owner identity

The collapse is **account-anchored**: local user accounts are the skeleton,
because they are OS-given and unambiguous, and they stay readable when everything
inside them is not. **Name similarity never makes a join** — it only corroborates
one already made by account or machine scope. That is what keeps the
locked-primary case answerable, and what stops a coworker's email being
attributed to the owner.

### Election cascade

First-hit-wins, **not** a weighted score, so the evidence view can print the
reason as one inspectable line (`elected: first-created + admin`). Exclude
system and service accounts first — `nologin` shells, uids below the human floor,
Windows built-ins. Then:

1. **Sole human account** → owner, `confirmed`, no further tests.
2. **First-created *and* admin** — uid 501 / uid 1000 / RID-1001 profile, in the
   admin group (`dscl` admin, `Administrators`, `wheel`/`sudo`).
3. **Corroborated by a machine-scope name** — hostname or banner names a person
   matching exactly one account.
4. **First-created, or admin, but not both.**
5. **Recency** — tiebreaker only, never a primary claim.

Two explicit exclusions: the **vantage account gets no bonus**, and **recency is
never a primary claim** — otherwise a guest session woken sixty seconds before
the finder opened the lid outranks the real owner.

### Registration merge

Two accounts merge into one owner identity **only** on shared
*account-registration* identity — same Apple ID, same MSA, same work UPN —
evidence the OS itself holds. The merged identity owns both accounts and pools
their channels, and the shared-machine banner does **not** fire: one person, two
doors.

**Identical real-name strings merge nothing.** A father and son of the same name
is a real household; they land in the two-candidate case below, which is the
correct hedged answer.

### Confidence

Tiers are heuristic words, never numbers, never percentages:
`confirmed` > `strong` > `likely` > `weak`.

**Corroboration promotes by at most one tier, and never into `confirmed`.** That
tier stays reserved for evidence the owner *authored* or *signed into*.
Independence is judged by **source family**, so a git email and the SSH key
comment generated alongside it are one source, not two. Free promotion would turn
one email copied into four dotfiles into a fake `confirmed`; no promotion at all
would throw away the only signal a bare Linux box ever offers — three independent
weak reads that agree.

**Two confidences are tracked, and the verdict shows the weaker.** *Which
account* (election) and *what that person is called* (name) are separate facts
and diverge sharply: a locked Linux box is certain about the account and guessing
at the name. `This is <name>'s laptop.` asserts both, so it carries the weaker;
the evidence view splits them into two rows.

### Channel merging

Merge **only on exact equality after per-kind normalization**:

- **Email** — lowercase, plus-tags folded onto the base address. **Never** across
  differing domains, even with an identical local-part.
- **Phone** — digits-only comparison, E.164 where the machine's locale infers a
  country. A local and an international form of one number merge.
- **Handle** — same platform *and* same handle.

A merged channel renders as one line in the most human-readable form, with every
source stacked beneath it in the evidence view. **Near-misses never silently
fuse**: a wrong address costs the finder an email, but a bad merge that hides the
right address costs the owner their laptop.

### Channels are return routes

One ranked list. Each entry carries a `whose` when it is not the owner's own. The
top-ranked channel on a rich Mac is often a partner's phone number lifted from
the owner's own lock-screen message — not the owner's number, but the best way to
reach them, because they published it for exactly this.

**Non-owner accounts are routes too** — housemates, co-residents, an MDM org's IT
contact — ranked strictly below every owner channel and never above an
owner-authored one, labelled with whose they are and why. A co-resident who can
hand the laptop over in person beats an inbox nobody checks. This is account-
roster identity, already in scope; it is not a trawl through anyone's profile.

### When it's murky

**Two accounts with equal claim** — two admins, two humans, both recent, nothing
in the hostname. One layout plus a banner: *"Two accounts have an equal claim —
this may be a shared machine"*, the verdict hedges with its tier capped at
`likely`, both candidates appear in the roster with their election evidence, and
because channels already carry `whose`, **both people's channels sit in the one
ranked list**. No second layout, no second render path.

**Machine name contradicts the elected owner** — hostname says `johns-macbook`,
election says Ana Vasquez. **Election wins.** A hostname is a *historical*
artifact recording who set the machine up, which on a resold or handed-down
laptop is emphatically not the current owner; uid/RID and login history describe
who uses it *now*. Name confidence drops to at most `likely`, and the stale name
gets its own line with the honest reading: *"the machine is named for John — this
may be a hand-me-down."* This is **not** the shared-machine banner, which means
two *accounts* with equal claim; here there is only one.

## 6. Render the return card

Action first, evidence one flag away. The section order is **fixed**:

```
╭──────────────────────────────────────────────────────────────────────────╮
│ This is John Appleseed's laptop.                                         │
│ MacBook Pro 14" (M3, 2023) · “John's MacBook Pro” · confirmed            │
╰──────────────────────────────────────────────────────────────────────────╯

  ⚑ THE OWNER LEFT A NOTE ON THE LOCK SCREEN

      “Lost? Please call Marie on +1 415 555 0142, or email me — reward,
      no questions asked. — John”

  HOW TO REACH THEM — best first

  1. +1 415 555 0142 (Marie)
     phone · confirmed · the owner wrote it themselves, for exactly this
  2. j.appleseed@icloud.com
     email · confirmed · Apple ID signed in on this Mac

  WHAT I'D DO NEXT

  • Call +1 415 555 0142 — the owner asked you to.
  • If no answer, email j.appleseed@icloud.com.

┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈
  7 signals · 2 accounts · read-only, nothing was changed
  run with --why to see where every line above came from
```

1. **Verdict box** — a fixed two lines on every run: one sentence, then
   `model · host name · tier`.
2. **Banner**, flagged `⚑`, quoted verbatim in the owner's own words. Rendered
   only when the owner actually set one. It is the highest-value return-signal on
   every OS.
3. **How to reach them — best first.** Numbered, ranked by directness, each
   channel followed by a `kind · tier · why` line where *why* is plain language
   ("the owner wrote it themselves, for exactly this"), never a command.
4. **What I'd do next** — capped at three.
5. **Footer** — `N signals · N accounts · read-only, nothing was changed`, plus
   the `--why` hint.

**Tiers render as words**, inline on the channel line. The dotted form (`●●●○`)
appears only in the evidence view, where rows need to be scannable in a column.

### The reach line

Fires whenever **no channel reaches `strong`**. This is the enrichment predicate
from step 7 exactly — one predicate drives both, so the two can never disagree.

It sits in the `⚑` slot, directly beneath the verdict box, where the banner would
go. The two are near-mutually-exclusive in practice — a banner essentially always
*is* a channel — so the slot is free exactly when this line is needed. The verdict
box keeps its fixed two-line form; no new shape is introduced.

**Labour is split by line: the verdict line says _who_, the reach line says _why
there is no route_.**

Two axes — no channel vs weak-only, crossed with **shut out** (a read was denied)
vs **blank** (everything was readable and empty). **Shut-out wins any mix**: a
denied read means something might be there.

    ⚑  Nothing here reaches them — the owner's account is locked, so nothing of
       theirs was readable.

    ⚑  Nothing here reaches them — every field that would carry a name or a
       contact detail is empty.

    ⚑  Nothing here reliably reaches them — the owner's account is locked, so the
       channels below are guesses from what's visible outside it. Treat them as leads.

    ⚑  Nothing here reliably reaches them — the channels below are inferred from
       account and machine names, not stated by the owner. Treat them as leads.

The cause clause in the shut-out fills is a **slot**, filled by the actual denial:
`the owner's account is locked` / `the owner's files are readable only by them` /
the TCC prompt that was declined. `Treat them as leads` is not decoration — a
finder acting on a weak channel contacts a stranger about a laptop that isn't
theirs.

### The verdict line when nobody is named

A card that opens by reporting its own failure is hollow. Three forms:

    Nothing on this machine names a person.
    The only account on this machine is jtorres — nothing here gives a name.
    The owner account looks like jtorres — nothing here gives a name.

Naming the account has a **floor**. Below the stoplist — `user`, `admin`,
`administrator`, `owner`, `guest`, `test`, `pc`, `laptop`, anything equal to the
machine name, and the OEM/OOBE defaults — the verdict names nobody, because
`This is user's laptop.` reads as a bug, not a finding.

An account name is **never rendered possessively**: `The only account is
jtorres`, never `This is jtorres's laptop`. A login name is not a person's name,
and the possessive quietly asserts an identity the skill has not established.

With no name there is no tier, which frees the box's second line: **the serial
takes the slot**, exactly when the serial is the only handle.

### `WHAT'S OUT OF REACH` is promoted onto the card

On a **reach-line run only**, capped at three items, the full list still behind
`--why`. On a full card it is noise; on this card it *is* the content — the
difference between "this skill found nothing" and "this machine holds nothing
reachable".

The locked account the skill declined to enter appears here as a `✗` row naming
the path, and the reach line names the lock as the cause. There is **no separate
sentence of self-justification** anywhere on the card.

**On a blank machine the section does not render at all** — nothing was denied.
Its absence is itself the shut-out/blank tell.

### Next steps — capped at three, ordered by what gets the laptop home

On a normal card this is a coda; on a reach-line card it is the entire payload.
Membership is **conditional**: a step appears only when it is real.

**Find My / Activation Lock, when on, takes the top slot in either fork:**

    • Find My is on and this Mac is reporting its location — the owner may already
      be watching it move. Leave it powered on and on wifi, and don't wipe it.

It is the only signal on the card that reaches the owner without the finder doing
anything, and it reframes the result: "no channel readable from this machine" is
not "unreachable" when the machine is already reporting its location. **When off
it is absent** — `Find My is off` is an evidence row, not a step. A fact the
finder cannot act on does not belong in a list of actions. macOS and Windows
only; Linux has no equivalent.

**Shut-out fork** (someone is named, nothing reaches them):

    • A public lookup could take “jtorres” and “j-torres-x1” further — opt-in,
      nothing from the laptop is sent, and you'll see each query before it runs.
      Say the word.
    • Otherwise: the venue's lost property, or a police station. Ask and I'll
      write the full record to a file you can hand over with it.
    • Lenovo can match the serial to a registered owner.

**Blank fork** (nobody named):

    • The serial 9BQ4XK3 is the only handle on this machine: Dell can match it
      to a registered owner.
    • Lost property, or a police station — both will log the serial. Ask and
      I'll write the full record to a file you can hand over with it.
    • A public lookup has nothing to work from here — no name, no email, no handle.

The **closed-door line** is deliberate: it occupies the third slot when there is
no third real action, and it stops a finder wondering whether the opt-in step the
preamble promised applies to them.

**Online enrichment is a line, never a prompt.** Prominence comes from
**position** — first in the shut-out fork — not from asking. The verbatim consent
copy is the gate, and prompting here would mean two asks for one decision. A card
that ends by asking a question also converts a read into an interaction the finder
may not want.

**The handover file folds into the lost-property line**, not into its own slot.
It only means anything next to a physical handoff, and as its own step it
displaces an action that might reach the owner.

### Voice

The impersonal voice **stays with the preamble** and is not extended over the
card. What it was protecting is preserved differently: **the reach line states
the machine, not the effort.** `Nothing on this machine names a person.`, never
`I couldn't find anyone.` A result reported as a fact does not need to apologise;
a result reported as an effort always sounds like it is.

## 7. Offer enrichment, when the card is thin

Read `references/online.md`. Offer once, **only when both**: no channel reaches
`strong` (the reach-line predicate), and the sendable set is non-empty. Otherwise
do not mention it. The finder can request it at any time with `--online`.

## 8. The two named views

`--why` and `--online` are **named views**, not flags on a binary — there is no
entrypoint executable, only the gate script. The card prints the token literally,
because a printed token is a far better affordance than an invitation to phrase
something: the finder reads `--why` and knows exactly what to type.

Honour **both** the literal token and its plain-English equivalent: "why do you
think that", "show your working", "look them up online".

### `--why` — the evidence view

Every signal as `tier · field: value` with the exact command underneath, plus a
`✗` row for everything deliberately not read:

```
  ●●●●  if-found message: set — see above
        ↳ defaults read …com.apple.loginwindow LoginwindowText
  ●●●○  device name: John's MacBook Pro
        ↳ scutil --get ComputerName
  ●●●●  [japple] Apple ID: j.appleseed@icloud.com
        ↳ MobileMeAccounts AccountID
  ✗     Contacts “me” card — TCC denied — needs Full Disk Access; skipped
```

It also carries: the election reason as one line, the two confidences split into
two rows, every source stacked under a merged channel, **a `✗` row per whitelist
entry attempted and denied, naming the exact path**, and a standing category
block of what is never read at all — the preamble's "what it doesn't" promise,
made good. An audit that will not say what it declined to read is a weaker audit,
and the counter-argument that a named path signposts a snoop does not survive
contact with `ls`.

### The handover file — only when asked

Terminal output is the default; nothing is written to a laptop that isn't yours
unless the finder asks. When asked, the file is Markdown and always the **full**
evidence version, because its job is to be handed to lost property, a vendor, or
the police. Sections, in order:

1. Title, best guess + tier, host name, serial, OS.
2. **Gathered from** — the vantage — and **gathered at**.
3. A line confirming nothing was modified and no locked account, message, file,
   or password store was opened.
4. The banner, quoted, with the command that read it.
5. **Contact channels** — table of `# · kind · value · confidence · source`,
   with online rows marked as such and **the exact queries issued** beside them.
6. **Accounts** — table of `account · uid · admin · last seen · state · owner?`.
7. **Every signal** — table of `field · value · confidence · source`.
8. **Deliberately not read.**
9. **Suggested next steps.**

Rejected: always-write (leaves a trace, cuts against the read-only guardrail) and
an end-of-run prompt (an extra interaction for a rarely-wanted artifact).

---

# `references/online.md` — the opt-in enrichment branch

A **bounded, corroborated, one-pass** lookup. Off by default. Never runs before
the card has been printed, and never without an explicit yes in this run.

**The sendable set.** Exactly three kinds may leave this machine:

| kind | example | sourced from |
|---|---|---|
| full name | `John Appleseed` | login account real-name fields |
| email | `john@appleseed.dev` | git config, Apple ID, MSA/OneDrive |
| corroborated handle | `github.com/jappleseed` | git remote, gh or ssh config |

A **corroborated handle** is one backed by a service reference on the machine. A
bare local account username is *not* a handle and is never sent — on most sites
it is a different person.

**Never sent**, each for its own reason:

- **Anything from the banner.** It is frequently a *third party's* phone or email
  — a partner, a colleague — who is not the owner and had no part in this. It is
  already a direct channel, so a lookup adds nothing and risks profiling a
  bystander. This is the sharpest line here: every other exclusion protects the
  owner, this one protects someone who is not even a party to the situation.
- **Serial number, hostname, MDM org, work tenant.** These identify the device or
  the employer, not the owner. A serial in a search box is closer to a
  stolen-goods lookup than to a return.
- **Work UPN.** Leaks where they work to a third party; a lookup on their name
  reaches the same place without it.
- **Phone numbers**, from any source.

**Query construction rule.** A query's entire content must be **one allow-listed
identifier value, verbatim, one identifier per query**. Nothing else from the
machine may appear in it — not as extra terms, not as context, not as a filter.
`"John Appleseed" resume Acme 2019` is a query built from the laptop's contents
and is forbidden, even though no file was uploaded.

This is a **construction** rule, not a stated one, and deliberately so: a stated
rule gets talked around at 2am ("the hostname is basically an identifier"), while
a construction rule is checkable by reading the query string. Laptop contents
travel in the shape of a query as easily as in an upload.

**Sources.** Permitted: a web search on an allowed identifier, and fetching the
public profile pages those results directly name (`github.com/<handle>`, a
personal site). Forbidden **by name**, not merely unlisted: people-search
aggregators and data brokers (Pipl, Spokeo, WhitePages and equivalents), and any
paid or regulated lookup (reverse phone, address records). They aggregate what
the owner never published, which is the snooping this skill promises it is not
doing — and "public sources" is loose enough that an agent can argue a data
broker is one, so naming them removes the argument.

**Consent.** Print verbatim, with the real values and their sources filled in,
then wait. Do not re-tone or expand it.

    The local search is done. A public lookup might turn up another way to reach them.

    Sent, if you say yes:

      name    John Appleseed          (this machine's login account)
      email   john@appleseed.dev      (this machine's git config)
      handle  github.com/jappleseed   (this machine's git remote)

    Nothing else from this laptop goes out — no files, no messages, no serial number,
    and nothing from the lock-screen note. The lookup is a web search plus the public
    profile pages those identifiers point at, run from this machine.

    Go ahead? (Or name just the ones you're happy to send.)

The per-line source annotation is what makes a narrowing reply usable — a finder
cannot sensibly drop the email without knowing it came from git config rather
than the owner's mail app. Honour a narrowing answer ("just the github one") by
sending only what was named. On a decline, print `Fine — the card above is what
the machine itself says.` and stop. With no network, say so in one line and skip.

**Corroboration rule — the one test for keeping a result.** Add an online channel
only when the page it came from **independently carries a second identifier
already found on this machine** — the GitHub profile for that handle lists that
same git email, or that same full name. That is a real join. Everything else is a
name collision: **discard it silently**, do not mention it, do not rank it. When
nothing survives, print `The lookup added nothing; the card above stands.`

Corroboration-or-nothing, rather than presenting candidates or hedging with a
`weak` tier: handing a finder a lineup of strangers is not a dossier, and every
wrong entry is an uninvolved person served up to someone holding a laptop. The
join test degrades gracefully to zero results; a confidence hedge does not.

**Budget: one pass.** One query per allowed identifier, plus fetching the profile
pages those results directly name. Then stop. Do not follow what those pages turn
up into further queries — iteration is how a return-the-laptop lookup becomes an
investigation of a person. "Reasonable depth" is not reviewable; a fixed budget
is.

**Merging.** Online channels join the **single ranked list**, not a separate
section, and the card is reprinted whole rather than appended to. Each carries
`online` in its `kind · tier · why` line. **Cap: `likely`** — an online channel
rests on a cross-source identity join and can never be `confirmed` or `strong`.
The cap does the ranking work a hard "never outranks a local channel" rule would,
without pretending a strong online hit is worse than a weak local one. `--why`
records the exact query issued and every URL fetched.

---

# `references/<os>.md` — the gathering tables

Every reference file uses one schema:

| column | meaning |
|---|---|
| **signal** | what it yields |
| **fields** | the named fields extracted — never a file body |
| **command / path** | the exact read |
| **family** | `owner-authored` / `account-registration` / `app-config` / `inferred` |
| **tier** | ceiling for this signal; corroboration may promote by one |
| **vantage** | `OUT` = passes the gate cross-boundary · `IN` = in-session only |
| **grounding** | `verified-live` or `doc-grounded` |

**Grounding is not decoration.** A table that silently mixes "validated on a real
box" with "read in a vendor support doc" hands the builder a false floor. Only the
Linux rows were validated on real hardware (an Arch/Omarchy laptop, SDDM, no
`accountsservice`); macOS and Windows are documentation-grounded throughout. The
build session verifies what the machine it runs on allows and leaves the rest
marked.

Every `IN` row still passes the gate when the path lies outside the vantage
account. `OUT` means the gate *can* pass it — never that it is read unchecked.

## macOS

| signal | fields | command / path | family | tier | vantage | grounding |
|---|---|---|---|---|---|---|
| banner | the message text | `defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText` | owner-authored | confirmed | OUT | doc-grounded |
| account roster | short names, UIDs ≥ 501 | `dscl . -list /Users UniqueID` | inferred | confirmed | OUT | doc-grounded |
| real name | `RealName` | `dscl . -read /Users/<u> RealName` | inferred | strong | OUT | doc-grounded |
| admin membership | `GroupMembership` | `dscl . -read /Groups/admin GroupMembership` | inferred | strong | OUT | doc-grounded |
| device name | `ComputerName` | `scutil --get ComputerName` | inferred | strong | OUT | doc-grounded |
| serial + Find My | `Serial Number`, `Activation Lock Status` | `system_profiler SPHardwareDataType` | inferred | strong | OUT | doc-grounded |
| MDM enrollment | enrolled?, organization | `profiles status -type enrollment`, then `profiles show -type enrollment` | account-registration | strong | OUT | doc-grounded |
| login history | last login per account | `last`, `who` | inferred | strong | OUT | doc-grounded |
| Apple ID | `AccountID`, `AlternateEmailAddresses` | `defaults read ~/Library/Preferences/MobileMeAccounts` | account-registration | confirmed | IN | doc-grounded |
| git identity | `user.name`, `user.email` | `git config --file <path> --get user.name` | app-config | likely | OUT (whitelisted) | doc-grounded |
| SSH key comment | trailing comment field | `awk '{print $NF}' ~/.ssh/*.pub` | app-config | weak | IN | doc-grounded |
| Contacts "me" card | that record's name, email, phone | Contacts UI — prefer it over scripting the store | app-config | likely | IN | doc-grounded |

**macOS notes.** `profiles show` may require root on some versions — if the gate
fails, record a `✗` row rather than elevating. `MobileMeAccounts` keeps its legacy
name through Sequoia 15; do not assume it was renamed. There is no unprivileged
command mapping Find My to an identity: Activation Lock is a yes/no, and the
serial is provenance for Apple or the authorities, not a local name lookup. TCC
blocks Contacts unless the terminal holds Full Disk Access — detect the denial and
degrade. Phone numbers are the weakest field on this OS: the only clean sources
are the banner and the "me" card. Do not go digging in iMessage or FaceTime
configs; that crosses into message infrastructure.

**Why `~/.gitconfig` is the one cross-boundary read here.** Homes are `drwxr-xr-x`
so traversal passes the gate, while `~/.ssh` and `~/Library` are both `700`.
macOS is the only OS where the cross-boundary whitelist yields anything at all.

## Windows

| signal | fields | command / path | family | tier | vantage | grounding |
|---|---|---|---|---|---|---|
| banner | `legalnoticetext`, `legalnoticecaption` | `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System` | owner-authored | confirmed | OUT | doc-grounded |
| account roster | `Name`, `FullName`, `Enabled`, `LastLogon`, `PrincipalSource`, `SID` | `Get-LocalUser` | inferred | strong | OUT | doc-grounded |
| profiles on disk | `LocalPath`, `SID`, `LastUseTime` | `Get-CimInstance Win32_UserProfile`, non-`Special` | inferred | strong | OUT | doc-grounded |
| admin membership | member names | `Get-LocalGroupMember Administrators` | inferred | strong | OUT | doc-grounded |
| last signed in | `LastLoggedOnDisplayName`, `LastLoggedOnSAMUser` | `HKLM:\...\Authentication\LogonUI` | account-registration | strong | OUT | doc-grounded |
| work tenant | `TenantName`, join state | `dsregcmd /status` → Device State, Tenant Details | account-registration | strong | OUT | doc-grounded |
| work UPN | `User Identity` | `dsregcmd /status` → SSO State | account-registration | strong | IN | doc-grounded |
| device name | hostname | `(Get-CimInstance Win32_ComputerSystem).Name` | inferred | likely | OUT | doc-grounded |
| registered owner | `RegisteredOwner`, `RegisteredOrganization` | `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion` | inferred | weak | OUT | doc-grounded |
| Find My Device | `LocationSyncEnabled` | `HKLM:\SOFTWARE\Microsoft\MdmCommon\SettingValues` | inferred | likely | OUT | doc-grounded |
| OneDrive | `UserEmail`, `UserName` | `HKCU:\Software\Microsoft\OneDrive\Accounts\Personal` and `\Business1` | account-registration | strong | IN | doc-grounded |
| MSA email | the subkey name | `HKCU:\SOFTWARE\Microsoft\IdentityCRL\UserExtendedProperties` | account-registration | strong | IN | doc-grounded |
| git identity | `user.name`, `user.email` | `git config --file <path> --get ...` | app-config | likely | IN | doc-grounded |
| SSH key comment | trailing comment field | `%USERPROFILE%\.ssh\*.pub` | app-config | weak | IN | doc-grounded |
| mail clients | account addresses, display names | Outlook profile registry account names; Thunderbird `profiles.ini` | app-config | likely | IN | doc-grounded |

**Windows notes.** `RegisteredOwner` is unreliable on modern installs — OOBE for a
Microsoft account frequently leaves it blank or `Windows User`. Treat the
**RID-1001 profile** as the real OOBE-owner signal instead. `LastLoggedOnSAMUser`
often surfaces the MSA email as `MicrosoftAccount\<email>` **without touching any
hive** — always prefer it over the per-user sources. `dsregcmd`'s SSO section only
appears with a live user context and a recorded PRT attempt; a freshly-booted
locked machine shows device and tenant sections only. A hardened machine may
restrict WMI, and the `dontdisplaylastusername` policy blanks the on-screen
display though the registry value can persist.

**The cross-boundary whitelist yields nothing on Windows.** `C:\Users\<owner>\` is
ACL'd to the owner plus Administrators, so every path in it fails the gate, and
`HKEY_USERS\<other-SID>` fails unconditionally. This is by design — it is the
elevation ban doing its work.

## Linux

| signal | fields | command / path | family | tier | vantage | grounding |
|---|---|---|---|---|---|---|
| banner | `banner-message-text` | `gsettings get org.gnome.login-screen banner-message-text`, or `/etc/dconf/db/gdm.d/*` | owner-authored | confirmed | OUT | doc-grounded |
| console banners | the text | `/etc/issue`, `/etc/motd` | owner-authored | weak | OUT | verified-live |
| account roster + GECOS | username, uid, GECOS name and phones, home | `getent passwd`, keep uid 1000–60000 | inferred (GECOS phone: owner-authored) | strong | OUT | verified-live |
| admin group | member names | `getent group wheel`, `getent group sudo` | inferred | strong | OUT | verified-live |
| home directories | directory names | `ls -1 /home` | inferred | strong | OUT | verified-live |
| device name | hostname, `PRETTY_HOSTNAME` | `hostnamectl`, `/etc/machine-info` | inferred | likely | OUT | verified-live |
| hardware + asset tag | `sys_vendor`, `product_name`, `chassis_asset_tag`, `board_asset_tag` | `/sys/class/dmi/id/*` | asset tag: owner-authored | strong | OUT | verified-live |
| display name | `RealName`, `Email` | `/var/lib/AccountsService/users/<u>` | account-registration | strong | OUT | doc-grounded |
| DM last user | `[Last] User`, autologin `User` | `/var/lib/sddm/state.conf`, `/etc/sddm.conf.d/autologin.conf` | inferred | strong | OUT | verified-live |
| login history | last login per account | `last -n 20`, `lastlog2` | inferred | strong | OUT | verified-live |
| git identity | `user.name`, `user.email` | `git config --file <path> --get ...` | app-config | likely | IN | verified-live |
| GitHub CLI | the `user:` line | `~/.config/gh/hosts.yml` | app-config | likely | IN | verified-live |
| GPG | UID lines (`Real Name <email>`) | `gpg --list-secret-keys --keyid-format=long` | app-config | strong | IN | doc-grounded |
| online accounts | `Provider`, `Identity`, `PresentationIdentity` | `~/.config/goa-1.0/accounts.conf` | account-registration | strong | IN | doc-grounded |
| SSH key comment | trailing comment field | `~/.ssh/*.pub` | app-config | weak | IN | verified-live |
| mail clients | the `From:` addresses | Thunderbird `prefs.js` identity keys; `~/.msmtprc` `from`; aerc `accounts.conf` | app-config | likely | IN | doc-grounded |

**Linux notes.** There is **no universal "if found" field** — the GDM banner is
the closest first-class mechanism and exists only on the GNOME/GDM stack, so
expect to fall back to identity inference. `HOME_MODE` in `/etc/login.defs` is the
pivot: `0700` (Arch, Fedora, RHEL) and `0750` (recent Ubuntu) make every `IN` row
unreachable cross-boundary, while legacy `0755` Debian/Ubuntu exposes individual
world-readable files. **Let the gate decide, per file — never assume from the
distro.** GECOS is frequently empty on personal installs. `accountsservice` is
pulled in by the GNOME/GDM stack and is simply absent on a minimal
KDE/Sway/Hyprland box. `lastlog` was replaced by `lastlog2`; the legacy
`/var/log/lastlog` may be a zero-byte stub. Identify the active display manager
with `readlink /etc/systemd/system/display-manager.service`. On AD/LDAP-joined
machines `getent passwd` surfaces directory users with fuller names, and the
corporate return path may beat personal contact.

**DMI serials are root-only** (`product_serial`, `board_serial` are mode `0400`)
and therefore fail the gate. Record a `✗` row; never elevate. The serial is
valuable for proving ownership, but that is the owner's and the authorities' job.

**Browsers stay closed.** A signed-in Firefox or Chrome profile holds an account
email, but reading it means parsing a store adjacent to browsing data and saved
credentials. Prefer git, GPG, and GOA.

## Unknown OS

A fixed floor of four rows. Nothing else, and no improvising equivalents.

| signal | fields | command / path | family | tier | vantage |
|---|---|---|---|---|---|
| device name | hostname | `hostname`, `uname -n` | inferred | likely | OUT |
| account roster | username, uid, GECOS, home | `getent passwd`, else `/etc/passwd`, uid ≥ 1000 | inferred | strong | OUT |
| admin group | member names | `getent group wheel`, `getent group sudo` | inferred | strong | OUT |
| git identity | `user.name`, `user.email` | `git config --file <path> --get ...` | app-config | likely | gate decides |

A hostname and a git email are often enough to get a laptop home, and the
reach-line card is already built for a machine that yields almost nothing.

---

# `tests/fixtures/` — the acceptance cases

Three fixture machines, carried over from the dossier prototype on branch
`prototype/dossier-format`. They are the build's acceptance cases: each must
render its card, its `--why` view, and its handover file.

| fixture | exercises |
|---|---|
| **mac-unlocked** | the rich path — banner present, a third party's phone ranked first, Apple ID `confirmed`, git identity `likely`, a TCC `✗` row, Find My on |
| **linux-locked** | locked-primary from a guest account — election certain, name a guess, the two confidences diverging, no channel, **shut-out** reach line, `WHAT'S OUT OF REACH` promoted |
| **barren-windows** | nobody named — the stoplist floor, the serial in the box's second line, **blank** reach line, `WHAT'S OUT OF REACH` absent, the blank next-steps fork |

The prototype's own `linux-locked` render **predates the reach-line decision** and
still carries the retired copy (`This is J. Torres (surname unconfirmed)'s
laptop.` and a possessive account name). The card spec above supersedes it; the
fixture's *data* is still good.

Retrieve the prototype with:

```
git show prototype/dossier-format:skills/whose-laptop-is-this/prototype-dossier-format.py > /tmp/dossier.py
python3 /tmp/dossier.py --all
```

---

# Build checklist

1. Write `SKILL.md` with the frontmatter above, carrying every verbatim block
   exactly: the preamble, the routing lines, the mid-run refusal, the announce
   line, the four reach-line fills, the three no-name verdict forms, and the
   next-step forks.
2. Write the four `references/<os>.md` files from the tables above, and
   `references/online.md` from the enrichment section.
3. Write `scripts/can-ordinary-read.sh` and `.ps1` to the gate contract. These are
   the only executables; there is no entrypoint binary.
4. Port the three fixtures into `tests/fixtures/` and render all three.
5. **Verify what the build machine allows**, and re-mark those rows
   `verified-live`. Leave the rest `doc-grounded` — do not upgrade a row you did
   not run.
6. Add the `README.md` entry under `## Skills`.

## Provenance

| ticket | what it locked |
|---|---|
| [macOS owner-identity & contact sources](https://github.com/pvinis/useful-ai/issues/10) | the macOS table |
| [Windows owner-identity & contact sources](https://github.com/pvinis/useful-ai/issues/11) | the Windows table |
| [Linux owner-identity & contact sources](https://github.com/pvinis/useful-ai/issues/12) | the Linux table |
| [Ethical preamble & intent confirmation copy](https://github.com/pvinis/useful-ai/issues/13) | the preamble, routing, refusal line, impersonal voice |
| [Owner-dossier output format](https://github.com/pvinis/useful-ai/issues/14) | the return card, tiers as words, `--why`, the handover file |
| [Online-enrichment opt-in step](https://github.com/pvinis/useful-ai/issues/15) | `references/online.md` entire |
| [Second-account reach into a locked owner's files](https://github.com/pvinis/useful-ai/issues/17) | the elevation ban, the gate, both whitelists, field-level extraction |
| [Collapse many signals into one owner identity](https://github.com/pvinis/useful-ai/issues/18) | the glossary, election, merge, tiers, return routes |
| [No-channel dossier: banner and next-steps copy](https://github.com/pvinis/useful-ai/issues/19) | the reach line, no-name verdicts, the stoplist, next-step forks |
| [Assemble the skill spec](https://github.com/pvinis/useful-ai/issues/16) | frontmatter, layout, the gate-script/table split, grounding marks, the unknown-OS floor, the named views |
