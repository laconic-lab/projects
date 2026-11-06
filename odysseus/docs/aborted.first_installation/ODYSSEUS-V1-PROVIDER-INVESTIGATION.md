# Odysseus v1 — Cloud Provider Architecture Investigation

| Document control | Value |
|---|---|
| Project generation | Odysseus v1 |
| Workstream | Cloud AI provider integration |
| Historical investigation | 56-step discovery, as recorded in the architecture reference |
| Initial provider target | Groq |
| Planned provider set | Seven providers |
| Implementation outcome | No approved production integration |
| Current status | Historical / superseded |
| Last corrected | 2026-11-06 |

> **Scope clarification:** This document records the separate v1 cloud-provider and credential-handling workstream. These findings are not the primary reason the original v1 Distrobox was removed. The v1 retirement decision concerned local Agent authority and inadequate host isolation; see [Installation and Retirement](./ODYSSEUS-V1-INSTALLATION-AND-RETIREMENT.md).

## 1. Purpose

This document consolidates provider-integration discoveries from the first Odysseus project.

The investigation aimed to integrate cloud AI providers into an existing application without replacing its existing endpoint, OAuth, local-provider or session behavior. The historical target was a shared provider architecture, beginning with Groq and eventually accommodating seven providers.

The key discovery was that provider integration was not simply an API-key field or model-list addition. It touched credential resolution, request construction, session persistence, model discovery, health reporting, logging, frontend behavior and multiple application call paths.

## 2. Intended provider scope

| Provider | Identifier | Historical priority |
|---|---|---|
| Groq | `groq` | First integration target |
| Cloudflare | `cloudflare` | Planned |
| OpenAI | `openai` | Planned |
| Gemini | `gemini` | Planned |
| Mistral | `mistral` | Planned |
| Cerebras | `cerebras` | Planned |
| OpenRouter | `openrouter` | Planned |

This list records design intent. It does not indicate that all seven providers were implemented, tested or enabled.

## 3. Existing application architecture discovered

The v1 investigation found an existing provider and endpoint architecture. The preferred approach was to extend shared services rather than create parallel provider logic.

| Area | Historical component or location | Role identified |
|---|---|---|
| LLM requests | `src/llm_core.py` | Existing model request handling |
| Endpoint resolution | `src/endpoint_resolver.py` | Shared endpoint runtime resolution |
| API key management | `src/api_key_manager.py` | Existing API key management |
| Secret storage | `src/secret_storage.py` | Existing encrypted storage support |
| Foreground routing | `src/foreground_model_routing.py` | Model/provider routing |
| Service health | `src/service_health.py` | Existing aggregate service health |
| Database | `core/database.py` | Persistent application state |
| Sessions | `core/session_manager.py` | Session handling |
| Model routes | `routes/model_routes.py` | Model and endpoint API paths |
| Session routes | `routes/session_routes.py` | Session API paths |
| Chat routes | `routes/chat_routes.py` | Chat request paths |
| Frontend administration | `static/js/admin.js` | Existing administrative interface |

These names are a historical inventory, not a guarantee that the same files or interfaces exist in v2 or in a current upstream version.

## 4. Credential-storage findings

### 4.1 Encrypted endpoint credentials

The investigation recorded an encrypted API-key field on the historical `ModelEndpoint` model:

```python
api_key = Column(EncryptedText, nullable=True)
```

The encryption implementation was associated with `src.secret_storage`. The investigation recorded an application key at:

```text
/home/deck/OdysseusProject/data/.app_key
```

### 4.2 Separate API key manager

A separate API key manager was also recorded, using:

```text
data/api_keys.json
data/.key
```

These were two existing mechanisms with different responsibilities. The proposed provider integration was not intended to introduce a third general-purpose credential store without a clear reason.

### 4.3 Critical session persistence finding

The historical `DbSession.headers` column was recorded as ordinary JSON:

```python
headers = Column(JSON, default=dict)
```

It was not an encrypted secret store.

**Design constraint:** host-file provider credentials and bearer tokens must not be persisted in ordinary session-header JSON. The intended design was to resolve credentials when constructing an outbound request and keep secret-bearing headers out of persistent session metadata.

Existing custom endpoint and OAuth behavior would need to remain compatible. Clearing all existing headers without understanding their purpose would not be a safe migration strategy.

## 5. Shared endpoint-resolution boundary

The investigation identified this existing resolver:

```python
resolve_endpoint_runtime(ep, owner)
```

Its recorded responsibilities included normalizing endpoint URLs, resolving endpoint credentials stored through the existing mechanism, resolving OAuth/session-backed credentials when configured, and returning runtime endpoint information for request construction.

The architectural preference was to extend this shared resolution boundary rather than scatter provider-specific file reads throughout individual routes.

This was a design direction, not evidence that complete host-file credential integration was implemented.

## 6. Model discovery is not authentication

The investigation highlighted that curated model lists and cached model inventories do not prove that a provider accepted the user's credentials.

| Concern | What it establishes | What it does not establish |
|---|---|---|
| Curated model list | Models known to the application | Provider availability or valid credentials |
| Cached model inventory | Previously stored model information | Current live connectivity |
| Model discovery request | Discovery endpoint response | Necessarily a valid authenticated inference path |
| Authenticated connection test | Provider accepted a suitable authenticated request | Availability of unrelated web-search capabilities |
| Web search / grounding test | Search capability availability | General model API availability |

A fallback to curated models must never be treated as proof of successful authentication.

## 7. Provider health model

The historical design proposed a provider-specific status vocabulary:

