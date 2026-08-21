<#
.SYNOPSIS
  can-ordinary-read — the permission gate for whose-laptop-is-this (Windows).

.DESCRIPTION
  Answers *could an ordinary principal read this path?* — not *can I read it?*

      can-ordinary-read.ps1 <path>

      exit 0  an ordinary principal could read it
      exit 1  denied — the ACL says no (reason on stdout)
      exit 2  usage error
      exit 3  path does not exist, or its ACL is not evaluable

  The rule: Get-Acl on the path, then require an Allow ACE granting read to
  Everyone, BUILTIN\Users, or NT AUTHORITY\Authenticated Users, with no Deny ACE
  matching the same principals. A grant to Administrators or SYSTEM alone
  *fails* — those are not ordinary principals.

  For registry paths, HKEY_USERS\<other-SID> fails unconditionally: reaching it
  means loading that account's NTUSER.DAT, which is elevation.

  Attempting the read and seeing what happens is not an implementation of this.
  It fails the elevated case, which is the one case that matters. The answer
  does not change when the caller is an Administrator.

  Metadata only. This script never opens a file, and never prints its contents.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
    [Console]::Error.WriteLine('usage: can-ordinary-read.ps1 <path>')
    exit 2
}

if ([string]::IsNullOrWhiteSpace($Path)) { Show-Usage }

# The principals that count as ordinary. Well-known SIDs, not display names:
# the names are localized and an English-only match silently denies everything
# on a German or Japanese install.
$OrdinarySids = @{
    'S-1-1-0'      = 'Everyone'
    'S-1-5-32-545' = 'BUILTIN\Users'
    'S-1-5-11'     = 'NT AUTHORITY\Authenticated Users'
}

# Rights that amount to reading the thing.
$ReadRights = [System.Security.AccessControl.FileSystemRights]::Read -bor
              [System.Security.AccessControl.FileSystemRights]::ReadData -bor
              [System.Security.AccessControl.FileSystemRights]::ReadAndExecute -bor
              [System.Security.AccessControl.FileSystemRights]::ReadPermissions

function Resolve-SidOf {
    param($Rule)
    try {
        return $Rule.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch {
        return $null
    }
}

function Test-GrantsRead {
    param($Rule)
    # File ACEs carry FileSystemRights, registry ACEs RegistryRights. Both are
    # bit fields sharing the same low bits for read; compare numerically.
    $rights = if ($Rule.PSObject.Properties['FileSystemRights']) {
        [int]$Rule.FileSystemRights
    } elseif ($Rule.PSObject.Properties['RegistryRights']) {
        [int]$Rule.RegistryRights
    } else {
        0
    }
    return ($rights -band [int]$ReadRights) -ne 0
}

# ── registry: HKEY_USERS\<other-SID> is refused outright ────────────────────

$normalized = $Path -replace '^Registry::', ''
if ($normalized -match '^(HKU:|HKEY_USERS)\\(S-1-[0-9-]+)') {
    $targetSid = $Matches[2]
    $me = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
    if ($targetSid -ne $me) {
        Write-Output "denied: $Path is another account's hive — reaching it means loading NTUSER.DAT, which is elevation"
        exit 1
    }
}

# ── read the ACL ────────────────────────────────────────────────────────────

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Output "unreadable: $Path does not exist"
    exit 3
}

try {
    $acl = Get-Acl -LiteralPath $Path
} catch {
    Write-Output "unreadable: cannot evaluate the ACL on $Path — $($_.Exception.Message)"
    exit 3
}

$rules = @($acl.Access)

# Deny wins, always, and is evaluated first.
foreach ($rule in $rules) {
    if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Deny) { continue }
    $sid = Resolve-SidOf $rule
    if ($sid -and $OrdinarySids.ContainsKey($sid) -and (Test-GrantsRead $rule)) {
        Write-Output "denied: $Path carries a Deny ACE for $($OrdinarySids[$sid])"
        exit 1
    }
}

foreach ($rule in $rules) {
    if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) { continue }
    $sid = Resolve-SidOf $rule
    if ($sid -and $OrdinarySids.ContainsKey($sid) -and (Test-GrantsRead $rule)) {
        Write-Output "ok: $Path grants read to $($OrdinarySids[$sid])"
        exit 0
    }
}

Write-Output "denied: $Path grants read to no ordinary principal — only to owner, Administrators, or SYSTEM"
exit 1
