---
name: technical-writing
description: 'Use for writing, revising, or reviewing prose: docstrings, comments, mathematical exposition, issues, design docs, PR summaries, READMEs, commit messages.'
---

# Technical Writing

Make the reader understand.

Read `references/on-writing.md` before editing. Also read `references/on-writing-mathematics.md` for mathematical text. Use `deep-module-design` for proof structure and `proof-review` for adversarial proof review.

## Edit

1. Read the full target and enough context to preserve its meaning.
2. Identify audience and purpose.
3. Remove a buried main point, vague references, undefined terms, repeated claims, code-restating comments, and paragraphs with more than one job.
4. Preserve claims and technical distinctions. Define a needed term on first use; replace a code comment with its reason or remove it.
5. Show a diff for local edits. For a full rewrite, give the revised text and a brief account of material changes.

## Review Only

Report each problem with its location and a fix. Do not rewrite unless asked.

## Subagent

Use [`agents/edit.md`](./agents/edit.md) for small prose-only edits.
