# Fixtures — the acceptance cases

Three fixture machines, carried over from the dossier prototype on branch
`prototype/dossier-format`. Each is a pair:

| | |
|---|---|
| `<name>.json` | what the machine yields — signals, accounts, channels, denials |
| `<name>.expected.md` | the card, the `--why` view, and the handover file it must render to, with the reasoning for every non-obvious choice |

| fixture | exercises |
|---|---|
| [`mac-unlocked`](mac-unlocked.expected.md) | the rich path — banner present, a third party's phone ranked first, Apple ID `confirmed`, git identity `likely`, a TCC `✗` row, Find My on |
| [`linux-locked`](linux-locked.expected.md) | locked-primary from a guest account — election certain, name a guess, the two confidences diverging, no channel, **shut-out** reach line, `WHAT'S OUT OF REACH` promoted |
| [`barren-windows`](barren-windows.expected.md) | nobody named — the stoplist floor, the serial in the box's second line, **blank** reach line, `WHAT'S OUT OF REACH` absent, the blank next-steps fork |

## How to use them

There is no renderer to run. The skill *is* the renderer, so the test is a read:
hand an agent `SKILL.md`, the matching `references/<os>.md`, and one `.json`, and
compare what it produces against the `.expected.md`. Between them the three cover
every conditional branch of the render spec — both reach-line axes, all three
no-name verdict forms, the stoplist floor, the promotion and the absence of
`WHAT'S OUT OF REACH`, both next-step forks, and the Find My slot both on and off.

Nothing here touches a real machine. Every value is invented; the `source` fields
are the commands the real skill would run.

## Two counting rules the render spec leaves implicit

Both were settled during the build, and both are visible in the `expected` block
of each fixture:

- **The footer's `N signals`** counts the `--why` rows that carry a tier. An
  `○○○○` row — a field that was readable and empty — is not a signal, and neither
  is a `✗` row. This is what makes `mac-unlocked` come out at the 7 the spec's own
  example shows, and it keeps a card that reaches nobody from inflating its own
  evidence count.
- **The footer's `N accounts`** counts human accounts after system and service
  accounts are excluded, including the vantage account.

## One conflict inside the spec, flagged not silently resolved

`DESIGN.md`'s shut-out next-step fork illustrates the enrichment line with
*"A public lookup could take “jtorres” and “j-torres-x1” further"* — a bare local
account username and a hostname, both of which `references/online.md` explicitly
forbids sending. `linux-locked` renders the sendable-set rule instead and drops
to the closed-door line; the reasoning is in
[`linux-locked.expected.md`](linux-locked.expected.md#why-there-is-no-enrichment-line).
