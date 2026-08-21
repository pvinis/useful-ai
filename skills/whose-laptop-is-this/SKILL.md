---
name: whose-laptop-is-this
description: Identify the owner of a found laptop and rank every read-only way to reach them, so the machine can be returned. Runs on the found machine itself and changes nothing. Use when someone has found a laptop or device that isn't theirs and wants to return it, asks whose laptop this is, is about to hand a machine to lost property or the police, or wants to know how to contact the owner of a device in front of them. The premise is always a device the user does not own.
---

# whose-laptop-is-this

Someone is sitting at a laptop they found. It is unlocked, or partly so. They
want to give it back. You are running **on that machine**, and what you hand
back is a **return card**: who the laptop belongs to, and every read-only way to
reach them, best first.

`DESIGN.md` holds the reasoning behind every decision here. Read it only if the
finder asks why the skill works the way it does.

## Rules that do not bend

This skill exists to return a device, not to snoop.

1. **In scope:** owner identity, contact channels, local account enumeration, and
   explicit return-signals — the owner's lock-screen if-found message, OS
   device-owner and registration fields, Find My / Activation Lock status.
2. **Out of scope, always:** message contents, browsing history, documents, saved
   passwords, financial data. Lock bypass. Password cracking.
3. **Escalation and elevation are both out of scope.** *Escalation* is obtaining
   privilege you were not granted. *Elevation* is asserting privilege you
   legitimately hold — `sudo`, an Administrator shell, `reg load` of another
   user's `NTUSER.DAT`. Neither is available to you here.
4. **The rule binds on the reach, not on the act.** Every read is gated by an
   explicit permission check against an **ordinary principal**, not by whether
   the read happens to succeed. Handed an already-root shell, you read exactly
   what you would read from a plain account. Where you detect you are elevated,
   say so once:

       running elevated; reads are still limited to what an ordinary account could see.

   The point of the rule: **admin rights change this skill's behaviour nowhere.**
5. **Reads extract named fields, never file bodies.** `git config --file <path>
   --get user.email`, never `cat`. A `.gitconfig` carries private remote URLs,
   `insteadOf` rewrites holding tokens, and signing-key ids; none of that enters
   your context. Same for every source: `MobileMeAccounts` yields `AccountID`,
   not the whole plist. It also makes the evidence trail exact — the recorded
   command *is* the entirety of what was read.
6. **Nothing is written** to the machine unless the finder explicitly asks for
   the handover file.

## Vocabulary

Use these words in the output, not just here. They only do their job by
repetition.

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
- **Banner** — the *owner's* lock-screen if-found message. Never used for
  anything else.
- **Reach line** — the card's own empty-state element, in the `⚑` slot. Distinct
  from a banner.
- **Shut out / blank** — a read was denied, versus everything was readable and
  empty. They look identical and mean opposite things.

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
the premise rather than asking readiness, so a "no" carries information. The
impersonal voice is deliberate: it reads as policy rather than as a promise from
whoever is talking.

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

Detect first. The promise the preamble makes is OS-independent, and "before it
does anything" beats "before it does anything except…". Read **exactly one**:

| detected | read |
|---|---|
| macOS | `references/macos.md` |
| Windows | `references/windows.md` |
| Linux | `references/linux.md` |
| anything else | `references/unknown-os.md` |

The unknown-OS path is a **fixed POSIX floor** — hostname, account roster, admin
group, git identity — and nothing more. It fires on BSD, a ChromeOS shell, a
stripped container. The card renders normally and the reach line carries the
thinness. Do not go looking for "equivalents" of the known signals: that is a
runtime-extensible whitelist wearing a different hat, and this skill does not
have one.

## 3. Establish the vantage

Two vantages, and they gate different reads:

- **In-session** — the finder is inside the owner's own unlocked account. The
  machine was handed over open.
- **Cross-boundary** — the finder is at the login screen or in a second/guest
  account, and the owner's account is locked. **Never enter the locked account.**

Record which one applies. It goes in the handover file's header and it drives the
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

```sh
scripts/can-ordinary-read.sh /Users/john/.gitconfig     # macOS, Linux, anything POSIX
pwsh scripts/can-ordinary-read.ps1 'C:\Users\john\.gitconfig'
```