| Status | Meaning |
|---|---|
| `ONLINE` | A suitable authenticated provider request succeeded |
| `DEGRADED` | Provider is reachable but reports rate limiting, server-side failure or another partial issue |
| `OFFLINE` | Network or transport connectivity is unavailable |
| `AUTH ERROR` | Credentials are missing, invalid or rejected |
| `NOT TESTED` | No suitable live test has been performed |

Illustrative classification:

| Observed result | Intended classification |
|---|---|
| Authenticated HTTP 2xx | ONLINE |
| HTTP 401 | AUTH ERROR |
| HTTP 403 | AUTH ERROR, subject to provider-specific interpretation |
| HTTP 429 | DEGRADED — rate limited |
| HTTP 5xx | DEGRADED — server error |
| DNS failure | OFFLINE |
| TLS failure | OFFLINE |
| Connection refused | OFFLINE |
| Network timeout | OFFLINE |
| No live test | NOT TESTED |

Provider-specific semantics would still need implementation and testing.

### 7.1 Preserve existing service-health semantics

The investigation sought to keep the existing general service-health vocabulary separate:

```text
ok
degraded
down
disabled
```

A new provider connection test should not silently redefine the existing aggregate health system. The historical endpoint listing was also intended to remain cache-only rather than unexpectedly triggering live provider requests.

## 8. Request paths requiring review

The investigation found that provider credentials could be used by multiple application paths, not only model discovery. Recorded areas included:

- Model discovery and refresh.
- Main chat requests.
- Session creation and switching.
- Chat route reconciliation.
- Research and memory operations.
- History compaction.
- Compare requests.
- Background monitoring.
- Agent session tools.
- Webhooks.

A credential resolver integrated into only one path would leave the provider integration incomplete. Each path would need inspection against the actual application version before implementation.

## 9. Historical host-side credential proposal

The proposed secret location was outside the Git repository:

```text
/home/deck/.config/odysseus/providers/
```

Planned structure:

```text
providers/
├── groq/odysseus-groq.key
├── cloudflare/odysseus-cloudflare.key
├── openai/odysseus-openai.key
├── gemini/odysseus-gemini.key
├── mistral/odysseus-mistral.key
├── cerebras/odysseus-cerebras.key
└── openrouter/odysseus-openrouter.key
```

| Property | Intended value |
|---|---|
| Owner | `deck` |
| Key-file mode | `600` |
| Location | Outside the Git repository |
| Secret in YAML/source | Prohibited |
| Secret in logs | Prohibited |
| Secret in browser UI | Prohibited |
| Secret in unencrypted session data | Prohibited |

The subsequent Groq work exposed a mismatch between intended permissions and an observed file state at one point. See [the Groq integration attempt](./ODYSSEUS-V1-GROQ-INTEGRATION-ATTEMPT.md).

## 10. Credential access and the former runtime

The provider work also highlighted a separate credential-access concern: the historical Distrobox process used the host user's UID and had a read/write host-home mount. A same-UID process may access host-user files according to effective permissions, so storing a key outside the Git repository or setting its mode to `600` did not, by itself, isolate it from the application process.

This overlap is relevant to credential threat modelling, but it does not change the causal history of the retirement decision: the original deployment was retired because the local Agent's effective authority and runtime isolation were unacceptable. Provider credential design remained a separate unfinished workstream.

## 11. Manual provider selection and cost controls

The intended behavior was conservative:

- Provider selection is manual.
- Model selection is manual.
- No automatic provider switching.
- No automatic fallback to another provider.
- No automatic consumption of paid API allowance.
- A conversation retains its selected provider unless the user changes it.
- Model/API allowance and web-search/grounding allowance are separate capabilities.

Registering several providers must not cause the application to query all of them automatically.

## 12. Logging and frontend requirements

The historical design called for operational diagnostics without exposing secrets.

Potential log fields included timestamp, provider identifier, model identifier, request ID, HTTP status, latency, token usage where available, error category and sanitized error message.

The following must never be logged or returned to frontend code:

- API keys.
- Authorization headers.
- Bearer tokens.
- Secret-bearing configuration values.
- Full request headers containing credentials.

The frontend was intended to show provider status and credential availability without receiving the underlying key. The preferred approach was incremental and modular, preserving existing authentication, Content Security Policy and frontend behavior.

## 13. Implementation status and limitations

The historical investigation was recorded as a 56-step discovery phase. It produced an architectural direction and identified integration points.

| Item | Historical state |
|---|---|
| Existing provider architecture inspected | Yes, as recorded by the investigation |
| Shared credential-resolution boundary identified | Yes |
| Session-header persistence risk identified | Yes |
| Provider health requirements defined | Yes |
| Seven-provider target documented | Yes |
| Groq selected as first target | Yes |
| Host-side key directory preparation started | Yes |
| Groq key file created | Recorded in the implementation transcript |
| All seven providers implemented | No evidence |
| Complete end-to-end integration validated | Not established |
| v1 deployment approved for continued operation | No; retired for local Agent/runtime security reasons |

## 14. Relationship to the current project

This investigation preserves engineering reasoning and historical lessons. It must not be used as a current implementation checklist without review.

Odysseus v2 is a separate project. Its audit must determine the acceptable runtime, trust boundaries, credential access mechanism, Agent permissions, filesystem access and network policy independently.

The [v1 provider architecture reference](../ODYSSEUS_PROVIDER_INTEGRATION_ARCHITECTURE.md) remains available, but its implementation-status statements are historical and must be read in the context of the v1 retirement.
