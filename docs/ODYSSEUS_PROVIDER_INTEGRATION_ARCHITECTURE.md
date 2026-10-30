# ODYSSEUS — Provider Integration Architecture

**Document:** ODYSSEUS_PROVIDER_INTEGRATION_ARCHITECTURE.md  
**Project:** Odysseus  
**Purpose:** Permanent architectural reference for secure multi-provider integration  
**Initial implementation target:** Groq  
**Architecture target:** Seven cloud providers  
**Discovery status:** 56-step investigation completed  
**Implementation status:** Not started  
**Document location:** `/home/deck/OdysseusRecovery/`

---

## 1. Mission and architectural objective

This document records the findings, constraints, security decisions, and proposed architecture resulting from the 56-step investigation of the existing Odysseus codebase.

The objective is to integrate multiple cloud AI providers into Odysseus without compromising its existing architecture, credential security, session handling, or local functionality.

Groq is the first implementation target.

However, the architecture must be designed once and support seven providers:

1. Groq
2. Cloudflare
3. OpenAI
4. Gemini
5. Mistral
6. Cerebras
7. OpenRouter

The intention is not to build seven independent integrations.

The intention is to build one shared provider architecture, then onboard each provider through its configuration and provider-specific transport requirements.

### Core principles

- Diagnose before modifying.
- Reuse existing architecture wherever possible.
- Centralize credential resolution.
- Keep provider secrets outside the project repository.
- Never persist host-file credentials in unencrypted session data.
- Preserve existing custom endpoint and OAuth functionality.
- Keep provider selection manual.
- Never automatically switch providers.
- Never automatically consume paid API allowance.
- Keep model discovery separate from connection authentication.
- Keep API availability separate from web-search or grounding availability.
- Preserve existing local providers and functionality.
- Make changes incrementally and test each step.

---

## 2. Discovery history — 56-step investigation

The investigation was deliberately performed before implementation.

Its purpose was to understand the existing application rather than introduce a second, competing provider system.

The following discovery milestones record the verified architectural findings. They are grouped by subject rather than reconstructing unverified command-by-command chronology.

### 2.1 Project and runtime discovery

Verified:

- Project root: `/home/deck/OdysseusProject`
- Container: `odysseus-box`
- Container operating system: Ubuntu 24.04
- Project Python environment: `.venv`
- Project interpreter: `/home/deck/OdysseusProject/.venv/bin/python`
- Python version: 3.12.3
- Web interface: `http://192.168.1.161:7011/`
- ChromaDB container: `odysseus-chromadb`
- ChromaDB host binding: `127.0.0.1:8100`

Important runtime rule:

The project must be entered before running Python imports that depend on the `src` package.

Correct pattern:

```bash
cd /home/deck/OdysseusProject || exit 1
./.venv/bin/python -c "..."
```

The Steam Deck host Python is not the Odysseus project interpreter.

### 2.2 Existing project state

The project already contains a substantial provider architecture.

Relevant areas include:

- `src/llm_core.py`
- `src/endpoint_resolver.py`
- `src/api_key_manager.py`
- `src/secret_storage.py`
- `src/foreground_model_routing.py`
- `src/service_health.py`
- `core/database.py`
- `core/session_manager.py`
- `routes/model_routes.py`
- `routes/session_routes.py`
- `routes/chat_routes.py`
- `routes/chat_helpers.py`
- `routes/research/research_routes.py`
- `routes/memory/memory_routes.py`
- `routes/history/history_routes.py`
- `routes/compare/compare_routes.py`
- `routes/webhook/webhook_routes.py`

The existing provider architecture is extensive.

The integration must extend it, not replace it.

### 2.3 Existing Groq support

Verified existing Groq-related behavior:

- Provider detection already recognizes `groq.com`.
- Provider labeling already recognizes Groq.
- The application already uses OpenAI-compatible request handling.
- Groq has a curated model list.
- The webhook provider registry already contains Groq.
- The provider specification already describes its OpenAI-compatible transport.

Existing Groq base URL:

```text
https://api.groq.com/openai/v1
```

Existing curated models include:

