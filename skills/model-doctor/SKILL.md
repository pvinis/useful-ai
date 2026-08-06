---
name: model-doctor
description: Audit the AI model references in a repo, config directory, or file set and check them against official provider documentation. Use when asked whether configured models are current, outdated, or deprecated, when a provider ships a new model or family and configs may be stale, when upgrading model IDs in agent harnesses (Claude Code, Codex, GitHub Actions, routers, SDK code), or when the user says "model doctor", "are my models stale", "audit my model configs", or "upgrade my models". Read-only by default; edits only with explicit per-change approval.
---

# Model Doctor

Audit model references in a user-supplied scope, determine whether each one is
still current using provider-authoritative sources, and offer approval-first
upgrades. Diagnosis is free and read-only; treatment requires explicit consent.

## Rules that do not bend

- **Read-only by default.** The audit produces a report. Do not edit anything
  until the user approves a specific change from that report.
- **Explicit scope only.** Audit the paths the user supplied, or the current
  repository if they supplied none. Never scan the whole home directory or
  wander outside the scope, even "just to check". If the user wants their
  personal configs audited, they must name the directories.
- **Authoritative sources only.** Model availability comes from official
  provider docs, official model-listing endpoints, or the local CLI's own
  catalog. Blogs, Reddit, chat memory, training-data recall, and model-name
  guessing establish nothing — a plausible-sounding ID is not an available ID.
- **No paid calls.** Never make a model/inference call to probe availability
  unless the user approves it. Metadata-only endpoints (e.g. a provider's
  `GET /models` list) consume no tokens and are fine when a key is already
  configured.
- **No background anything.** Do not schedule recurring audits, create Login
  Items, cron jobs, or services. A periodic audit is a separate opt-in the
  user must ask for.

## Workflow

### 1. Establish scope

Confirm what to audit: the paths/repo the user named, else the current
repository. State the scope at the top of the report so a wrong assumption is
visible immediately.

### 2. Inventory

Run the deterministic scanner:

```bash
python3 scripts/inventory.py <scope-path> [more-paths] [--json]
```

It finds model-reference candidates with file:line, provider guess, and a
path-based context hint (config, lockfile, fixture, historical-doc, vendored,
generated). It is read-only and never leaves the given paths.

Then read each hit in context and build the real inventory. The script finds
strings; you decide what they are. Consult `references/discovery.md` for the
places model references hide (harness configs, GitHub Actions, routers,
orchestrators like Firstmate and Gastown, SDK code, env vars) and for known
model-name families the regexes may have missed — grep for those too if the
scope plausibly contains them.

For every reference record:

- **Reference**: exact model ID or alias string
- **Location**: file:line (all occurrences)
- **Provider and harness**: e.g. Anthropic via Claude Code settings, OpenAI via
  LiteLLM router, Anthropic via Bedrock ID
- **Settings that ride along**: reasoning/effort level, thinking budget,
  temperature, max tokens
- **Routing position**: primary, fallback, or one tier of a router
- **Active vs historical**: active configuration vs changelogs, docs about the
  past, fixtures, snapshots, eval baselines, examples, lockfiles, vendored or
  generated code. Historical material is *reported* (in "Skipped") but never
  proposed for change unless the user explicitly asks.
- **Inferred role**: what job this model does — frontier planner, balanced
  worker, economical worker, reviewer/judge, visual worker, embedding,
  voice/transcription, image generation. Infer from context (variable names,
  agent names, tier position, comments), and say what the inference is based on.

### 3. Research current models

For each provider present in the inventory, establish the current catalog from
its authoritative source. Check both "what is current" and "what is deprecated
or scheduled for retirement".

| Provider | Authoritative sources |
|---|---|
| OpenAI | The official developer docs. If the `openai-docs` skill is installed (Codex ships it in `$CODEX_HOME/skills/.system/openai-docs`, default `~/.codex/skills/.system/openai-docs`), run its resolver first: `sh <dir>/scripts/resolve-latest-model-info` → JSON with `model` + migration/prompting guide URLs. Otherwise fetch `https://developers.openai.com/api/docs/guides/latest-model.md` and the platform docs' models + deprecations pages. |
| Anthropic | Model docs at `https://platform.claude.com/docs/en/docs/about-claude/models/overview` (docs.anthropic.com redirects there) and the model-deprecations page. Cross-check what the locally installed Claude CLI supports (its documented model aliases / release notes) — the API catalog and the CLI catalog can differ. The `GET /v1/models` API lists availability without token cost. |
| Google | `https://ai.google.dev/gemini-api/docs/models` (and Vertex AI model docs for Vertex IDs). |
| Others detected | That provider's official model documentation or model-listing API (Mistral, xAI, Cohere, Meta/Llama hosts, AWS Bedrock catalog, OpenRouter's public `GET /api/v1/models`, Ollama's local `ollama list`). |

