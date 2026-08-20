# macOS owner-identity & contact sources (read-only)

Research for ticket `01-macos-owner-sources` of the `whose-laptop-is-this` map.
Goal: authoritative, **read-only** local sources of a found Mac's owner identity
and contact details, for building a "return this laptop" owner dossier.

**Guardrail respected.** Only identity + contact info + account enumeration +
explicit return-signals are cataloged. No message contents, browsing history,
document bodies, saved passwords, or financial data. No lock bypass / privilege
escalation. Every command below is read-only.

**Testing caveat.** No macOS machine was available to run these. Every command is
grounded in Apple documentation, man-page mirrors, or MDM-vendor references
(cited). Version- or permission-dependent behavior is flagged per row and in
"Gaps & caveats".

Reliability tiers follow the map: `confirmed` > `strong` > `likely` > `weak`.

---

## Quick-reference table

`needs-unlock` = must be run inside the owner's own unlocked account (data lives
under their `~/Library`, mode 700). `no` = readable from any local account
(including a second/guest account) or before any login.

| # | Source / command | Yields | Reliability | Needs owner unlock? |
|---|---|---|---|---|
| 1 | `dscl . -list /Users` | short usernames of every account (incl. system) | confirmed | no |
| 2 | `dscl . -list /Users UniqueID` | UID per account (filter UID ≥ 501 = human) | confirmed | no |
| 3 | `dscl . -read /Users/<u> RealName` | full name ("John Appleseed") | strong | no |
| 4 | `dscl . -read /Groups/admin GroupMembership` | which accounts are admins (owner heuristic) | strong | no |
| 5 | `scutil --get ComputerName` | device name, often "John's MacBook Pro" → first name | strong | no |
| 6 | `scutil --get LocalHostName` / `HostName` | hostname variant, may echo name | likely | no |
| 7 | `defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText` | owner-authored "if found" message (name/phone/email/reward) | confirmed (when set) | no |
| 8 | `defaults read ~/Library/Preferences/MobileMeAccounts` | iCloud/Apple ID email (`AccountID`), alt emails, display name | confirmed | **yes** |
| 9 | `system_profiler SPHardwareDataType` | serial number + **Activation Lock Status** (Find My proxy) | strong | no |
| 10 | `profiles status -type enrollment` | MDM-managed? DEP? (→ org owns device) | strong | no |
| 11 | `profiles show -type enrollment` | enrolling **organization** name/details | likely | maybe root — see notes |
| 12 | `git config --get user.email` / `... user.name` | email + name (dev machines) | likely | yes (own shell) / see #7-outside |
| 13 | `cat ~/.ssh/*.pub` | key comment, often `user@host` or email | weak | yes (`~/.ssh` is 700) |
| 14 | Contacts "me" card (`~/Library/Application Support/AddressBook`) | owner's own name/email/phone | likely | **yes** + TCC (Full Disk Access) |
| 15 | `id -F` / `finger <user>` | full name of a user | strong | no (for any named user) |
| 16 | `last <user>` / `who` / `w` | login history / currently-logged-in usernames | strong | no |
| 17 | `ls -la /Users` | home-dir names (= usernames) of all accounts | confirmed | no |

---

## Details by source

### Account identity (Directory Service — `dscl`)

