# data

Shared data files that the prompts and skills in this repo pull from.

## `sims-loading-messages.{json,txt}`

595 loading-screen messages from the Maxis sims — the "Reticulating Splines"
family. Feed them to an AI coding CLI so it narrates its work like a game
loading a save. See
[`prompts/sims-loading-verbs.md`](../prompts/sims-loading-verbs.md) for the
setup.

- `sims-loading-messages.txt` — flat, deduped, one message per line. What you
  want in almost every case.
- `sims-loading-messages.json` — the same messages grouped by game and
  expansion pack, so you can pick a single era instead of all of them.

| Set              | Messages | Source                                                                             |
| ---------------- | -------- | ---------------------------------------------------------------------------------- |
| The Sims         | 85       | [The Sims Wiki](https://sims.fandom.com/wiki/Loading_screen_messages)               |
| The Sims 2       | 171      | The Sims Wiki                                                                      |
| The Sims Stories | 31       | The Sims Wiki                                                                      |
| The Sims 3       | 221      | The Sims Wiki                                                                      |
| SimCity 4        | 106      | [community-compiled list](https://gist.github.com/erikcox/7e96d031d00d7ecb1a2f)     |
| **Unique total** | **595**  |                                                                                    |

### One thing worth knowing

**There is no Sims 4 list.** Loading-screen messages ran from The Sims through
The Sims 3 and were dropped for The Sims 4, which kept only "Reticulating
splines" as a nod. If you came looking for "the Sims 4 loading verbs", the ones
you remember are Sims 1–3. The joke itself starts earlier still, in SimCity
2000, where the line was spoken aloud.

SimCity 4 is included because it is the origin list and the most
technical-sounding of the lot, which suits a coding agent. It shares exactly one
line with the Sims lists: `Reticulating Splines`.

### Normalization

Verbatim apart from three things: trailing `...` / `…` stripped (every consumer
appends its own), whitespace collapsed, wiki markup removed. Original spellings
and typos are preserved on purpose — `Bureacritizing Bureaucracies`,
`Aesthesizing Industrial Areas`, and `Routing Neural Network Infanstructure`
are all shipped exactly as Maxis shipped them.

578 of the 595 open with a gerund, so they read correctly with an ellipsis
appended. The rest are deliberate one-offs worth keeping — `Still Reticulating
Splines`, `Re-Re-Re-Re-Re-Reticulating Splines`, `De-inviting Don Lothario`,
`Happy 14th Birthday Reticulated Splines!`, and `Roof = Roof(1/3*pi*r^2*h)`.

### Regenerating

```bash
python3 data/fetch-sims-loading-messages.py
```

Refetches from both sources and rewrites both files. No dependencies beyond the
standard library.

### Rights

The messages are EA / Maxis's writing. They are collected here as a reference
list already publicly documented on The Sims Wiki, for use as a homage in
personal tooling. No affiliation with or endorsement by EA or Maxis.
