---
name: subagent-routing
description: Details for the subagent-routing rule - running a subagent again when its result is not acceptable, conflicts with skills that dispatch subagents, and changes to the tier table. Read only when the subagent-routing rule points here.
disable-model-invocation: true
---

# Subagent routing: details

This file adds to the subagent-routing rule. The tier table (which model each of light, standard, and strong uses) exists only in the rule. This file uses only the tier names. For tier choice, when to dispatch, splitting the work, and the report format, the rule applies.

## Local additions

The user can keep personal additions in `~/.subagent-routing.local.md` (on Windows: `%USERPROFILE%\.subagent-routing.local.md`). If that file exists, read it after this file. It can contain, for example, tiers for the roles of the user's own skills. If it disagrees with this file, the local file applies. A model that the user names in the conversation still applies first. The local file is read only together with this file, so it cannot change the always-on rule, for example the tier table.

## Run a subagent again

**Stopped on an error**: a subagent that stopped on a provider or connection error (Cursor reports `Provider Error` and an `Agent ID`) has not given a bad result yet. Continue it once with `resume` and that full 36-character ID, and ask it to save what it has to disk before it goes on. A shortened or made-up ID fails with `Composer not found for resume`; the file names under `agent-transcripts/<chat>/subagents/` are the full IDs. If the continued run also fails, or the subagent cannot be continued, treat the result as not acceptable.

**Not acceptable**: one or more of these is true.

- The result does not answer the question, or it leaves out an item that the prompt asked for.
- A conclusion has no evidence: no file path and line, no command and output, and no source link.
- For a list that must be complete, the result does not return the commands it used and the total count, or the total does not agree with the number of items.
- Your own check finds that the result does not agree with the facts.
- The subagent says it is not sure, or it stopped before it finished.
- After a code change, the tests or checks fail.

**What to do**:

1. Run the task again one tier up: light goes to standard, standard goes to strong. Use the new tier's model for your model family, or omit the model if the new tier has no model in your family so that the subagent inherits your model. Run each task again at most one time. If the first run was already at the strong tier (or already inherited your model), run the task again at most one time with a fresh subagent at that same model; if the second result is also not acceptable, go to step 3.
2. Give the new run three things: the original task, what was not acceptable, and the facts from the first result that you checked yourself. Do not give conclusions that you did not check, because they can mislead the new subagent. For batch work, also name the items that the first run already wrote to disk, so that the new run does only the rest.
3. If the second result is also not acceptable, do the missing parts yourself where you can. For the parts you cannot do, tell the user what is not solved and where it stopped.

## Conflicts with skills that dispatch subagents

Model choice, from highest priority to lowest:

1. A model that the user names for a piece of work, including an answer that the user gives when a skill asks them. It applies only to the dispatches for that work.
2. The subagent-routing rule.
3. Model instructions in the skill file, for example "inherit the parent model" or "use the same model for all roles".

Whether to dispatch, how many subagents, and foreground or background follow the skill. The limit of 4 subagents at the same time still applies: if a skill asks for more than 4 at the same time, start 4, and start the next one each time one finishes.

### Common skill roles and their tiers

For a role that is not in this table, pick the tier by task type as the rule says. The local additions file can add rows for the user's own skills.

| Role in a skill | Tier |
|---|---|
| First-pass code review, spec review, security review, final review | Standard |
| Re-review of incremental fixes after an initial review | Standard |
| Locate files, symbols, settings, or doc citations; routine read-only scouting of code paths, git history, or logs; look up tool or product docs (such as `cursor-guide`); run an existing command, script, or test and collect output or errors | Light |
| Cross-module multi-step code analysis; grade items against a fixed rubric; fact-check a report against local files; follow MRs and fix routine pipeline/review issues | Standard |
| Implementer that follows a fixed plan, a decided change (including running offline evaluations), or reviewer/user feedback | Standard |
| Implementer that must make its own design decisions | Strong |
| Merger with no conflicts | Standard |
| Merger that must resolve conflicts | Strong |
| Alternative designs, approaches for a fix, architecture walk-through | Strong |
| Research and summaries; CI failure triage (`ci-investigator`); browser testing (`browser-use`) | Standard |
| Look up facts in the environment for an interview or planning skill | Light (or standard when synthesis is needed) |

### Skills that ask for different models per role

Some skills ask the user to pick a model strategy for a panel of reviewers or jurors. Apply the user's answer as priority 1, with these limits:

- **Different models**: pick only models at standard tier or higher from the models you can dispatch: the strong and standard tiers, plus flagship models from other vendors at the same level. Use models from different vendors where you can. Do not use the light tier or variants whose name contains `fast`. Besides a model that the user names, this is the only case in which you set a model of another family than your own.
- **The same model**: use the strong-tier model for your family if the table has one; otherwise let all roles inherit your own model.

## The tier table and the available models do not agree

The available models are the models that your subagent tool accepts (for example, the model list in the tool description). Check only the models in the tier table that belong to your own model's family.

- **A tier's model is not available**: dispatch with the model of the next tier up. If the strong tier's model is not available, do not set a model, so that the subagent uses its default model. Tell the user which tier is missing and ask which model to use instead.
- **A newer version of the same model family is available** (for example, the table says version 5 and version 6 is in the list): tell the user that you recommend the change, and continue to dispatch with the table. Change the table only after the user agrees.

How to change the table: change only the line of that tier, where the rule is installed, and keep all other text as it is.

- If the rule was installed by the install script into a file (Claude Code `CLAUDE.md`, Codex `AGENTS.md`), run the install script again and pass all three tier models (`install.ps1` on Windows, `install.sh` on macOS and Linux, in the folder that contains this file's `skills` folder), not only the changed one: a tier that you leave out goes back to a placeholder. The script replaces only its own block.
- If the rule is a Cursor User Rule, update that rule in Cursor Settings. If you have a tool that edits user rules, list the rules first, find the one titled `subagent-routing`, and update only the tier line.
- This file does not change.
