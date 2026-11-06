# Odysseus v1 — Groq Integration Attempt

| Document control | Value |
|---|---|
| Project generation | Odysseus v1 |
| Workstream | First cloud provider integration |
| Initial provider | Groq |
| Intended first stage | Read-only inspection, followed by credential foundation |
| Historical project path | `/home/deck/OdysseusProject` |
| Historical Distrobox | `odysseus-box` |
| Final status | Not completed as a production integration |
| Current purpose | Historical record only |
| Last corrected | 2026-11-06 |

> **Scope clarification:** This is a record of the separate cloud-provider credential workstream. The original v1 Distrobox was retired because of local Agent authority and host-isolation risks, not because the Groq integration or Cloud AI API work was the primary cause. Do not restore the old key file, directory tree, runtime or application configuration based on this record.

## 1. Objective

Groq was selected as the first provider for the planned shared cloud-provider architecture. The intention was to extend the existing Odysseus endpoint and credential architecture rather than create an isolated integration that would later need to be duplicated for other providers.

The work was explicitly incremental: inspect the application; establish real integration points; inspect configuration, dependencies, secret handling, routing and logging; prepare a credential foundation only after inspection; then implement and validate one provider before expanding the provider set.

The initial inspection was intended to be read-only. Package installation, source edits, service restarts and key creation were not part of that first inspection step.

## 2. Historical handover environment

| Property | Recorded value |
|---|---|
| Host | Steam Deck / SteamOS |
| Host user | `deck` |
| Distrobox | `odysseus-box` |
| Container distribution | Ubuntu 24.04 |
| Project directory | `/home/deck/OdysseusProject` |
| Project interpreter | `/home/deck/OdysseusProject/.venv/bin/python` |
| Project Python | 3.12.3 |
| Host Python | Separate; not to be used for project dependencies |
| Recovery directory | `/home/deck/OdysseusRecovery` |

These are historical observations and must not be assumed to describe the current Steam Deck or v2 environment.

## 3. Existing Groq support discovered

The provider investigation recorded that parts of Groq support already existed in the upstream application:

- Provider detection recognized Groq-related URLs.
- Provider labeling recognized Groq.
- OpenAI-compatible request handling was available.
- A curated Groq model list existed.
- A webhook provider registry included Groq.
- The provider specification described an OpenAI-compatible transport.

The recorded Groq base URL was:

```text
https://api.groq.com/openai/v1
```

This reduced the need for a separate transport implementation, but did not prove that authentication, request routing or end-to-end provider use was complete.

A curated model list is not evidence that a key is valid or that the provider is reachable.

## 4. Agreed inspection constraints

The handover required no package installation, directory creation, source modification, API-key entry or service restart during the initial inspection. It also required one small diagnostic step at a time, explicit host/container labels, use of the project interpreter, preservation of existing local modifications, no automatic provider switching or fallback, and no automatic paid API usage.

These were v1 working rules. They are preserved as historical decisions, not as active authorization to modify v2.

## 5. Credential directory preparation

The planned host-side credential root was:

```text
/home/deck/.config/odysseus/providers/
```

The Groq key file was named:

```text
/home/deck/.config/odysseus/providers/groq/odysseus-groq.key
```

Other provider directories were prepared for the longer-term seven-provider target.

### 5.1 Permission observations

The transcript recorded this sequence:

| Stage | Observed state |
|---|---|
| Initial inspection | Provider directories and key files were missing |
| Directory preparation | Provider subdirectories were created |
| Directory verification | Provider subdirectories reported mode `700` |
| Groq key creation | Key file was created |
| First key-file check | File reported mode `644` |
| Permission correction | A `chmod 600` operation was performed |
| Follow-up check | File reported mode `600` |

The transcript also recorded the parent directories `/home/deck/.config/odysseus` and `providers` as mode `755` at that point.

**Important:** this is a historical record of an observed correction. It is not a complete permission audit, and it does not establish that the full credential access path was secure.

### 5.2 Container identity and host mount

The historical Distrobox identity check reported:

