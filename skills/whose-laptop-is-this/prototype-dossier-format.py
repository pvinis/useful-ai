#!/usr/bin/env python3
"""PROTOTYPE — throwaway. Not the skill; a mock of its output.

Three radically different layouts for the `whose-laptop-is-this` owner dossier,
switchable with --variant, rendered against fixture data taken from the per-OS
research (map #9, tickets #10/#11/#12). Nothing here touches a real machine:
every value below is invented, the "source" column is the command the real
skill would run.

    python3 prototype-dossier-format.py                       # A, mac-unlocked
    python3 prototype-dossier-format.py -v B -c linux-locked
    python3 prototype-dossier-format.py --file                # saved-to-file form
    python3 prototype-dossier-format.py --all                 # every combo

Question it answers: which terminal layout do we want, how do tiers and channel
rank render, what does the saved file look like, and how does the locked-owner
case degrade?
"""

import argparse, sys

# ── fixtures ────────────────────────────────────────────────────────────────
# tier: confirmed > strong > likely > weak  (map's heuristic tiers, no scores)

MAC = {
    "os": "macOS 15.3 (Sequoia)",
    "vantage": "inside the owner's own unlocked account (japple)",
    "machine": {"name": "John's MacBook Pro", "model": 'MacBook Pro 14" (M3, 2023)',
                "serial": "C02XL0THJGH5"},
    "owner": {"name": "John Appleseed", "tier": "confirmed", "account": "japple"},
    "note": {"text": "Lost? Please call Marie on +1 415 555 0142, or email me — "
                     "reward, no questions asked. — John",
             "source": "defaults read /Library/Preferences/com.apple.loginwindow "
                       "LoginwindowText"},
    "channels": [
        {"kind": "phone", "value": "+1 415 555 0142 (Marie)", "tier": "confirmed",
         "why": "the owner wrote it themselves, for exactly this",
         "source": "lock-screen if-found message"},
        {"kind": "email", "value": "j.appleseed@icloud.com", "tier": "confirmed",
         "why": "Apple ID signed in on this Mac",
         "source": "defaults read ~/Library/Preferences/MobileMeAccounts → AccountID"},
        {"kind": "email", "value": "john@appleseed.dev", "tier": "likely",
         "why": "commits under it — monitored, but maybe not urgently",
         "source": "git config --get user.email"},
        {"kind": "handle", "value": "github.com/jappleseed", "tier": "weak",
         "why": "public profile, slow channel, needs opt-in enrichment to confirm",
         "source": "~/.ssh/id_ed25519.pub comment"},
    ],
    "accounts": [
        {"user": "japple", "uid": 501, "admin": True, "real": "John Appleseed",
         "last": "logged in now", "state": "open", "owner": True,
         "signals": [("Apple ID", "j.appleseed@icloud.com", "confirmed",
                      "MobileMeAccounts AccountID"),
                     ("git identity", "John Appleseed <john@appleseed.dev>", "likely",
                      "git config --get user.name/.email")]},
        {"user": "sam", "uid": 502, "admin": False, "real": "Sam Ortiz",
         "last": "3 months ago", "state": "locked", "owner": False, "signals": []},
    ],
    "machine_signals": [
        ("if-found message", "set — see above", "confirmed",
         "defaults read …com.apple.loginwindow LoginwindowText"),
        ("device name", "John's MacBook Pro", "strong", "scutil --get ComputerName"),
        ("serial", "C02XL0THJGH5", "strong", "system_profiler SPHardwareDataType"),
        ("Activation Lock", "Enabled — Find My is on, Apple can reach the owner",
         "strong", "system_profiler SPHardwareDataType"),
        ("MDM enrollment", "none — personally owned", "strong",
         "profiles status -type enrollment"),
    ],
    "blocked": [("Contacts “me” card", "TCC denied — needs Full Disk Access; skipped")],
    "next": ["Call +1 415 555 0142 — the owner asked you to.",
             "If no answer, email j.appleseed@icloud.com.",
             "Find My is on: leaving it somewhere safe and untouched is fine — "
             "the owner can already see where it is."],
}

