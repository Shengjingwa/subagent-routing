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

## Why reviews run only on request

Independent reviews found real bugs that the author had missed:

- A hook silently allowed every command, because its input started with a byte-order mark.
- A maintenance script would crash on an empty configuration object.

An earlier version of the rule asked for one strong-tier review before every multi-file or risky delivery. In the author's projects, each merge request already gets a review before it merges, so the extra review repeated that work and added 7-12 minutes of a strong model to most deliveries. The rule now dispatches a review subagent only when the user or a running skill asks for one, and reviews run at the standard tier.

## Why the final message holds the full answer

A strong-model subagent once put its full answer in a message that was not the final message. The parent receives only the final message, so that answer did not reach the parent. The rule now requires the full answer in the final message.

## Why a named model covers only its own work

A user who names a model usually names it for one piece of work, such as two independent drafts from two vendors. Agents carried the name over to later dispatches in the same chat. In one chat, a Gemini main agent sent a routine re-review to a Claude model that the user had named only for an earlier evaluation. So the rule applies a named model only to the work it was named for, and the other dispatches follow the tier table.

## Why batch subagents write in chunks

With at most 4 subagents for a batch, each subagent had about 80 items. One subagent tried to put all its results, about 230 KB, in one message. The connection to the model provider failed after 5 minutes, and none of the results were saved. When a subagent writes its results to a file about 20 items at a time, each message stays short, and a failed run keeps its finished items.

## Why each subagent gets about 30 minutes of work

Long runs failed much more often than short ones. From 2026-10-10 to 2026-10-23, 6 foreground Gemini subagents ran 30 minutes or longer, and 5 of them stopped on an error after 45-66 minutes. In one chat, a single subagent had to repair 1,025 items in one run; it failed 5 times and used about 4 hours without a result. Only 2 of 199 foreground Claude subagents ran longer than 30 minutes; both finished, the longer one after 44 minutes. When each share fits in about 30 minutes, a failed run loses little, and the next round starts from the files already written.

## Why a failed subagent is continued once, not restarted

When a subagent stops on a provider or connection error, Cursor reports its Agent ID so that the agent can send a follow-up. Main agents started new subagents instead, and the new subagents did all the reading again. When the agent continues the same subagent, that work is kept. The ID must be complete: shortened IDs and made-up IDs failed with "Composer not found for resume". One main agent had only an 8-character prefix of a reviewer's ID left in its context, so it started a fresh reviewer that had to read the whole change again; the transcript folder has the full IDs.

Continuing has a limit. In the 1,025-item chat, the main agent continued the subagent twice, then started a new one with the same task and continued that one too, and every run failed. In two other chats, subagents stopped on `resource_exhausted` after several follow-ups had filled their context. So the agent continues a subagent once. If it stops again, a new subagent gets a smaller share and the files that the first one wrote.

A follow-up also fails when the subagent is still running, or when it belongs to another chat: a duplicated chat keeps the subagent IDs of the chat it was copied from. The details file says what to do in each case.

## Why long subagents run in the background

A main agent that waits for a subagent in the foreground keeps its own connection open for the whole wait. In one chat on 2026-10-23, that connection dropped 17 minutes into such a wait. After it reconnected, Cursor marked the subagent call as cancelled, and the main agent received no result. The subagent kept running and finished 33 seconds later, with a report of about 20,000 characters in its transcript. The main agent looked for that transcript in the wrong folder, then started a new subagent for the same task, which took another 8 minutes.

A background subagent does not hold the main agent's connection, and the agent is told when it finishes. So the rule starts a subagent that may take longer than about 5 minutes in the background, even when the next step needs its result. Typical small tasks take 1-3 minutes, so quick lookups still run in the foreground. When a call still comes back cancelled or empty, the details file has the agent read the subagent's transcript before it runs anything again.

## Why the parent checks the evidence

A subagent can be wrong. One reviewer said that a logged field was wrong. The live data showed that the field was right.

For this reason, the rule makes the parent check 1-2 key pieces of evidence before it uses a conclusion. If the conclusion is "not found", the parent checks again or runs the subagent again one tier up.

## What the rule does not do

- It does not enforce anything. There is no hook and no runtime code.
- It does not write a dispatch log. It only asks the agent to name the model of each subagent in its progress notes.
