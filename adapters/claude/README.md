# Claude Code

[Back to the main README](../../README.md)

The install script writes the rule as a marked block into `CLAUDE.md` in the Claude Code config directory.

## Install

```powershell
./install.ps1 -Claude -Light haiku -Standard sonnet -Strong opus
```

```bash
./install.sh --claude --light haiku --standard sonnet --strong opus
```

Start a new Claude Code session after you install.

## Where the rule ends up

- File: `CLAUDE.md` in `$CLAUDE_CONFIG_DIR`, or in `~/.claude` if the variable is not set. On Windows, `~` is your user profile folder.
- The block starts with a line that begins `<!-- >>> subagent-routing` and ends with a line that begins `<!-- <<< subagent-routing`.
- Warning: do not edit inside the block. The next run replaces it. Text outside the block stays as it is.
- Before each change, the script writes a backup, `CLAUDE.md.subagent-routing.bak`, in the same folder.
- Warning: keep the clone where it is. The block points to the details file by absolute path.

## Example tiers

These are examples. The aliases `haiku`, `sonnet`, and `opus` work. Full model ids also work.

| Tier | Example |
|---|---|
| Light | `haiku` |
| Standard | `sonnet` |
| Strong | `opus` |

## Caveats

The subagent tool is `Agent`. It was `Task` before v2.1.63, and `Task` still works as an alias. Claude can pass a `model` parameter for each call, and the rule makes it do so.

Claude Code picks the model of a subagent in this order:

1. The `model` parameter of the call.
2. The `model` field in the subagent's file.
3. The `CLAUDE_CODE_SUBAGENT_MODEL` variable.
4. The main model.

The rule sets the first item. The tier table therefore wins over the `model` field of a custom subagent.

- Warning: if `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` is set (v2.1.257 or later), Claude cannot pass a model for a call. The tier table then has no effect. Unset the variable to use the table.
- Before v2.1.251, `CLAUDE_CODE_SUBAGENT_MODEL` overrode the `model` parameter of the call. With an older version, unset it.
- If an installed mod sets a model in its `agent.spawn` hook, Claude Code uses that model instead of the `model` parameter.
- If your organization has an `availableModels` allowlist, Claude Code replaces a tier model that is not on it with another model.
- Subagents other than Explore and Plan also load `CLAUDE.md`, so they read the rule too. The rule tells a subagent not to split the work, delegate, or ask for a review unless its prompt asks.
- To use the rule in one project only, paste it into that project's `CLAUDE.md`. See [the generic page](../generic/README.md).

## Uninstall

```powershell
./install.ps1 -Claude -Uninstall
```

```bash
./install.sh --claude --uninstall
```

The script removes only its own block.

## Docs

- [Claude Code subagents](https://code.claude.com/docs/en/sub-agents)
