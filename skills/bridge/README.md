# crew HUD

A [SwiftBar](https://github.com/swiftbar/SwiftBar) plugin that puts the crew in
the menu bar: how many members are asking, running, and dead, with a dropdown of
every slug and member, and a notification when something needs you.

It reads `crew status --json` and nothing else. It is a renderer — it never
writes anything under `~/crew`.

## Install

Nothing installs itself. Install SwiftBar and `jq` if you do not have them, then
symlink the plugin into your SwiftBar plugin folder, from the repo root:

```sh
ln -s "$PWD/skills/bridge/scripts/crew-hud-swiftbar.sh" ~/.config/swiftbar/crew.10s.sh
```

The `10s` in the name is the refresh interval, and 10 seconds is the recommended
one: any cadence works, and the plugin renders from cache when a poll is still
running, so a short interval costs nothing visible. Rename the symlink to change
it — `crew.30s.sh`, `crew.1m.sh`.

If the plugin came out of a fresh clone and SwiftBar does not list it, it is the
executable bit: `chmod +x skills/bridge/scripts/crew-hud-swiftbar.sh`.

## Check that notifications work

The bell posts through `osascript`, which macOS attributes to Script Editor. Fire
one by hand:

```sh
osascript -e 'display notification "crew HUD is wired up" with title "crew"'
```

If no banner appears, open System Settings → Notifications → Script Editor and
allow them. Do this once, before you rely on the bell — a suppressed banner looks
exactly like a quiet crew.

## What it shows

The menu bar carries an anchor plus the counts that matter: `⚓ 1❓ 2▶`, with
`✗N` added when members died or failed, and a dim lone `⚓` when there is nothing
to report. The dropdown lists each slug, attention first, then each member as one
line — question first, then dead, then running, then done. A stale member (running
but quiet for a long time) is marked `⚠`. Clicking a member opens its state
directory in Finder.

The bell rings once per question a member asks, and once on each confirmed
transition into died, failed, or done. A poll with more than three of those posts
a single summary instead.

## What it writes

`~/.cache/crew-hud/`, and only that:

| | |
|---|---|
| `snapshot.json` | what each member's status was last poll, so the bell can spot edges |
| `bell.log` | one tab-separated line per ring: timestamp, key, transition, body |
| `last-output.txt` | the last good render, reprinted when two polls overlap |
| `error.txt` | the collector's stderr, opened from the error dropdown |
| `lock/` | poll lock, removed when the poll ends |

Deleting that directory is safe. The next poll re-seeds it silently: open
questions ring again, finished members do not.

## Tests

```sh
bash skills/bridge/tests/hud/run.sh
```

Renders every row of the failure matrix from fixture documents and asserts every
bell transition against `bell.log`, in a scratch cache. It posts no
notifications.
