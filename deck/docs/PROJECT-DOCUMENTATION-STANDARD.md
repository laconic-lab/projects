# Project Documentation Standard

Repository-wide guidance for creating, maintaining and reviewing project documentation in `laconic-lab/projects`.

| Document control | Value |
|---|---|
| Scope | All projects and supporting documentation in this repository |
| Status | Current standard |
| Format | Markdown preferred; other formats only when justified |
| Maintainer | [laconic-lab](https://github.com/laconic-lab) |
| Companion standard | [Engineering & Security Baseline](./ENGINEERING-AND-SECURITY-BASELINE.md) |

> **Purpose:** make project documentation useful, readable, maintainable and safe to publish. Document the real project, its current state and the evidence behind important claims. Do not force every project into an identical set of files.

---

## Contents

- [1. Documentation principles](#1-documentation-principles)
- [2. Documentation roles](#2-documentation-roles)
- [3. README requirements](#3-readme-requirements)
- [4. Content expectations by role](#4-content-expectations-by-role)
- [5. Security and publication rules — mandatory](#5-security-and-publication-rules-mandatory)
- [6. Evidence, accuracy and status language](#6-evidence-accuracy-and-status-language)
- [7. Naming, structure and formatting](#7-naming-structure-and-formatting)
- [8. Documentation hierarchy and authority](#8-documentation-hierarchy-and-authority)
- [9. Updating documentation](#9-updating-documentation)
- [10. AI-assisted documentation work](#10-ai-assisted-documentation-work)
- [11. Exceptions and maintenance](#11-exceptions-and-maintenance)

---

## 1. Documentation principles

1. **Document the project, not the conversation.** Convert useful decisions and verified outcomes into durable documentation. Chat transcripts, raw terminal dumps and step-by-step conversation exports are not substitutes for maintained project documentation.
2. **Describe reality.** Separate implemented, tested, verified, proposed, planned, deprecated and historical information.
3. **Prefer a clear source of truth.** Avoid multiple files that claim to be the authoritative description of the same setting or procedure.
4. **Use the right document for the job.** A short project may need only a README. A service with meaningful operational risk may need separate architecture, security, backup and troubleshooting guides.
5. **Keep documents focused.** Each file should have a clear purpose, audience and scope.
6. **Prefer Markdown.** Use `.md` for human-readable project documentation because GitHub renders headings, tables, links, code blocks and lists consistently.
7. **Keep documentation actionable.** Include prerequisites, exact scope, expected results, verification and recovery information when relevant.
8. **Avoid needless duplication.** Link to an authoritative explanation instead of copying it into several files.
9. **Preserve useful history.** Do not rewrite historical records to make old work appear to have happened differently.
10. **Treat every repository file as publishable.** A private repository, ignored file, archived directory or historical note is not a safe place for secrets.

## 2. Documentation roles

The roles below are a flexible reference, not a mandatory checklist. Select only the documents justified by the project's complexity, risk, maturity and intended audience.

| Role | Recommended file | What it should answer |
|---|---|---|
| Project entry point | `README.md` | What is this project, what is its status, and where should a reader go next? |
| Architecture and operations | `docs/ARCHITECTURE-AND-OPERATIONS.md` | What runs, where does it run, how do components interact, and how is it operated? |
| Installation and setup | `docs/INSTALLATION.md` | What prerequisites and steps are needed for a clean installation or setup? |
| Security | `docs/SECURITY.md` | What are the trust boundaries, permissions, exposures, risks and safeguards? |
| Backup and recovery | `docs/BACKUP-AND-RECOVERY.md` | What data matters, how is it backed up, and how can it be restored and verified? |
| Troubleshooting | `docs/TROUBLESHOOTING.md` | How are known symptoms diagnosed safely and resolved? |
| Audit or feasibility | `docs/AUDIT.md` or a dated, clearly named report | What was examined, what evidence was collected, and what conclusions or limitations follow? |
| Technical reference | `docs/REFERENCE.md` or a specific topic name | What exact configuration, interface, command or compatibility detail must be retained? |
| Release history | `CHANGELOG.md` or `docs/RELEASE-NOTES.md` | What meaningful user-facing or operational changes were made over time? |
| Current inventory | `docs/MANIFEST.md` | What components, files or capabilities currently exist, when such an inventory is useful? |
| Session handover | A dated handover note, only when needed | What was completed, what remains, and what should the next session verify? |

Existing project-specific names may be retained when they are clear and consistently used. Do not rename a stable documentation set merely to match these example filenames.

### Choosing the minimum useful set

- **Small script or utility:** README, plus usage or reference notes if necessary.
- **Application or agent:** README, architecture/operations, security, installation, and troubleshooting as justified; add backup/recovery when persistent state exists.
- **Persistent service or infrastructure:** README, architecture/operations, installation, security, backup/recovery and troubleshooting are normally appropriate.
- **Audit or feasibility investigation:** a scoped audit report with evidence, assumptions, limitations and a clear decision/status. Do not imply an implementation exists.
- **Historical or abandoned work:** label it clearly as archived, superseded, aborted or reference-only. Keep it out of the current operational instructions.

## 3. README requirements

Every active project should have a concise `README.md` at its project root unless there is a clear reason not to.

A useful README normally contains:

1. **Purpose:** a short description of the project.
2. **Status:** operational, development, experimental, audit-only, paused, archived or another precise state.
3. **Platform and architecture:** a brief summary of the actual runtime and important dependencies.
4. **Current capabilities:** what is implemented, without presenting plans as features.
5. **Access and operation:** how the project is normally started or accessed, when applicable. Do not expose secret values.
6. **Requirements and limitations:** relevant prerequisites, compatibility constraints and known limitations.
7. **Documentation index:** links to the authoritative detailed documents.
8. **Safety note:** important operational cautions, if omission could cause harm or data loss.

Keep the README an entry point, not a copy of every detailed guide. Prefer relative links that work within the repository.

## 4. Content expectations by role

### Architecture and operations

Document the actual system:

- Runtime and execution location: host, Distrobox, Podman, VM, client or other environment.
- Component responsibilities and relationships.
- Persistent data, configuration, cache, logs and backup locations, where useful.
- Network listeners, interfaces, ports and access paths.
- Startup, shutdown, status and log procedures.
- Lifecycle ownership: manual, service-managed, scheduled or externally managed.
- Dependencies, resource requirements and known limitations.
- Which statements describe current verified state versus intended design.

Use diagrams when they clarify boundaries or data flow. Label conceptual diagrams as conceptual.

### Installation and setup

Document a reproducible setup path:

- Supported platform and prerequisites.
- Required permissions and why they are needed.
- Ordered installation steps with clear environment context.
- Configuration inputs and safe placeholders.
- Expected output and validation steps.
- Recovery or rollback path for meaningful changes.
- Known platform-specific caveats.

Do not include real credentials or copy secret-bearing configuration into examples.

### Security

Document security properties rather than vague assurances:

- Trust boundaries and identities.
- Privileges, capabilities, mounts, sockets and devices.
- Network exposure and access controls.
- Credential handling and secret storage model.
- Data sensitivity, logs and backup protection.
- Threats, mitigations, residual risks and unverified assumptions.
- Any deliberate exception and why it exists.

Do not claim a container, Distrobox, firewall or allowlist provides isolation unless the effective configuration and relevant boundary have been examined.

### Backup and recovery

State what is and is not protected:

- Persistent data and configuration that must survive.
- Backup scope, destination, format and frequency or trigger.
- Exclusions, including reproducible caches or disposable runtime layers.
- Integrity checks and how to interpret their results.
- Restore prerequisites and ordered restore steps.
- Post-restore validation.
- Known gaps, untested steps and recovery limitations.

A successful backup command is not proof of recoverability. Distinguish backup creation, integrity verification and an actual restore test.

### Troubleshooting

Organize by symptom or failure mode:

- Observable symptom and scope.
- Safe read-only checks first.
- How to interpret likely results.
- Least disruptive corrective action.
- Verification after the action.
- Escalation or rollback conditions.

Do not make destructive resets, broad permission changes, reinstallations or service restarts the default first response. Explain their impact and require appropriate authorization.

### Audits and feasibility reports

Every audit should identify:

- Scope and exclusions.
- Date or evidence collection period.
- Environment and versions observed, when relevant.
- Commands, sources or methods used.
- Findings with supporting evidence.
- Risks, uncertainty and untested areas.
- Conclusion and decision: feasible, infeasible, conditional, unresolved or another precise outcome.
- Follow-up work, clearly separated from completed work.

An audit is a point-in-time assessment. It does not prove that the environment remains unchanged.

### Release notes and changelogs

Use a chronological history when changes are meaningful enough to warrant one.

Record:
- Date and version, if the project actually uses versions.
- User-visible, operational or security-relevant changes.
- Fixes and removals.
- Important compatibility or migration notes.
- Validation performed and its scope.
- Known regressions or limitations.

Do not invent semantic versions, release numbers, dates or test results. Do not call routine documentation edits a software release unless the project's convention says so.

### Manifests and inventories

Use a manifest only when a current inventory is genuinely useful—for example, an agent tool allowlist, component inventory, deployment inventory or reproducible package list.

A manifest should:
- State exactly what it inventories and what it excludes.
- Reflect the current verified state.
- Identify whether entries are enabled, optional, planned or deprecated.
- Avoid duplicating full explanations from architecture or security documents.
- Never contain secret values.

A manifest is not automatically a release history, and a release history is not automatically a current inventory.

## 5. Security and publication rules — mandatory

**No credentials or secrets belong in repository documentation. This rule applies to every file, format, branch, commit, example, screenshot, log excerpt and archived document.**

Never publish or commit:

- Passwords, passphrases, PINs or recovery codes.
- API keys, provider keys, access tokens, refresh tokens or bearer tokens.
- Private SSH keys, signing keys, certificates containing private key material, or seed phrases.
- Cookies, session identifiers, authorization headers or browser storage exports.
- Secret-bearing `.env` files or configuration files containing live credentials.
- Database credentials, webhook secrets, cloud credentials or service-account keys.
- One-time codes, reset links or URLs containing embedded credentials.
- Unredacted diagnostic output that reveals any of the above.

Also avoid publishing personal or operationally sensitive material that is not necessary to explain the project, such as private account identifiers, personal contact details, device serial numbers, unique hardware identifiers, private file contents or internal access links.

### Safe alternatives

Use unmistakable placeholders, for example:

```dotenv
API_KEY=<YOUR_PROVIDER_API_KEY>
SERVICE_TOKEN=<REDACTED>
```

For commands, show the variable name or a prompt without revealing its value:

```bash
read -rsp "API key: " API_KEY
export API_KEY
unset API_KEY
```

Prefer documenting:
- The name and purpose of a required setting.
- Where the secret is stored, described generically (for example, an OS credential store or a user-only configuration file).
- Which process or identity is allowed to access it.
- How it is supplied without printing it.
- How to rotate or revoke it.

Do not include real values even when they are already visible elsewhere in the repository or conversation. Do not reproduce them in a new document for convenience.

### Local IP addresses and network details

Private LAN addresses are not inherently credentials or secrets. They may be documented when they materially help explain a real deployment, network topology, firewall rule or client configuration.

Use judgment:
- It is acceptable to retain a real private LAN IP when it is useful and the repository owner is comfortable publishing it.
- Use placeholders such as `<STEAM_DECK_LAN_IP>` in reusable instructions and examples.
- Do not confuse private RFC1918 addresses with public internet addresses.
- Avoid publishing public IP addresses, externally reachable hostnames, precise physical location details or network information that creates an unnecessary exposure.
- Never include passwords, tokens or other secrets alongside an IP address.

Do not waste effort removing harmless local addressing merely for cosmetic anonymization. The priority is to prevent credential disclosure and avoid unnecessary exposure of genuinely sensitive information.

### Before publishing

Review the complete proposed diff—not just the new README—for:
- Secret values and credential-bearing files.
- Logs, screenshots, command output and copied configuration.
- Personal data and unnecessary unique identifiers.
- Public endpoints or access details that are not required.
- Broken links and references to files that no longer exist.

If a secret is found in Git history, deleting it from the latest file is not sufficient. Treat it as exposed: revoke or rotate it first, then assess history cleanup and any copies or forks. Never assume a force-push alone invalidates a credential.

## 6. Evidence, accuracy and status language

Use status words consistently:

| Label | Meaning |
|---|---|
| **VERIFIED** | Directly checked with relevant evidence in the stated scope. |
| **TESTED** | A defined test was run; record what it covered and its result. |
| **REPORTED** | A result was reported by a person or external source but not independently checked here. |
| **DOCUMENTED** | Present in an existing document; not necessarily checked against live state. |
| **PROPOSED** | A design or change that has not been implemented. |
| **PLANNED** | Intended future work. |
| **PENDING** | Work or verification remains outstanding. |
| **NOT TESTED** | No relevant test was performed. |
| **UNKNOWN** | Available evidence is insufficient to determine the state. |
| **DEPRECATED / ARCHIVED** | Retained for history or reference; not current operating guidance. |

For important claims, include the evidence source and date where that helps future readers. Record limitations beside the claim, not buried in an unrelated section.

Never convert a reported result into a verified result without performing the check. Never imply that a service is currently running based only on an installation guide or historical test.

## 7. Naming, structure and formatting

- Prefer descriptive filenames in Markdown, using a consistent style within each project.
- Keep the project root uncluttered. Put substantial guides in a project-level `docs/` directory.
- Use relative links for files within the repository.
- Use headings in a logical hierarchy; do not skip heading levels for visual effect.
- Use tables for compact comparisons and structured metadata, not for long paragraphs.
- Use fenced code blocks with a language identifier for commands and configuration examples.
- Explain which machine, user, directory or environment a command targets.
- Mark destructive or state-changing commands clearly and explain prerequisites and consequences.
- Use placeholders for machine-specific values in reusable procedures.
- Add dates when they clarify the age or validity of an observation. Do not add artificial version numbers.
- Keep line length and paragraph size comfortable for GitHub's rendered view.
- Avoid decorative banners, excessive capitalization, emoji-heavy headings and walls of unstructured text.

### 7.1 Raw-source readability and ASCII-resilient Markdown

Markdown remains the default documentation format. Documents should work well in both GitHub's rendered view and their unrendered source form, including when read in a terminal, editor, code review diff or AI-assisted workflow.

This is **ASCII-resilient Markdown**, not ASCII-only documentation. Keep Markdown headings, links, lists, tables and fenced code blocks. Use plain-text diagrams where they communicate structure more clearly than prose or a table. Do not replace useful Markdown features merely to make a file look like a plain-text document.

#### Core requirements

- **Preserve meaning without rendering.** The document's purpose, scope, decisions, warnings, status and essential relationships must remain understandable from the source. Do not make color, emoji, HTML, badges or visual positioning the only carrier of important meaning.
- **Use a consistent heading hierarchy.** Use one H1 for the document title, then progress through H2 and H3 in order. Do not use bold text as a substitute for headings or skip levels for visual effect. Number headings when numbering helps navigation or stable references; do not add numbering solely for decoration.
- **Prefer ordinary Markdown syntax.** Use standard heading, list, link, table and fenced-code syntax. Avoid unnecessary escaped punctuation, bold-wrapped headings, embedded HTML and formatting tricks that make source harder to scan.
- **Keep paragraphs and list items focused.** Use meaningful line breaks between structural elements. Wrap ordinary prose sensibly where it improves diffs and raw reading, but do not reflow historical evidence or alter exact command output merely to satisfy a line-width target.
- **Use explicit textual status.** Important states must be written as words, not conveyed only by color, icons or badges. Reuse the evidence vocabulary in Section 6 and any stricter project-specific vocabulary.
- **Distinguish current from historical information.** Label dated observations, superseded procedures, archived records and unverified claims clearly. A source-readable layout must not make historical evidence appear to be current operating guidance.
- **Make links understandable in source.** Prefer descriptive link text and repository-relative links for files in this repository. Avoid relying on a rendered link's surrounding visual context to explain its destination.
- **Keep exact technical material exact.** Commands, paths, hashes, identifiers, configuration values and copied evidence must not be wrapped, reformatted or edited in ways that change their meaning. Identify execution context and mutation risk around operational commands.

#### ASCII and plain-text diagrams

Use a fenced `text` code block for diagrams that explain architecture, components, network paths, trust boundaries, data flow, dependencies, process lifecycle or recovery relationships.

A diagram should:

1. Have a clear title or an immediately adjacent explanation.
2. Use a consistent direction and simple, recognizable connectors.
3. Label components and boundaries explicitly; do not rely on color or decorative symbols.
4. Remain reasonably narrow where practical, while prioritizing correctness over an arbitrary character limit.
5. Distinguish verified implementation from conceptual, proposed or historical architecture.
6. Be followed by prose when a relationship, exception or security implication is not self-evident.

Example:

```text
LAN client
    |
    | SSH / TCP 22
    v
Steam Deck host
    |
    +-- OpenSSH service
    |
    +-- User session
          |
          +-- Project files
          +-- Isolated workloads
```

This is an illustrative layout only. A real project diagram must use the project's verified names, boundaries and paths, and state when it represents a proposal rather than an observed implementation.

Do not force every document to contain a diagram. A diagram is useful when it makes relationships or boundaries easier to understand; otherwise, concise prose or a table is preferable.

#### Tables, lists and structured information

- Keep Markdown tables for compact inventories, comparisons, configuration summaries, evidence matrices and document-control metadata.
- Give each table clear column headings. Keep cells concise and avoid putting long paragraphs, command transcripts or nested lists inside cells.
- If a table becomes too wide or difficult to read in raw form, consider splitting it by topic or replacing relationship-oriented content with a diagram and explanatory text.
- Use lists for sequences, requirements, checklists and unordered collections. Use numbered lists when order matters.
- Do not convert all tables into ASCII-art tables. Markdown tables are more maintainable and render well on GitHub.

#### Navigation and document size

- Short documents generally do not need a table of contents.
- For long guides, standards and audit records, provide useful navigation when it materially improves discovery. A manually maintained contents list is appropriate only when it can be kept accurate; otherwise use clear heading structure and GitHub heading anchors.
- Keep opening sections especially informative: document purpose, scope, current status, authority, and important safety or continuation constraints should appear before lengthy detail where relevant.
- Large living audits should identify the canonical record, current version or record date, continuation rules, evidence vocabulary and final/active disposition near the beginning.
- Do not add navigation boilerplate to every file. Match the navigation mechanism to the document's length, role and rate of change.

#### Document-specific flexibility

This section defines shared readability principles, not a universal document template.

- **README and index:** prioritize project purpose, current status, architecture at a glance, responsibilities and links to authoritative detail.
- **Architecture and operations:** use diagrams for component relationships and operational flows; use tables for responsibilities, ports, settings and dependencies.
- **Security documents:** make trust boundaries, controls, risks, evidence and authorization limits explicit in text as well as diagrams.
- **Installation, backup and recovery guides:** organize by safe sequence, prerequisites, execution context, expected result, verification and rollback or recovery.
- **Audits and living evidence records:** preserve chronology, test identifiers, exact results, decisions and limitations. Improve navigation and presentation without rewriting or silently consolidating evidence.
- **Release notes and archives:** preserve historical wording and chronology where they are part of the record. Do not bulk-reformat archived material for stylistic consistency.

#### Review checks

Before publishing a substantive documentation change, check both the rendered GitHub view and the raw Markdown source where practical.

Confirm that:

- Heading levels and section order are logical.
- Diagrams remain aligned and understandable in a monospaced view.
- Tables have not become misleading, excessively wide or needlessly complex.
- Important status, warnings and authorization boundaries remain explicit without styling.
- Links and heading references resolve.
- Commands, paths, hashes, test evidence and historical records have not been unintentionally changed.
- The rendered and raw views communicate the same meaning.

Prefer targeted improvements over wholesale reformatting. When a document already meets these requirements, preserve it.

---

## 8. Documentation hierarchy and authority

Use this practical order when documents disagree:

1. **Current verified implementation and runtime evidence** establish what is actually present now.
2. **Project-specific security and operational documentation** define approved project boundaries and procedures, provided they do not contradict the shared baseline.
3. **Project README** is the entry point and index; detailed role documents own their specialist explanations.
4. **Audit reports and dated handovers** record scoped observations at a point in time.
5. **Release notes and changelogs** preserve historical change records; they do not override current state.
6. **Archived, aborted or superseded material** is reference-only unless explicitly revalidated.

The [Engineering & Security Baseline](./ENGINEERING-AND-SECURITY-BASELINE.md) provides cross-project defaults. Project-specific documentation may define a justified exception, but it must identify the reason, scope, risk and approval. It must not silently weaken a mandatory security rule.

If a conflict affects safety, data integrity, security or a destructive action, stop and resolve it before proceeding.

## 9. Updating documentation

When a project change warrants documentation:

1. Identify the project and the exact files whose roles are affected.
2. Read the current README and relevant authoritative documents before editing.
3. Verify the implementation state needed to support the proposed statements.
4. Decide whether to update an existing document or create a new one. Prefer updating the right existing file over adding duplicates.
5. Preserve valid historical entries and project-specific conventions.
6. Update cross-links and indexes when filenames or roles change.
7. Review the complete diff for accuracy, scope, readability, security and accidental disclosure.
8. Read back the published files and verify links and references where practical.
9. Report exactly what changed and what was not checked.

Back up local files before significant local edits when appropriate. A Git commit provides history, but it does not replace a separate backup where one is required for operational recovery.

Do not modify application code, configuration, services or unrelated projects as part of a documentation-only task unless separately requested and authorized.

## 10. AI-assisted documentation work

An AI assistant working in this repository must:

- Read this standard and the [Engineering & Security Baseline](./ENGINEERING-AND-SECURITY-BASELINE.md) before making repository-wide documentation decisions.
- Inspect the target project's README and relevant documentation before proposing changes.
- Use the repository's current documentation as evidence, not as unquestionable proof of live state.
- Avoid scanning unrelated local filesystems or systems when a repository-scoped review is sufficient.
- Never invent paths, commands, versions, test results, status or implementation details.
- Never copy credentials or secret values into documentation, output, commits or summaries.
- Use placeholders for secret values and redact sensitive diagnostic material.
- Preserve useful local IP information when it is relevant; do not treat private LAN IPs as secrets by default.
- Prefer concise, readable Markdown consistent with the SSH and Pi-hole documentation style.
- Ask before destructive actions, security boundary changes, installations, resets, service restarts or changes outside the requested scope.
- Distinguish edits made from checks performed. Do not claim a security scan, test or verification that was not actually completed.

## 11. Exceptions and maintenance

A project may use another format or document structure when there is a concrete reason, such as machine-readable metadata, an upstream-required format or an established technical convention.

An exception should state:
- What differs from this standard.
- Why the difference is needed.
- Which project and files it applies to.
- Any security or maintenance implications.

Review this standard when the repository's architecture, documentation practices or security requirements materially change. Do not create documentation overhead for its own sake.

---

**Operating principle:** write the smallest set of accurate, readable and secure documents that lets another person understand, operate, verify and recover the project—without exposing credentials or pretending unverified work is complete.
