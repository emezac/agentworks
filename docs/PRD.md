# Product Requirements Document: Agent Coordination Protocol SaaS (ACPaaS)

**Version:** 1.0
**Date:** 2023-11-16
**Status:** Draft
**Author/Owner:** [Enrique Meza C]

---

## 1. Introduction

**1.1. Overview**
Agent Coordination Protocol SaaS (ACPaaS) is a cloud-based platform designed to provide a standardized, robust, and secure protocol implementation for coordinating diverse software agents across different programming languages and environments. Positioned as the "Stripe Gateway for Agents," ACPaaS facilitates reliable bidirectional communication and task execution, initially focusing on Python and Ruby agents.

**1.2. Problem Statement**
Developing multi-agent systems often involves creating custom, complex, and error-prone communication protocols. There's a lack of standardized, commercially supported solutions that handle secure authentication, session management, reliable messaging, and cross-language compatibility (like Python/Ruby) out-of-the-box, especially for agents requiring potentially long-running task coordination (up to 15 minutes).

**1.3. Vision & Value Proposition**
ACPaaS provides the missing infrastructure layer for diverse agent orchestration. It allows developers to focus on agent logic rather than communication plumbing, enabling faster development, deployment, and management of multi-agent systems in heterogeneous environments with built-in security, reliability, and monitoring capabilities.

## 2. Goals & Objectives

* **Provide a Standardized Protocol:** Offer a well-defined, robust protocol specification based on WSS, mTLS, and concepts inspired by reliable messaging control.
* **Enable Interoperability:** Facilitate seamless bidirectional communication and task execution specifically between Python and Ruby agents (MVP), with extensibility for other languages planned.
* **Ensure Security:** Implement strong, mandatory mutual TLS (mTLS) authentication for all agent communications.
* **Guarantee Reliability:** Incorporate mechanisms for session management, message acknowledgments (ACKs), sequencing, and basic flow control.
* **Simplify Development:** Offer clear documentation, examples, and potentially SDKs/developer kits to accelerate agent integration.
* **Provide Operational Visibility:** Offer a developer dashboard for monitoring agent status, communication logs, and basic metrics.
* **Establish a Commercial Offering:** Create a viable SaaS business with tiered subscription plans based on usage and features.

## 3. Target Audience

* **Software Developers:** Building applications involving multi-agent systems, distributed task processing, or automation across different microservices/scripts.
* **AI/ML Teams:** Coordinating complex AI/ML workflows involving multiple specialized agents (e.g., data pre-processing agent, model training agent, results reporting agent) potentially written in different languages or running in different environments.
* **Companies & Enterprises:** Implementing internal automation, integration, or distributed systems requiring reliable coordination between components built with diverse technology stacks (Python/Ruby focus initially).

## 4. Core Features & Requirements (MVP - Based on 5-Day Plan Scope)

This section details the minimum viable product requirements, aligned with the proposed 5-day development sprint.

**4.1. Core Protocol Implementation**
    ***4.1.1. Transport:** Communication MUST occur over WebSockets Secure (WSS).
    *   **4.1.2. Serialization:** Messages MUST use JSON format.
    ***4.1.3. Message Structure:** All messages MUST adhere to the defined JSON schema (see Section 5.2.1), including standard fields like `tipo`, `id_mensaje`, `origen`, `destino`, `timestamp`, and protocol control fields (`id_sesion`, `numero_secuencia`, `requiere_ack`, `respuesta_a`).
    *   **4.1.4. Message Types:** The system MUST support and correctly handle the defined message types (see Section 5.2.2) covering Registration, Capability Exchange, Session Management, Task Management, Flow Control, and Reliability.

**4.2. Authentication & Security**
    ***4.2.1. Mandatory mTLS:** All WSS connections between agents and/or the platform MUST be authenticated using mutual TLS (mTLS). Connections without valid, verifiable client and server certificates MUST be rejected.
    *   **4.2.2. Certificate Validation:** The system (both Python/FastAPI backend and Ruby agent library/example) MUST validate the peer's certificate against a configured Certificate Authority (CA). Agent identity (`origen` field) SHOULD align with information in the certificate (e.g., Common Name - CN).
    *   **4.2.3. Certificate Management Support:** Provide basic documentation and scripts (using OpenSSL) for users to generate the necessary CA and agent certificates. *(Note: A full UI for cert management is likely post-MVP)*.

**4.3. Agent Lifecycle & Discovery**
    ***4.3.1. Agent Registration:** Implement handling for `REGISTRO` and `ACK_REGISTRO` messages. Successfully authenticated agents MUST register to participate.
    *   **4.3.2. Basic Agent Directory:** Maintain an internal registry of currently connected/registered agents, including their identifiers and potentially last seen status. *(Note: Full distributed discovery via gossip is post-MVP)*.
    *   **4.3.3. Capability Exchange:** Implement handling for `CAPABILITY_ANNOUNCE` and `CAPABILITY_ACK` messages. Agents MUST exchange capabilities after registration. The system SHOULD store peer capabilities. *(Note: Complex capability matching/routing is post-MVP)*.

