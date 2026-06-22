---
name: trim-ios-simulator
description: Clean up an iOS Simulator's home screen by uninstalling the apps you don't need for development, keeping only the relevant ones. Use when the simulator home screen is cluttered with old builds or test apps, when the user says "clean up the simulator", "remove apps from the sim", "only keep my dev app on the simulator", or wants a tidy simulator for screenshots/demos. macOS + Xcode only.
---

# Trim iOS Simulator

Remove clutter from an iOS Simulator so its home screen shows only the apps that
matter for the current work. Uses Xcode's built-in `simctl` — no extra tooling
required.

## Safety rules

- **Only uninstall user-installed apps.** Never touch Apple system apps (bundle
  IDs starting with `com.apple.`). `simctl` won't remove most of them anyway, but
  don't try.
- **Always confirm the exact removal list with the user before uninstalling.**
  Uninstalling deletes that app's data in the simulator.
- This operates on a *simulator*, not a real device. Don't run destructive
  commands against physical devices.

## Steps

### 1. Pick the target simulator

List devices and choose the booted one; if several are booted or none is, ask
which to use.

```bash
xcrun simctl list devices booted        # booted sims
xcrun simctl list devices available     # all available sims
```

Capture the device UDID for the chosen simulator.

> If the Argent MCP toolkit is available, you may use its device tools to list
> and select the simulator instead — but app uninstall is fine via `simctl`.

### 2. List the installed user apps

```bash
xcrun simctl listapps <UDID>
```

This prints a plist of every installed app. Extract the **user** apps only —
those with `ApplicationType = User` (skip `System`). For each, note its
`CFBundleDisplayName` (or `CFBundleName`) and `CFBundleIdentifier`.

A quick way to get just the user bundle IDs + names:

```bash
xcrun simctl listapps <UDID> | plutil -convert json -o - - | \
  /usr/bin/python3 -c 'import sys,json;[print(f"{v.get(\"CFBundleIdentifier\",\"?\")}\t{v.get(\"CFBundleDisplayName\") or v.get(\"CFBundleName\") or \"?\"}") for v in json.load(sys.stdin).values() if v.get("ApplicationType")=="User"]'
```

### 3. Decide what to keep

Show the user the list of user apps with names + bundle IDs. Then either:
- Ask which to **keep** (everything else gets removed), or
- If the user already named the app(s) they're working on (or a bundle-ID
  prefix like `com.acme.`), propose keeping those and removing the rest.

Present the concrete **remove list** (names + bundle IDs) and get an explicit yes.

### 4. Uninstall the rest

For each bundle ID to remove:

```bash
xcrun simctl uninstall <UDID> <bundle-id>
```

(Boot the simulator first if a command complains it isn't booted:
`xcrun simctl boot <UDID>`.)

### 5. Report

Confirm what was removed and what remains. Optionally take a screenshot of the
cleaned home screen so the user can see the result.

## Notes

- To wipe a simulator back to factory instead of trimming app-by-app:
  `xcrun simctl erase <UDID>` (nuclear — removes everything; confirm first).
- App icons can linger on the springboard briefly; restarting the simulator or
  `xcrun simctl shutdown <UDID> && xcrun simctl boot <UDID>` refreshes it.
