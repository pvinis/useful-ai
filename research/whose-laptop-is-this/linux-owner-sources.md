# Linux owner-identity & contact sources (read-only)

Research for ticket `03-linux-owner-sources` of the `whose-laptop-is-this` skill.
Catalogs the authoritative, **read-only** local sources of a found Linux laptop's
owner identity and contact details, for building an owner dossier.

**Guardrail (binding).** Everything here stays within: identity + contact info +
account enumeration + explicit return-signals. **Excluded:** message contents,
browsing history, documents, saved passwords, financial data; and any lock
bypass / privilege escalation / password cracking. All commands below are
read-only. Sources that would require root you do not already have are marked and
must not be reached by escalation.

**Vantage column legend**
- **OUTSIDE** — world-readable; obtainable from *any* logged-in account (e.g. a
  guest/second account) with no root and without entering the owner's account.
- **OWNER** — lives under the owner's `$HOME` (or needs their session); readable
  only when the owner's account is unlocked/entered (or with root).
- **ROOT** — needs root you already legitimately hold (e.g. a secondary *admin*
  account). Never obtain by escalation.

Validated live on the host machine where noted (Arch/Omarchy, Hyprland, **SDDM**
display manager, no GNOME/KDE, `accountsservice` **not** installed). "Path present"
= confirmed to exist and yield the described shape on that box; "documented" =
confirmed against primary docs (source not installed locally).

---

## A. Account roster & host metadata — mostly OUTSIDE

| # | Source | Read-only command / path | Yields | Reliability | Vantage |
|---|--------|--------------------------|--------|-------------|---------|
| A1 | **`/etc/passwd` (GECOS)** | `getent passwd` then filter, or `awk -F: '$3>=1000 && $3<65000' /etc/passwd` | Username, UID, home dir, shell; **GECOS field 5** = full name + room + **work phone** + **home phone** (comma-separated) | Username/home: high. GECOS name/phone: high **when populated**, but frequently empty on personal machines (empty on test host) | OUTSIDE (`/etc/passwd` is `-rw-r--r--`, validated) |
| A2 | **`getent passwd`** | `getent passwd` | Same as A1 but **NSS-aware** — also returns LDAP/SSSD/AD-joined directory users, which may carry richer names/mail | High; preferred over raw `cat` because it sees remote directories on managed machines | OUTSIDE |
| A3 | **Human accounts filter** | `getent passwd \| awk -F: '$3>=1000 && $3<60000 {print $1,$3,$5,$6}'` | The real people vs system accounts. UID **1000** is almost always the first/primary human = likely owner | High heuristic. `SYS_UID_MAX` is 999 on most distros so >=1000 = human | OUTSIDE |
| A4 | **GECOS readers** | `pinky -l USER` (coreutils, always present) or `finger USER` (if installed) | Pretty-prints the GECOS "real name" and dirs without hand-parsing colons | Same as A1; convenience wrapper. `pinky` validated present | OUTSIDE |
| A5 | **`/home/*`** | `ls -1 /home` | Directory **names** = usernames of everyone with a home, incl. accounts not in the greeter | High for enumeration. Note: dir *contents* are usually NOT readable from outside (see caveat on `HOME_MODE`) | OUTSIDE (the listing; not the contents) |
| A6 | **Admin/sudo group** | `getent group wheel`; `getent group sudo`; `id USER` | Which human is the administrator → strongest "this is the owner's account" tie-breaker among several users | High. **`wheel`** on Arch/Fedora/RHEL, **`sudo`** on Debian/Ubuntu (only one exists; `sudo` absent on test host) | OUTSIDE (`/etc/group` is `-rw-r--r--`, validated) |
| A7 | **Hostname** | `hostname`; `cat /etc/hostname`; `hostnamectl` | Host name often encodes the owner ("pavlos-thinkpad", "janes-mbp"). `hostnamectl` also gives **hardware vendor/model + chassis=laptop** (context) | Name-as-hint: medium (users rename freely). Vendor/model: high | OUTSIDE |
| A8 | **Pretty hostname / deployment** | `cat /etc/machine-info`; `hostnamectl` `PRETTY_HOSTNAME`/`DEPLOYMENT` | A free-text pretty name like "Jane's Laptop" if set | Medium; often unset (absent on test host) | OUTSIDE |
| A9 | **DMI asset/owner tags** | `cat /sys/class/dmi/id/{sys_vendor,product_name,product_family,chassis_asset_tag,board_asset_tag}` | Vendor/model, and **asset-tag** fields an owner/org may set to an inventory or owner string → **return-signal** | Asset tag: high *if* set (default "NO Asset Tag" on test host). Vendor/model: high | OUTSIDE (these DMI nodes are `-r--r--r--`, validated) |
| A10 | **DMI serials** | `/sys/class/dmi/id/product_serial`, `board_serial` | Serial number (useful to match a police report / vendor "proof of ownership"), **not** a contact | High value for the *owner* to prove ownership | **ROOT** — these nodes are `-r--------` (validated denied as user). Do not escalate |

