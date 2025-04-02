# ACPaaS - 5-Day Development To-Do List

## Legend

* `[ ]` - To Do
* `[x]` - Done
* `(P)` - Python Task
* `(R)` - Ruby Task
* `(B)` - Both Python & Ruby Task
* `(S)` - Server/Platform Task (FastAPI Backend)
* `(D)` - Documentation/Infra/Other Task

---

## Day 1: Core Protocol Definition & Authentication System

**Objective:** Define the protocol specification and implement the authentication system with mTLS.

### 1. Define Protocol Message Structure

* [x] (D) Finalize JSON schema definition (as provided in PRD Section 5.2.1) in `docs/PROTOCOL_SPEC.md`.
* [x] (P) Implement `create_message(**kwargs)` helper function in Python agent base. Include default values (`requiere_ack=False`, etc.).
* [x] (D) List all official `tipo` values (message types from PRD Section 5.2.2) in `docs/PROTOCOL_SPEC.md`.
* [x] (P) Implement `parse_message(json_str)` helper function in Python agent base. Include basic validation (required fields present).
* [x] (R) Implement `create_message(**kwargs)` helper function in Ruby agent base. Include default values.
* [x] (R) Implement `parse_message(json_str)` helper function in Ruby agent base. Include basic validation.

### 2. Authentication System Implementation (mTLS)

* [x] (D) Create OpenSSL script `scripts/generate_ca.sh` to generate `ca-key.pem` and `ca-cert.pem`.
* [x] (D) Move `generate_agent_cert.sh` script to `bin/` directory.
* [x] (D) Create OpenSSL script `scripts/generate_agent_cert.sh <agent_name>` to generate `agent_name-key.pem`, `agent_name-csr.pem`, and sign it with the CA to create `agent_name-cert.pem`.
* [x] (D) Document certificate generation process (using the scripts) in `docs/AUTHENTICATION.md`.
* [x] (S, P) Configure Python WSS server (FastAPI/websockets) for mTLS:
  * [x] Require client certificates.
  * [x] Load server cert/key.
  * [x] Load CA cert for client verification.
  * [x] Set `verify_mode = ssl.CERT_REQUIRED`.
* [x] (P) Configure Python WSS client connection logic for mTLS:
  * [x] Load client cert/key.
  * [x] Load CA cert for server verification.
  * [x] Set `verify_mode = ssl.CERT_REQUIRED`.
* [ ] (R) Configure Ruby WSS server (`async-websocket` with `async-ssl`) for mTLS:
  * [ ] Require client certificates (`verify_mode = OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT`).
  * [ ] Load server cert/key.
  * [ ] Load CA cert (`ca_file`).
* [ ] (R) Configure Ruby WSS client connection logic for mTLS:
  * [ ] Load client cert/key.
  * [ ] Load CA cert (`ca_file`).
  * [ ] Set `verify_mode`.

### 3. Basic Transport Layer (WSS)

* [ ] (S, P) Create basic FastAPI project structure.
* [ ] (S, P) Add a WSS endpoint route (`/ws/{agent_id}`) using `websockets` library integration.
* [ ] (R) Create basic Ruby agent script structure using `async-websocket` server and client patterns.
* [ ] (B) Implement basic WSS connection handling (log on_connect, on_disconnect).

### 4. Day 1 Testing & Deliverables

* [ ] (D) Create initial `docs/PROTOCOL_SPEC.md` with message structure and types.
* [ ] (D) Create certificate generation scripts (`scripts/`) and `docs/AUTHENTICATION.md`.
* [ ] (B) Test basic WSS connectivity **with mTLS enabled** between:
  * [ ] Python Server <-> Python Client
  * [ ] Ruby Server <-> Ruby Client
  * [ ] Python Server <-> Ruby Client
  * [ ] Ruby Server <-> Python Client
* [ ] (B) Verify connections fail if incorrect/missing certificates are used.

---

## Day 2: Agent Registration & Capability Exchange

**Objective:** Implement agent registration, discovery (basic), and capability exchange mechanisms.

### 1. Agent Registration System

* [ ] (P) Implement `REGISTRO` sending logic in Python client (after successful connect/mTLS). Payload should include its advertised URI.
* [ ] (S, P) Implement `REGISTRO` handling logic in Python server:
  * [ ] Verify authenticated agent ID matches `origen`.
  * [ ] Store agent ID and connection status in a simple in-memory `agent_directory` (dict).
  * [ ] Store agent's advertised URI.