LINUX = {
    "os": "Linux (Arch, SDDM greeter)",
    "vantage": "a second/guest account — the owner's account is LOCKED and stays that way",
    "machine": {"name": "j-torres-x1", "model": "Lenovo ThinkPad X1 Carbon Gen 11",
                "serial": "unreadable (root-only DMI node — not escalating)"},
    "owner": {"name": "J. Torres (surname unconfirmed)", "tier": "likely",
              "account": "jtorres"},
    "note": None,
    "channels": [],
    "accounts": [
        {"user": "jtorres", "uid": 1000, "admin": True, "real": "— (GECOS empty)",
         "last": "today, 14:20", "state": "locked", "owner": True,
         "signals": [("home dir", "/home/jtorres (mode 0700)", "confirmed", "ls -ld /home/*"),
                     ("git / gh / mail identity", "unreadable from here — inside the "
                      "locked 0700 home", "—", "not attempted")]},
        {"user": "guest", "uid": 1001, "admin": False, "real": "Guest",
         "last": "logged in now (you)", "state": "open", "owner": False, "signals": []},
    ],
    "machine_signals": [
        ("greeter last user", "jtorres", "strong", "/var/lib/sddm/state.conf [Last] User"),
        ("admin group", "jtorres is the only member of wheel", "strong", "getent group wheel"),
        ("hostname", "j-torres-x1 — encodes the same name", "likely", "hostnamectl"),
        ("if-found message", "none — no GDM banner, /etc/issue is the distro default",
         "—", "gsettings … banner-message-text; cat /etc/issue"),
        ("asset tag", "“NO Asset Tag” — unset", "—", "cat /sys/class/dmi/id/chassis_asset_tag"),
    ],
    "blocked": [("everything under /home/jtorres", "home is mode 0700 and the account is "
                 "locked — git email, gh handle, mail accounts all sit behind it"),
                ("hardware serial", "/sys/class/dmi/id/product_serial is root-only")],
    "next": ["No contact channel was readable without entering the locked account, "
             "which this skill will not do.",
             "Online enrichment (opt-in, separate step) could take “jtorres” + "
             "“j-torres-x1” to public sources — say the word and it runs.",
             "Otherwise: hand it to the venue's lost property, or Lenovo support with "
             "the model — they can match a registered owner."],
}

BARREN = {
    "os": "Windows 11 23H2",
    "vantage": "the only account on the machine, signed in",
    "machine": {"name": "DESKTOP-7K2F9Q1", "model": "Dell Latitude 5440",
                "serial": "9BQ4XK3"},
    "owner": {"name": None, "tier": None, "account": None},
    "note": None,
    "channels": [],
    "accounts": [
        {"user": "user", "uid": 1001, "admin": True, "real": "— (FullName blank)",
         "last": "logged in now", "state": "open", "owner": True,
         "signals": [("Microsoft account", "none — local account only", "confirmed",
                      "Get-LocalUser → PrincipalSource: Local"),
                     ("OneDrive", "not configured", "confirmed",
                      "HKCU:\\Software\\Microsoft\\OneDrive\\Accounts")]},
    ],
    "machine_signals": [
        ("if-found message", "not set", "—",
         "HKLM:\\…\\Policies\\System → legalnoticetext"),
        ("registered owner", "blank", "—", "HKLM:\\…\\Windows NT\\CurrentVersion"),
        ("last signed-in user", "blank — policy hides it", "—",
         "HKLM:\\…\\Authentication\\LogonUI"),
        ("work/school account", "not joined to any tenant", "confirmed", "dsregcmd /status"),
        ("Find My Device", "off", "strong",
         "HKLM:\\…\\MdmCommon\\SettingValues → LocationSyncEnabled"),
        ("serial", "9BQ4XK3", "strong", "Get-CimInstance Win32_BIOS"),
    ],
    "blocked": [],
    "next": ["Nothing on this machine names a person. That is the honest answer, "
             "not a failure to look harder.",
             "The serial 9BQ4XK3 is the only handle: Dell support can match it to a "
             "registered owner, and police lost-property will log it.",
             "Online enrichment has nothing to work from here — no identifier to enrich."],
}

CASES = {"mac-unlocked": MAC, "linux-locked": LINUX, "barren": BARREN}
VARIANTS = {"A": "Return card", "B": "Evidence ledger", "C": "Account roster"}

