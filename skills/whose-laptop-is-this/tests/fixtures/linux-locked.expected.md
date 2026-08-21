# `linux-locked` — expected render

Data: [`linux-locked.json`](linux-locked.json). Exercises locked-primary from a
guest account — election certain, name a guess, the two confidences diverging, no
channel, **shut-out** reach line, `WHAT'S OUT OF REACH` promoted.

**Predicate check.** There are no channels at all, so *no channel reaches
`strong`* is true: **reach line fires, `WHAT'S OUT OF REACH` is promoted onto the
card.** The enrichment offer does *not* fire — see the note below the card.

**This render supersedes the prototype's.** The prototype predates the reach-line
decision and opened `This is J. Torres (surname unconfirmed)'s laptop.` — an
account name rendered possessively, which the card spec rules out. The fixture's
data is unchanged; only the render moved.

---

## The card

```
╭──────────────────────────────────────────────────────────────────────────╮
│ The owner account looks like jtorres — nothing here gives a name.        │
│ Lenovo ThinkPad X1 Carbon Gen 11 · “j-torres-x1” · serial unreadable     │
╰──────────────────────────────────────────────────────────────────────────╯

  ⚑  Nothing here reaches them — the owner's account is locked, so nothing of
     theirs was readable.

  WHAT'S OUT OF REACH

  ✗  /home/jtorres — mode 0700, no o+x for an ordinary principal. The git email,
     the gh handle and any mail account sit behind it.
  ✗  /sys/class/dmi/id/product_serial — mode 0400, root-only.
  ✗  /var/lib/sddm/state.conf — /var/lib/sddm is mode 0750, no o+x.

  WHAT I'D DO NEXT

  • The venue's lost property, or a police station. Ask and I'll write the full
    record to a file you can hand over with it.
  • Lenovo can match the serial to a registered owner.
  • A public lookup has nothing to work from here — no name, no email, no handle.

┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈
  5 signals · 2 accounts · read-only, nothing was changed
  run with --why to see where every line above came from
```

**The verdict names nobody, and does not name the account possessively.**
Election is `confirmed` — `jtorres` is uid 1000, the sole member of `wheel`, and
the machine name encodes the same string. The *name* is `weak`: `j-torres-x1` is a
hostname, GECOS is empty, and the only sources that carry a real name are behind
the lock. The verdict carries the weaker of the two, so it takes the third
no-name form.

**The serial takes the box's second line** — no name means no tier, freeing the
slot. Here the serial is itself unreadable, so the slot says so rather than going
blank: it is still the honest second line, and it tells the finder to flip the
laptop over, where the serial is printed.

**Two things the card deliberately does not do.** It does not apologise, and it
does not justify declining to enter the locked account anywhere in prose. The
`✗` row names the path and the reach line names the lock as the cause; between
them the finder can see exactly what happened.

### Why there is no enrichment line

The shut-out fork's first bullet is the opt-in lookup, and it is **suppressed
here because the sendable set is empty**. `references/online.md` permits exactly
three kinds out: a full name, an email, and a *corroborated* handle. This machine
offers none — `jtorres` is a bare local account username, which is explicitly not
a handle, and `j-torres-x1` is a hostname, which is explicitly never sent. Step 7
gates the offer on the sendable set being non-empty, so it does not fire.

The **closed-door line** takes the freed third slot, which is exactly what it is
for: the preamble promised the finder an opt-in lookup, and this tells them it
does not apply to them.

> **Spec conflict, flagged for the record.** The shut-out fork's illustrative
> copy in `DESIGN.md` reads *"A public lookup could take “jtorres” and
> “j-torres-x1” further"* — built from this fixture, but from the two values
> `references/online.md` forbids sending. This render follows the sendable-set
> rule, which is the normative one and the more strongly argued.

## `--why`

