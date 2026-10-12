---
name: subagent-routing
description: Details for the subagent-routing rule - running a subagent again at a higher tier, conflicts with skills that dispatch subagents, and changes to the tier table. Read only when the subagent-routing rule points here.
disable-model-invocation: true
---

# Subagent routing: details

This file adds to the subagent-routing rule. The tier table (which model each of light, standard, and strong uses) exists only in the rule. This file uses only the tier names. For tier choice, when to dispatch, splitting the work, review before delivery, and the report format, the rule applies.

## Local additions

The user can keep personal additions in `~/.subagent-routing.local.md` (on Windows: `%USERPROFILE%\.subagent-routing.local.md`). If that file exists, read it after this file. It can contain, for example, tiers for the roles of the user's own skills. If it disagrees with this file, the local file applies. A model that the user names in the conversation still applies first. The local file is read only together with this file, so it cannot change the always-on rule, for example the tier table.

## Run again at a higher tier

**Not acceptable**: one or more of these is true.

- The result does not answer the question, or it leaves out an item that the prompt asked for.
- A conclusion has no evidence: no file path and line, no command and output, and no source link.
- For a list that must be complete, the result does not return the commands it used and the total count, or the total does not agree with the number of items.
- Your own check finds that the result does not agree with the facts.
- The subagent says it is not sure, or it stopped before it finished.
- After a code change, the tests or checks fail.

**What to do**:

1. Run the task again one tier up: light goes to standard, standard goes to strong. Run each task again at most one time. If a strong-tier result is not acceptable, do not run it again; go to step 3.
2. Give the new run three things: the original task, what was not acceptable, and the facts from the first result that you checked yourself. Do not give conclusions that you did not check, because they can mislead the new subagent.
3. If the second result is also not acceptable, do the missing parts yourself where you can. For the parts you cannot do, tell the user what is not solved and where it stopped.

## Conflicts with skills that dispatch subagents

Model choice, from highest priority to lowest:

1. A model that the user names in this session, including an answer that the user gives when a skill asks them. This applies only to that dispatch.
2. The subagent-routing rule.
3. Model instructions in the skill file, for example "inherit the parent model" or "use the same model for all roles".

Whether to dispatch, how many subagents, and foreground or background follow the skill. The limit of 4 subagents at the same time still applies: if a skill asks for more than 4 at the same time, start 4, and start the next one each time one finishes.

### Common skill roles and their tiers

For a role that is not in this table, pick the tier by task type as the rule says. The local additions file can add rows for the user's own skills.

| Role in a skill | Tier |
|---|---|
| Code review, spec review, security review, final review | Strong |
| Read-only exploration: code paths, git history, logs | Standard |
| Implementer that follows a fixed plan or a ticket that already says what to change | Standard |
| Implementer that must make its own design decisions | Strong |
| Merger with no conflicts | Standard |
| Merger that must resolve conflicts | Strong |
| Alternative designs, approaches for a fix, architecture walk-through | Strong |
| Research and summaries | Standard |
| Look up facts in the environment for an interview or planning skill | Light or standard, by task type |

### Skills that ask for different models per role

Some skills ask the user to pick a model strategy for a panel of reviewers or jurors. Apply the user's answer as priority 1, with these limits:

- **Different models**: pick only models at standard tier or higher from the models you can dispatch: the strong and standard tiers, plus flagship models from other vendors at the same level. Use models from different vendors where you can. Do not use the light tier or variants whose name contains `fast`.
- **The same model**: use the strong tier for all roles.

## The tier table and the available models do not agree

The available models are the models that your subagent tool accepts (for example, the model list in the tool description).

- **A tier's model is not available**: dispatch with the model of the next tier up. If the strong tier's model is not available, do not set a model, so that the subagent uses its default model. Tell the user which tier is missing and ask which model to use instead.
- **A newer version of the same model family is available** (for example, the table says version 5 and version 6 is in the list): tell the user that you recommend the change, and continue to dispatch with the table. Change the table only after the user agrees.

How to change the table: change only the line of that tier, where the rule is installed, and keep all other text as it is.

- If the rule was installed by the install script into a file (Claude Code `CLAUDE.md`, Codex `AGENTS.md`), run the install script again and pass all three tier models (`install.ps1` on Windows, `install.sh` on macOS and Linux, in the folder that contains this file's `skills` folder), not only the changed one: a tier that you leave out goes back to a placeholder. The script replaces only its own block.
- If the rule is a Cursor User Rule, update that rule in Cursor Settings. If you have a tool that edits user rules, list the rules first, find the one titled `subagent-routing`, and update only the tier line.
- This file does not change.
