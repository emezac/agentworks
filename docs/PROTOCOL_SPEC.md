# ACPaaS Protocol Specification

**Version:** 1.1 (Draft)
**Date:** 2023-11-16

---

## 1. Overview

This document specifies the Agent Coordination Protocol as implemented by the Agent Coordination Protocol SaaS (ACPaaS). This protocol facilitates secure, reliable, and stateful communication between heterogeneous software agents, initially focusing on Python and Ruby implementations.

The protocol operates over **WebSockets Secure (WSS)** and mandates **Mutual TLS (mTLS)** for authentication. Messages are formatted using **JSON**.

## 2. Transport & Authentication

*   **Transport:** All communication MUST occur over WebSockets Secure (WSS).
*   **Authentication:** All connections MUST use Mutual TLS (mTLS). Both client and server MUST present valid X.509 certificates signed by a trusted Certificate Authority (CA). The Common Name (CN) or other certificate attributes MAY be used to correlate with the agent's identifier (`origen`). Connection MUST fail if mTLS handshake or certificate validation fails.

## 3. Message Structure

All messages in the ACPaaS protocol are JSON objects with the following structure:

```json
{
  "tipo": "string",
  "id_mensaje": "string (uuid)",
  "origen": "string",
  "destino": "string",
  "respuesta_a": "string (uuid) | null",
  "timestamp": "string (ISO 8601 UTC)",
  "id_sesion": "string (uuid) | null",
  "numero_secuencia": "integer | null",
  "requiere_ack": "boolean",
  "datos": "object | null"
}
```

### 3.1 Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id_mensaje` | String (UUID) | Yes | Unique identifier for the message. Must be a valid UUID v4. |
| `tipo` | String | Yes | Message type identifier. See section 4 for valid values. |
| `origen` | String | Yes | Identifier of the sending agent. |
| `destino` | String | Yes | Identifier of the receiving agent. Use "BROADCAST" for broadcast messages. |
| `timestamp` | String (ISO8601) | Yes | Message creation timestamp in ISO8601 format (YYYY-MM-DDTHH:MM:SS.sssZ). |
| `requiere_ack` | Boolean | No | If true, the receiver must send a MESSAGE_ACK in response. Default: false. |
| `respuesta_a` | String (UUID) | No | When responding to a message, contains the ID of the original message. |
| `id_sesion` | String (UUID) | No | Session identifier for messages that are part of a session. |
| `numero_secuencia` | Integer | No | Sequence number within a session. Required for session messages. |
| `datos` | Object | No | Message payload. Structure depends on message type. |

### 3.2 Validation Rules

1. `id_mensaje` must be a valid UUID v4 string
2. `tipo` must be one of the defined message types (see section 4)
3. `origen` and `destino` must be valid agent identifiers
4. `timestamp` must be a valid ISO8601 timestamp
5. `numero_secuencia` must be a non-negative integer
6. `respuesta_a` must be a valid UUID v4 string when present
7. `id_sesion` must be a valid UUID v4 string when present

## 4. Message Types (tipo)

This section details the defined message types and the expected structure of their datos payload.

### 4.1 Registration

Used for agents to announce their presence after successful mTLS connection.

#### REGISTRO

Direction: Agent -> Server/Peer

datos:

```json
{
  "uri": "string" // The WSS URI where this agent can be reached (e.g., "wss://agent-a.internal:8765")
}
```

Use code with caution.

Json

Notes: Sent immediately after connection establishment.

#### ACK_REGISTRO

Direction: Server/Peer -> Agent

respuesta_a: id_mensaje of the REGISTRO message.

datos: null (or optionally server confirmation details).

Notes: Confirms successful registration.

### 4.2 Capability Exchange

Used for agents to declare their capabilities and protocol understanding.

#### CAPABILITY_ANNOUNCE

Direction: Agent <-> Server/Peer

datos:

```json
{
  "version_protocolo": "string", // E.g., "1.1"
  "capacidades": ["string"],     // List of supported capabilities (e.g., ["task_processing", "langroid_basic"])
  // Optional: other limits/metadata
  "max_sesiones_concurrentes": "integer | null",
  "formatos_payload": ["string"] // E.g., ["json"]
}
```

Use code with caution.

Json

Notes: Sent by both parties after successful ACK_REGISTRO.

#### CAPABILITY_ACK

Direction: Agent <-> Server/Peer

