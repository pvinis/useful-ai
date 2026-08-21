# macOS — gathering table

Read this only after detecting macOS. Everything here is subject to the rules in
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

> **Every row here is `doc-grounded`.** No Mac was available during the research
> pass or the build, so these commands are grounded in Apple's own documentation,
> not in commands anyone ran. Expect one to be wrong. When one fails, record a
> `✗` row and move on — do not go hunting for a substitute command.

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

## Notes

**`profiles show` may require root** on some versions — if the gate fails, record
a `✗` row rather than elevating.

**`MobileMeAccounts` keeps its legacy name** through Sequoia 15; do not assume it
was renamed.

**There is no unprivileged command mapping Find My to an identity.** Activation
Lock is a yes/no, and the serial is provenance for Apple or the authorities, not
a local name lookup. When Activation Lock is on, that fact takes the top
next-step slot — it is the one signal that reaches the owner without the finder
doing anything.

**TCC blocks Contacts** unless the terminal holds Full Disk Access — detect the
denial and degrade. The `✗` row reads *"Contacts "me" card — TCC denied — needs
Full Disk Access; skipped"*. Do not prompt the finder to grant it: that is a
change to a machine that is not theirs.

**Phone numbers are the weakest field on this OS.** The only clean sources are
the banner and the "me" card. Do not go digging in iMessage or FaceTime configs;
that crosses into message infrastructure.

## The gate, on this OS

```sh
scripts/can-ordinary-read.sh /Users/john/.gitconfig
```

`0` pass · `1` denied · `2` usage · `3` absent or not evaluable. Quote the
one-line reason into the `✗` row rather than paraphrasing it.

**macOS is the only OS where the cross-boundary whitelist yields anything at
all.** Homes are `drwxr-xr-x` so traversal passes the gate, while `~/.ssh` and
`~/Library` are both `700`. That leaves `<home>/.gitconfig` and
`<home>/.config/git/config` — fields `user.name` and `user.email` — as the entire
cross-boundary surface.

This is exactly the flagship case: a locked Mac where `dscl` yields a name,
`LoginwindowText` is usually unset, and the git email is the only contactable
channel that exists outside the account. Announce that read, once:

    → Reading git name and email from /Users/john/.gitconfig — the only file
      opened outside this account.
