# Windows — gathering table

Read this only after detecting Windows. Everything here is subject to the rules
in `SKILL.md`: named fields only, never file bodies, and every read of a path
outside the vantage account goes through the gate first.

**Columns.** *signal* what it yields · *fields* the named fields extracted ·
*command / path* the exact read · *family* the independence bucket
(`owner-authored` / `account-registration` / `app-config` / `inferred`) · *tier*
the ceiling for this signal, corroboration may promote by one · *vantage* `OUT`
passes the gate cross-boundary, `IN` in-session only · *grounding*
`verified-live` or `doc-grounded`.

Every `IN` row still passes the gate when the path lies outside the vantage
account. `OUT` means the gate *can* pass it — never that it is read unchecked.

> **Every row here is `doc-grounded`.** No Windows machine was available during
> the research pass or the build, so these commands are grounded in Microsoft's
> own documentation, not in commands anyone ran. Expect one to be wrong. When one
> fails, record a `✗` row and move on — do not go hunting for a substitute.

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

## Notes

**`RegisteredOwner` is unreliable on modern installs** — OOBE for a Microsoft
account frequently leaves it blank or `Windows User`. Treat the **RID-1001
profile** as the real OOBE-owner signal instead. `Windows User` is on the verdict
stoplist for exactly this reason.

**`LastLoggedOnSAMUser` often surfaces the MSA email** as
`MicrosoftAccount\<email>` **without touching any hive** — always prefer it over
the per-user sources. It is the closest thing Windows has to the locked Mac's
`.gitconfig`.

**`dsregcmd`'s SSO section only appears with a live user context** and a recorded
PRT attempt; a freshly-booted locked machine shows device and tenant sections
only.

**A hardened machine may restrict WMI**, and the `dontdisplaylastusername` policy
blanks the on-screen display though the registry value can persist.

## The gate, on this OS

```powershell
pwsh scripts/can-ordinary-read.ps1 'C:\Users\john\.gitconfig'
pwsh scripts/can-ordinary-read.ps1 'HKU:\S-1-5-21-...-1001\Software\...'
```

`0` pass · `1` denied · `2` usage · `3` absent or not evaluable. Quote the
one-line reason into the `✗` row rather than paraphrasing it.

The gate requires an **Allow** ACE granting read to `Everyone`, `BUILTIN\Users`,
or `NT AUTHORITY\Authenticated Users`, with no matching **Deny**. A grant to
`Administrators` or `SYSTEM` alone fails. `HKEY_USERS\<other-SID>` fails
unconditionally — reaching it means loading `NTUSER.DAT`, which is elevation.

**The cross-boundary whitelist yields nothing on Windows.** `C:\Users\<owner>\`
is ACL'd to the owner plus Administrators, so every path in it fails the gate.
This is by design — it is the elevation ban doing its work, and the correct
result is a shut-out reach line built from `HKLM` machine-scope signals alone.
