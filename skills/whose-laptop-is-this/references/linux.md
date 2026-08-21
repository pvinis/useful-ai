# Linux — gathering table

Read this only after detecting Linux. Everything here is subject to the rules in
`SKILL.md`: named fields only, never file bodies, and every read of a path
outside the vantage account goes through the gate first.

**Columns.** *signal* what it yields · *fields* the named fields extracted ·
*command / path* the exact read · *family* the independence bucket
(`owner-authored` / `account-registration` / `app-config` / `inferred`) · *tier*
the ceiling for this signal, corroboration may promote by one · *vantage* `OUT`
passes the gate cross-boundary, `IN` in-session only · *grounding*
`verified-live` or `doc-grounded`.

Every `IN` row still passes the gate when the path lies outside the vantage
account. `OUT` means the gate *can* pass it — never that it is read unchecked.

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
| DM autologin user | `User` | `/etc/sddm.conf.d/autologin.conf`, `/etc/gdm/custom.conf` `AutomaticLogin` | inferred | strong | OUT | verified-live |
| DM last user | `[Last] User` | `/var/lib/sddm/state.conf` | inferred | strong | gate decides | verified-live |
| login history | last login per account | `last -n 20`, `lastlog2` | inferred | strong | OUT | verified-live |
| git identity | `user.name`, `user.email` | `git config --file <path> --get ...` | app-config | likely | IN | verified-live |
| GitHub CLI | the `user:` line | `~/.config/gh/hosts.yml` | app-config | likely | IN | verified-live |
| GPG | UID lines (`Real Name <email>`) | `gpg --list-secret-keys --keyid-format=long` | app-config | strong | IN | doc-grounded |
| online accounts | `Provider`, `Identity`, `PresentationIdentity` | `~/.config/goa-1.0/accounts.conf` | account-registration | strong | IN | doc-grounded |
| SSH key comment | trailing comment field | `~/.ssh/*.pub` | app-config | weak | IN | verified-live |
| mail clients | the `From:` addresses | Thunderbird `prefs.js` identity keys; `~/.msmtprc` `from`; aerc `accounts.conf` | app-config | likely | IN | doc-grounded |

## Notes

**There is no universal "if found" field.** The GDM banner is the closest
first-class mechanism and exists only on the GNOME/GDM stack, so expect to fall
back to identity inference.

**`HOME_MODE` in `/etc/login.defs` is the pivot.** `0700` (Arch, Fedora, RHEL)
and `0750` (recent Ubuntu) make every `IN` row unreachable cross-boundary, while
legacy `0755` Debian/Ubuntu exposes individual world-readable files. **Let the
gate decide, per file — never assume from the distro.**

**GECOS is frequently empty** on personal installs. `accountsservice` is pulled in
by the GNOME/GDM stack and is simply absent on a minimal KDE/Sway/Hyprland box.

**`lastlog` was replaced by `lastlog2`**; the legacy `/var/log/lastlog` may be a
zero-byte stub. Identify the active display manager with
`readlink /etc/systemd/system/display-manager.service`.

**On AD/LDAP-joined machines** `getent passwd` surfaces directory users with
fuller names, and the corporate return path may beat personal contact.

**DMI serials are root-only** (`product_serial`, `board_serial` are mode `0400`)
and therefore fail the gate. Record a `✗` row; never elevate. The serial is
valuable for proving ownership, but that is the owner's and the authorities' job.

**Browsers stay closed.** A signed-in Firefox or Chrome profile holds an account
email, but reading it means parsing a store adjacent to browsing data and saved
credentials. Prefer git, GPG, and GOA.

## The gate, on this OS

```sh
scripts/can-ordinary-read.sh /home/jtorres/.gitconfig
```

`0` pass · `1` denied · `2` usage · `3` absent or not evaluable. Quote the
one-line reason into the `✗` row rather than paraphrasing it.

The cross-boundary whitelist is `<home>/.gitconfig` and
`<home>/.config/git/config`, fields `user.name` and `user.email`. On a `0700` or
`0750` home the gate denies both at the home directory itself, and the correct
result is a shut-out reach line — not a search for something else to read.

## Build-session verification

Run on Omarchy 4.0.0 (Arch, kernel 7.1.8, SDDM, Hyprland, no `accountsservice`,
no GNOME), one human account, `HOME_MODE 0700`:

- **Re-marked `verified-live` from `doc-grounded`:** *DM autologin user* —
  `/etc/sddm.conf.d/autologin.conf` is mode `0644` and yields `User=`; and
  *GitHub CLI*, whose `user:` line extracted cleanly.
- **`DM last user` split out of the row it shared** with autologin, and its
  vantage changed from `OUT` to `gate decides`: `/var/lib/sddm` is
  `drwxr-x--- sddm:sddm` here, so `state.conf` **fails the gate** on this distro
  while remaining world-readable on others. The autologin file carries the same
  fact and does pass.
- **Confirmed denied, as specified:** `/sys/class/dmi/id/product_serial` and
  `board_serial` (mode `0400`), and every path under a `0700` home.
- **Left `doc-grounded`, absent on this box:** the GDM banner (no
  `org.gnome.login-screen` schema, no `/etc/dconf/db/gdm.d/`),
  `/var/lib/AccountsService/users/` (directory does not exist), and
  `~/.config/goa-1.0/accounts.conf`.
- **Left `doc-grounded`, command ran but yielded nothing to extract:** GPG —
  `gpg --list-secret-keys` exits `0` with no keyring on this machine, so no UID
  line was ever observed.
- **`SSH key comment` kept at `verified-live` from the research pass**; this
  machine has no `~/.ssh/*.pub` to re-run it against.