- `openai/gpt-oss-120b`
- `openai/gpt-oss-20b`
- `groq/compound`
- `groq/compound-mini`
- `llama-3.1-8b-instant`
- `llama-3.3-70b-versatile`
- `llama-4-scout-17b-16e-instruct`
- `llama-4-maverick-17b-128e-instruct`

Important distinction:

A curated model list is not proof that a provider is reachable or that its API key is valid.

Model availability and provider authentication must be treated as separate concerns.

### 2.4 Existing credential storage

Two existing credential systems were discovered.

**A. ModelEndpoint credentials**

The `ModelEndpoint` database model contains:

```python
api_key = Column(EncryptedText, nullable=True)
```

The `EncryptedText` type uses `src.secret_storage`.

Its encryption key is:

```text
/home/deck/OdysseusProject/data/.app_key
```

This protects database credentials at rest.

**B. API key manager**

`src/api_key_manager.py` uses a separate encrypted file:

```text
data/api_keys.json
```

Its encryption key is:

```text
data/.key
```

These are two existing storage systems with different purposes.

The provider integration must not introduce an unnecessary third general-purpose secret store.

The new host-file provider credentials are a deliberately defined, separate mechanism for managed provider keys.

### 2.5 Important encryption finding

The `DbSession.headers` database column is:

```python
headers = Column(JSON, default=dict)
```

It is ordinary JSON, not encrypted.

This is a critical security discovery.

Authentication headers containing bearer tokens or API keys must not be written into this column.

The future architecture must resolve credentials at request time and keep host-file secrets out of persisted session metadata.

### 2.6 Existing endpoint resolution

The existing shared resolver is:

```python
resolve_endpoint_runtime(ep, owner)
```

It currently:

- Normalizes endpoint URLs.
- Reads the endpoint's database API key.
- Resolves OAuth/session-backed credentials when `provider_auth_id` is present.
- Returns the resolved base URL and API key.

This is the natural foundation for the new provider credential resolution architecture.

The new implementation should extend this shared boundary rather than scatter provider-key file reads throughout application routes.

### 2.7 Existing application call paths

The investigation identified multiple paths that use endpoint credentials.

Important examples:

- Model discovery and refresh
- Main chat requests
- Session creation
- Session switching
- Chat route reconciliation
- Research
- Memory operations
- History compaction
- Compare requests
- Background monitoring
- Agent session tools
- Webhooks

Some discovery and refresh paths already use the shared endpoint resolver.

Other paths directly access `ep.api_key` or use session headers.

These differences must be addressed carefully.

A provider key-file implementation that only supports model discovery would be incomplete.

### 2.8 Existing model discovery and health behavior

The existing `_probe_endpoint()` function:

- Calls provider model discovery.
- Uses provider-specific handling where necessary.
- May fall back to curated model lists.
- Does not independently provide a reliable authentication result.

The existing `_ping_endpoint()` function:

- Checks endpoint reachability.
- Exposes HTTP status information.
- Treats certain unsuccessful HTTP responses as unreachable.
- Does not currently provide the complete provider-specific status classification required by this architecture.

The existing `providers_health()` function:

- Uses model discovery.
- Treats nonempty model results as success.
- Is part of the general service-health system.

The general service-health system must retain its existing semantics.

A separate provider connection-test mechanism is required.

### 2.9 Existing endpoint listing behavior

The `/model-endpoints` listing route is intentionally cache-only.

It derives its status from cached model inventory and endpoint state.

It does not perform a live provider connection test.

This behavior should remain unchanged.

The user interface must distinguish:

- Model inventory information
- Live provider connection health
- Credential availability

An endpoint with cached models is not necessarily online.

An endpoint with no cached models is not necessarily offline.

### 2.10 Existing frontend behavior

Relevant frontend file:

```text
static/js/admin.js
```

Existing endpoint rendering uses fields such as:

- `online`
- `status`
- `has_key`
- `api_key_fingerprint`
- model count

Some existing UI logic assumes that `online` describes model inventory.

The integration must preserve backward compatibility for existing endpoints.

Host-file credentials will need their own non-secret metadata.

The UI must never receive the actual provider key.

