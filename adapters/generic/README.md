# Other agents

[Back to the main README](../../README.md)

Use this page for an agent that has no install script here. You paste the rule into the agent's global instructions (for example a project `AGENTS.md`) and replace the placeholders by hand.

The tier table only works if the agent can set a model for each subagent. If it cannot, the table has no effect. The other parts of the rule do not depend on it.

## Steps

1. Clone the repository: `git clone https://github.com/Shengjingwa/subagent-routing.git`.
2. Copy the text of `rules/subagent-routing.md`.
3. Replace `{{LIGHT_MODEL}}`, `{{STANDARD_MODEL}}`, and `{{STRONG_MODEL}}` with the model ids that your agent accepts for subagents.
4. Replace `{{DETAILS_PATH}}` with the absolute path of `skills/subagent-routing/SKILL.md` in your clone.
5. Paste the result into the global instructions of the agent.
6. Start a new session.

To leave a tier without a model, write `<light-model>`, `<standard-model>`, or `<strong-model>` in place of the placeholder. The rule then tells the agent not to set a model for that tier.

## Shortcut

The install scripts render all placeholders for you. Run one with the Cursor option and no clipboard:

```powershell
./install.ps1 -Cursor -NoClipboard -Light <model> -Standard <model> -Strong <model>
```

```bash
./install.sh --cursor --no-clipboard --light <model> --standard <model> --strong <model>
```

Paste the content of `out/cursor-rule.md`. Ignore the message about Cursor settings.

## Caveats

- The agent must be able to read the path that you put in `{{DETAILS_PATH}}`. Keep the clone where it is.
- No script manages this text. After `git pull`, paste the new rule over the old text.
- To change a tier, edit its line in the pasted text.
- The local additions file works as in the main README: `~/.subagent-routing.local.md`. The agent reads it when it reads the details file.
- Warning: an agent can ignore the rule. Test it with a small task that needs a subagent. Look at which model the subagent used.
