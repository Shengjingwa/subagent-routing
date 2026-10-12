# Codex

[Back to the main README](../../README.md)

The install script writes the rule as a marked block into the global instructions file of Codex CLI.

## Install

Use model slugs that your Codex accepts. The `/model` picker shows them. In this example, replace each placeholder in angle brackets with a slug:

```powershell
./install.ps1 -Codex -Light <fast-model> -Standard <mid-model> -Strong <main-model>
```

```bash
./install.sh --codex --light <fast-model> --standard <mid-model> --strong <main-model>
```

Start a new Codex session after you install.

## Where the rule ends up

- File: `AGENTS.md` in `$CODEX_HOME`, or in `~/.codex` if the variable is not set.
- If `AGENTS.override.md` exists in that folder and is not empty, the script writes the block there. Codex reads only the override file in that case.
- If you add a non-empty override file after you install, run the script again. It writes the block into the override file and warns that `AGENTS.md` still has the old block. Uninstall removes the block from both files.
- The block starts with a line that begins `<!-- >>> subagent-routing` and ends with a line that begins `<!-- <<< subagent-routing`. Do not edit inside it. The next run replaces it.
- Before each change, the script writes a backup, `<file>.subagent-routing.bak`, in the same folder.
- Warning: keep the clone where it is. The block points to the details file by absolute path.

## Example tiers

Codex has no fixed tier names. Use this pattern, so that the main agent is itself strong-tier:

| Tier | Model |
|---|---|
| Light | A small, fast model |
| Standard | A mid-size model |
| Strong | The model of your main session |

## Caveats

- The subagent tool is `spawn_agent`. It accepts `model` and `reasoning_effort`. The rule sets only the model.
- Codex delegates when you ask, or when `AGENTS.md` or skill instructions ask. The rule is such an instruction.
- A subagent that gets its own model starts without the conversation history (`fork_turns` set to `"none"`). A fork with the full history keeps the parent's model. So the dispatch prompt must carry the background that the subagent needs.
- Warning: if `config.toml` sets `expose_spawn_agent_model_overrides = false` under `[features.multi_agent_v2]`, `spawn_agent` has no `model` parameter. The tier table then has no effect.
- A model that the agent passes at spawn overrides `agents.default_subagent_model` in `config.toml`.
- A custom agent file that sets `model` takes precedence over the model that the agent passes at spawn.
- To use the rule in one project only, paste it into that project's `AGENTS.md`. See [the generic page](../generic/README.md).

## Uninstall

```powershell
./install.ps1 -Codex -Uninstall
```

```bash
./install.sh --codex --uninstall
```

The script removes only its own block, from `AGENTS.md` and from `AGENTS.override.md` if that file exists.

## Docs

- [Codex subagents](https://developers.openai.com/codex/subagents)
- [Codex AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md)
- The `spawn_agent` tool and its `model` and `reasoning_effort` parameters are in the Codex source: [multi_agents_spec.rs](https://github.com/openai/codex/blob/main/codex-rs/core/src/tools/handlers/multi_agents_spec.rs) and [multi_agent_instructions.rs](https://github.com/openai/codex/blob/main/codex-rs/prompts/src/multi_agent_instructions.rs).