The investigation also established that broad rewrites of:

```text
static/index.html
static/js/app.js
```

are not part of the preferred approach.

Any required provider interface changes should be isolated and reversible.

---

## 3. Security architecture

### 3.1 Host-side provider key storage

The agreed host-side directory structure is:

```text
/home/deck/.config/odysseus/
└── providers/
    ├── groq/
    │   └── odysseus-groq.key
    ├── cloudflare/
    │   └── odysseus-cloudflare.key
    ├── openai/
    │   └── odysseus-openai.key
    ├── gemini/
    │   └── odysseus-gemini.key
    ├── mistral/
    │   └── odysseus-mistral.key
    ├── cerebras/
    │   └── odysseus-cerebras.key
    └── openrouter/
        └── odysseus-openrouter.key
```

The files are stored outside the Odysseus Git repository.

Expected permissions:

- Files owned by `deck`.
- Key files mode `600`.
- Provider directories restricted appropriately.
- No API keys in source files.
- No API keys in YAML configuration.
- No API keys in logs.
- No API keys in prompts.
- No API keys exposed to browser JavaScript.

### 3.2 Container access

Verified:

- Distrobox mounts `/home/deck` into the container.
- The mount is read/write.
- The project runtime executes as UID 1000.
- The host home directory is mode `700`.
- The host `.config` directory is mode `755`.

A key file owned by `deck` with mode `600` should be readable by the application running as that same UID.

Important limitation:

This is not a read-only mount or a separate security boundary.

The application process running as `deck` can potentially read and modify files accessible to that user.

The design therefore relies on restrictive filesystem permissions and disciplined application behavior, not on a claim of container-level isolation.

### 3.3 Credential resolution principle

The intended flow:

```text
HOST
  |
  | Provider key file
  v
SHARED CREDENTIAL RESOLVER
  |
  | Resolve key at request time
  v
REQUEST-SPECIFIC AUTH HEADERS
  |
  v
ODYSSEUS PROVIDER REQUEST
  |
  v
CLOUD PROVIDER
```

Credentials should be resolved only when required.

The actual secret should not be returned to frontend code or persisted in session JSON.

### 3.4 Session protection

Session metadata should retain:

- Endpoint ID
- Endpoint URL
- Model
- Route identity
- Non-secret configuration

It should not contain host-file provider authentication headers.

Target:

```text
SESSION DATABASE
  |
  +-- endpoint_id
  +-- endpoint_url
  +-- model
  +-- route metadata
  |
  +-- NO host-file API key
  +-- NO persisted host-file bearer token
```

Existing custom endpoint credentials and OAuth behavior must continue to work.

Legacy session headers require a controlled compatibility and migration strategy.

Do not silently delete existing session credentials.

Do not blindly clear every session header: some existing functionality may depend on explicitly supplied custom headers.

### 3.5 Existing modifications that must be preserved

The investigation identified existing local changes:

```text
M  src/builtin_mcp.py
?? decktools/
?? requirements-odysseus.txt
```

These are not part of the provider integration and must be preserved.

Never use destructive Git cleanup or reset operations as part of this work.

---

## 4. Seven-provider architecture

### 4.1 Provider registry

The architecture must support:

| Provider | Provider ID |
|---|---|
| Groq | `groq` |
| Cloudflare | `cloudflare` |
| OpenAI | `openai` |
| Gemini | `gemini` |
| Mistral | `mistral` |
| Cerebras | `cerebras` |
| OpenRouter | `openrouter` |

Each provider should have a consistent configuration and logging location.

### 4.2 Project-side provider directories

Target structure:

```text
/home/deck/OdysseusProject/providers/
├── groq/
│   ├── config.yaml
│   └── logs/
│       ├── api.log
│       └── errors.log
├── cloudflare/
│   ├── config.yaml
│   └── logs/
│       ├── api.log
│       └── errors.log
├── openai/
│   ├── config.yaml
│   └── logs/
│       ├── api.log
│       └── errors.log
├── gemini/
│   ├── config.yaml
│   └── logs/
│       ├── api.log
│       └── errors.log
├── mistral/
│   ├── config.yaml
│   └── logs/
│       ├── api.log
│       └── errors.log
├── cerebras/
│   ├── config.yaml
│   └── logs/
│       ├── api.log
│       └── errors.log
└── openrouter/
    ├── config.yaml
    └── logs/
        ├── api.log
        └── errors.log
```