---

## B. Login & session history — WHO uses this machine

| # | Source | Command | Yields | Reliability | Vantage |
|---|--------|---------|--------|-------------|---------|
| B1 | **Recent logins** | `last -n 20` | Which users logged in, when, from where (tty/host) → confirms the active human | High; ranks accounts by recency of use | OUTSIDE typically (`/var/log/wtmp` is group-`utmp` readable on most distros; validated readable) |
| B2 | **Last-per-user** | `lastlog2` (modern) or `lastlog` (legacy) | One line per account: last login time → distinguishes live vs dormant accounts | High. **`lastlog` was replaced by `lastlog2`** (SQLite `/var/lib/lastlog/lastlog2.db`); legacy `/var/log/lastlog` may be 0 bytes (validated on host) | OUTSIDE (db was `-rw-r--r--`, validated) |
| B3 | **Currently logged in** | `who`; `w`; `loginctl list-sessions` + `loginctl show-session ID` | The user in front of you right now → the account you're most likely inside | High | OUTSIDE (`who`/`loginctl` validated) |

---

## C. Display-name & desktop-account sources

| # | Source | Read-only command / path | Yields | Reliability | Vantage |
|---|--------|--------------------------|--------|-------------|---------|
| C1 | **AccountsService** | `cat /var/lib/AccountsService/users/USERNAME` | INI file with **`RealName`** (full name) and optionally **`Email`**, plus `IconFile`, `Language`, login history keys | High **where present**. Populated by GNOME/GDM stack; **absent when `accountsservice` not installed** (not installed on test host → dir missing) | OUTSIDE (system dir, files typically `-rw-r--r--` root-owned) |
| C2 | **GNOME Online Accounts** | `cat $HOME/.config/goa-1.0/accounts.conf` | Per online account: `Provider` (google/ms/nextcloud/imap/kerberos…), **`Identity`** (usually the email), `PresentationIdentity` (display email/handle). **Tokens are NOT here** — they're in the keyring, so reading identity does not touch secrets | High for enumerating the owner's online **email addresses**. Format is "effectively private" per GNOME but is plain INI | **OWNER** (under `$HOME`) |
| C3 | **KDE / KAccounts** | `sqlite3 $HOME/.config/libaccounts-glib/accounts.db 'select * from Accounts;'` (read-only); also `$HOME/.config/kaccountsrc`, `signond` config | Provider + account identity/email for KDE online accounts (libaccounts-glib backing store) | Medium-high where KDE Plasma + KAccounts used (absent on test host) | **OWNER** |
| C4 | **User avatar** | `$HOME/.face` / `$HOME/.face.icon`; `AccountsService` `IconFile` | A photo of the owner (visual ID, not text) | Low-medium; a face, not a name | Mixed (`.face` under `$HOME` = OWNER; AccountsService copy = OUTSIDE) |

---

## D. Config-file emails & handles — high-value, mostly OWNER

These are the richest **contact** sources, but nearly all live under the owner's
`$HOME`, so they need the owner's account entered (or root). On this host `$HOME`
is mode **0700**, so a second account cannot read any of them.

| # | Source | Read-only command / path | Yields | Reliability | Vantage |
|---|--------|--------------------------|--------|-------------|---------|
| D1 | **Git identity** | `git config --show-origin --get user.email` / `user.name`; or `cat $HOME/.config/git/config` and `$HOME/.gitconfig` | **Real name + email** the owner commits under | **Very high** — usually a real, monitored personal/work email. Validated: yielded name + email on host | OWNER |
| D2 | **Per-repo git** | `git -C ~/path config user.email`; grep `.git/config` in project dirs | Sometimes a *different* (work) email per repo | High | OWNER |
| D3 | **GitHub CLI** | `cat $HOME/.config/gh/hosts.yml` (read the `user:` line, **not** tokens); `gh auth status` | **GitHub handle** (`user: pvinis` validated) → strong social/contact channel | High where `gh` used | OWNER |
| D4 | **SSH public keys** | `for k in ~/.ssh/*.pub; do awk '{print $NF}' "$k"; done`; `cat ~/.ssh/config` | Key **comment** is often `name@host` or an email; `config` may name hosts/users | Medium (comment is free-text) | OWNER (`~/.ssh` usually 0700) |
| D5 | **GPG keys** | `gpg --list-secret-keys --keyid-format=long` | UID lines = **`Real Name <email>`** for the owner's own key(s) | Very high where GPG used (none on test host) | OWNER (reads `~/.gnupg`, 0700) |
| D6 | **npm** | `npm config get email`; `npm config get init-author-email`; `cat ~/.npmrc` (skip `_auth*`) | Publish email / author email | Medium (dev machines) | OWNER |
| D7 | **Cloud CLIs** | gcloud: `grep account ~/.config/gcloud/configurations/*`; also `~/.config/gh`, `~/.aws/config` (region only, no email) | Signed-in **account email** (gcloud/azure) | High where present | OWNER |
| D8 | **Mail clients** | Thunderbird: `grep -hoiE 'mail.identity.*useremail.*' ~/.thunderbird/*/prefs.js`; Evolution accounts; `~/.muttrc`/`~/.config/neomutt` `set from`; msmtp `~/.msmtprc` `from`; aerc `~/.config/aerc/accounts.conf` | The **From:** address(es) the owner sends mail as | High where a native mail client is configured (none on test host) | OWNER |
| D9 | **Debian mail identity** | `cat /etc/mailname` | Host's canonical mail domain/name | Low-medium; Debian-family only (absent on test host) | OUTSIDE |

