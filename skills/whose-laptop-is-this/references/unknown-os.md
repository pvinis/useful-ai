# Unknown OS — the fixed floor

Read this when OS detection lands on anything that is not macOS, Windows, or
Linux: BSD, a ChromeOS shell, a stripped container, an appliance.

**A fixed floor of four rows. Nothing else, and no improvising equivalents.**

The temptation here is to reason by analogy — "this is FreeBSD, the moral
equivalent of `/var/lib/AccountsService` would be…". Don't. That is a
runtime-extensible whitelist wearing a different hat, and it is exactly what the
two whitelists in `SKILL.md` are fixed and exhaustive to prevent. Four rows, then
render.

| signal | fields | command / path | family | tier | vantage |
|---|---|---|---|---|---|
| device name | hostname | `hostname`, `uname -n` | inferred | likely | OUT |
| account roster | username, uid, GECOS, home | `getent passwd`, else `/etc/passwd`, uid ≥ 1000 | inferred | strong | OUT |
| admin group | member names | `getent group wheel`, `getent group sudo` | inferred | strong | OUT |
| git identity | `user.name`, `user.email` | `git config --file <path> --get ...` | app-config | likely | gate decides |

Grounding does not apply: these four are POSIX baseline, and the reason this
floor exists is that they are the commands that survive when nothing else is
recognisable.

## The gate, on this OS

```sh
scripts/can-ordinary-read.sh /home/jtorres/.gitconfig
```

The script is plain POSIX `sh` and uses only `stat`, `readlink`, and shell
arithmetic, so it runs wherever the floor does. If `stat` supports neither GNU
`-c` nor BSD `-f`, the gate exits `3` and every gated read becomes a `✗` row —
that is the correct outcome, not a reason to fall back to `test -r`.

## Rendering

The card renders normally. **The reach line carries the thinness** — it is built
for a machine that yields almost nothing, and this path will usually take the
`blank` fill:

    ⚑  Nothing here reliably reaches them — the channels below are inferred from
       account and machine names, not stated by the owner. Treat them as leads.

A hostname and a git email are often enough to get a laptop home. Do not
apologise for the short card, and do not pad it: state the machine, not the
effort.
