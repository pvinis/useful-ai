# `mac-unlocked` — expected render

Data: [`mac-unlocked.json`](mac-unlocked.json). Exercises the rich path — banner
present, a third party's phone ranked first, Apple ID `confirmed`, git identity
`likely`, a TCC `✗` row, Find My on.

**Predicate check.** Two channels reach `confirmed`, so *no channel reaches
`strong`* is false: **no reach line, no promoted `WHAT'S OUT OF REACH`, no
enrichment offer.** One predicate, three consequences.

---

## The card

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
  3. john@appleseed.dev
     email · likely · commits under it — monitored, but maybe not urgently
  4. github.com/jappleseed
     handle · weak · public profile, slow channel

  WHAT I'D DO NEXT

  • Call +1 415 555 0142 — the owner asked you to.
  • If no answer, email j.appleseed@icloud.com.
  • Find My is on and this Mac is reporting its location — the owner may already
    be watching it move. Leave it powered on and on wifi, and don't wipe it.

┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈
  7 signals · 2 accounts · read-only, nothing was changed
  run with --why to see where every line above came from
```

**Marie's number ranks first and is not the owner's.** It carries its `whose`, and
its *why* says why it outranks the owner's own Apple ID: the owner published it
for exactly this situation. This is the return-route rule doing its job.

**Find My sits third, not first.** The top-slot rule is written for the two
reach-line forks, where it reframes a card that otherwise reaches nobody. On a
card with two `confirmed` channels, "ordered by what gets the laptop home" puts
the number the owner asked you to call above a fact the finder mostly acts on by
doing nothing.

## `--why`

```
  ELECTED: japple — first-created + admin (cascade step 2)

  CONFIDENCE
    which account  ●●●●  confirmed
    what they're called  ●●●●  confirmed

  ●●●●  if-found message: set — see above
        ↳ defaults read …com.apple.loginwindow LoginwindowText
  ●●●○  device name: John's MacBook Pro
        ↳ scutil --get ComputerName
  ●●●○  serial: C02XL0THJGH5
        ↳ system_profiler SPHardwareDataType
  ●●●○  Activation Lock: Enabled — Find My is on
        ↳ system_profiler SPHardwareDataType
  ●●●○  MDM enrollment: none — personally owned
        ↳ profiles status -type enrollment
  ●●●●  [japple] Apple ID: j.appleseed@icloud.com
        ↳ MobileMeAccounts AccountID
  ●●○○  [japple] git identity: John Appleseed <john@appleseed.dev>
        ↳ git config --get user.name/.email
  ✗     Contacts “me” card — TCC denied — needs Full Disk Access; skipped

  CHANNELS, AS RANKED
    1  ●●●●  phone   +1 415 555 0142 (Marie)   ← lock-screen if-found message
    2  ●●●●  email   j.appleseed@icloud.com    ← MobileMeAccounts AccountID
    3  ●●○○  email   john@appleseed.dev        ← git config --get user.email
    4  ●○○○  handle  github.com/jappleseed     ← ~/.ssh/id_ed25519.pub comment

  ACCOUNTS
    japple  uid 501  admin  open    logged in now   ← owner
    sam     uid 502  —      locked  3 months ago

  NEVER READ, ON ANY RUN
    messages · browsing history · documents · saved passwords · financial data
    keyrings and token stores · ~/.ssh private keys · browser profiles
    sam's home — not a candidate under the first-pass heuristic
```

**`john@appleseed.dev` and `github.com/jappleseed` are one source, not two.** Both
are `app-config`; the SSH key comment was generated alongside the git identity.
Neither promotes the other.

## The handover file

Written only when asked, to the current directory, never into the owner's home.

```markdown
# Found laptop — owner record

**Best guess:** John Appleseed — confirmed
**Host name:** John's MacBook Pro
**Serial:** C02XL0THJGH5
**OS:** macOS 15.3 (Sequoia)

**Gathered from:** inside the owner's own unlocked account (japple) — in-session
**Gathered at:** <timestamp>

Nothing on this machine was modified. No locked account, message, file, or
password store was opened.

## The owner's lock-screen note

> “Lost? Please call Marie on +1 415 555 0142, or email me — reward, no
> questions asked. — John”

Read with `defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText`.

## Contact channels

| # | kind | value | confidence | source |
|---|---|---|---|---|
| 1 | phone | +1 415 555 0142 (Marie) | confirmed | lock-screen if-found message |
| 2 | email | j.appleseed@icloud.com | confirmed | MobileMeAccounts AccountID |
| 3 | email | john@appleseed.dev | likely | git config --get user.email |
| 4 | handle | github.com/jappleseed | weak | ~/.ssh/id_ed25519.pub comment |

No online lookup was run.

## Accounts

| account | uid | admin | last seen | state | owner? |
|---|---|---|---|---|---|
| japple | 501 | yes | logged in now | open | yes — first-created + admin |
| sam | 502 | no | 3 months ago | locked | no |

## Every signal

| field | value | confidence | source |
|---|---|---|---|
| if-found message | set — see above | confirmed | defaults read …LoginwindowText |
| device name | John's MacBook Pro | strong | scutil --get ComputerName |
| serial | C02XL0THJGH5 | strong | system_profiler SPHardwareDataType |
| Activation Lock | Enabled — Find My is on | strong | system_profiler SPHardwareDataType |
| MDM enrollment | none — personally owned | strong | profiles status -type enrollment |
| Apple ID | j.appleseed@icloud.com | confirmed | MobileMeAccounts AccountID |
| git identity | John Appleseed <john@appleseed.dev> | likely | git config --get user.name/.email |

## Deliberately not read

- Contacts “me” card — TCC denied — needs Full Disk Access; skipped
- sam's home — not a candidate under the first-pass owner heuristic
- Never read on any run: messages, browsing history, documents, saved passwords,
  financial data, keyrings and token stores, `~/.ssh` private keys, browser
  profiles

## Suggested next steps

1. Call +1 415 555 0142 — the owner asked you to.
2. If no answer, email j.appleseed@icloud.com.
3. Find My is on and this Mac is reporting its location. Leave it powered on and
   on wifi, and don't wipe it.
```