These directories are organizational.

They do not imply seven separate binaries, runtimes, or application instances.

Provider-specific configuration must not contain secrets.

### 4.3 Shared provider services

The intended shared architecture consists of:

1. Provider registry
2. Provider configuration
3. Credential resolver
4. Request authentication/header builder
5. Connection-test service
6. Model discovery integration
7. Provider status classification
8. Sanitized logging
9. Frontend status interface
10. Provider-specific tests

Provider-specific behavior should be isolated behind this common architecture.

### 4.4 Manual provider selection

The provider selector must be manual.

Requirements:

- User explicitly selects the provider.
- User explicitly selects the model.
- No automatic provider switching.
- No automatic fallback to another cloud provider.
- No automatic paid API usage.
- A conversation should retain its selected provider unless the user changes it.
- Provider usage allowance and web-search allowance must be tracked separately.

---

## 5. Provider connection health

### 5.1 Required status values

The provider connection system must distinguish:

- `ONLINE`
- `DEGRADED`
- `OFFLINE`
- `AUTH ERROR`
- `NOT TESTED`

Rate limiting and server errors should also expose a useful reason within the degraded state.

### 5.2 HTTP and transport classification

| Result | Classification |
|---|---|
| Authenticated HTTP 2xx | ONLINE |
| HTTP 401 | AUTH ERROR |
| HTTP 403 | AUTH ERROR |
| HTTP 429 | DEGRADED — RATE LIMITED |
| HTTP 5xx | DEGRADED — SERVER ERROR |
| DNS failure | OFFLINE |
| TLS failure | OFFLINE |
| Connection refused | OFFLINE |
| Network timeout | OFFLINE |
| No connection test performed | NOT TESTED |

A provider returning HTTP 429 is reachable.

A provider returning HTTP 5xx is reachable but experiencing a server-side problem.

Neither should be incorrectly described as a network outage.

### 5.3 Authentication must be independently verified

A model list is not proof of authentication.

A curated model fallback must never produce an ONLINE result.

A successful connection test must demonstrate that the provider accepted an authenticated request.

Model discovery and authentication are related but separate operations.

### 5.4 Existing health system separation

Keep the existing general service-health vocabulary:

```text
ok
degraded
down
disabled
```

Do not silently change its meaning to the new provider-specific vocabulary.

The new provider test mechanism must be independent of the general service-health aggregate.

The existing cache-only endpoint listing must also remain cache-only.

### 5.5 Search and grounding availability

A successful API request does not prove that web search or grounding is available.

These must be represented as separate capabilities.

Do not infer search availability from successful model authentication.

Do not infer model capabilities merely from a model ID.

---

## 6. Provider interface and logging requirements

### 6.1 Provider information displayed

The Command Center should eventually show:

- Provider name
- Connection status
- Credential availability
- Selected model
- Active provider
- Last connection test
- Test Connection action
- Provider-specific logs
- Useful error explanations

The interface must not display API keys.

### 6.2 Required log fields

Provider API logs should include, where available:

- Timestamp
- Provider
- Model
- Request ID
- HTTP status
- Latency
- Token usage
- Error category
- Sanitized error message

### 6.3 Logging security

Never log:

- API keys
- Authorization headers
- Bearer tokens
- Full secret-bearing request headers
- Secret-bearing configuration values

Technical errors should be sanitized before being shown to the user.

Authentication failures should be distinguishable from connectivity failures.

### 6.4 Frontend integration approach

Preferred order:

1. Inspect existing UI architecture.
2. Prefer existing settings and configuration mechanisms.
3. Add isolated provider dashboard components where appropriate.
4. Make isolated HTML/CSS/JavaScript changes only when required.
5. Preserve existing authentication and Content Security Policy.
6. Back up affected files before modifying them.
7. Verify reversibility and test behavior.

