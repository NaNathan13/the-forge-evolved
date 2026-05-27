---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when the user wants to stress-test a plan, get grilled on their design, or mentions "grill me". Leaned on by /ponder.
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time.

Prefer `AskUserQuestion` for decisions with a small set of clear options; fall back to plain prose questions when the space is open-ended.

If a question can be answered by exploring the codebase, explore the codebase instead of asking.

## Resolve forks before moving on

Don't stack open questions. When a round surfaces a conflict or a fork, resolve it before posing the next question. The goal is a design with no unresolved branches by the end — something `/inscribe` can write down without having to guess.

## Glossary nicety (optional)

If a round defines, sharpens, or contradicts a term that matters to the project, jot it into `CONTEXT.md` under `## Language` with a one-line `Edit` (single entry, leave the rest untouched):

```markdown
**Term**: Definition. What it is, where it lives, what it is NOT.
```

Then emit one line to the transcript: `noted: **Term** → CONTEXT.md`. This fires only when a term was genuinely defined or contradicted — skip cosmetic variation. Don't let it interrupt the grilling rhythm.