respuesta_a: id_mensaje of the CAPABILITY_ANNOUNCE being acknowledged.

datos: null.

Notes: Confirms reception of the peer's capabilities.

### 4.3 Session Management

Used to establish, manage, and terminate logical communication sessions. All session messages REQUIRE id_sesion to be set (except SESSION_INIT which establishes it).

#### SESSION_INIT

Direction: Agent -> Peer

id_sesion: A newly generated UUID for the proposed session.

requiere_ack: Recommended true.

datos:

```json
{
  "proposito": "string | null", // Optional description of the session's goal
  "requisitos": "object | null" // Optional requirements (e.g., {"timeout_min": 30, "required_capability": "image_analysis"})
}
```

Use code with caution.

Json

Notes: Proposes a new logical session.

#### SESSION_ACCEPT

Direction: Peer -> Initiator Agent

respuesta_a: id_mensaje of the SESSION_INIT.

id_sesion: The same id_sesion from the SESSION_INIT.

datos: null (or optionally adjusted parameters).

Notes: Confirms acceptance of the session. Session becomes 'active'.

#### SESSION_REJECT

Direction: Peer -> Initiator Agent

respuesta_a: id_mensaje of the SESSION_INIT.

id_sesion: The same id_sesion from the SESSION_INIT.

datos:

```json
{
  "motivo": "string",       // Reason for rejection (e.g., "Recursos insuficientes", "Capacidad requerida no soportada")
  "codigo_error": "integer | null" // Optional error code (e.g., 429, 503)
}
```

Use code with caution.

Json

Notes: Rejects the session proposal.

#### SESSION_CLOSE

Direction: Agent -> Peer (either participant can initiate)

id_sesion: ID of the session to close.

requiere_ack: Recommended true.

datos:

```json
{
  "motivo": "string | null" // Optional reason for closing (e.g., "Tarea completada", "Timeout")
}
```

Use code with caution.

Json

Notes: Requests the orderly termination of the specified session.

### 4.4 Task Management

Used for requesting and responding to work units within an active session.

#### SOLICITUD_TAREA

Direction: Agent -> Peer (within an active session)

id_sesion: REQUIRED. ID of the active session.

numero_secuencia: REQUIRED. Next sequence number for this sender in this session.

requiere_ack: REQUIRED true.

datos:

```json
{
  "descripcion_tarea": "string", // Description of the task to be performed
  "parametros": "object | null" // Any specific parameters needed for the task
  // Potentially: "timeout_sugerido_seg": integer
}
```

Use code with caution.

Json

Notes: Assigns a task to the peer.

#### RESPUESTA_TAREA

Direction: Peer -> Requesting Agent (within an active session)

respuesta_a: id_mensaje of the SOLICITUD_TAREA.

id_sesion: REQUIRED. ID of the active session.

numero_secuencia: REQUIRED. Next sequence number for this sender in this session.

requiere_ack: Optional, depends on if the response itself is critical.

datos:

```json
{
  "estado": "string",       // e.g., "exito", "fallo"
  "resultado": "object | string | null", // The result of the task if estado is "exito"
  "error_detalle": "object | string | null" // Details if estado is "fallo" (See ERROR message for potential structure)
}
```

Use code with caution.

Json

Notes: Provides the outcome of a previously requested task.

### 4.5 Flow Control

Used for managing the rate of message transmission.

#### FLOW_CONTROL

Direction: Agent -> Peer

id_sesion: Optional. If specified, applies only to that session. If null, applies globally to the peer connection.

datos:

```json
{
  "accion": "string", // "PAUSE" or "RESUME"
  "valor": "any | null" // Optional: Could specify rate limit in future versions. null for PAUSE/RESUME.
}
```

Use code with caution.

Json

Notes: Signals the peer to temporarily stop (PAUSE) or resume (RESUME) sending non-critical messages (like new SESSION_INIT or SOLICITUD_TAREA).

### 4.6 Reliability & Error Reporting

Used for protocol-level acknowledgments and error signaling.

#### MESSAGE_ACK

Direction: Agent -> Peer

respuesta_a: id_mensaje of the message being acknowledged (the one with requiere_ack: true).

id_sesion: MUST match the id_sesion of the original message, if present.

numero_secuencia: MUST match the numero_secuencia of the original message, if present.

datos: null.

Notes: Low-level acknowledgment confirming reception of a specific message. Sent automatically by the receiver when requiere_ack was true.

#### ERROR