Avoid broad rewrites of existing application frontend files.

---

## 7. Proposed implementation sequence

Implementation is deliberately separate from the discovery and documentation phase.

Each step must be completed and verified before moving to the next.

### Step 1 — Host key foundation

Establish the seven-provider directory structure on the Steam Deck host.

Requirements:

- Correct ownership.
- Restrictive directory permissions.
- Key-file permissions of `600`.
- No secret values in the repository.
- No changes to Odysseus application code.

### Step 2 — Shared credential resolver

Extend the existing endpoint credential-resolution architecture.

Requirements:

- Resolve managed provider keys from host files.
- Preserve existing encrypted database credentials.
- Preserve OAuth/session-backed credential behavior.
- Preserve explicitly supplied custom endpoint credentials.
- Never expose secrets to frontend code.
- Avoid introducing another general-purpose secret store.

### Step 3 — Session credential protection

Adapt session handling so managed host-file credentials are resolved at request time.

Requirements:

- Do not persist host-file authentication headers in `DbSession.headers`.
- Preserve endpoint identity and model selection.
- Preserve legacy custom endpoint behavior.
- Establish a controlled legacy-header compatibility strategy.
- Avoid destructive migration or silent deletion of existing credentials.

### Step 4 — Runtime integration

Integrate the shared resolver across the relevant request paths.

Areas to verify include:

- Main chat
- Session creation
- Session switching
- Chat route reconciliation
- Research
- Memory
- History compaction
- Compare
- Background monitoring
- Agent session tools
- Webhooks
- Model discovery and refresh

Only paths that actually require provider credentials should be changed.

Local providers and unrelated image-provider paths must remain unaffected.

### Step 5 — Groq connection testing

Implement a dedicated provider connection test.

Requirements:

- Use the host-file credential resolver.
- Do not submit the actual key through the existing form-based endpoint test.
- Do not persist the key into `ModelEndpoint.api_key`.
- Do not automatically create or assign an endpoint.
- Distinguish authentication, rate limiting, server errors, and transport failures.
- Never let curated model fallback prove authentication.

### Step 6 — Provider interface

Introduce the provider status and configuration interface.

Requirements:

- Manual provider selection.
- Manual model selection.
- Clear status information.
- Test Connection.
- Sanitized logs.
- No key exposure.
- No automatic fallback or switching.

### Step 7 — Verification

Verify the implementation through tests and controlled runtime checks.

Test categories:

- Credential file permissions.
- Credential resolution.
- Existing database credential compatibility.
- OAuth compatibility.
- Session persistence security.
- Request header construction.
- Chat operation.
- Model discovery.
- Connection status classification.
- Frontend behavior.
- Secret redaction.
- Existing local endpoint regression tests.

The implementation must not be considered complete merely because a model appears in a model list.

---

## 8. Testing and acceptance criteria

The provider integration is acceptable only when all relevant criteria are met.

### Credential security

- [ ] Host keys remain outside the Git repository.
- [ ] Key files are owned by `deck`.
- [ ] Key files use mode `600`.
- [ ] Secrets do not appear in logs.
- [ ] Secrets do not appear in browser responses.
- [ ] Host-file credentials are not persisted in session JSON.
- [ ] Existing encrypted endpoint credentials still work.
- [ ] Existing OAuth/session credentials still work.

### Provider connection

- [ ] Valid authenticated request produces ONLINE.
- [ ] HTTP 401 produces AUTH ERROR.
- [ ] HTTP 403 produces AUTH ERROR.
- [ ] HTTP 429 produces DEGRADED — RATE LIMITED.
- [ ] HTTP 5xx produces DEGRADED — SERVER ERROR.
- [ ] DNS/TLS/refused connection produces OFFLINE.
- [ ] Untested provider produces NOT TESTED.
- [ ] Curated model fallback cannot produce ONLINE.

### Runtime integration

- [ ] Main chat uses the shared resolver.
- [ ] Session switching uses the shared resolver.
- [ ] Research and memory paths remain functional.
- [ ] Background and agent paths remain functional.
- [ ] Existing local providers remain functional.
- [ ] Existing custom endpoint credentials remain functional.
- [ ] Existing endpoint inventory remains cache-only.