* [ ] (S, P) Implement `ACK_REGISTRO` sending logic from Python server upon successful registration.
* [ ] (P) Implement `ACK_REGISTRO` handling logic in Python client (confirm registration success).
* [ ] (R) Implement `REGISTRO` sending logic in Ruby client.
* [ ] (S, R?) Implement `REGISTRO` handling logic (Ruby server - *Note: Initially, the platform backend (Python) might handle all registration*).
* [ ] (S, R?) Implement `ACK_REGISTRO` sending logic (Ruby server - *See note above*).
* [ ] (R) Implement `ACK_REGISTRO` handling logic in Ruby client.
* [ ] (S) Define data structure for `agent_directory` (e.g., `Dict[str, Dict]`).

### 2. Capability Exchange Protocol

* [ ] (P) Implement `CAPABILITY_ANNOUNCE` sending in Python client/server (after successful `ACK_REGISTRO`). Define sample capabilities (e.g., `{"version": "1.0", "capabilities": ["langroid_basic_task"]}`).
* [ ] (P) Implement `CAPABILITY_ANNOUNCE` handling in Python client/server: Store peer capabilities in an in-memory `peer_capabilities` dict (`Dict[str, Dict]`).
* [ ] (P) Implement `CAPABILITY_ACK` sending in Python client/server upon receiving `CAPABILITY_ANNOUNCE`.
* [ ] (P) Implement `CAPABILITY_ACK` handling in Python client/server (log confirmation).
* [ ] (R) Implement `CAPABILITY_ANNOUNCE` sending in Ruby client/server. Define sample capabilities (e.g., `{"version": "1.0", "capabilities": ["ruby_data_processor"]}`).
* [ ] (R) Implement `CAPABILITY_ANNOUNCE` handling in Ruby client/server. Store peer capabilities.
* [ ] (R) Implement `CAPABILITY_ACK` sending in Ruby client/server.
* [ ] (R) Implement `CAPABILITY_ACK` handling in Ruby client/server.
* [ ] (S) Define data structure for `peer_capabilities` storage (potentially linked to `agent_directory`).

### 3. Dashboard Foundations

* [ ] (S, P) Set up basic web framework route in FastAPI for the dashboard (or use a separate simple frontend framework).
* [ ] (S, P) Create dashboard API endpoint `/api/v1/agents` that returns data from the `agent_directory`.
* [ ] (S, P) Add basic message counters (e.g., `messages_processed`) to the main WSS handler.
* [ ] (S, P) Create dashboard API endpoint `/api/v1/metrics` that returns simple counters.
* [ ] (D) Create a minimal HTML/JS frontend to display data from `/api/v1/agents` and `/api/v1/metrics`.
* [ ] (S, P) Add placeholder functions/logic for tier checks (`def check_tier_limit(user_id, action): return True`).

### 4. Day 2 Testing & Deliverables

* [ ] (B) Test agent registration flow (Python <-> Ruby). Verify agent details appear in the `agent_directory` via API or logs.
* [ ] (B) Test capability exchange flow (Python <-> Ruby). Verify capabilities are stored/logged correctly.
* [ ] (D) Check basic dashboard page loads and displays agent/metric data.
* [ ] (D) Create initial test suite stubs for registration and capability exchange logic.

---

## Day 3: Session Management & Task Execution

**Objective:** Implement logical session management and task execution framework.

### 1. Session Management

* [ ] (S) Define session state data structure (e.g., in-memory `sessions: Dict[str, Dict]`, storing `session_id`, `state` ('pending', 'active', 'closing'), `participants`, `seq_sent`, `seq_recv`, `created_at`).
* [ ] (B) Implement `SESSION_INIT` sending logic (e.g., triggered by a user action or agent need). Generate `id_sesion`.
* [ ] (B) Implement `SESSION_INIT` handling logic:
  * [ ] Check if peer is capable/available.
  * [ ] Store session as 'pending'.
  * [ ] Send `SESSION_ACCEPT` or `SESSION_REJECT`.
* [ ] (B) Implement `SESSION_ACCEPT` sending/handling (Update session state to 'active').
* [ ] (B) Implement `SESSION_REJECT` sending/handling (Remove 'pending' session state).
* [ ] (B) Implement `SESSION_CLOSE` sending/handling (Remove 'active' session state).
* [ ] (S) Implement basic session cleanup (e.g., background task to remove 'pending' sessions older than X seconds, remove 'active' sessions on agent disconnect).

### 2. Task Request/Response System