TIER_DOTS = {"confirmed": "●●●●", "strong": "●●●○", "likely": "●●○○",
             "weak": "●○○○", "—": "○○○○"}
W = 74


def rule(ch="─"):
    return ch * W


def wrap(text, indent=0, width=W, hang=0):
    out, line = [], ""
    pad = indent
    for word in text.split():
        if len(line) + len(word) + 1 > width - pad:
            out.append(" " * pad + line)
            line, pad = word, indent + hang
        else:
            line = f"{line} {word}".strip()
    if line:
        out.append(" " * pad + line)
    return "\n".join(out)


# ── variant A: return card ──────────────────────────────────────────────────
# Action first. One sentence a panicking finder can act on, the owner's own
# words next, channels ranked, evidence folded away behind --why.

def variant_a(d):
    o, m = d["owner"], d["machine"]
    L = ["╭" + rule("─") + "╮"]
    if o["name"]:
        headline = f"This is {o['name']}'s laptop."
        sub = f"{m['model']} · “{m['name']}” · {o['tier']}"
    else:
        headline = "We could not work out whose laptop this is."
        sub = f"{m['model']} · serial {m['serial']} · nothing here names a person"
    L += ["│ " + headline.ljust(W - 2) + " │", "│ " + sub.ljust(W - 2) + " │",
          "╰" + rule("─") + "╯", ""]

    if d["note"]:
        L += ["  ⚑ THE OWNER LEFT A NOTE ON THE LOCK SCREEN", ""]
        L += [wrap(f"“{d['note']['text']}”", 6), ""]

    if d["channels"]:
        L += ["  HOW TO REACH THEM — best first", ""]
        for i, c in enumerate(d["channels"], 1):
            L.append(f"  {i}. {c['value']}")
            L.append(f"     {c['kind']} · {c['tier']} · {c['why']}")
        L.append("")
    else:
        L += ["  HOW TO REACH THEM", "",
              wrap("Nothing. No email, phone or handle was readable without going "
                   "somewhere this skill won't go.", 5), ""]

    L += ["  WHAT I'D DO NEXT", ""]
    for step in d["next"]:
        L.append(wrap("• " + step, 2, hang=2))
    n = len(d["machine_signals"]) + sum(len(a["signals"]) for a in d["accounts"])
    L += ["", rule("┈"),
          f"  {n} signals · {len(d['accounts'])} "
          f"account{'s' if len(d['accounts']) != 1 else ''} · read-only, "
          f"nothing was changed", "  run with --why to see where every line above came from"]
    return "\n".join(L)


def variant_a_why(d):
    L = ["  WHY I THINK SO", ""]
    for f, v, t, s in d["machine_signals"]:
        L.append(f"  {TIER_DOTS[t]}  {f}: {v}")
        L.append(f"        ↳ {s}")
    for a in d["accounts"]:
        for f, v, t, s in a["signals"]:
            L.append(f"  {TIER_DOTS[t]}  [{a['user']}] {f}: {v}")
            L.append(f"        ↳ {s}")
    for what, why in d["blocked"]:
        L.append(f"  ✗     {what} — {why}")
    return "\n".join(L)


# ── variant B: evidence ledger ──────────────────────────────────────────────
# Source-centric. The dossier IS the audit trail; the identity is a conclusion
# printed at the bottom, derived in the open, for a reader judging the guess.