**4.4. Session Management**
    ***4.4.1. Session Lifecycle Messages:** Implement handling for `SESSION_INIT`, `SESSION_ACCEPT`, `SESSION_REJECT`, and `SESSION_CLOSE` messages.
    *   **4.4.2. Session State Tracking:** Maintain the state (e.g., pending, active, closing) of logical sessions identified by `id_sesion`.
    ***4.4.3. Session Context:** Task-related messages (`SOLICITUD_TAREA`, `RESPUESTA_TAREA`) MUST be associated with an active session via `id_sesion`.
    *   **4.4.4. Basic Session Cleanup:** Implement mechanisms to clean up session state on explicit `SESSION_CLOSE` or potentially on agent disconnection/timeout (details TBD).

**4.5. Task Execution & Reliability**
    ***4.5.1. Task Messages:** Implement handling for `SOLICITUD_TAREA` and `RESPUESTA_TAREA` within the context of an active session.
    *   **4.5.2. Message Acknowledgement:** Implement handling for `MESSAGE_ACK`. Messages marked with `requiere_ack: true` MUST trigger a `MESSAGE_ACK` from the receiver upon successful reception.
    ***4.5.3. ACK Timeout/Retry:** Senders of messages requiring ACKs SHOULD implement a basic timeout mechanism. *(Note: Automatic retransmission strategy details TBD, logging the timeout is MVP)*.
    *   **4.5.4. Sequence Numbers:** Messages within a session SHOULD use `numero_secuencia` for ordering. The receiver SHOULD be able to detect gaps (logging gaps is MVP, requesting retransmission is post-MVP).

**4.6. Flow Control & Error Handling**
    ***4.6.1. Basic Flow Control:** Implement handling for `FLOW_CONTROL` message with `PAUSE`/`RESUME` actions. Agents receiving `PAUSE` SHOULD temporarily halt sending new requests to the sender.
    *   **4.6.2. Structured Error Reporting:** Implement handling for the `ERROR` message type. Errors encountered during message processing or task execution SHOULD be reported back using this structured format, including `respuesta_a` where applicable.
    *   **4.6.3. Robust Parsing:** Message parsing MUST gracefully handle malformed JSON or messages not conforming to the schema without crashing the agent/server.

**4.7. Basic SaaS Functionality (MVP)**
    ***4.7.1. Monitoring Dashboard:** Provide a very basic web dashboard displaying:
        *   List of registered agents and their status (connected/disconnected).
        *Simple count of messages processed / tasks handled (overall).
    *   **4.7.2. Usage Tracking Backend:** Implement backend mechanisms to track message/request counts per user/account for future billing enforcement.
    ***4.7.3. Billing Integration Points:** Integrate the Stripe SDK (or chosen provider) and implement the backend logic to associate usage with subscription tiers (Free, Basic, Pro as defined). *(Note: Full subscription management UI is post-MVP)*.
    *   **4.7.4. Tier Enforcement (Basic):** Implement basic enforcement for the Free tier limits (e.g., request counting).

**4.8. Developer Experience (MVP)**
    ***4.8.1. Core Documentation:** Provide clear documentation for:
        *   Protocol Specification (message structure, types, flows).
        *Authentication setup (mTLS certificate generation).
        *   Quick Start guide for Python agents.
        *Quick Start guide for Ruby agents.
    *   **4.8.2. Example Implementations:** Provide working, minimal example code for:
        *A Python agent acting as both client/server.
        *   A Ruby agent acting as both client/server.
        *A simple scenario showing registration, capability exchange, session initiation, task request/response, and session close between Python and Ruby.
    *   **4.8.3. Python Agent Foundation:** Leverage Langroid concepts where applicable for the Python agent implementation examples.

## 5. Design & Technical Specifications

* **5.1. Technical Stack**

* **Backend API/Coordination Hub:** Python (FastAPI)
* **Agent Implementations (Initial):** Python (using `websockets`, `asyncio`, potentially `langroid`), Ruby (using `async-websocket` or similar)
* **Communication Protocol:** WebSockets Secure (WSS)
* **Authentication:** Mutual TLS (mTLS) via OpenSSL generated certificates.
* **Message Format:** JSON
* **Frontend Dashboard:** (Specific framework TBD - e.g., React, Vue, simple HTML/JS)

