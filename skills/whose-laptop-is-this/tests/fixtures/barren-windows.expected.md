# `barren-windows` — expected render

Data: [`barren-windows.json`](barren-windows.json). Exercises the case where
nobody is named — the stoplist floor, the serial in the box's second line,
**blank** reach line, `WHAT'S OUT OF REACH` absent, the blank next-steps fork.

**Predicate check.** There are no channels at all, so *no channel reaches
`strong`* is true: **the reach line fires**. Nothing was denied, so
`WHAT'S OUT OF REACH` does **not** render — its absence is the tell that separates
this card from `linux-locked`.

---

## The card

```
╭──────────────────────────────────────────────────────────────────────────╮
│ Nothing on this machine names a person.                                  │
│ Dell Latitude 5440 · “DESKTOP-7K2F9Q1” · serial 9BQ4XK3                  │
╰──────────────────────────────────────────────────────────────────────────╯

  ⚑  Nothing here reaches them — every field that would carry a name or a
     contact detail is empty.

  WHAT I'D DO NEXT

  • The serial 9BQ4XK3 is the only handle on this machine: Dell can match it
    to a registered owner.
  • Lost property, or a police station — both will log the serial. Ask and
    I'll write the full record to a file you can hand over with it.
  • A public lookup has nothing to work from here — no name, no email, no handle.

┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈
  6 signals · 1 account · read-only, nothing was changed
  run with --why to see where every line above came from
```

**The verdict takes the first no-name form, not the second.** There *is* only one
account, so `The only account on this machine is user — nothing here gives a
name.` is grammatically available — but `user` is on the stoplist, and below the
floor the verdict names nobody at all. `The only account on this machine is user`
reads as a bug, exactly as `This is user's laptop.` would.

**The serial takes the box's second line.** No name means no tier, which frees
the slot precisely when the serial is the only handle left. It then does the
work again as the first next step.

**`DESKTOP-7K2F9Q1` is a `weak` signal, not a name.** It is the OOBE default and
matches the stoplist entry for machine-name-derived identity. It appears in the
box as the host name, because the box always carries the host name, and nowhere
else.

**No `WHAT'S OUT OF REACH`, and that is the point.** Every field was readable and
every field was empty. On `linux-locked` the same shape of card carries three `✗`
rows and a shut-out reach line; here the section's absence tells the finder that
nothing is being withheld — the machine simply holds nothing.

**No Find My step.** It is off, so it is an evidence row and not an action. A
fact the finder cannot act on does not belong in a list of actions.

### Why there is no enrichment line

The sendable set is empty. `user` is on the stoplist and is a bare local account
username besides, which `references/online.md` explicitly excludes;
`DESKTOP-7K2F9Q1` is a hostname, also excluded. With no full name, no email, and
no corroborated handle, step 7's second condition fails and the offer never
fires. The **closed-door line** says so in the third slot.

## `--why`

```
  ELECTED: user — sole human account (cascade step 1)

  CONFIDENCE
    which account        ●●●●  confirmed — it is the only human account
    what they're called  ○○○○  none — FullName is blank and the account name is
                                below the stoplist floor

  ●●●●  [user] Microsoft account: none — local account only
        ↳ Get-LocalUser → PrincipalSource: Local
  ●●●●  [user] OneDrive: not configured
        ↳ HKCU:\Software\Microsoft\OneDrive\Accounts
  ●●●●  work/school account: not joined to any tenant
        ↳ dsregcmd /status
  ●●●○  Find My Device: off
        ↳ HKLM:\…\MdmCommon\SettingValues → LocationSyncEnabled
  ●●●○  serial: 9BQ4XK3
        ↳ Get-CimInstance Win32_BIOS
  ●○○○  device name: DESKTOP-7K2F9Q1 — OOBE default, names nobody
        ↳ (Get-CimInstance Win32_ComputerSystem).Name
  ○○○○  if-found message: not set
        ↳ HKLM:\…\Policies\System → legalnoticetext
  ○○○○  registered owner: blank
        ↳ HKLM:\…\Windows NT\CurrentVersion → RegisteredOwner
  ○○○○  last signed-in user: blank — dontdisplaylastusername policy hides it
        ↳ HKLM:\…\Authentication\LogonUI

  CHANNELS, AS RANKED
    none

  ACCOUNTS
    user  RID 1001  admin  open  logged in now  ← owner, sole human account

  DENIED
    none — every whitelisted source on this machine was readable

  NEVER READ, ON ANY RUN
    messages · browsing history · documents · saved passwords · financial data
    keyrings and token stores · %USERPROFILE%\.ssh private keys · browser profiles
```

**The `DENIED: none` row is load-bearing.** It is what makes "blank" checkable
rather than inferred. A reader comparing this view with `linux-locked`'s four `✗`
rows can see the difference between a machine that held nothing and a machine
that would not open.

**`registered owner: blank` is the expected reading, not a failure.** OOBE for a
Microsoft account routinely leaves it blank or `Windows User`; the RID-1001
profile is the real OOBE-owner signal, and here it points at an account whose
name is on the stoplist.

## The handover file

Written only when asked, to the current directory. This is the fixture where the
handover file matters most — it is the only artifact the finder has.

```markdown
# Found laptop — owner record

**Best guess:** none. Nothing on this machine names a person.
**Election confidence:** confirmed — `user` is the only human account
**Host name:** DESKTOP-7K2F9Q1 (Windows OOBE default)
**Serial:** 9BQ4XK3
**OS:** Windows 11 23H2

**Gathered from:** the only account on the machine, signed in — in-session
**Gathered at:** <timestamp>

Nothing on this machine was modified. No locked account, message, file, or
password store was opened. Nothing was denied: every whitelisted source was
readable, and every one of them was empty.

## The owner's lock-screen note

None. `legalnoticetext` is not set.

## Contact channels

None. No online lookup was run — this machine offers no name, email, or
corroborated handle to look up.

## Accounts

| account | uid | admin | last seen | state | owner? |
|---|---|---|---|---|---|
| user | RID 1001 | yes | logged in now | open | yes — sole human account |

`user` is a default account name and establishes no identity.

## Every signal

| field | value | confidence | source |
|---|---|---|---|
| Microsoft account | none — local account only | confirmed | Get-LocalUser → PrincipalSource |
| OneDrive | not configured | confirmed | HKCU:\Software\Microsoft\OneDrive\Accounts |
| work/school account | not joined to any tenant | confirmed | dsregcmd /status |
| Find My Device | off | strong | HKLM:\…\MdmCommon\SettingValues |
| serial | 9BQ4XK3 | strong | Get-CimInstance Win32_BIOS |
| device name | DESKTOP-7K2F9Q1 — OOBE default | weak | Win32_ComputerSystem.Name |
| if-found message | not set | — | HKLM:\…\Policies\System |
| registered owner | blank | — | HKLM:\…\Windows NT\CurrentVersion |
| last signed-in user | blank — policy hides it | — | HKLM:\…\Authentication\LogonUI |

## Deliberately not read

- Nothing was denied on this machine.
- Never read on any run: messages, browsing history, documents, saved passwords,
  financial data, keyrings and token stores, `%USERPROFILE%\.ssh` private keys,
  browser profiles

## Suggested next steps

1. The serial 9BQ4XK3 is the only handle on this machine. Dell can match it to a
   registered owner.
2. Lost property, or a police station — both will log the serial. Hand this
   record over with it.
3. A public lookup has nothing to work from here — no name, no email, no handle.
```