`dscl` is the Directory Service command-line utility; the local node is `.`.
Read subcommands are `-list`, `-read`, `-readall`, `-search`; reading the local
node does **not** require root for public attributes like usernames and RealName.
([ss64 dscl](https://ss64.com/mac/dscl.html))

- **Enumerate accounts:** `dscl . -list /Users` prints every record under
  `/Users`, including system daemons (`_spotlight`, `root`, `daemon`, …). Filter
  to humans with `dscl . -list /Users UniqueID` and keep UID ≥ 501 (the first
  interactive account is 501). ([ss64 dscl](https://ss64.com/mac/dscl.html))
- **Full name:** `dscl . -read /Users/<user> RealName` (or `dscl . -read
  /Users/<user>` for all public attributes). RealName is the "Full Name" field
  shown in Users & Groups. May be blank or a nickname → fall back to
  ComputerName. ([ss64 dscl](https://ss64.com/mac/dscl.html))
- **Owner heuristic — admin membership:** `dscl . -read /Groups/admin
  GroupMembership` lists admin short-names. The **owner** is usually: admin +
  UID 501 (first-created) + most recent/most frequent login + first name matching
  ComputerName. Use these to rank which account is the owner's.
- **Search:** `dscl . -search /Users RealName "Smith"` finds records by name.
- Reliability: `confirmed` for enumeration; `strong` for the name (blank/nickname
  is the failure mode). All readable from any account (local node is shared).

> The canonical account store `/var/db/dslocal/nodes/Default/users/*.plist` is
> `root:wheel`, mode 700 — **root only**. Use `dscl`, which reads it via the
> directory service, not the raw plists. (Raw-plist reading is out of reach
> without privilege escalation and is not needed.)

### Device name (`scutil`)

`scutil --get ComputerName` / `--get LocalHostName` / `--get HostName`. `--get`
does **not** require root (only `--set` does). ComputerName is the user-friendly
name shown in Finder/Sharing and very often contains the owner's first name
("John's MacBook Pro"). ([ss64 scutil](https://ss64.com/mac/scutil.html))
Reliability `strong` for a first-name hint; can be a generic/renamed value.

### Lock-screen "if found" message (best explicit return-signal)

- **Read:** `defaults read /Library/Preferences/com.apple.loginwindow
  LoginwindowText`
- Set by the owner via **System Settings → Lock Screen → "Show message when
  locked" → Set** (older: Security & Privacy → General → "Show a message when the
  screen is locked"). Apple documents this as intended for **"contact details for
  a lost computer."** ([Apple: Display a message in the Mac login
  window](https://support.apple.com/guide/mac-help/mh35890/mac))
- The file `/Library/Preferences/com.apple.loginwindow.plist` is `root`-owned but
  world-readable (mode 644), so any local account can read it, and the message is
  rendered on the login/lock screen itself **before** any login. ([osxdaily lock
  message](https://osxdaily.com/2011/07/28/login-and-lock-screen-message-in-mac-os-x-lion/))
- Yields whatever the owner wrote: name, phone, email, reward text. When present
  this is the **highest-value, most authoritative** return-signal — the owner
  literally left return instructions. Reliability `confirmed` when set; often
  simply unset (then the key is absent).

### Apple ID / iCloud email + phone (`MobileMeAccounts`)

- **Read:** `defaults read ~/Library/Preferences/MobileMeAccounts` (Apple still
  names the domain "MobileMe"; confirmed working through macOS Sequoia 15).
  ([Jamf: iCloud account
  info](https://community.jamf.com/general-discussions-2/find-out-who-is-signed-in-to-icloud-and-with-what-account-they-are-signed-in-with-22550))
- Yields: `AccountID` = the iCloud/Apple ID **email**; plus display name and
  `AlternateEmailAddresses`. To isolate the email:
  `defaults read ~/Library/Preferences/MobileMeAccounts | grep AccountID`.
- Reliability `confirmed` for the signed-in Apple ID email. **Needs the owner's
  account unlocked** — the plist is under their `~/Library` (mode 700), not
  readable from another account.
- **Phone number** is *not* reliably in this plist; the Apple ID phone is best
  obtained from the owner-authored LoginwindowText (#7) or the Contacts "me" card
  (#14). iMessage/FaceTime registered phone numbers exist but live in messaging
  configs — treated as out of guardrail (message infrastructure) and skipped.

### Find My / Activation Lock (ownership proxy)

- **Read:** `system_profiler SPHardwareDataType` — on Apple-silicon and T2 Macs
  the output includes **`Activation Lock Status: Enabled/Disabled`** alongside the
  **Serial Number**. ([Jamf: Activation Lock
  status](https://community.jamf.com/t5/jamf-pro/activation-lock-status/td-p/217000))
- Activation Lock = Enabled confirms Find My is on and the Mac is tied to an
  Apple ID, but it does **not** reveal *whose* Apple ID. Serial number is not a
  local identity source, but is the key Apple/authorities use to reach the
  registered owner — capture it for the dossier's provenance trail.
- Reliability `strong`; runs from any account, no root. There is no unprivileged
  local command that maps Find My → owner identity (the FindMyMac token is
  root-only nvram and out of scope).

### MDM / enrollment owner (managed Macs)

- **Status:** `profiles status -type enrollment` (macOS 10.13.4+) reports whether
  the Mac is MDM-enrolled and DEP/Automated-Enrollment. Runs as a normal user.
  ([Der Flounder: detecting UAMDM](https://derflounder.wordpress.com/2018/03/30/detecting-user-approved-mdm-using-the-profiles-command-line-tool-on-macos-10-13-4/))
- **Details / org:** `profiles show -type enrollment` (also GUI: System Settings →
  General → Device Management) surfaces the **enrolling organization**, which for
  a company/school-owned laptop is the fastest return path (contact their IT).
  Reliability `likely`; `profiles show` may require root on some versions — verify
  on device. ([Apple: enrollment profile
  glossary](https://support.apple.com/guide/mac-help/aside/glos4dbccdad/mac))

### Developer-identity fallbacks (git / ssh)

- `git config --get user.email` and `git config --get user.name` read
  `~/.gitconfig` (or `~/.config/git/config`). Common on developer machines; may be
  a personal *or* work email. Reliability `likely`.
- `~/.ssh/*.pub` key comments frequently end in `user@host` or an email; `~/.ssh/
  config` may hold `User`/`HostName`. Reliability `weak`, and `~/.ssh` is mode 700
  so it is only reachable inside the owner's own account.

### Contacts "me" card ("My Card")

- The owner's own contact card is legitimate identity/contact data. Contacts data
  lives at `~/Library/Application Support/AddressBook/` in an opaque SQLite
  `AddressBook-vXX.abcddb`; the "me" record is one row. ([Apple Community: Contacts
  data location](https://discussions.apple.com/thread/7753178))
- **Two hard gates:** (1) it is under `~/Library` (mode 700) → needs the owner's
  account unlocked; (2) it is TCC-protected — a terminal/tool reading it needs
  **Full Disk Access**, or the read is silently blocked. The rest of the address
  book is *other people's* contacts and is **out of scope** — extract only the
  "me" record, not the whole DB. Reliability `likely`, gated. Prefer the built-in
  Contacts UI ("My Card") for a human finder over scripting the DB.

### Small confirmations of the current user

- `id -F` prints the RealName of the current user; `finger <user>` (if enabled)
  and `id -P` show name fields. `whoami` / `id` give the short name.
- `last <user>`, `who`, `w` show login history and currently-logged-in users
  (usernames + times) — helps rank which account is actively the owner's.
  Reliability `strong`; all runnable from any account.

---

## From outside a locked account (LOCKED-PRIMARY / ACCESSIBLE-SECONDARY, Q9)

Scenario: the owner's account is **locked**, but you are at the login screen or
inside a **second/guest account**. Never enter the locked account. What owner
signal survives:

**At the login/lock screen (no login at all):**
- The **lock-screen message** (#7) renders here — the owner's own return note.
  ([Apple](https://support.apple.com/guide/mac-help/mh35890/mac))
- If "Display login window as: **List of users**" is set, each account's **Full
  Name** is shown under its icon (hidden/system accounts excluded). This is the
  RealName from the directory. ([Apple Community](https://discussions.apple.com/thread/2638668))

**From an open second/guest account (any local account):**
- **Return message:** `defaults read /Library/Preferences/com.apple.loginwindow
  LoginwindowText` — world-readable (644). *Top signal.*
- **Device name:** `scutil --get ComputerName` (+ `LocalHostName`) — usually the
  owner's first name.
- **All accounts + full names:** `dscl . -list /Users` then `dscl . -read
  /Users/<u> RealName` for each human (UID ≥ 501); `dscl . -read /Groups/admin
  GroupMembership` to spot the owner's admin account. The local directory node is
  shared, so this works from any account.
- **Home-dir names:** `ls -la /Users` lists every account's home directory
  (= short usernames). Home dirs are mode 755 (world-listable/traversable so the
  Public folder works). ([Apple Community: home perms](https://discussions.apple.com/thread/1396411))
- **Device serial + Activation Lock:** `system_profiler SPHardwareDataType`.
- **MDM org (managed Macs):** `profiles status -type enrollment` (+ `show`).
- **git identity of the locked user — often works cross-account:** because each
  home dir is 755 and `~/.gitconfig` sits *directly* in the home dir with default
  mode 644, `cat /Users/<owner>/.gitconfig` (or `git config -f
  /Users/<owner>/.gitconfig --get user.email`) can expose the owner's git
  name/email from a *second* account. Reliability `likely` — fails if the user
  tightened home-dir perms or stores git config under `~/.config` (inside
  `~/Library`-adjacent 700 paths it would be blocked). Try it; don't rely on it.

**What is NOT readable from outside the locked account** (all under `~/Library`,
mode 700, or TCC-gated): `MobileMeAccounts` (Apple ID email), the Contacts DB /
"me" card, `~/.ssh` keys, and — by guardrail — all mail/messages/browser data.

**Guest-account note:** the macOS Guest account is sandboxed and its home is
wiped at logout, but it can still run `dscl`, `scutil`, `system_profiler`,
`profiles`, read `/Library/Preferences`, and traverse `/Users`. A standard second
account is less restricted (e.g. more likely to read another home dir's world-
readable files). Assume the guest can do everything in the "any local account"
list above.

---

## Owner-ranking heuristic (how the dossier should pick the owner account)

Rank accounts (UID ≥ 501, non-hidden) by, in order: admin membership
(`/Groups/admin`), first-created (UID 501), recent/frequent login (`last`), and
first name matching ComputerName. The top account's RealName + its
MobileMeAccounts AppleID (if unlockable) is the primary identity; LoginwindowText
overrides everything when it names a person/contact explicitly.

## Gaps & caveats

- **Untested.** Commands are documentation-grounded, not run on a Mac. Flag
  `profiles show` root-need, exact `MobileMeAccounts` keys, and login-window
  behavior for on-device verification.
- **Phone numbers are the weakest field.** No clean unprivileged source except
  the owner-authored LoginwindowText or the Contacts "me" card (gated). Do not go
  digging in iMessage/FaceTime configs — that crosses into message infrastructure.
- **TCC / Full Disk Access.** Even *inside* the owner's unlocked account, a
  terminal reading Contacts (and some other user data) is blocked unless the tool
  has Full Disk Access. `dscl`, `scutil`, `defaults` on `/Library`,
  `system_profiler`, `profiles`, and `git` are **not** TCC-gated. The skill should
  detect a TCC denial and degrade gracefully.
- **Find My gives ownership, not identity.** Activation Lock status is a yes/no;
  serial number is provenance for Apple/authorities, not a local name lookup.
- **Managed Macs are a shortcut.** If `profiles status` shows enrollment, the
  enrolling org (from `profiles show`) is often the best return route regardless
  of the local account state.
- **RealName / ComputerName can be blank, nicknamed, or generic** — always cross-
  check multiple sources before asserting an identity; rank with the map's
  confidence tiers.
- **"MobileMe" legacy naming** persists (the plist is still `MobileMeAccounts`
  through Sequoia 15) — don't assume the key was renamed.