def variant_b(d):
    o, m = d["owner"], d["machine"]
    L = [f"whose-laptop-is-this — evidence ledger",
         f"{m['model']} · {d['os']} · host {m['name']} · serial {m['serial']}",
         f"vantage: {d['vantage']}", rule("═"), "",
         "  tier  field                  value", rule("┈")]

    def row(f, v, t, s, tag=""):
        L.append(f"  {TIER_DOTS[t]}  {(tag + f)[:21].ljust(21)}  {v}")
        L.append(f"        {''.ljust(21)}  ← {s}")

    for f, v, t, s in d["machine_signals"]:
        row(f, v, t, s)
    for a in d["accounts"]:
        for f, v, t, s in a["signals"]:
            row(f, v, t, s, tag=f"{a['user']}:")
    for what, why in d["blocked"]:
        L.append(f"  ✗✗✗✗  {what[:21].ljust(21)}  not read — {why}")
    L += ["", "  ACCOUNTS", rule("┈"),
          "  user        uid   admin  last seen         state"]
    for a in d["accounts"]:
        star = "★" if a["owner"] else " "
        L.append(f"  {star}{a['user'][:10].ljust(11)} {str(a['uid']).ljust(5)} "
                 f"{('yes' if a['admin'] else 'no').ljust(6)} "
                 f"{a['last'][:17].ljust(17)} {a['state']}")
    L += ["", "  CHANNELS, RANKED BY DIRECTNESS", rule("┈")]
    if d["channels"]:
        for i, c in enumerate(d["channels"], 1):
            L.append(f"  {i}. {TIER_DOTS[c['tier']]} {c['kind'].ljust(6)} {c['value']}")
            L.append(f"        ← {c['source']}")
    else:
        L.append("  (none readable)")
    L += ["", "  CONCLUSION", rule("┈")]
    if o["name"]:
        L.append(wrap(f"Owner is {o['name']} ({o['tier']}), account “{o['account']}” — "
                      f"the admin, first-created, most-recently-used account, and the "
                      f"name it carries agrees with the host name.", 2))
    else:
        L.append(wrap("No owner identity. Every identity field on this machine is "
                      "blank, unset or policy-hidden — see the ✗ and “—” rows above. "
                      "The serial is the only usable handle.", 2))
    return "\n".join(L)


# ── variant C: account roster ───────────────────────────────────────────────
# Machine-shaped. Accounts are the spine, because "whose is this" is really
# "which of these accounts is the owner's" — and it degrades most honestly
# when the owner's account is the one you can't open.

def variant_c(d):
    m = d["machine"]
    L = [f"WHOSE LAPTOP IS THIS", rule("═"),
         f"  {m['model']} — {d['os']}",
         f"  host “{m['name']}” · serial {m['serial']}",
         f"  you are: {d['vantage']}", "",
         f"  ACCOUNTS ON THIS MACHINE ({len(d['accounts'])})", rule("─")]
    for a in d["accounts"]:
        mark = "★ LIKELY OWNER" if a["owner"] else "  other account"
        lock = {"locked": "🔒 locked — not entered, by design",
                "open": "unlocked"}[a["state"]]
        L += ["", f"  {mark}",
              f"    {a['user']}  ·  uid {a['uid']}  ·  "
              f"{'admin' if a['admin'] else 'standard'}  ·  {lock}",
              f"    name: {a['real']}    last seen: {a['last']}"]
        for f, v, t, s in a["signals"]:
            L.append(f"      {f}: {v}")
            L.append(f"        {TIER_DOTS[t]} {t}  ← {s}")
        if a["owner"] and not a["signals"]:
            L.append("      (no identity fields readable for this account)")
    L += ["", "  THE MACHINE ITSELF", rule("─")]
    for f, v, t, s in d["machine_signals"]:
        L.append(f"    {TIER_DOTS[t]} {f.ljust(20)} {v}")
    if d["note"]:
        L += ["", "  ⚑ IF-FOUND MESSAGE, IN THE OWNER'S OWN WORDS", rule("─"),
              wrap(f"“{d['note']['text']}”", 4)]
    L += ["", "  CONTACT CHANNELS", rule("─")]
    if d["channels"]:
        for i, c in enumerate(d["channels"], 1):
            L.append(f"    {i}. {c['kind'].ljust(6)} {c['value']}   "
                     f"{TIER_DOTS[c['tier']]} {c['tier']}")
    else:
        L.append("    none — see “what's out of reach” below" if d["blocked"]
                 else "    none — the identity fields on this machine are simply unset")
    if d["blocked"]:
        L += ["", "  WHAT'S OUT OF REACH", rule("─")]
        for what, why in d["blocked"]:
            L.append(wrap(f"✗ {what} — {why}", 4, hang=2))
    L += ["", "  NEXT", rule("─")]
    for s in d["next"]:
        L.append(wrap("• " + s, 4, hang=2))
    return "\n".join(L)


# ── the saved-to-file form (Markdown, archival: always full evidence) ───────

