# Prompt: how many watts is my Mac charging at right now?

Copy everything below the line and give it to your AI coding agent on a macOS
machine. It's read-only — it just inspects power telemetry and reports back.

---

Tell me how much power my Mac is drawing from the charger **right now**, in
watts, and whether it's charging, full, or running on battery. Use macOS's
built-in power tooling — don't install anything. Read-only; don't change any
power settings.

## How to get it

The adapter and battery details live in IORegistry and `system_profiler`:

- **Adapter wattage (what the charger can supply):**
  `system_profiler SPPowerDataType` → look for `AC Charger Information`
  (`Wattage (W)`, `Charging`, `Connected`).
- **Live draw / battery state:** `ioreg -rn AppleSmartBattery` exposes
  `Voltage` (mV), `Amperage` (mA, signed — negative = discharging), `IsCharging`,
  `ExternalConnected`, `CurrentCapacity`, `MaxCapacity`, `FullyCharged`,
  `AppleRawCurrentCapacity`. Approximate instantaneous power ≈
  `Voltage(V) × |Amperage(A)|`.
- **Per-process / system rails (optional, needs sudo):**
  `sudo powermetrics --samplers battery -n 1` (and on Apple silicon the SMC
  power samplers) give a more detailed breakdown if I ask for depth.

## What to report

1. Adapter: connected? rated wattage?
2. Battery: charging / fully charged / discharging, and current %.
3. Best estimate of **watts flowing right now**, with the
   voltage × amperage figures you used so I can sanity-check it.

Keep it to a short, clear summary. If a value needs `sudo`, ask before running
it rather than assuming.