```
  ELECTED: jtorres — first-created + admin (cascade step 2), corroborated by the
           machine name

  CONFIDENCE
    which account        ●●●●  confirmed
    what they're called  ●○○○  weak — hostname only; GECOS empty, no readable
                                real-name source outside the locked account

  ●●●○  greeter last user: jtorres
        ↳ /etc/sddm.conf.d/autologin.conf → User
  ●●●○  admin group: jtorres is the only member of wheel
        ↳ getent group wheel
  ●●○○  hostname: j-torres-x1 — encodes the same name
        ↳ hostnamectl
  ●●●○  hardware: LENOVO ThinkPad X1 Carbon Gen 11
        ↳ /sys/class/dmi/id/sys_vendor, product_name
  ●●●●  [jtorres] home dir: /home/jtorres (mode 0700)
        ↳ ls -ld /home/*
  ○○○○  if-found message: none — no GDM banner, /etc/issue is the distro default
        ↳ gsettings get org.gnome.login-screen banner-message-text; /etc/issue
  ○○○○  asset tag: “NO Asset Tag” — unset
        ↳ /sys/class/dmi/id/chassis_asset_tag
  ✗     /home/jtorres/.gitconfig — denied: /home/jtorres is mode 700 — no o+x,
        an ordinary principal cannot traverse it
  ✗     /home/jtorres/.config/git/config — denied, same cause
  ✗     /sys/class/dmi/id/product_serial — denied: mode 400 — no o+r
  ✗     /var/lib/sddm/state.conf — denied: /var/lib/sddm is mode 750 — no o+x

  CHANNELS, AS RANKED
    none

  ACCOUNTS
    jtorres  uid 1000  admin  locked  today, 14:20        ← owner
    guest    uid 1001  —      open    logged in now (you) ← you are here

  NEVER READ, ON ANY RUN
    messages · browsing history · documents · saved passwords · financial data
    keyrings and token stores · ~/.ssh private keys · browser profiles
    the locked account itself — never entered, on any vantage
```

**Both cross-boundary whitelist entries were attempted and both are `✗` rows**,
each naming its exact path. That is the whole cross-boundary surface on Linux
with `HOME_MODE 0700`: two paths, both denied at the home directory itself. The
correct response is this card, not a search for something else to read.

## The handover file

Written only when asked, to the current directory, never into the owner's home.

```markdown
# Found laptop — owner record

**Best guess:** no name — the owner account looks like `jtorres`
**Election confidence:** confirmed · **Name confidence:** weak
**Host name:** j-torres-x1
**Serial:** unreadable from an ordinary account (/sys/class/dmi/id/product_serial
is mode 0400). It is printed on the underside of the chassis.
**OS:** Linux (Arch, SDDM greeter)

**Gathered from:** a second/guest account — cross-boundary. The owner's account is
locked and was never entered.
**Gathered at:** <timestamp>

Nothing on this machine was modified. No locked account, message, file, or
password store was opened.

## The owner's lock-screen note

None. There is no GDM banner and `/etc/issue` holds the distro default.

## Contact channels

None were readable. No online lookup was run — this machine offers no name,
email, or corroborated handle to look up.

## Accounts

| account | uid | admin | last seen | state | owner? |
|---|---|---|---|---|---|
| jtorres | 1000 | yes | today, 14:20 | locked | yes — first-created + admin, sole member of wheel |
| guest | 1001 | no | logged in now | open | no — the account this was gathered from |

## Every signal

| field | value | confidence | source |
|---|---|---|---|
| greeter last user | jtorres | strong | /etc/sddm.conf.d/autologin.conf → User |
| admin group | jtorres is the only member of wheel | strong | getent group wheel |
| hostname | j-torres-x1 — encodes the same name | likely | hostnamectl |
| hardware | LENOVO ThinkPad X1 Carbon Gen 11 | strong | /sys/class/dmi/id/sys_vendor, product_name |
| home dir | /home/jtorres (mode 0700) | confirmed | ls -ld /home/* |
| if-found message | none | — | gsettings …banner-message-text; /etc/issue |
| asset tag | unset | — | /sys/class/dmi/id/chassis_asset_tag |

## Deliberately not read

- `/home/jtorres/.gitconfig` — denied: mode 700 on the home, no o+x
- `/home/jtorres/.config/git/config` — denied, same cause
- `/sys/class/dmi/id/product_serial` — denied: mode 400, root-only
- `/var/lib/sddm/state.conf` — denied: /var/lib/sddm is mode 750, no o+x
- The locked account itself — never entered, on any vantage
- Never read on any run: messages, browsing history, documents, saved passwords,
  financial data, keyrings and token stores, `~/.ssh` private keys, browser
  profiles

## Suggested next steps

1. The venue's lost property, or a police station — hand this record over with it.
2. Lenovo can match the serial to a registered owner. The serial is on the
   underside of the chassis.
3. A public lookup has nothing to work from here — no name, no email, no handle.
```