### User interface

- [ ] Provider status is understandable.
- [ ] Model selection is manual.
- [ ] Provider selection is manual.
- [ ] Test Connection works.
- [ ] Logs are sanitized.
- [ ] No automatic provider switching occurs.
- [ ] No automatic paid API usage occurs.

---

## 9. Future provider onboarding

Once the common architecture is proven with Groq, the remaining providers should be onboarded one at a time.

For every new provider:

1. Confirm its official API base URL.
2. Confirm authentication requirements.
3. Confirm model discovery behavior.
4. Confirm request and streaming compatibility.
5. Confirm provider-specific error behavior.
6. Add provider configuration.
7. Add provider-specific tests.
8. Verify the common connection-status classifier.
9. Verify secret handling.
10. Verify manual selection and model behavior.

Do not assume that every provider supports identical request parameters, streaming behavior, model discovery, tools, or search capabilities.

The common architecture should provide shared infrastructure without pretending provider capabilities are identical.

---

## 10. Protected project boundaries

The following rules apply throughout implementation.

- Do not delete or reset existing project changes.
- Preserve the existing `src/builtin_mcp.py` modification.
- Preserve `decktools/`.
- Preserve `requirements-odysseus.txt`.
- Do not replace existing endpoint systems unnecessarily.
- Do not modify unrelated Pi-hole, SSH, Stable Diffusion, or Local AI projects.
- Do not enable automatic startup.
- Do not introduce automatic provider fallback.
- Do not expose API keys to the browser.
- Do not perform destructive database migrations without explicit review.
- Back up affected files before modifications.
- Verify each change before proceeding.

---

## 11. Current implementation status

| Area | Status |
|---|---|
| 56-step discovery | COMPLETE |
| Existing provider architecture inspection | COMPLETE |
| Existing credential storage inspection | COMPLETE |
| Session header security finding | VERIFIED |
| Provider status requirements | DEFINED |
| Seven-provider architecture | PROPOSED |
| Architecture documentation | THIS DOCUMENT |
| Host key foundation | NOT STARTED |
| Shared credential resolver | NOT STARTED |
| Session protection changes | NOT STARTED |
| Runtime integration | NOT STARTED |
| Groq connection test | NOT STARTED |
| Provider interface | NOT STARTED |
| Remaining provider onboarding | NOT STARTED |

No source-code implementation is authorized merely by the completion of this document.

Implementation requires explicit approval of the relevant step.

---

## 12. Architectural decision record

The following decisions are the current agreed direction.

**ADR-001 — One shared provider architecture**

Build common provider infrastructure once for seven providers. Groq is the first implementation.

**ADR-002 — Host-side managed credentials**

Managed provider keys live outside the project repository under:

```text
/home/deck/.config/odysseus/providers/
```

**ADR-003 — Request-time credential resolution**

Resolve host-file credentials at the request boundary. Do not store them in unencrypted session headers.

**ADR-004 — Preserve existing credential mechanisms**

Existing encrypted database credentials and OAuth/session-backed credentials must continue working.

**ADR-005 — Separate inventory from health**

Cached model inventory is not live provider connection health.

**ADR-006 — Authentication must be proven**

Curated models and successful model-list fallback cannot prove API authentication.

**ADR-007 — Explicit provider health states**

Use ONLINE, DEGRADED, OFFLINE, AUTH ERROR, and NOT TESTED, with meaningful reason classifications.

**ADR-008 — Manual provider selection**

No automatic switching, fallback, or paid usage.

**ADR-009 — Search is a separate capability**

API connectivity does not establish web-search or grounding availability.

**ADR-010 — Incremental implementation**

One small, verified implementation step at a time.

---

## 13. Final note

This document is the architectural reference for the Odysseus multi-provider integration.

It records what was discovered, why the existing architecture matters, what security risks were identified, and what the implementation must preserve.

Future implementation changes should be compared against this document.

If the architecture changes, update this document deliberately and record the reason.

**The guiding principle: understand first, design once, implement carefully, verify everything.**

---

**End of document.**