> **Guardrail note on browsers.** A signed-in Firefox/Chrome profile also holds an
> account email, but reading it means parsing the browser profile — adjacent to
> browsing data/saved credentials. **Treat as out of scope**; prefer the cleaner
> sources above. Do not open browser stores for identity.

---

## E. Explicit "return this device" / return-signal channels

| # | Source | Read-only command / path | Yields | Vantage |
|---|--------|--------------------------|--------|---------|
| E1 | **GDM login banner** | `gsettings get org.gnome.login-screen banner-message-text`; or read `/etc/dconf/db/gdm.d/*` | Free-text banner on the GNOME login screen — the natural place an owner puts **"If found, contact …"** | OUTSIDE (system dconf; GNOME/GDM only) |
| E2 | **Console banners** | `cat /etc/issue`; `cat /etc/motd`; `/etc/issue.net` | Pre-login / post-login console text; may hold an if-found note | OUTSIDE (validated present; default template on host) |
| E3 | **DMI asset tag** | see **A9** (`chassis_asset_tag` / `board_asset_tag`) | Owner/inventory string an owner may burn in as a return contact | OUTSIDE |
| E4 | **Lock-screen / wallpaper image** | the finder simply *sees* it; file at `~/.config` theme dirs (e.g. Omarchy backgrounds, SDDM theme) | Some owners put contact info on the wallpaper/lock image (visual, not a text field) | Visual — not programmatic |

> Linux has **no standardized OS-level "if found" owner field** equivalent to
> macOS/Windows device-owner registration; the GDM banner (E1) is the closest
> first-class mechanism, and it exists only on the GNOME/GDM stack.

---

## From outside a locked account (LOCKED-PRIMARY / ACCESSIBLE-SECONDARY, Q9)

If the owner's account is **locked** but you are in a **guest/second account** (no
root), these owner signals remain readable — **all OUTSIDE rows above**, most
usefully:

1. **Display-manager greeter, seen before any login.**
   - **GDM (GNOME):** the greeter user list is built by **AccountsService** and
     shows each account's **RealName (full name)**, not just the username — often
     the single best free read of the owner's real name. Source: A1/C1 back it.
   - **SDDM (KDE/Omarchy):** greeter lists users from `/etc/passwd` filtered by
     `[Users] MaximumUid/MinimumUid/HideUsers` (`/usr/lib/sddm/sddm.conf.d/default.conf`,
     validated), and with `RememberLastUser=true` **pre-selects the last user**,
     whose name is stored in **`/var/lib/sddm/state.conf` `[Last] User=`**. On this
     host autologin is configured — `/etc/sddm.conf.d/autologin.conf` contains
     **`User=pavlos`** (world-readable `-rw-r--r--`, validated) — a direct owner
     pointer readable without any login at all.
   - **LightDM:** `greeter-hide-users=false` shows the AccountsService user list
     similarly.
2. **Account roster & admin tie-break:** `getent passwd` + `getent group wheel|sudo`
   → the human accounts and which one is the admin/owner (A2, A6).
3. **Home directory names:** `ls /home` → usernames even for the locked account (A5).
4. **AccountsService `RealName`/`Email`** files if present (C1) — system dir,
   world-readable, so the locked owner's display name/email leak here on
   GNOME-stack machines even with their account locked.
5. **Login history:** `last`, `lastlog2`, `loginctl` → who the primary user is
   and how recently active (B1–B3).
6. **Host + hardware:** hostname, `machine-info`, DMI vendor/model/asset-tag,
   console/GDM banners (A7–A9, E1–E3).

**What is NOT reachable from a second account (without root):** everything under
the owner's `$HOME` — git/ssh/gpg/gh/mail/GOA emails and handles (Section D, C2/C3)
— **when `$HOME` is mode 0700** (the case on Arch and modern Ubuntu). See caveat.

---

## Distro / desktop / display-manager differences