```text
uid=1000(deck)
gid=1000(ubuntu)
```

A Podman mount inspection recorded:

```text
/home/deck -> /home/deck | RW=true
```

The container process used the host user's UID. A same-UID process could potentially access user-owned host files according to their effective permissions.

The intended key-file mode of `600` did not by itself isolate the credential from the Odysseus process. If the application process ran as the same UID, it could read that file.

The historical design therefore needed a more carefully defined trust boundary than simply storing a key outside the Git repository. This is a credential-handling finding, separate from the broader local Agent/runtime reason for retiring v1.

## 6. Credential access requirements

The proposed provider credential system aimed to keep API keys outside the repository, source code, YAML configuration, unencrypted session metadata, logs, terminal diagnostics and browser code. Agent tools that did not require credentials were not to receive access to them.

The application still needed a controlled way to obtain credentials for outbound provider requests. The broad read/write home mount and same-UID behavior complicated that requirement.

This is a historical security concern, not a recommendation to restore the old mount.

## 7. Key creation was not provider integration

Creating a key file was only a preparatory step. A complete provider integration would also have required:

1. Safe credential resolution.
2. Correct request-time authentication.
3. Integration across all relevant application request paths.
4. Protection against secret persistence in session JSON.
5. Provider-specific connection testing.
6. Separation of authentication from model discovery.
7. Sanitized logging and error handling.
8. Frontend status without secret exposure.
9. Regression tests for existing local providers, OAuth and custom endpoints.
10. Security review of the complete runtime and host access model.

The historical transcript does not establish completion of this sequence.

## 8. Known implementation boundaries

The provider investigation identified several issues the Groq implementation needed to respect:

- Existing endpoint credentials already had an encrypted storage mechanism.
- A separate API key manager already existed.
- Session headers were stored as ordinary JSON.
- A shared endpoint resolver was a natural integration point.
- Model discovery and provider authentication were separate concerns.
- Cached endpoint listings were not live health checks.
- Existing general service-health semantics were not to be changed casually.
- Multiple application request paths needed consistent credential resolution.
- Provider status needed to distinguish online, degraded, offline, authentication error and not tested.

See [the provider investigation](./ODYSSEUS-V1-PROVIDER-INVESTIGATION.md) for the consolidated findings.

## 9. Outcome

The Groq work progressed through investigation and initial credential preparation. The historical record includes a created Groq key file and a correction of its observed permissions from `644` to `600`.

The Groq integration was not completed as a validated production provider. The original v1 deployment was subsequently retired for the separate local Agent/runtime security reasons documented in [Installation and Retirement](./ODYSSEUS-V1-INSTALLATION-AND-RETIREMENT.md).

Therefore:

- Do not describe Groq as a fully integrated and validated v1 provider.
- Do not assume the old key file still exists.
- Do not assume the old credential directories remain.
- Do not restore the old Distrobox to continue the integration.
- Do not transfer old secrets into v2.
- Do not treat a successful key-file permission check as proof of a safe credential architecture.

## 10. Lessons retained

1. A key stored outside Git is not automatically protected from the application process.
2. A same-UID container process can have access to host-user files exposed through mounts.
3. File permissions must be assessed together with parent-directory permissions, identity mapping and mounts.
4. Secret access should be explicit and narrowly scoped.
5. Session metadata must not become an accidental secret store.
6. Model discovery, provider reachability and authentication need independent states.
7. A successful installation does not establish the safety of later integrations.
8. Security architecture must be reviewed before external credentials are connected to an Agent runtime.

## 11. Related historical sources

- [Provider investigation](./ODYSSEUS-V1-PROVIDER-INVESTIGATION.md)
- [Installation and retirement record](./ODYSSEUS-V1-INSTALLATION-AND-RETIREMENT.md)
- [Original Groq inspection transcript](./archive/originals/_1.1_ Odysseus - Groq Step Inspection.txt)
- [Original Groq implementation transcript](./archive/originals/_1.2_ Odysseus - Groq Step Implementation.txt)

The original conversation exports remain the source material for details not reproduced in this curated summary.
