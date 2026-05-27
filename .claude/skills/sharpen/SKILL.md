---
name: sharpen
description: Use when the user wants help writing a prompt, says "sharpen", "write me a prompt", "what should I tell Claude next", or needs to formulate instructions for any AI agent, session, or tool. Also use when the user asks to "write a continuation prompt" or "wrap up and give me a prompt for next time".
---

# Sharpen — turn a rough idea into a precise prompt

Takes a fuzzy "I want to do X" and produces a clear, effective prompt ready to paste anywhere — a new Claude session, an agent dispatch, a skill invocation, a continuation handoff, or any other AI tool.

## Invocation

```
/sharpen                    # "what are you trying to do?"
/sharpen <rough idea>       # start from the idea
```

## Workflow

### 1. Extract the raw intent

From the user's rough idea, identify:
- **What** they want done (the task)
- **Why** it matters (the motivation)
- **What "done" looks like** (success criteria)

If any are missing, ask — max 3 clarifying questions total, each with a recommended answer. Don't stall momentum with unlimited back-and-forth.

### 2. Build the prompt

**Always include:**

| Field | Purpose |
| --- | --- |
| **Task** | Single imperative directive |
| **Context** | What the recipient needs to know — current state, prior decisions, relevant files |

**Include only when they'd change the output:**

| Field | Purpose |
| --- | --- |
| **Constraints** | Rules, boundaries, what's in/out scope. Use positive directives: "write short sentences" beats "don't write long paragraphs" |
| **Output** | Format, structure, or artifact to produce — skip when the default is fine |

Every token must earn its place. When a constraint can be shown with one example instead of explained with several sentences, use the example.

### 3. Tighten

Before presenting, do a pass:
- **Cut filler** — remove words that don't change model behavior ("please", "make sure to", "it is important that")
- **Examples over rules** — one input→output example replaces multiple constraint sentences
- **Positive over negative** — "do X" is followed more reliably than "don't do Y"
- **Link, don't inline** — for continuations/handoffs, reference files and PRs rather than pasting their full content

### 4. Adapt to destination

- **New session / continuation**: Include what was done, what's left, key file paths, decisions made. Link to artifacts rather than inlining everything.
- **Agent / subagent**: Be fully self-contained — no conversation history. Include file paths and success criteria.
- **Skill or tool invocation**: Seed direction only. The skill has its own structure.

If the destination isn't obvious, ask once.

### 5. Present and refine

Show the drafted prompt in a fenced code block. Ask:

> **Ready to use, or want to adjust?**

Use AskUserQuestion with options: "Use it" / "Adjust" / "Start over".

On "Use it": hand the prompt to the user. If they've indicated a target that can be invoked directly (e.g. a skill in the current session), offer to run it.

## Anti-patterns

- **Don't over-engineer simple prompts.** If "build the login page" is already precise enough, say so.
- **Don't pad with empty fields.** A 2-field prompt that's precise beats a 6-field prompt with filler.
- **Don't second-guess the destination.** Sharpen writes the prompt, not the workflow.
- **Don't execute the task.** Sharpen produces the prompt. The user decides what to do with it.
- **Don't explain constraints when you can show them.** One example conveys more than three sentences of rules.
