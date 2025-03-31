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

All messages exchanged via the protocol MUST adhere to the following JSON structure:

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
Use code with caution.
Markdown
Field Descriptions:

Field	Type	Required	Description
tipo	string	Yes	Identifies the type of the message (see Section 4). Determines the structure of the datos field.
id_mensaje	string (uuid)	Yes	A unique identifier (UUID v4 recommended) for this specific message instance.
origen	string	Yes	The unique identifier of the agent sending the message. Should align with the authenticated identity (mTLS).
destino	string	Yes	The unique identifier of the intended recipient agent.
respuesta_a	string (uuid) | null	No	If this message is a direct response or acknowledgment to a previous message, this holds the id_mensaje of that original message. null otherwise.
timestamp	string (ISO 8601 UTC)	Yes	The UTC timestamp when the message was created by the origin agent, in ISO 8601 format (e.g., 2023-11-16T10:30:00Z).
id_sesion	string (uuid) | null	No	Identifier for a specific logical session or conversation between agents. null for global/non-session messages (e.g., REGISTRO, HEARTBEAT). Required for session-specific messages.
numero_secuencia	integer | null	No	An incremental sequence number used for ordering messages within a specific id_sesion. Starts usually at 0 or 1. null for non-session messages.
requiere_ack	boolean	No	If true, the sender requests the recipient to send a MESSAGE_ACK upon successful reception of this message. Defaults to false.
datos	object | null	No	A JSON object containing data specific to the tipo of message. null if the message type carries no payload. See Section 4 for payload structure per type.
4. Message Types (tipo)
This section details the defined message types and the expected structure of their datos payload.

4.1. Registration
Used for agents to announce their presence after successful mTLS connection.

REGISTRO

Direction: Agent -> Server/Peer

datos:

{
  "uri": "string" // The WSS URI where this agent can be reached (e.g., "wss://agent-a.internal:8765")
}
Use code with caution.
Json
Notes: Sent immediately after connection establishment.

ACK_REGISTRO

Direction: Server/Peer -> Agent

respuesta_a: id_mensaje of the REGISTRO message.

datos: null (or optionally server confirmation details).

Notes: Confirms successful registration.

4.2. Capability Exchange
Used for agents to declare their capabilities and protocol understanding.

CAPABILITY_ANNOUNCE

Direction: Agent <-> Server/Peer

datos:

{
  "version_protocolo": "string", // E.g., "1.1"
  "capacidades": ["string"],     // List of supported capabilities (e.g., ["task_processing", "langroid_basic"])
  // Optional: other limits/metadata
  "max_sesiones_concurrentes": "integer | null",
  "formatos_payload": ["string"] // E.g., ["json"]
}
Use code with caution.
Json
Notes: Sent by both parties after successful ACK_REGISTRO.

CAPABILITY_ACK

Direction: Agent <-> Server/Peer

respuesta_a: id_mensaje of the CAPABILITY_ANNOUNCE being acknowledged.

datos: null.

Notes: Confirms reception of the peer's capabilities.

4.3. Session Management
Used to establish, manage, and terminate logical communication sessions. All session messages REQUIRE id_sesion to be set (except SESSION_INIT which establishes it).

SESSION_INIT

Direction: Agent -> Peer

id_sesion: A newly generated UUID for the proposed session.

requiere_ack: Recommended true.

datos:

{
  "proposito": "string | null", // Optional description of the session's goal
  "requisitos": "object | null" // Optional requirements (e.g., {"timeout_min": 30, "required_capability": "image_analysis"})
}
Use code with caution.
Json
Notes: Proposes a new logical session.

SESSION_ACCEPT

Direction: Peer -> Initiator Agent

respuesta_a: id_mensaje of the SESSION_INIT.

id_sesion: The same id_sesion from the SESSION_INIT.

datos: null (or optionally adjusted parameters).

Notes: Confirms acceptance of the session. Session becomes 'active'.

SESSION_REJECT

Direction: Peer -> Initiator Agent

respuesta_a: id_mensaje of the SESSION_INIT.

id_sesion: The same id_sesion from the SESSION_INIT.

datos:

{
  "motivo": "string",       // Reason for rejection (e.g., "Recursos insuficientes", "Capacidad requerida no soportada")
  "codigo_error": "integer | null" // Optional error code (e.g., 429, 503)
}
Use code with caution.
Json
Notes: Rejects the session proposal.

SESSION_CLOSE

Direction: Agent -> Peer (either participant can initiate)

id_sesion: ID of the session to close.

requiere_ack: Recommended true.

datos:

{
  "motivo": "string | null" // Optional reason for closing (e.g., "Tarea completada", "Timeout")
}
Use code with caution.
Json
Notes: Requests the orderly termination of the specified session.

4.4. Task Management
Used for requesting and responding to work units within an active session.

SOLICITUD_TAREA

Direction: Agent -> Peer (within an active session)

id_sesion: REQUIRED. ID of the active session.

numero_secuencia: REQUIRED. Next sequence number for this sender in this session.

requiere_ack: REQUIRED true.

datos:

{
  "descripcion_tarea": "string", // Description of the task to be performed
  "parametros": "object | null" // Any specific parameters needed for the task
  // Potentially: "timeout_sugerido_seg": integer
}
Use code with caution.
Json
Notes: Assigns a task to the peer.

RESPUESTA_TAREA

Direction: Peer -> Requesting Agent (within an active session)

respuesta_a: id_mensaje of the SOLICITUD_TAREA.

id_sesion: REQUIRED. ID of the active session.

numero_secuencia: REQUIRED. Next sequence number for this sender in this session.

requiere_ack: Optional, depends on if the response itself is critical.

datos:

{
  "estado": "string",       // e.g., "exito", "fallo"
  "resultado": "object | string | null", // The result of the task if estado is "exito"
  "error_detalle": "object | string | null" // Details if estado is "fallo" (See ERROR message for potential structure)
}
Use code with caution.
Json
Notes: Provides the outcome of a previously requested task.

4.5. Flow Control
Used for managing the rate of message transmission.

FLOW_CONTROL

Direction: Agent -> Peer

id_sesion: Optional. If specified, applies only to that session. If null, applies globally to the peer connection.

datos:

{
  "accion": "string", // "PAUSE" or "RESUME"
  "valor": "any | null" // Optional: Could specify rate limit in future versions. null for PAUSE/RESUME.
}
Use code with caution.
Json
Notes: Signals the peer to temporarily stop (PAUSE) or resume (RESUME) sending non-critical messages (like new SESSION_INIT or SOLICITUD_TAREA).

4.6. Reliability & Error Reporting
Used for protocol-level acknowledgments and error signaling.

MESSAGE_ACK

Direction: Agent -> Peer

respuesta_a: id_mensaje of the message being acknowledged (the one with requiere_ack: true).

id_sesion: MUST match the id_sesion of the original message, if present.

numero_secuencia: MUST match the numero_secuencia of the original message, if present.

datos: null.

Notes: Low-level acknowledgment confirming reception of a specific message. Sent automatically by the receiver when requiere_ack was true.

ERROR

Direction: Agent -> Peer

respuesta_a: Optional. id_mensaje of the message that caused or is related to the error.

id_sesion: Optional. The session associated with the error, if applicable.

datos:

{
  "codigo_error": "string", // A specific error code (e.g., "INVALID_MESSAGE_FORMAT", "SESSION_NOT_FOUND", "TASK_EXECUTION_FAILED", "RATE_LIMIT_EXCEEDED", "AUTH_FAILED")
  "mensaje_error": "string", // A human-readable description of the error.
  "detalles_adicionales": "object | string | null" // Optional extra context or stack trace snippet.
}
Use code with caution.
Json
Notes: Reports an issue encountered at the protocol or application level related to agent communication.

4.7. Miscellaneous (Optional - Example)
Protocols often include general status or keep-alive messages.

HEARTBEAT (Example - Can be added if needed)

Direction: Agent <-> Peer

id_sesion: null

datos: null

Notes: Can be sent periodically to keep the connection alive or check peer responsiveness. May expect a HEARTBEAT_ACK in response.

5. Standard Communication Flows (Examples)
5.1. Connection, Registration & Capability Exchange
Client initiates WSS connection to Server.

mTLS Handshake succeeds.

Client -> Server: REGISTRO (datos: {"uri": "wss://client:port"})

Server -> Client: ACK_REGISTRO (respuesta_a: ID of REGISTRO)

Client -> Server: CAPABILITY_ANNOUNCE (datos: {...client caps...})

Server -> Client: CAPABILITY_ANNOUNCE (datos: {...server caps...})

Client -> Server: CAPABILITY_ACK (respuesta_a: ID of Server's CAPABILITY_ANNOUNCE)

Server -> Client: CAPABILITY_ACK (respuesta_a: ID of Client's CAPABILITY_ANNOUNCE)

Connection established and ready for sessions/tasks.

5.2. Simple Session and Task Execution
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

6. Versioning
This document describes Version 1.1 of the ACPaaS Protocol. The protocol version should be included in the CAPABILITY_ANNOUNCE message to allow for future evolution and backward compatibility negotiation if needed.