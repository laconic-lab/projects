# Waydroid — Audit Records

This directory contains the active, cumulative feasibility audit and its preserved historical source documents.

## Active document

- [Waydroid SSH — Living Container Feasibility Audit](WAYDROID-SSH-LIVING-FEASIBILITY-AUDIT.md)

Read this document first before continuing the audit. It contains the current project constraints, historical environment, completed test ledger, Tests 21–25 consistency review, confirmed temporary-container cleanup, current dependency gates, and evidence-recording schemas. The unchanged v1.7 snapshot is preserved in the archive. The next action is the proposed read-only Podman JSON query; no host cgroup or systemd changes are authorized.

## Archive

The original export, previous consolidated audit, and versioned canonical snapshots are retained under [archive/2026-11-06](archive/2026-11-06/).

- `_1.0_ Waydroid SSH Feasibility Audit.md` — original exported conversation and reconstruction instructions.
- `1.0_Waydroid-SSH-Consolidated-Audit.md` — previous consolidated technical audit.
- `WAYDROID-SSH-LIVING-FEASIBILITY-AUDIT-v1.0.md` — unchanged snapshot of the initial canonical audit, before Test 20 was incorporated.
- `WAYDROID-SSH-LIVING-FEASIBILITY-AUDIT-v1.7.md` — unchanged snapshot of the canonical audit immediately after Test 25 cleanup was verified and before the v1.8 consistency-review corrections.

The archive is historical source material; it is not the active continuation document.

## Maintenance rule

Record every completed test immediately in the canonical living audit, including the exact executed command, relevant unedited output, exit statuses, interpretation, limitations, repeat policy, version/change-log entry, and updated continuation handoff. After every five completed tests, review documentation consistency and preserve an unchanged versioned archive snapshot; create an earlier snapshot before a significant architecture/security decision or material restructuring. Every new ChatGPT conversation must begin from the canonical handoff and latest test ledger, never from assumed conversation memory. Never mark a proposed command as executed. Do not repeat a completed test without documenting the changed condition and reason. The active audit version and README handoff must agree on the next exact action.
