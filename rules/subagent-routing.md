# Subagent routing

Each time you dispatch a subagent (Cursor: `Task` tool; Claude Code: `Agent` tool; Codex: `spawn_agent`), set its model from the tier table below. Treat this as an explicit user request for that model. If the user names a different model in the conversation, use that model for that dispatch.

If you are a subagent yourself, skip the split announcement, the delegation of strong-tier work, and the review before delivery, and dispatch subagents only when your prompt asks you to. Still use the report format that your prompt asks for.

Tier table (models appear only here; to change a model, change only these three lines):
- Light: `{{LIGHT_MODEL}}`
- Standard: `{{STANDARD_MODEL}}`
- Strong: `{{STRONG_MODEL}}`

If a tier still shows a placeholder in angle brackets, do not set the model for that tier, so that the subagent uses its default model. If the strong tier is a placeholder, treat your own model as the strong-tier model. Remind the user once per session to fill in the table.

Pick the tier by task type. If you are not sure, go one tier up:
- Light: high-volume information gathering that needs no judgment. Examples: pull facts from many files or repositories one by one, extract given facts from known web pages, run commands that you wrote and pull the failures or error lines out of long output. You always write the commands.
- Standard: work that needs understanding but no design. Examples: explain code, summarize research, triage CI failures, test in a browser, write code that follows a change you already decided (including the same change across many modules).
- Strong: design, root-cause diagnosis, code and security review, and code that needs its own design decisions.

When to dispatch: do targeted lookups yourself (a known file or symbol, 2-3 files, or one search). Also do design and diagnosis that depend on the conversation yourself, unless your own model is not the strong-tier model (see "Split the work"). Dispatch broad searches, work that would fill your context, work that can run in parallel, and reviews that need a fresh context without your assumptions. Start independent subagents together, at most 4 at a time. Run work whose result you do not need yet in the background.

Split the work: for a task that changes 2 or more files or needs more than one line of investigation, first say in one or two sentences what you do yourself, what you dispatch in parallel, and what goes to the background. Then start; do not wait for confirmation. If your own model is not the strong-tier model, dispatch all strong-tier work (design, root-cause diagnosis, review, also when it depends on the conversation) to a strong-tier subagent, and put the background it needs in its prompt.

Review before delivery: when a change spans more than one file, or touches security, data, or a release, dispatch one strong-tier subagent for an independent review before you deliver. Give it only the diff, the goal, and the acceptance criteria. Fix the problems that you confirm and run the checks again. Put doubtful points and proposed design changes in your delivery note. Do not do this review for small changes (a few lines that do not touch security, data, or a release, even if they span files), or when a running skill has its own review step.

In each dispatch prompt, tell the subagent to give the conclusion first, then the evidence (file:line, commands and their output), then what it did not find or is not sure about. For a list that must be complete, it also returns the commands it used and the total count. Tell it to put the complete answer in its final message, because you receive only that message. In your progress notes, say which model each subagent used and whether you ran it again at a higher tier.

Before you use a subagent's conclusion to change code or to tell the user a result, check 1-2 key pieces of its evidence yourself. If the conclusion is "not found" or "does not exist", check again yourself or run it again one tier up. Read `{{DETAILS_PATH}}` first when you need to run a subagent again at a higher tier, when a running skill prescribes how to dispatch subagents, when the user asks to change the tier table, or when the tier table and the models you can dispatch do not agree (a tier's model is missing, or a newer version of the same model family is available).
