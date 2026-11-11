# Shyrka Agent — Maintenance, Update and Backup Policy

> **Document role:** Change, backup, validation and recovery workflow.  
> **Source:** `howto_update.txt` (archived unchanged under [archive/originals](./archive/originals/)).  
> **Conversion scope:** Markdown structure and presentation; technical operating policy retained. Documentation references were updated to the current Markdown filenames. No Steam Deck audit or runtime revalidation was performed.

## Before a significant change

1. Stop an interactive agent session, if one is running.
2. Create a pre-change backup.
3. Apply only the intended change.
4. Run `agent --check` and the unit tests.
5. Verify the dashboard and archive.
6. Create another backup after validation.
7. Record the change in [Release Notes](./RELEASE-NOTES.md) and [Project Versions](./PROJECT-VERSIONS.md).

## Unified backup

Run:

```bash
/home/deck/LocalAIAgentrecovery/backup.sh
```

## Verify the latest backup

Run:

```bash
/home/deck/LocalAIAgentrecovery/recovery.sh check
```

## Restore a specific backup

Run:

```bash
/home/deck/LocalAIAgentrecovery/recovery.sh restore \
  /home/deck/LocalAIAgentrecovery/backups/Shyrka-Agent-TIMESTAMP
```

## Restore behavior

The restore process asks for explicit confirmation and creates a safety backup before restoring. It restores the project files and SQLite archive. It does not remove unrelated files or reinstall the virtual environment or model weights.

## Operational boundaries

- Keep the agent manual-start only.
- Do not add shell execution, arbitrary writes, unapproved tools, unrestricted sudo, or credential access.
- Keep model inference local unless explicitly authorized otherwise.

## Change workflow schema

```text
Significant change proposed
  |
  v
Create pre-change backup
  |
  v
Apply only the intended change
  |
  v
Run agent check and unit tests
  |
  v
Verify dashboard and archive
  |
  v
Create post-validation backup
  |
  v
Record change in release history
```

The workflow reflects the existing policy. It is not a claim that these checks were run during this documentation conversion.
