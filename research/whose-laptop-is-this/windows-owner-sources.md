# Windows owner-identity & contact sources (read-only)

Research for ticket `02-windows-owner-sources`. Scope is bound by the map's
**Guardrail**: identity + contact info + account enumeration + explicit
return-signals only. No message/file/history contents, no saved passwords, no
financial data, no lock bypass or privilege escalation. Every command below is
read-only.

> Testing caveat: these were **not** run on a live Windows box. Each command /
> path is grounded in Microsoft primary docs (cited) and class/registry
> references. Field availability varies by Windows build and by how the machine
> was set up (local vs Microsoft vs work account, OEM vs clean install), so
> treat "reliability" as *how dependably this yields a real owner signal when
> present*, not a guarantee it is populated.

Legend for **Needs unlock?** column:
- **No (system-wide)** — value lives in an HKLM key / world-readable location or
  a WMI class any standard local account can query; readable from a
  second/guest account while the owner's account is locked.
- **Owner's hive** — value lives in the owner's per-user registry hive
  (`HKCU` / `HKEY_USERS\<owner-SID>`). Loaded only while the owner is signed in.
  From another account it requires admin rights to load `NTUSER.DAT`
  (ACL-restricted) — allowed only if the *accessible* account is itself an
  admin; never a bypass.
- **Owner's profile files** — file under `C:\Users\<owner>\...`; the folder name
  is visible to anyone, but file contents are ACL'd to that user + admins.

---

## Master table