If a provider's status genuinely cannot be established from an authoritative
source, that is a finding (UNVERIFIABLE), not a license to guess.

### 4. Classify each active reference

- **CURRENT** — the provider's current offering for that role/tier, or a
  supported pinned snapshot with no newer snapshot in its family.
- **DIRECT SUCCESSOR AVAILABLE** — a newer model exists that preserves *all* of:
  provider, workload tier, intended role, endpoint/tool compatibility,
  reasoning-effort support, and broadly comparable cost/latency. If any of
  those changes, it is not a direct successor.
- **NEW FAMILY/TIER AVAILABLE** — newer options exist but differ in family,
  tier, capability, price class, or the mapping is ambiguous.
- **DEPRECATED OR REMOVED** — the provider marks it deprecated, retiring, or
  already gone.
- **UNVERIFIABLE** — status cannot be established from authoritative sources.

For DIRECT SUCCESSOR: propose the smallest exact diff and note any known
behavioral differences from the provider's migration notes.

For NEW FAMILY/TIER (and ambiguous successors): do the deeper comparison —
capability, cost, latency, context window, tool support, modalities, effort
levels, deprecation status, migration risks — using authoritative data only,
and recommend a role-by-role mapping. Where authoritative data doesn't cover a
dimension, say so rather than filling it in.

Two invariants when proposing replacements:

- **Never collapse a multi-tier router into the newest flagship.** A
  planner/worker/cheap-tier split exists for cost and latency reasons; map each
  tier to its counterpart in the new lineup.
- **Never silently swap pinned snapshots for moving aliases, or aliases for
  pins.** Pinning is a deliberate reproducibility choice; aliasing is a
  deliberate freshness choice. If the migration forces a change of kind (or a
  change to effort/routing behavior), surface it as its own decision.

### 5. Report and stop

Present the approval screen and wait. A general request like "upgrade my
models" authorized the *audit*, not the edits — approval means the user answers
the Decisions list ("apply 1 and 3", or "apply all" after seeing it).

```markdown
## Model Doctor — <scope>

### Inventory
| Reference | Location | Provider/harness | Effort | Role | Status |

### Findings (one block per non-CURRENT active reference)
- Current reference and location(s)
- Inferred role (and evidence for the inference)
- Status, with authoritative evidence links
- Proposed replacement (exact string) — or role-mapping options for a new family
- Implications: behavior, cost, latency, compatibility
- Exact files/lines that would change

### Decisions needed
1. <finding> → <proposed change> — approve / skip / discuss

### Skipped
Historical, fixture, lockfile, vendored hits left alone; UNVERIFIABLE items.
```

### 6. Apply approved changes only

Make exactly the approved edits — smallest possible diffs, no drive-by
cleanups, nothing from the skip list.

### 7. Validate after editing

- Re-parse every edited config: JSON (`python3 -c 'import json,sys; json.load(open(sys.argv[1]))'`),
  TOML (`tomllib`), YAML (project tooling or `python3 -c 'import yaml,...'` if
  available). Syntax-check edited code files.
- Run the repository's relevant tests/linters if it has them.
- Verify the local CLI/harness accepts the new IDs via its catalog or docs —
  without paid inference calls. Offer a one-shot smoke test only as an explicit
  user-approved option.
- Re-run the inventory and report what remains: intentionally unchanged
  references, skipped items, and anything still UNVERIFIABLE.

## Red flags — stop if you catch yourself thinking

- "This model name obviously exists" → verify against the provider source.
- "I'll just update all of these while I'm here" → only approved items.
- "The flagship is better, one model is simpler" → tiers exist for a reason.
- "The alias is basically the same as the pin" → it is a behavior change.
- "The home directory probably has more configs" → out of scope unless named.
