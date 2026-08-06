# Discovery: where model references live, and what they look like

Two lists to make the inventory complete. Neither is a statement of what is
*current* — currency always comes from the provider-authoritative sources in
SKILL.md step 3.

## Where model references hide

Check whichever of these plausibly exist inside the audit scope.

**Agent harnesses and CLIs**

- **Claude Code**: `.claude/settings.json` / `settings.local.json` (`model`,
  `env.ANTHROPIC_MODEL`), `.claude/agents/*.md` frontmatter (`model:` —
  often bare aliases like `sonnet`/`opus`/`haiku`), plugin and hook configs,
  `CLAUDE.md` prose that pins behavior to a model. User-level `~/.claude/`
  equivalents only when the user put them in scope.
- **Codex CLI**: `~/.codex/config.toml` or project `.codex/config.toml`
  (`model`, `model_reasoning_effort`, per-profile overrides), `AGENTS.md`.
- **Other CLIs**: aider (`.aider.conf.yml`), opencode, pi, goose, continue.dev
  (`config.json`/`config.yaml`), Cursor/Zed/Cline/Roo settings exports.

**CI and GitHub**

- **Official Claude GitHub Action**: `.github/workflows/*.yml` steps using
  `anthropics/claude-code-action` / `anthropics/claude-code-base-action` —
  model set via the `model:` input or `claude_args: --model ...`.
- Any workflow env: `ANTHROPIC_MODEL`, `OPENAI_MODEL`, `*_MODEL` vars,
  Dockerfiles, `.env*` files, deploy manifests.

**Multi-agent orchestrators**

- **Firstmate** (kunchenguid/firstmate): an agent distro; its operational home
  (`FM_HOME`, with `config/`, `state/`, `projects/`) holds harness/model
  routing — per-task captain overrides, routing rules, defaults, and the
  crewmate harness choices. Audit the `FM_HOME` config when in scope.
- **Gastown** (Steve Yegge's orchestrator, gastownhall): role-based agents
  (Mayor, Polecats, etc.) each mapped to a harness/model in its config —
  a multi-tier setup whose role structure must be preserved.
- Custom scripts and homegrown routers: grep for SDK constructor calls and
  `model=` / `"model":` assignments.

**Routers and gateways**

- LiteLLM (`config.yaml` `model_list`, fallbacks, routing groups), OpenRouter
  slugs (`provider/model`), Portkey/Helicone/Requesty configs, Vercel AI
  Gateway. These encode deliberate tier/cost structure — inventory each tier
  separately.

**SDK and application code**

- Anthropic SDKs (`model="claude-..."`), OpenAI SDKs, Vercel AI SDK
  (`anthropic('...')`, `openai('...')`), LangChain/LlamaIndex model args,
  Bedrock (`anthropic.claude-...-v1:0`) and Vertex (`claude-...@date`) IDs.
- Embedding, reranker, transcription, TTS, and image models — easy to miss
  because they sit next to the "main" model and rarely get upgraded with it.

## Known model-name families (discovery aid)

This table ages by design. Use it to recognize references and to grep for
shapes the inventory script may have missed — never to decide what exists or
what is current.

| Provider | Name shapes seen in the wild |
|---|---|
| Anthropic | `claude-fable-5`, `claude-opus-5`, `claude-sonnet-5`, `claude-haiku-4-5[-YYYYMMDD]`, `claude-opus-4-x`, `claude-sonnet-4-x`, older dated `claude-3-5-sonnet-20241022`-style pins, `claude-3-*`; Bedrock `anthropic.claude-*`; Vertex `claude-*@date`; Claude Code aliases `fable`/`opus`/`sonnet`/`haiku` |
| OpenAI | `gpt-5.6-sol`, `gpt-5.x`, `gpt-4o[-mini]`, `gpt-4.1`, `gpt-4-turbo`, `o1`/`o3`/`o4-mini` reasoning models, `chatgpt-4o-latest`, `text-embedding-3-small/large`, `whisper-1`, `tts-1`, `dall-e-3`, legacy `text-davinci-*` |
| Google | `gemini-2.x-pro/flash[-lite]`, `gemini-1.5-*`, `gemma-*`, `imagen-*`, `veo-*` |
| Meta | `llama-4-*`, `llama-3.x-*` (often via hosts: Groq, Together, Bedrock) |
| Mistral | `mistral-large/medium/small-*`, `codestral-*`, `ministral-*`, `magistral-*`, `pixtral-*`, `mixtral-*` |
| DeepSeek | `deepseek-chat`, `deepseek-reasoner`, `deepseek-v3*`, `deepseek-r1*` |
| xAI | `grok-4*`, `grok-3*`, `grok-code-*` |
| Cohere | `command-a-*`, `command-r[-plus]`, `embed-english/multilingual-v*` |
| Amazon | `amazon.nova-pro/lite/micro/premier-*`, `amazon.titan-*` |
| Voyage | `voyage-3*`, `voyage-code-*`, `rerank-*` |

Also watch for: date-pinned snapshots (`-20241022`, `@20251001`, `-2025-04-16`),
`-latest` moving aliases, region/endpoint prefixes (`us.anthropic.`,
`global.`), and gateway slugs (`anthropic/claude-sonnet-5`).