* [ ] (B) Implement `SOLICITUD_TAREA` sending logic:
  * [ ] Must be within an 'active' session.
  * [ ] Include `id_sesion`.
  * [ ] Include next `numero_secuencia`.
  * [ ] Set `requiere_ack: true`.
  * [ ] Store request details locally to correlate response.
* [ ] (B) Implement `SOLICITUD_TAREA` handling logic:
  * [ ] Validate `id_sesion` and `numero_secuencia`.
  * [ ] Send `MESSAGE_ACK` (see next section).
  * [ ] Execute dummy task (e.g., `asyncio.sleep(2)` / `task.sleep(2)`).
  * [ ] Send `RESPUESTA_TAREA`.
* [ ] (B) Implement `RESPUESTA_TAREA` sending logic:
  * [ ] Include `respuesta_a` (original task msg id).
  * [ ] Include `id_sesion`.
  * [ ] Include next `numero_secuencia`.
* [ ] (B) Implement `RESPUESTA_TAREA` handling logic:
  * [ ] Validate `id_sesion` and `numero_secuencia`.
  * [ ] Correlate with original `SOLICITUD_TAREA`.
  * [ ] Log result.

### 3. Reliability Implementation (ACKs & Sequencing)

* [ ] (B) Implement `MESSAGE_ACK` sending logic, triggered immediately upon receiving a message with `requiere_ack: true`. Must include correct `respuesta_a`, `id_sesion`, `numero_secuencia`.
* [ ] (B) Implement `MESSAGE_ACK` handling logic:
  * [ ] Correlate with the original sent message ID (`respuesta_a`).
  * [ ] Clear any pending ACK timeout/state for that message.
* [ ] (B) Add `seq_sent` and `seq_recv` tracking per participant within the session state data structure.
* [ ] (B) Implement sequence number assignment logic: Increment `seq_sent` for the sender within the session before sending session messages (`SOLICITUD_TAREA`, `RESPUESTA_TAREA`, etc.).
* [ ] (B) Implement sequence number validation logic: Upon receiving a session message, compare `numero_secuencia` with expected `seq_recv`. Log errors/warnings for mismatches or gaps. Increment expected `seq_recv` if valid.
* [ ] (B) Implement basic timeout logic for expecting `MESSAGE_ACK` after sending a message with `requiere_ack: true`. Log a warning if timeout occurs. *(Advanced retry logic is post-MVP)*.

### 4. Day 3 Testing & Deliverables

* [ ] (B) Test full session lifecycle (INIT -> ACCEPT -> SOLICITUD_TAREA -> RESPUESTA_TAREA -> CLOSE) between Python and Ruby.
* [ ] (B) Verify `MESSAGE_ACK` messages are sent/received correctly for tasks.
* [ ] (B) Verify sequence numbers are incremented and validated (check logs for warnings on manual manipulation).
* [ ] (B) Test `SESSION_REJECT` flow.
* [ ] (D) Extend test suite for session and task execution flows.

---

## Day 4: Flow Control, Error Handling & Billing Integration

**Objective:** Implement flow control, error handling, and subscription billing hooks.

### 1. Flow Control Implementation

* [ ] (B) Implement `FLOW_CONTROL` sending logic (Payload: `{"action": "PAUSE"}` or `{"action": "RESUME"}`, optional `id_sesion`). Trigger manually via a command or simple heuristic (e.g., > N active tasks).
* [ ] (B) Implement `FLOW_CONTROL` handling logic:
  * [ ] Set/unset an internal state flag (e.g., `peer_paused[peer_id] = True/False`).
  * [ ] Check this flag before sending new `SESSION_INIT` or `SOLICITUD_TAREA` messages.

### 2. Error Handling System

* [ ] (B) Implement `ERROR` message sending logic. Trigger on:
  * [ ] Message parsing failures (invalid JSON, missing fields).
  * [ ] Invalid state (e.g., task request received for unknown session).
  * [ ] Exceptions during task execution.
  * [ ] Include details in `datos`: `{"code": "ERR_CODE", "message": "Details...", "original_message_id": "uuid"}`. Use `respuesta_a`.
* [ ] (B) Implement `ERROR` message handling logic:
  * [ ] Log error details clearly.
  * [ ] Potentially close the related session if the error is fatal for it.
* [ ] (B) Review all message handling code (`parse_message`, task execution) and wrap critical sections in `try...except / rescue` blocks that trigger `ERROR` message sending on failure.

### 3. Billing Integration

