# subagent-routing

[简体中文](README.zh-CN.md)

subagent-routing is a plain-text rule that tells your coding agent (Cursor, Claude Code, or Codex) how to use subagents. The agent splits the work, picks a model for each subagent from a three-tier table, and checks what the subagents report.

A subagent is a second agent that the main agent dispatches for one task. It works in a fresh context, and several can run in parallel. It also costs time and money, and its answer can be wrong.

The rule is always on: the agent reads it in every session. A second file holds the details, and the agent reads it only in specific cases. There are no hooks and no runtime code. The rule is only text, so nothing forces the agent to follow it.

## What the rule makes the agent do

1. For a task that changes 2 or more files, say what it does itself, what it dispatches in parallel, and what goes to the background. Then begin the work.
2. Pick the tier of each subagent from the tier table, by task type. A tier can list one model or comma-separated models from different model families (for example, Claude and Gemini). If the chosen tier lists a model in the main model's family, use it; otherwise let the subagent inherit the main model by default. Never take a model of another family from the table; use one only for the work that the user names it for in a message, or when a running skill asks for models of different vendors.
3. Send strong-tier work (design, diagnosis) to a strong-tier subagent when the table has a strong-tier model in the main model's family and the main model is weaker.
4. Dispatch a review subagent only when the user or a running skill asks for one. Reviews run at the standard tier.
5. Ask each subagent for the conclusion first, then the evidence, then what it is not sure about. The full answer goes in the final message.
6. Check 1-2 key pieces of evidence before it uses a subagent's conclusion.
7. Continue a subagent that stopped on a provider or connection error once (in Cursor, with `resume` and its full Agent ID); if it stops again, give a new subagent a smaller share. Size batch work so that each subagent finishes in about 30 minutes. Run a failed subagent again: one tier up (inheriting the main model if the higher tier has no model for that family), or once with a fresh subagent at the same model if already at the top tier or already inheriting the main model.

A subagent reads the rule too, if its agent loads the same instructions. The rule tells it to skip steps 1 and 3, and to dispatch only when its prompt asks.

The tier table has three tiers:

| Tier | Task type |
|---|---|
| Light | Read-only lookups, routine code/git/log scouting, or running existing commands and scripts |
| Standard | Synthesis, rubric-based verification, MR follow-up, independent code, spec, and security reviews (first pass and incremental), and code changes where the design is already decided |
| Strong | Open-ended design, hard root-cause diagnosis, and code that must make its own design decisions |

When not sure between Light and Standard on read-only work or running commands, the agent starts with Light. When not sure between Standard and Strong on code changes, verification, or analysis, it uses Standard.

## Install

You need `git`, and PowerShell (Windows) or a Bash shell (macOS, Linux, Git Bash). Select at least one agent. This example installs for Claude Code.

Windows:

```powershell
git clone https://github.com/Shengjingwa/subagent-routing.git
cd subagent-routing
./install.ps1 -Claude -Light haiku -Standard sonnet -Strong opus
```

If PowerShell says that running scripts is disabled, start the script this way: `powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Claude -Light haiku -Standard sonnet -Strong opus`.

macOS, Linux, or Git Bash:

```bash
git clone https://github.com/Shengjingwa/subagent-routing.git
cd subagent-routing
./install.sh --claude --light haiku --standard sonnet --strong opus
```

Start a new chat or session after you install.

Both scripts take the same options. The first column is for `install.ps1`, the second for `install.sh`.

| `install.ps1` | `install.sh` | What it does |
|---|---|---|
| `-Cursor` | `--cursor` | Writes `out/cursor-rule.md` and copies it to the clipboard |
| `-Claude` | `--claude` | Writes a marked block into `CLAUDE.md` |
| `-Codex` | `--codex` | Writes a marked block into `AGENTS.md` |
| `-Light`, `-Standard`, `-Strong` | `--light`, `--standard`, `--strong` | Sets the model of a tier |
| `-Uninstall` | `--uninstall` | Removes what the script wrote |
| `-NoClipboard` | `--no-clipboard` | Does not copy the Cursor rule to the clipboard |

Each agent has its own page with the steps, the file that changes, and caveats:

| Agent | Where the rule ends up | Page |
|---|---|---|
| Cursor | `out/cursor-rule.md`, which you paste into User Rules | [adapters/cursor](adapters/cursor/README.md) |
| Claude Code | A block in `CLAUDE.md` in `$CLAUDE_CONFIG_DIR` or `~/.claude` | [adapters/claude](adapters/claude/README.md) |
| Codex | A block in `AGENTS.md` in `$CODEX_HOME` or `~/.codex` | [adapters/codex](adapters/codex/README.md) |
| Any other agent | Text that you paste by hand | [adapters/generic](adapters/generic/README.md) |

