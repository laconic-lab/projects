# Project Roadbooks

## Purpose
A roadbook is a compact, chronological handover for a project or long-running ChatGPT work thread. It survives chat resets and context limits.

It records decisions, actions performed, observed results, problems, and the next agreed step. It does not replace technical documentation, installation guides, architecture standards, or source files.

## How to use
1. Keep one roadbook per substantial project or independently evolving work thread.
2. At the start of a new ChatGPT conversation, provide the relevant roadbook and ask the assistant to treat it as the historical handover.
3. Read the roadbook before proposing work. Do not repeat completed tests or silently replace recorded decisions with generic assumptions.
4. Append entries as work progresses. Preserve chronology and original evidence; correct mistakes explicitly rather than rewriting history invisibly.
5. Record successful, failed, and inconclusive attempts.
6. Distinguish clearly between **Decision**, **Action**, **Observation**, **Hypothesis**, and **Pending**.
7. Include exact dates, versions, filenames, commands, build numbers, and paths when known. Never invent missing details.
8. Keep credentials, passwords, tokens, private keys, and other secrets out of roadbooks.
9. Keep entries concise and actionable. Link to canonical project documentation for deep technical detail.
10. Update the roadbook after meaningful milestones and before handing work to a new chat.

## Suggested entry format
```markdown
## YYYY-MM-DD — Short milestone title
- **Decision:** ...
- **Action:** ...
- **Observation:** ...
- **Caveat / unresolved:** ...
- **Next:** ...
```

Not every entry needs every field. Mark uncertain claims as unverified. Never describe a planned action as completed.

## Starting a new chat
Provide this README if the convention is unfamiliar, the roadbook for the relevant project, and any current logs or artifacts needed for the immediate task.

The assistant should first summarize the recorded state and immediate next step, then continue from that point. The roadbook is the historical source of truth for the work sequence; current files, logs, and live system evidence remain authoritative for present state.