* [ ] (S, P) Add Stripe Python SDK dependency (`pip install stripe`).
* [ ] (S, P) Implement backend usage counter logic: Increment counters per `account_id` (associated with agent/user) for specific actions (e.g., `SESSION_INIT`, `SOLICITUD_TAREA`). Store counts (in-memory/simple DB for MVP).
* [ ] (S, P) Define hardcoded tier limits (e.g., `FREE_LIMIT = 5`, `BASIC_LIMIT = 1000`).
* [ ] (S, P) Implement `check_usage_limit(account_id, action)` function:
  * [ ] Retrieve current count for the account.
  * [ ] Get account's tier (hardcode/placeholder).
  * [ ] Compare count against tier limit. Return `True` (allowed) or `False` (denied).
* [ ] (S, P) Add calls to `check_usage_limit` before processing potentially billable actions (`SESSION_INIT`, `SOLICITUD_TAREA`). If denied, send an `ERROR` message back.
* [ ] (S, P) Create placeholder FastAPI endpoints for webhook handling (`/stripe-webhook`) and potentially basic subscription status (`/api/v1/subscription`).

### 4. Day 4 Testing & Deliverables

* [ ] (B) Test `FLOW_CONTROL` PAUSE/RESUME logic manually. Verify new tasks are blocked when paused.
* [ ] (B) Test `ERROR` message generation by sending invalid JSON or triggering task exceptions. Verify `ERROR` is received and logged.
* [ ] (S) Test basic usage limit enforcement: Send more requests than the free tier limit and verify subsequent requests are rejected with an error.
* [ ] (D) Document `FLOW_CONTROL` and `ERROR` message details in `PROTOCOL_SPEC.md`.

---

## Day 5: Documentation, Examples & Deployment Prep

**Objective:** Complete documentation, create examples, and prepare for deployment.

### 1. Protocol Documentation Finalization

* [ ] (D) Review and complete `docs/PROTOCOL_SPEC.md` with all message types, fields, and standard flows (handshake, session, task, error).
* [ ] (D) Write `docs/QUICK_START_PYTHON.md` covering setup, auth, connection, and basic task execution.
* [ ] (D) Write `docs/QUICK_START_RUBY.md` covering setup, auth, connection, and basic task execution.
* [ ] (D) Create/update the main project `README.md` with overview, features, setup instructions, and links to other docs.

### 2. Example Implementations

* [ ] (P) Refine Python agent code into a clean, reusable example (`examples/python_agent/`).
* [ ] (R) Refine Ruby agent code into a clean, reusable example (`examples/ruby_agent/`).
* [ ] (P) Create a minimal Python client script (`examples/python_client/`) demonstrating connect, register, send one task, receive response.
* [ ] (R) Create a minimal Ruby client script (`examples/ruby_client/`) demonstrating connect, register, send one task, receive response.
* [ ] (B) Implement a complex interaction example:
  * [ ] Agent A (Python) starts session with Agent B (Ruby).
  * [ ] A sends Task 1 to B.
  * [ ] B needs info, sends Task 2 *back to A* within the same session.
  * [ ] A completes Task 2, sends response to B.
  * [ ] B uses Task 2 result to complete Task 1, sends response to A.
  * [ ] A closes the session.
  * [ ] Place this in `examples/complex_interaction/`.

### 3. Deployment Preparation

* [ ] (D) Choose initial Cloud Provider (e.g., AWS, GCP, Azure).
* [ ] (D) Draft basic infrastructure setup steps or script (IaC preferred - e.g., Terraform, Pulumi) for:
  * [ ] Compute instance (VM/Container runner like EC2, GCE, App Service).
  * [ ] Basic networking (VPC/Subnet).
  * [ ] Firewall rules (Allow WSS traffic on specified port).
  * [ ] (Optional) Basic database/cache service (e.g., RDS, ElastiCache).
* [ ] (S, P) Create `Dockerfile` for the FastAPI backend application.
* [ ] (S, P) Configure basic health check endpoint (e.g., `/health`) in FastAPI.
* [ ] (D) Set up basic monitoring alerts (e.g., CPU utilization, health check failures) using Cloud Provider tools.
* [ ] (D) Write `docs/DEPLOYMENT.md` outlining the steps to deploy the backend.

### 4. Developer Kit & Final Review

* [ ] (D) Organize `examples/`, `scripts/`, `docs/` into a clear structure.
* [ ] (D) Write a brief `DEV_KIT_GUIDE.md` explaining the contents and how to get started.
* [ ] (B) Perform final end-to-end testing of all major features (Auth, Register, Caps, Session, Task, ACK, Seq, Error, Flow Control) between Python and Ruby.
* [ ] (B, S, D) Review all code and documentation for consistency, clarity, and correctness. Fix any remaining bugs or typos.