These tier models are examples. Use the model names that your agent accepts for subagents.

| Agent | Light | Standard | Strong |
|---|---|---|---|
| Cursor | `claude-haiku-5-5-thinking-xhigh` | `claude-sonnet-5-5-xhigh` | `claude-opus-5-5-xhigh` |
| Claude Code | `haiku` | `sonnet` | `opus` |
| Codex | A small, fast model | A mid-size model | The model of your main session |

Notes for all agents:

- One run uses one set of tier models. Run the script once for each agent, because each agent accepts different model names.
- A tier that you leave out stays a placeholder such as `<light-model>`. The rule then tells the agent not to set a model for that tier. It also tells the agent to remind you once per session.
- The script keeps the existing content of a file. It writes a backup, `<file>.subagent-routing.bak`, before each change. The backup holds the file as it was before the last change. When you run it again, it replaces only its own block.
- Warning: keep the clone where it is. The rule points to the details file by absolute path. If you move the clone, run the script again.

## Change tiers

Run the install command again with the new model names. Pass all three tiers every time, because a tier that you leave out goes back to a placeholder. The script replaces its old block.

- Cursor: paste the new `out/cursor-rule.md` over the old User Rule.
- Other agents: edit the three tier lines in the text that you pasted.

## Update

Run `git pull`. Then run the install command again with the same options.

## Uninstall

Run the install command with the uninstall option:

```powershell
./install.ps1 -Claude -Codex -Uninstall
```

```bash
./install.sh --claude --codex --uninstall
```

The script removes only its own block and keeps the rest of the file. If the file held only that block, the script deletes the file and keeps the backup. If that file is a symbolic link, the script keeps the link and empties the file that it points to. For Codex, uninstall removes the block from both `AGENTS.md` and `AGENTS.override.md`.

Uninstall gives back the original bytes, including the line ending of each line, the BOM, and text in any encoding. If the file did not end with a newline, install adds one before the block and notes this in the begin marker. Uninstall then removes the newline at the end of the file again. If you added text after the block, that newline stays, so that no lines run together. An empty file that you install into is deleted on uninstall, like a file that held only the block.

Cursor: delete the User Rule titled `subagent-routing` in Cursor Settings > Rules. The `-Cursor -Uninstall` option deletes `out/cursor-rule.md` and prints a reminder.

## Local additions file

You can keep personal additions in `~/.subagent-routing.local.md`. On Windows the path is `%USERPROFILE%\.subagent-routing.local.md`. The install script does not create this file. You create it.

The file can hold, for example, tiers for the roles of your own skills. If it disagrees with the details file, the local file applies. A model that you name in the conversation still applies first.

The agent reads this file when it reads the details file. That happens only in specific cases, for example when it runs a subagent again at a higher tier, or when a skill says how to dispatch subagents. So the file cannot change the always-on rule, for example the tier table.

## Related projects

These projects solve parts of the same problem. The facts below are from 2026-10-12.

- [foxhatleo/leos-agent](https://github.com/foxhatleo/leos-agent): a policy layer for Claude Code, Codex, Cursor, and OpenCode. It routes model and reasoning effort by tier, and adds a review gate, hooks, and a dispatch log. Its README says native Windows is not supported.
- [AqueGen/model-routing](https://github.com/AqueGen/model-routing): a Claude Code plugin with pinned subagents, a routing skill, and a hook that counts dispatches.
- [liuhl152/cursor-subagent-delegation](https://github.com/liuhl152/cursor-subagent-delegation): Cursor rules and skills. A `preToolUse` hook denies a `Task` call that has no explicit model. The project also keeps a delegation log. It needs Bash and `jq`.
- [obra/superpowers](https://github.com/obra/superpowers): a large skills framework. Its `subagent-driven-development` skill has a model-selection section (cheap, standard, most capable).

What is different here:

- It is only text: one rule and one details file. It has no hooks and no runtime.
- One rule text works for three agents. Installers exist for Windows and for macOS/Linux.
- It covers when to dispatch, how to split the work, how to review, and how to check results. It does not cover only which model to use.

A hook can enforce a choice, and text cannot. If you need enforcement or a dispatch log, use one of the projects above.

## Design notes

[docs/design.md](docs/design.md) explains why this is rule text and not a hook. It also lists what the author measured.

## License

MIT. See [LICENSE](LICENSE).