| # | Source | Read-only command / path | Yields | Reliability | Needs unlock? |
|---|--------|--------------------------|--------|-------------|----------------|
| 1 | Local user accounts | `Get-LocalUser \| Select Name,FullName,Enabled,Description,LastLogon,PrincipalSource,SID` | Account name, **FullName** (display name), enabled state, last logon, whether the account is Local / MicrosoftAccount / AzureAD | High for names & account type; FullName often the person's real name | No (system-wide) |
| 2 | User accounts (WMI) | `Get-CimInstance Win32_UserAccount -Filter "LocalAccount=TRUE" \| Select Name,FullName,Domain,Disabled,SID,Caption` | Same identity fields via WMI; `Domain` + `Caption` (DOMAIN\name); confirms local vs domain | High | No (system-wide) |
| 3 | User profiles on disk | `Get-CimInstance Win32_UserProfile \| Where {-not $_.Special} \| Select LocalPath,SID,LastUseTime,Loaded` | `C:\Users\<name>` folder per real profile, SID, **LastUseTime** (which profile is used most → likely owner), currently-loaded profiles | High for enumerating real users & recency | No (system-wide) |
| 4 | Owner / primary profile | Profile whose SID RID = **1001** (first user created at OOBE); cross-ref highest `LastUseTime` (#3) and admin membership (#5) | Best single guess at *the* owner account | Strong heuristic, not authoritative | No (system-wide) |
| 5 | Admin membership | `Get-LocalGroupMember Administrators` | Which accounts are admins (owner is usually a local admin) | Medium-high (supporting signal) | No (system-wide) |
| 6 | Microsoft-account email | `HKEY_USERS\<owner-SID>\SOFTWARE\Microsoft\IdentityCRL\UserExtendedProperties\<email>` (subkey name is the email); corroborate with #7/#12 | **MSA email address** tied to the profile | High when present, but hive-gated | Owner's hive |
| 7 | OneDrive account email | `Get-ItemProperty 'HKCU:\Software\Microsoft\OneDrive\Accounts\Personal' \| Select UserEmail,UserName,UserFolder` and `...\Business1` | **Email**, display name, sync-folder path for personal &/or work OneDrive | High when OneDrive configured | Owner's hive |
| 8 | Registered owner | `Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' \| Select RegisteredOwner,RegisteredOrganization` (or `Get-ComputerInfo` → `WindowsRegisteredOwner/Organization`) | Name + org typed at install | Low-medium on modern OEM/OOBE installs (often "Windows User", OEM name, or blank); higher on hand-installed/enterprise machines | No (system-wide) |
| 9 | Work / Azure AD (Entra) account | `dsregcmd /status` — read `Device State` (AzureAdJoined/DomainJoined/DomainName), `Tenant Details` (**TenantName**, TenantId), `SSO State` (**User Identity** = UPN/email), `User State` | **Org/tenant name**, work **UPN/email**, join type | High when device is Entra/AD-joined; `User Identity` under SSO only when a PRT attempt logged; run in **user context** | Partly system-wide (tenant/join); UPN needs owner context |
| 10 | Domain / UPN of current user | `whoami /upn` and `whoami /fqdn` (and `whoami /user` for SID) | Owner's UPN (email-form) & distinguished name on domain machines | High **only while owner is logged in** | Owner's session |
| 11 | Find My Device status | `Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\MdmCommon\SettingValues' \| Select LocationSyncEnabled` (1=on) | Return-signal: device tracking is enabled → owner can locate/recover it (implies an MSA is attached) | Medium; presence/name of key varies by build | No (system-wide) |
| 12 | Sign-in / last-user display | `Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI'` → `LastLoggedOnDisplayName`, `LastLoggedOnUser`, `LastLoggedOnSAMUser` | Display name + account (often `MicrosoftAccount\email`) of the last person to sign in | High for last-user; the SAMUser form can directly reveal the MSA email | No (system-wide) |
| 13 | Legal-notice "if found" text | `Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' \| Select legalnoticecaption,legalnoticetext` | **Explicit return-signal**: any "if found contact…" message shown pre-logon | High-value *if set* (usually empty on personal machines) | No (system-wide) |
| 14 | Computer name | `$env:COMPUTERNAME` / `hostname` / `(Get-CimInstance Win32_ComputerSystem).Name` | Hostname often encodes owner ("Johns-Laptop", "OWNER-PC", "JSMITH-XPS") | Low-medium (heuristic) | No (system-wide) |
| 15 | Primary owner (WMI) | `Get-CimInstance Win32_ComputerSystem \| Select PrimaryOwnerName,Name,Domain,UserName` | `PrimaryOwnerName` (registered owner), `Domain`/workgroup, `UserName` (currently-logged-on DOMAIN\user) | PrimaryOwnerName same caveats as #8; `UserName` only populated while someone is logged on locally | No (system-wide), `UserName` needs a live session |
| 16 | System summary | `systeminfo` / `Get-ComputerInfo` | One-shot: Registered Owner/Org, Domain, Host Name, join info | Convenience aggregator of #8/#9/#14 | No (system-wide) |
| 17 | Git identity | `git config --global user.name` / `user.email`; file `%USERPROFILE%\.gitconfig`; per-repo `.git/config` | **Name + email** the owner commits under | High *as a contact email* when present; identity of the account holder | Owner's profile files |
| 18 | SSH identity | Dir `%USERPROFILE%\.ssh\`; comment field of `*.pub` keys (`Get-Content ~\.ssh\id_*.pub` → often `user@host` / email); `~\.ssh\config` `User`/`HostName` | Email/username in key comments, accounts on remote hosts | Medium (email in `.pub` comment is a strong fallback) | Owner's profile files |
| 19 | Mail-client accounts | Outlook profile registry `HKCU:\Software\Microsoft\Office\<ver>\Outlook\Profiles\...` (account/email names only); Thunderbird `%APPDATA%\Thunderbird\profiles.ini`; Windows Mail account list | Configured **email addresses / display names** (identity + contact, *not* message bodies) | Medium; presence varies | Owner's hive / profile files |

---

## From outside a locked account (Q9: locked-primary / accessible-secondary)

You are signed into a guest/second account; the owner's account is **locked**.
What you can still read *without entering it or bypassing anything*:

**Best signals available system-wide (no unlock needed):**
- **Sign-in screen account picker** — Windows lists every *enabled* local user by
  **display name (FullName)** in the bottom-left of the lock screen. Reproduce
  programmatically with `Get-LocalUser` (#1) → `FullName`, or
  `Get-CimInstance Win32_UserAccount` (#2). This is the single most reliable
  outside-the-account view of who the machine's users are.
- **`C:\Users\*` folder names** — `Get-ChildItem C:\Users -Directory` or
  `Win32_UserProfile.LocalPath` (#3). Folder names are enumerable by any user
  (contents are ACL-locked, and we don't read them). `LastUseTime` tells you
  which is the primary/owner profile.
- **`net user`** (built-in) — enumerates local account names without PowerShell.
- **`query user` / `quser`** — shows account names of any currently-active/
  disconnected sessions.
- **HKLM registry values**, all world-readable and independent of who is logged
  in: `RegisteredOwner`/`RegisteredOrganization` (#8), `legalnoticetext`/
  `legalnoticecaption` (#13 — the deliberate "return this to…" channel),
  `LogonUI\LastLoggedOnDisplayName` + `LastLoggedOnSAMUser` (#12 — last user's
  name and often their `MicrosoftAccount\email`), Find My Device state (#11),
  computer name (#14).
- **`dsregcmd /status`** device/tenant sections (#9) — the **organization/tenant
  name** and join state are device-level and readable from any account (the
  per-user UPN under `SSO State` is not, without the owner's session).
- **`Win32_ComputerSystem.PrimaryOwnerName`** (#15) and `systeminfo` (#16).

**What is NOT readable from outside the locked account (do not attempt to force):**
- The owner's **MSA email** (#6) and **OneDrive email** (#7) live in the owner's
  per-user hive — loaded only in their session. From a *non-admin* second
  account they are unreadable; from an *admin* second account you could load
  their `NTUSER.DAT` read-only, but that reaches into their profile and is a
  judgment call for the skill (stay identity-only if done at all). The
  `LastLoggedOnSAMUser` value (#12) often surfaces the same MSA email without
  touching the hive — prefer that.
- Git/SSH/mail identity (#17–19) sits in the owner's profile files (ACL'd to
  the owner + admins). Same admin-only caveat.

Net: from a locked-primary machine you can almost always get **display
name(s)**, **the "if found" legal notice**, **the org/tenant name**, **the
last-user MSA email (via LogonUI SAMUser)**, and **hostname** — a workable
dossier — without ever entering the owner's account.

---

## Ranking the sign strength (for the dossier's confidence tiers)

- **confirmed / strong**: `legalnoticetext` return message (#13); `dsregcmd`
  tenant + `User Identity` UPN (#9); OneDrive `UserEmail` (#7); MSA email (#6);
  `LogonUI\LastLoggedOnSAMUser` when it holds `MicrosoftAccount\<email>` (#12);
  git `user.email` (#17).
- **likely**: `FullName` from `Get-LocalUser`/`Win32_UserAccount` (#1/#2) matched
  to the RID-1001 / highest-`LastUseTime` profile (#3/#4); SSH `.pub` key email
  comment (#18); mail-client account emails (#19).
- **weak / heuristic**: `RegisteredOwner` (#8/#15), computer name (#14) — good
  corroboration, poor as sole evidence.

Rank contact channels by directness: work/MSA **email** and legal-notice
contact > OneDrive/git email > SSH/mail-derived email > name-only (needs online
enrichment, which is a separate opt-in step).

---

## Gaps & caveats

- **Not lab-verified.** Grounded in primary docs; exact property population and
  registry-key presence vary by Windows 10 vs 11, build, and setup path.
- **`RegisteredOwner` is unreliable on modern installs.** OOBE for a Microsoft
  account frequently leaves it blank or set to "Windows User" / the OEM name.
  There is no distinct "OOBE owner name" field beyond this + the first user
  account; treat the first-created profile (RID 1001) as the real OOBE owner
  signal.
- **No documented single API for the MSA email.** The `IdentityCRL` subkey (#6)
  and OneDrive `UserEmail` (#7) are the practical sources; both are per-user
  hive values, so they need the owner's session (or admin hive-load). Community-
  documented paths, not a first-party "get the account email" cmdlet.
- **`dsregcmd` `User Identity`/`SSO State`** only appears when there's a logged-
  in user context and a recorded PRT attempt; on a freshly-booted locked
  machine you may see only device/tenant sections.
- **`Win32_ComputerSystem.UserName`** and `whoami /upn` are empty unless the
  owner is actively logged on — of little use in the locked-primary case.
- **Hostname/RegisteredOwner can be stale or deliberately generic** (resold
  machines, corporate imaging) — corroborate, never conclude from them alone.
- **Standard-user WMI/registry access:** reading `Win32_*` (root\cimv2) and HKLM
  software keys works for standard users by default, but a hardened/enterprise
  machine may restrict WMI or the account picker (`dontdisplaylastusername`
  policy blanks #12's on-screen display, though the registry value can persist).

---

## Primary sources

- Get-LocalUser — [MicrosoftDocs/PowerShell-Docs](https://github.com/MicrosoftDocs/PowerShell-Docs/blob/main/reference/5.1/Microsoft.PowerShell.LocalAccounts/Get-LocalUser.md) (PrincipalSource: Local / Active Directory / Microsoft Account); LocalUser object properties — [PowerShell/PowerShell LocalUser.cs](https://github.com/PowerShell/PowerShell/blob/master/src/Microsoft.PowerShell.LocalAccounts/LocalAccounts/LocalUser.cs), [4sysops](https://4sysops.com/archives/the-new-local-user-and-group-cmdlets-in-powershell-5-1/)
- Win32_UserAccount — [Microsoft Learn](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-useraccount) (Name, FullName, Domain, Caption, Disabled, LocalAccount, SID)
- Win32_UserProfile — [Microsoft Learn](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/legacy/ee886409(v=vs.85)) (SID, LocalPath, Special, Loaded, LastUseTime)
- Win32_ComputerSystem (PrimaryOwnerName, UserName, Domain, Name) — [Microsoft Learn](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-computersystem), [Collecting information about computers](https://learn.microsoft.com/en-us/powershell/scripting/samples/collecting-information-about-computers)
- dsregcmd /status fields — [Microsoft Entra: Troubleshoot devices using dsregcmd](https://learn.microsoft.com/en-us/entra/identity/devices/troubleshoot-device-dsregcmd) (Device State, Tenant Details → TenantName, SSO State → User Identity/UPN)
- RegisteredOwner/RegisteredOrganization & legalnoticetext/legalnoticecaption paths — [Deploying Legal Notices (Microsoft Community Hub)](https://techcommunity.microsoft.com/blog/askds/deploying-legal-notices-to-domain-computers-using-group-policy/395047); registry locations corroborated in [Windows System Configuration Registry Keys](https://securitymatrixblogs.substack.com/p/windows-system-configuration-registry)
- LogonUI LastLoggedOnDisplayName/SAMUser/User — [HKLM\...\Authentication\LogonUI reference](https://renenyffenegger.ch/notes/Windows/registry/tree/HKEY_LOCAL_MACHINE/Software/Microsoft/Windows/CurrentVersion/Authentication/LogonUI/index)
- OneDrive account registry (Personal/Business1 → UserEmail, UserName, UserFolder) — [Microsoft Community Hub: Query User Specific Registry Keys](https://techcommunity.microsoft.com/discussions/windowspowershell/query-user-specific-registry-keys-and-export-to-csv/1031841)
- MSA email in HKEY_USERS\<SID>\SOFTWARE\Microsoft\IdentityCRL\UserExtendedProperties — community-documented (not first-party); SID→profile map at HKLM\...\Windows NT\CurrentVersion\ProfileList
- Find My Device — HKLM\SOFTWARE\Microsoft\MdmCommon\SettingValues\LocationSyncEnabled ([elevenforum](https://www.elevenforum.com/t/enable-or-disable-find-my-device-in-windows-11.3861/))
- Git config file location `%USERPROFILE%\.gitconfig` — [Pro Git: Customizing Git](https://git-scm.com/book/en/v2/Customizing-Git-Git-Configuration); SSH files under `%USERPROFILE%\.ssh\` — [Manage an SSH Config File in Windows](https://www.itechguides.com/how-to-manage-an-ssh-config-file-in-windows-and-linux/)