def file_form(d, case):
    o, m = d["owner"], d["machine"]
    who = o["name"] or "UNIDENTIFIED"
    L = [f"# Owner dossier — {m['model']}", "",
         f"- **Best guess:** {who}" + (f" ({o['tier']})" if o["tier"] else ""),
         f"- **Host name:** {m['name']}",
         f"- **Serial:** {m['serial']}",
         f"- **OS:** {d['os']}",
         f"- **Gathered from:** {d['vantage']}",
         "- **Gathered at:** <timestamp>",
         "", "> Read-only. Nothing on the machine was modified, and no locked "
         "account, message, file or password store was opened.", ""]
    if d["note"]:
        L += ["## If-found message left by the owner", "",
              f"> {d['note']['text']}", "", f"`{d['note']['source']}`", ""]
    L += ["## Contact channels", ""]
    if d["channels"]:
        L += ["| # | kind | value | confidence | source |",
              "|---|------|-------|-----------|--------|"]
        for i, c in enumerate(d["channels"], 1):
            L.append(f"| {i} | {c['kind']} | {c['value']} | {c['tier']} | "
                     f"`{c['source']}` |")
    else:
        L.append("None readable from this vantage.")
    L += ["", "## Accounts", "",
          "| account | uid | admin | last seen | state | owner? |",
          "|---------|-----|-------|-----------|-------|--------|"]
    for a in d["accounts"]:
        L.append(f"| {a['user']} | {a['uid']} | {'yes' if a['admin'] else 'no'} | "
                 f"{a['last']} | {a['state']} | {'★' if a['owner'] else ''} |")
    L += ["", "## Every signal", "",
          "| field | value | confidence | source |", "|-------|-------|-----------|--------|"]
    for f, v, t, s in d["machine_signals"]:
        L.append(f"| {f} | {v} | {t} | `{s}` |")
    for a in d["accounts"]:
        for f, v, t, s in a["signals"]:
            L.append(f"| {a['user']}: {f} | {v} | {t} | `{s}` |")
    if d["blocked"]:
        L += ["", "## Deliberately not read", ""]
        for what, why in d["blocked"]:
            L.append(f"- **{what}** — {why}")
    L += ["", "## Suggested next steps", ""]
    L += [f"{i}. {s}" for i, s in enumerate(d["next"], 1)]
    L += ["", "---", "", f"Produced by `whose-laptop-is-this` (fixture: {case}).",
          "Hand this to lost property, the vendor, or the police as-is."]
    return "\n".join(L)


def switcher(v, case):
    keys = list(VARIANTS)
    i = keys.index(v)
    prev, nxt = keys[(i - 1) % 3], keys[(i + 1) % 3]
    return ("\n" + rule("━") + "\n"
            f"  ◀ {prev}   [ {v} · {VARIANTS[v]} ]   {nxt} ▶     case: {case}\n"
            f"  -v {'/'.join(keys)}   -c {'/'.join(CASES)}   --file   --all\n")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("-v", "--variant", choices=list(VARIANTS), default="A")
    p.add_argument("-c", "--case", choices=list(CASES), default="mac-unlocked")
    p.add_argument("--why", action="store_true", help="variant A: expand the evidence")
    p.add_argument("--file", action="store_true", help="render the saved-to-file form")
    p.add_argument("--all", action="store_true", help="every variant × every case")
    a = p.parse_args()

    render = {"A": variant_a, "B": variant_b, "C": variant_c}

    if a.all:
        for case in CASES:
            for v in VARIANTS:
                print("\n" + "█" * W)
                print(f"█ {v} — {VARIANTS[v]}   ·   case: {case}".ljust(W) + "█")
                print("█" * W + "\n")
                print(render[v](CASES[case]))
                if v == "A":
                    print("\n" + variant_a_why(CASES[case]))
            print("\n" + "█" * W)
            print(f"█ saved-to-file form   ·   case: {case}".ljust(W) + "█")
            print("█" * W + "\n")
            print(file_form(CASES[case], case))
        return

    if a.file:
        print(file_form(CASES[a.case], a.case))
        return

    print(render[a.variant](CASES[a.case]))
    if a.why and a.variant == "A":
        print("\n" + variant_a_why(CASES[a.case]))
    print(switcher(a.variant, a.case))


if __name__ == "__main__":
    main()