- **Admin group:** `wheel` (Arch, Fedora, RHEL, openSUSE) vs `sudo` (Debian,
  Ubuntu). Check both; only one exists (host had `wheel`, no `sudo`).
- **AccountsService present?** Pulled in by GNOME/GDM; **not installed** on a
  minimal KDE/Sway/Hyprland box (absent on Omarchy host) → C1 and the GDM greeter
  full-name read simply do not exist there; fall back to `/etc/passwd` GECOS.
- **`lastlog` vs `lastlog2`:** util-linux replaced classic `lastlog` with
  `lastlog2` (SQLite). Newer installs have only `lastlog2`; `/var/log/lastlog`
  may be a 0-byte legacy stub.
- **Display managers:** GDM (full names via AccountsService), SDDM (`/etc/passwd`
  + `state.conf` last user), LightDM (`greeter-hide-users`), greetd/tuigreet
  (often lists nothing). Behaviour of the greeter user list and last-user memory
  differs per DM — check which is active via
  `readlink /etc/systemd/system/display-manager.service`.
- **Online-accounts store:** GNOME → `~/.config/goa-1.0/accounts.conf`; KDE →
  `~/.config/libaccounts-glib/accounts.db` + `kaccountsrc`. Neither present on a
  bare WM setup; the owner's git/gpg email is then the fallback contact.
- **`HOME_MODE`:** governs whether Section D is reachable from a second account
  (see caveat).

---

## Gaps & caveats

- **`HOME_MODE` decides the whole "outside" story for Section D.** `/etc/login.defs`
  `HOME_MODE` (validated `0700` on host; Arch default) makes `$HOME` unreadable to
  other non-root users → git/ssh/mail emails are OWNER-only. **Older Debian/Ubuntu
  default to 0755**, and recent Ubuntu to **0750**, under which *individual*
  world-readable files (e.g. `~/.config/git/config`) *can* be read from a second
  account — but tool dirs that set their own `0700` (`~/.ssh`, `~/.gnupg`) stay
  private regardless. So "readable from outside" for D-rows is **distro- and
  per-file-dependent**; probe rather than assume.
- **GECOS is often empty** on personal installs (empty on host). Do not rely on
  the passwd name/phone fields alone; corroborate with git/AccountsService.
- **Serial numbers need root** (`product_serial`/`board_serial` are `0400`).
  Valuable for proving ownership but out of reach without escalation — leave to
  the owner/authorities.
- **GOA/KAccounts formats are officially "private"** — read only `Identity`/
  `PresentationIdentity`/`Provider` for the email; never touch the keyring.
- **No universal Linux "if found" field.** Return-signals are scattered (GDM
  banner, `/etc/issue`, asset tag, wallpaper) and usually absent; expect to fall
  back to identity+contact inference.
- **Multiple humans:** rank owner candidates by (a) UID 1000, (b) admin group
  membership, (c) most-recent/most-frequent login (`last`/`lastlog2`), (d)
  richest identity footprint. Non-owner accounts still get enumerated for the
  locked-primary case.
- **AD/LDAP-joined machines:** `getent passwd` surfaces directory users with
  fuller names/mail than `/etc/passwd`; a corporate return path (IT/asset owner)
  may beat personal contact.

---

## Primary sources

- `chfn(1)` man page — GECOS fields = real name, work room, **work phone**, home
  phone (validated locally via `man chfn`).
- `login.defs(5)` — `HOME_MODE`, `SYS_UID_MAX`/`UID_MIN`.
- AccountsService D-Bus spec — user properties incl. `RealName`, `Email`, `IconFile`:
  https://www.freedesktop.org/software/accountsservice/docs/ (and the Arch package
  file list confirming `/var/lib/AccountsService/users/`).
- GNOME Online Accounts — configuration store `$XDG_CONFIG_HOME/goa-1.0/accounts.conf`,
  fields `Provider`/`Identity`/`PresentationIdentity`, credentials in keyring:
  https://gnome.pages.gitlab.gnome.org/gnome-online-accounts/configuration.html
- GDM login banner — `org.gnome.login-screen` `banner-message-enable` /
  `banner-message-text`, dconf `/etc/dconf/db/gdm.d/`:
  https://help.gnome.org/system-admin-guide/login-banner.html
- GDM greeter user list gathered by AccountsService (ArchWiki GDM):
  https://wiki.archlinux.org/title/GDM
- SDDM — `[Users]` filtering + `RememberLastUser` → `/var/lib/sddm/state.conf`
  `[Last] User=` (validated `default.conf` locally; behaviour per sddm/sddm docs).
- `last(1)`, `lastlog2(8)`, `loginctl(1)`, `getent(1)`, `hostnamectl(1)` man pages.
- Linux DMI sysfs — `/sys/class/dmi/id/*` field permissions (validated locally).