Direction: Agent -> Peer

respuesta_a: Optional. id_mensaje of the message that caused or is related to the error.

id_sesion: Optional. The session associated with the error, if applicable.

datos:

```json
{
  "codigo_error": "string", // A specific error code (e.g., "INVALID_MESSAGE_FORMAT", "SESSION_NOT_FOUND", "TASK_EXECUTION_FAILED", "RATE_LIMIT_EXCEEDED", "AUTH_FAILED")
  "mensaje_error": "string", // A human-readable description of the error.
  "detalles_adicionales": "object | string | null" // Optional extra context or stack trace snippet.
}
```

Use code with caution.

Json

Notes: Reports an issue encountered at the protocol or application level related to agent communication.

### 4.7 Miscellaneous (Optional - Example)

Protocols often include general status or keep-alive messages.

#### HEARTBEAT (Example - Can be added if needed)

Direction: Agent <-> Peer

id_sesion: null

datos: null

Notes: Can be sent periodically to keep the connection alive or check peer responsiveness. May expect a HEARTBEAT_ACK in response.

## 5. Standard Communication Flows (Examples)

### 5.1 Connection, Registration & Capability Exchange

Client initiates WSS connection to Server.

mTLS Handshake succeeds.

Client -> Server: REGISTRO (datos: {"uri": "wss://client:port"})

Server -> Client: ACK_REGISTRO (respuesta_a: ID of REGISTRO)

Client -> Server: CAPABILITY_ANNOUNCE (datos: {...client caps...})

Server -> Client: CAPABILITY_ANNOUNCE (datos: {...server caps...})

Client -> Server: CAPABILITY_ACK (respuesta_a: ID of Server's CAPABILITY_ANNOUNCE)

Server -> Client: CAPABILITY_ACK (respuesta_a: ID of Client's CAPABILITY_ANNOUNCE)

Connection established and ready for sessions/tasks.

### 5.2 Simple Session and Task Execution

(Assumes connection is established and capabilities exchanged)

Agent A -> Agent B: SESSION_INIT (id_sesion: uuid-1, requiere_ack: true)

Agent B -> Agent A: MESSAGE_ACK (respuesta_a: ID of SESSION_INIT)

Agent B -> Agent A: SESSION_ACCEPT (respuesta_a: ID of SESSION_INIT, id_sesion: uuid-1)

Agent A -> Agent B: SOLICITUD_TAREA (id_sesion: uuid-1, numero_secuencia: 1, requiere_ack: true, datos: {...task details...})

Agent B -> Agent A: MESSAGE_ACK (respuesta_a: ID of SOLICITUD_TAREA, id_sesion: uuid-1, numero_secuencia: 1)

(Agent B executes the task)

Agent B -> Agent A: RESPUESTA_TAREA (respuesta_a: ID of SOLICITUD_TAREA, id_sesion: uuid-1, numero_secuencia: 1, datos: { "estado": "exito", "resultado": {...}})

Agent A -> Agent B: SESSION_CLOSE (id_sesion: uuid-1, requiere_ack: true)

Agent B -> Agent A: MESSAGE_ACK (respuesta_a: ID of SESSION_CLOSE)

(Session uuid-1 is terminated on both sides)

## 6. Versioning

This document describes Version 1.1 of the ACPaaS Protocol. The protocol version should be included in the CAPABILITY_ANNOUNCE message to allow for future evolution and backward compatibility negotiation if needed.

## Message Types

The following are the official `tipo` values as defined in PRD Section 5.2.2:

- `INIT`: Initialization message for starting a session.
- `ACK`: Acknowledgment message for confirming receipt.
- `ERROR`: Error message indicating a problem.
- `REGISTRO`: Registration message for agent registration.
- `ACK_REGISTRO`: Acknowledgment for registration.
- `CAPABILITY_ANNOUNCE`: Message to announce capabilities.
- `CAPABILITY_ACK`: Acknowledgment for capability announcement.
- `SESSION_INIT`: Message to initiate a session.
- `SESSION_ACCEPT`: Acceptance of a session initiation.
- `SESSION_REJECT`: Rejection of a session initiation.
- `SESSION_CLOSE`: Message to close a session.
- `SOLICITUD_TAREA`: Task request message.
- `RESPUESTA_TAREA`: Task response message.
- `FLOW_CONTROL`: Message for flow control actions.
- `MESSAGE_ACK`: Acknowledgment for messages requiring confirmation.