Exit `0` pass · `1` denied · `2` usage · `3` path absent or not evaluable. The
one-line reason on stdout is what fills the `✗` row in the evidence view — quote
it rather than paraphrasing.

**Never implement "attempt the read and see".** It fails the elevated case, which
is the only case that matters, and it hard-codes permission assumptions that vary
by OS version. On POSIX that specifically means never `test -r`: it reports the
*effective* answer and silently passes for root.

### The two whitelists

Both are **fixed and exhaustive**. Neither may be read as a category
("identity-shaped files") that you can extend at runtime. Every entry names the
field extracted, not just the path.

**Cross-boundary whitelist — git identity, and nothing else:**

| path | fields |
|---|---|
| `<home>/.gitconfig` | `user.name`, `user.email` |
| `<home>/.config/git/config` | `user.name`, `user.email` |

No globbing. No directory trawling. Nothing off-list even when readable.

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
anything rule 2 excludes.

### Which homes get touched

Only accounts surviving a **first-pass** owner heuristic — admin group, plus
first-created (uid 501 / uid 1000 / RID 1001), plus most-recent use — at most the
top one or two. Never every human home on the machine.

The heuristic and the read are **mutually recursive by design**: the git name is
often what settles the ranking, so a strict "best candidate only" rule would be
circular. Hence two passes — rank on OS-given signals, read the top one or two,
then run the full election in step 5 with those reads in hand.

### Announce the crossing

No second confirmation prompt: the intent gate covers the run, and a prompt whose
only sensible answer is "yes" trains click-through. Instead announce at the
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
reason as one inspectable line (`elected: first-created + admin`). Exclude system
and service accounts first — `nologin` shells, uids below the human floor,
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
comment generated alongside it are one source, not two.

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
hand the laptop over in person beats an inbox nobody checks.

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
and the possessive quietly asserts an identity you have not established.

With no name there is no tier, which frees the box's second line: **the serial
takes the slot**, exactly when the serial is the only handle.

### `WHAT'S OUT OF REACH` is promoted onto the card

On a **reach-line run only**, capped at three items, the full list still behind
`--why`. On a full card it is noise; on this card it *is* the content — the
difference between "this skill found nothing" and "this machine holds nothing
reachable".

The locked account you declined to enter appears here as a `✗` row naming the
path, and the reach line names the lock as the cause. There is **no separate
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
copy in `references/online.md` is the gate, and prompting here would mean two
asks for one decision.

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

Dots map `●●●● confirmed · ●●●○ strong · ●●○○ likely · ●○○○ weak · ○○○○ none`.

It also carries: the election reason as one line, the two confidences split into
two rows, every source stacked under a merged channel, **a `✗` row per whitelist
entry attempted and denied, naming the exact path**, and a standing category
block of what is never read at all — the preamble's "what it doesn't" promise,
made good. An audit that will not say what it declined to read is a weaker audit.

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

Write it where the finder asks, and say the path back to them. Default to the
current directory, never into the owner's home.

## Things that will bite

- **A denied read and an empty field look identical and mean opposite things.**
  Carry the distinction from the gate's exit code all the way to the reach line:
  `1` is shut out, a successful read of nothing is blank. Never infer it from an
  empty string.
- **The gate's answer is not your answer.** If you are root, everything is
  readable and the gate still says no. That gap is the feature. Do not
  "double-check" a denial by reading the file.
- **`test -r` and `Test-Path` are not gates.** Both report the effective answer.
  The gate script exists precisely because the obvious one-liner is wrong.
- **The reach line and the enrichment offer share one predicate** — no channel
  reaches `strong`. If you compute it twice you will eventually disagree with
  yourself on a card that shows a reach line and no lookup line, or worse, the
  reverse.
- **The banner is a channel, not a search term.** It routinely names a third
  party who is not the owner and had no part in this. It ranks first on the card
  and is never sent anywhere — see `references/online.md`.
- **A hostname is history, not ownership.** `johns-macbook` on a hand-me-down
  says who set it up years ago. Election wins; the hostname gets its own hedged
  line.
- **Grounding marks in the reference tables are load-bearing.** `doc-grounded`
  means nobody has run that command on real hardware. When one fails, record a
  `✗` row and move on — do not go hunting for a substitute command, and do not
  quietly upgrade the row.
