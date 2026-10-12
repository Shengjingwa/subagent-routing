# Cursor

[Back to the main README](../../README.md)

Cursor keeps User Rules in its settings, not in a file. The install script cannot write them. It writes the rule to `out/cursor-rule.md` in your clone and copies it to the clipboard. You then add it to Cursor.

## Install

Run the script with tier models that your Cursor accepts for subagents. The `Task` tool lists them.

```powershell
./install.ps1 -Cursor -Light claude-haiku-5-5-thinking-xhigh -Standard claude-sonnet-5-5-xhigh -Strong claude-opus-5-5-xhigh
```

```bash
./install.sh --cursor --light claude-haiku-5-5-thinking-xhigh --standard claude-sonnet-5-5-xhigh --strong claude-opus-5-5-xhigh
```

Then:

1. Open Cursor Settings > Rules > User Rules.
2. Add a rule with the title `subagent-routing`. Paste the rule text. If a rule with that title exists, replace its text.
3. Start a new chat.

Instead of step 2, you can ask a Cursor agent: `Add the content of out/cursor-rule.md as a user rule titled subagent-routing.` Use the full path that the script prints.

## Where the rule ends up

- In your User Rules, under the title `subagent-routing`.
- As `out/cursor-rule.md` in the clone. Git ignores `out/`.

## Example tiers

These ids are examples. Use the ids that your Cursor accepts.

| Tier | Example model id |
|---|---|
| Light | `claude-haiku-5-5-thinking-xhigh` |
| Standard | `claude-sonnet-5-5-xhigh` |
| Strong | `claude-opus-5-5-xhigh` |

A model id can carry parameters in square brackets, for example `claude-opus-5[effort=high]`. The script accepts this form. Put quotes around the id:

```powershell
./install.ps1 -Cursor -Light claude-haiku-5-5-thinking-xhigh -Standard claude-sonnet-5-5-xhigh -Strong 'claude-opus-5[effort=high]'
```

## Caveats

- The subagent tool is `Task`. The main agent can name a model for each call.
- The script cannot read or edit User Rules. To change a tier, run the script again and paste the new text over the old rule.
- Cursor can use another model if your team admin blocks the model or your plan does not include it. The subagent task card shows which model ran.
- Each request bills at the list price of the model that ran. A subagent can use a different model than the parent chat.
- A Cursor `subagentStart` hook can only allow or deny a subagent. A `preToolUse` hook can rewrite the `Task` input, including the model, but it cannot judge the task type. See [the design notes](../../docs/design.md#why-not-a-hook).
- Warning: keep the clone where it is. The rule points to the details file by absolute path.
- To use the rule in one project only, paste it into that project's `AGENTS.md`. Cursor reads `AGENTS.md` in projects. See [the generic page](../generic/README.md).

## Uninstall

Delete the User Rule titled `subagent-routing` in Cursor Settings > Rules. The `-Cursor -Uninstall` option (`--cursor --uninstall` for `install.sh`) deletes `out/cursor-rule.md`.

## Docs

- [Cursor subagents](https://cursor.com/docs/context/subagents)
- [Cursor rules](https://cursor.com/docs/context/rules)
- [Cursor hooks](https://cursor.com/docs/hooks)