**5.2. Protocol Details**
    ***5.2.1. Message Structure (JSON Schema):**
        ```json
        {
          "type": "object",
          "properties": {
            "tipo": { "type": "string", "description": "Message type identifier (e.g., REGISTRO, SOLICITUD_TAREA)" },
            "id_mensaje": { "type": "string", "format": "uuid", "description": "Unique identifier for this message" },
            "origen": { "type": "string", "description": "Unique ID of the sending agent" },
            "destino": { "type": "string", "description": "Unique ID of the intended recipient agent" },
            "respuesta_a": { "type": ["string", "null"], "format": "uuid", "description": "ID of the message this is a response/ack to" },
            "timestamp": { "type": "string", "format": "date-time", "description": "ISO 8601 UTC timestamp of message creation" },
            "id_sesion": { "type": ["string", "null"], "format": "uuid", "description": "Identifier for the logical session, if applicable" },
            "numero_secuencia": { "type": ["integer", "null"], "minimum": 0, "description": "Sequence number within a session for ordering" },
            "requiere_ack": { "type": "boolean", "default": false, "description": "Indicates if a MESSAGE_ACK is requested for this message" },
            "datos": { "type": ["object", "null"], "description": "Payload specific to the message tipo" }
          },
          "required": ["tipo", "id_mensaje", "origen", "destino", "timestamp"]
        }
        ```
    *   **5.2.2. Message Types (`tipo` field values):**
        *`REGISTRO`, `ACK_REGISTRO`
        *   `CAPABILITY_ANNOUNCE`, `CAPABILITY_ACK`
        *`SESSION_INIT`, `SESSION_ACCEPT`, `SESSION_REJECT`, `SESSION_CLOSE`
        *   `SOLICITUD_TAREA`, `RESPUESTA_TAREA`
        *`FLOW_CONTROL` (Payload indicates `PAUSE`/`RESUME` and scope)
        *   `MESSAGE_ACK`
        *`ERROR` (Payload contains error details)
    *   **5.2.3. Authentication Flow:**
        1. Client initiates WSS connection to Server (Agent-to-Agent or Agent-to-Hub).
        2. Standard TLS handshake occurs, with *both* client and server presenting certificates.
        3. Both parties validate the peer's certificate against the trusted CA. Connection proceeds only if validation succeeds.
        4. Agent sends `REGISTRO` message over the secure channel.
        5. Capabilities are exchanged via `CAPABILITY_ANNOUNCE`/`ACK`.
        6. Session management and task execution can begin.

* **5.3. Scalability Considerations (Initial Design)**

* The FastAPI backend SHOULD be designed stateless to allow horizontal scaling of WSS connection handlers.
* Agent/Session state management MAY require a distributed cache or database (e.g., Redis, PostgreSQL) if scaling beyond a single backend instance is anticipated soon.
* Consider database connection pooling.
* Implement basic rate limiting at the WSS entry point (potentially tied to authenticated user/tier later).

* **5.4. Agent Implementation Notes**

* Python agent examples will draw inspiration from Langroid's actor/message-passing model but implement the ACPaaS protocol directly.
* Ruby agent examples will use suitable asynchronous libraries (`async/async-websocket`).

## 6. Release Criteria (MVP)

The MVP is considered complete when:

* All Core Features & Requirements listed in Section 4 are implemented and demonstrably functional between Python and Ruby agents.
* mTLS authentication is enforced and working reliably.
* Basic session management and task execution flow is operational.
* ACKs and basic sequencing provide a layer of reliability.
* Basic flow control and error reporting are functional.
* A minimal monitoring dashboard shows connected agents.
* Backend usage tracking hooks for billing are in place.
* Core documentation (Protocol, Auth, Quick Starts) is available.
* Working Python and Ruby agent examples implementing a simple task exchange scenario are provided.
* Automated tests cover core protocol message handling, authentication, and session lifecycle basics.

## 7. Success Metrics

* **Adoption:** Number of registered users/accounts, Number of active agents connected daily/weekly.
* **Revenue:** Monthly Recurring Revenue (MRR) from Basic and Pro tiers.
* **Reliability:** Protocol message success rate (e.g., SOLICITUD_TAREA leading to RESPUESTA_TAREA or ERROR), Average agent connection uptime.
* **Performance:** Average latency for simple request/response cycles (within defined constraints).
* **User Satisfaction:** Support ticket volume/resolution time, Qualitative feedback from early adopters.

## 8. Future Considerations (Post-MVP Roadmap)

* **Month 1 (Stability & Feedback):** Bug fixing, documentation improvements based on feedback, performance tuning.
* **Month 3 (Feature Expansion):** Support for additional languages (e.g., Node.js, Go), Advanced session recovery mechanisms, Dashboard visualization tools for interactions, Agent templates.
* **Month 6 (Enterprise Features):** Team management features, Audit logging, Advanced monitoring/analytics, Potential on-premises deployment option.
* **Longer Term:** Enhanced capability negotiation/routing, Distributed agent discovery (gossip), Integration marketplace.

## 9. Risks

* **Technical:** Scaling WSS connections efficiently, User complexity in managing mTLS certificates, Ensuring backward compatibility during protocol evolution, Potential performance bottlenecks under high message volume.
* **Business:** Achieving market adoption against potential inertia or in-house solutions, Validating the pricing strategy, Competition emerging, Managing operational costs.

## 10. Open Issues / Questions

* Finalize detailed session timeout and cleanup strategy.
* Define specific rate limits for subscription tiers.
* Detail the exact schema for the `ERROR` message payload.
* Specify the exact strategy for handling message retransmissions on ACK timeout (avoiding duplicates).
* Determine initial cloud provider and infrastructure details (e.g., specific database, cache choices).
* User interface details for certificate management (if any in later versions).
