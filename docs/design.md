# Design notes

[Back to the main README](../README.md)

These notes explain why subagent-routing is built as it is. The measurements are the author's own, taken in 2026 on the author's own tasks. They are not a benchmark.

## Why an always-on rule and not a skill

Whether to dispatch a subagent is a decision in every task. An agent loads a skill only when it thinks the skill applies. For this decision, that is too late. So the rule is always on.

The details live in a separate file. The agent reads it only in specific cases, such as a rerun or a conflict with a skill. This keeps the always-on text short.

## Why not a hook

A hook can set a model, but it cannot pick the right tier. The tier depends on the task type, and that is a judgment about the task text. A hook can only apply a fixed mapping. The rule also covers decisions that a hook does not see: whether to dispatch at all, how to split the work, and when to ask for a review.

Hooks also differ for each agent. In Cursor, a `subagentStart` hook can only allow or deny a subagent. A `preToolUse` hook can rewrite the input of the `Task` tool (`updated_input`), and so it can change the model. Plain rule text works in all three agents: Cursor, Claude Code, and Codex.

The price is that nothing enforces the rule. The agent can ignore it.

## What a dispatch costs

- Each dispatch has a fixed overhead. A trivial file-count task on a light model took about 20 seconds. Typical small tasks took 1-3 minutes. An independent code review on a strong model took 7-12 minutes.
- The subagent does not see the conversation. The prompt must carry the background.
- The parent must check the result, and that takes time.
- Tasks that depend on each other in series cannot run in parallel.

For this reason, the rule tells the agent to do targeted lookups itself.

## What the measurements showed

- Speed comes from running subagents in parallel and in the background. It does not come from cheaper models.
- On small tasks, a cheaper model that was labelled faster was not faster end to end. It also gave the weakest answers.
- On one task, a mid-tier model took the same time as the strong model. On another task, it was about 1.5 times faster.

## Why a fresh context matters

Independent reviews found real bugs that the author had missed:

- A hook silently allowed every command, because its input started with a byte-order mark.
- A maintenance script would crash on an empty configuration object.

For this reason, the rule asks for one independent strong-tier review before the agent delivers a multi-file or risky change. The reviewer gets only the diff, the goal, and the acceptance criteria.

## Why the final message holds the full answer

A strong-model subagent once put its full answer in a message that was not the final message. The parent receives only the final message, so that answer did not reach the parent. The rule now requires the full answer in the final message.

## Why a named model covers only its own work

A user who names a model usually names it for one piece of work, such as two independent drafts from two vendors. Agents carried the name over to later dispatches in the same chat. In one chat, a Gemini main agent sent a routine re-review to a Claude model that the user had named only for an earlier evaluation. So the rule applies a named model only to the work it was named for, and the other dispatches follow the tier table.

## Why batch subagents write in chunks

With at most 4 subagents for a batch, each subagent had about 80 items. One subagent tried to put all its results, about 230 KB, in one message. The connection to the model provider failed after 5 minutes, and none of the results were saved. When a subagent writes its results to a file about 20 items at a time, each message stays short, and a failed run keeps its finished items.

## Why a failed subagent is continued, not restarted

When a subagent stops on a provider or connection error, Cursor reports its Agent ID so that the agent can send a follow-up. Main agents started new subagents instead, and the new subagents did all the reading again. When the agent continues the same subagent, that work is kept. The ID must be complete: shortened IDs and made-up IDs failed with "Composer not found for resume".

## Why the parent checks the evidence

A subagent can be wrong. One reviewer said that a logged field was wrong. The live data showed that the field was right.

For this reason, the rule makes the parent check 1-2 key pieces of evidence before it uses a conclusion. If the conclusion is "not found", the parent checks again or runs the subagent again one tier up.

## What the rule does not do

- It does not enforce anything. There is no hook and no runtime code.
- It does not write a dispatch log. It only asks the agent to name the model of each subagent in its progress notes.
