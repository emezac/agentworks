# ACPaaS Quick Start Guide: Python Agent

**Version:** 1.0
**Date:** 2023-11-16

---

## 1. Introduction

This guide provides instructions to set up and run a basic Python agent that can connect to the ACPaaS system (or another ACPaaS-compliant agent) using the defined protocol over WSS with mTLS authentication.

## 2. Prerequisites

* **Python:** Version 3.8 or higher recommended (due to `asyncio` usage).
* **Libraries:** Install the necessary Python libraries:

    ```bash
    pip install websockets==11.* # Or a compatible version
    # Add other dependencies if your agent logic requires them (e.g., langroid)
    # pip install langroid
    ```

* **Certificates:** You MUST have the required certificate files generated as described in `AUTHENTICATION.md`:
  * `ca-cert.pem` (The public CA certificate)
  * `<your_agent_id>-key.pem` (Your agent's private key)
  * `<your_agent_id>-cert.pem` (Your agent's public certificate)
* **ACPaaS Server/Peer:** An ACPaaS-compliant server or peer agent must be running and accessible (e.g., the FastAPI backend or another agent). Know its WSS URI (e.g., `wss://acpaas.example.com:443` or `wss://peer_agent:8766`).

## 3. Agent Configuration

Your agent script will need configuration, typically provided via environment variables, command-line arguments, or a config file. Key parameters include:

* `AGENT_ID`: Your agent's unique identifier (must match the CN in your certificate).
* `AGENT_WSS_URI`: The WSS URI where *this* agent will listen for incoming connections (if acting as a server), e.g., `wss://0.0.0.0:8765`.
* `PEER_WSS_URI`: The WSS URI of the server or initial peer to connect to.
* `CA_CERT_PATH`: Path to `ca-cert.pem`.
* `MY_CERT_PATH`: Path to `<your_agent_id>-cert.pem`.
* `MY_KEY_PATH`: Path to `<your_agent_id>-key.pem`.

## 4. Basic Agent Implementation (`agent_py.py` Example)

Below is a simplified structure based on the `websockets` library and `asyncio`. Adapt this using the full implementation provided in the main project examples.

```python
import asyncio
import websockets
import ssl
import json
import uuid
import datetime
import logging
import os
import argparse # Example for config

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(name)s %(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

# --- Configuration ---
parser = argparse.ArgumentParser()
parser.add_argument("--id", required=True, help="Unique Agent ID (matches cert CN)")
parser.add_argument("--port", type=int, required=True, help="Port for this agent to listen on")
parser.add_argument("--peer-uri", required=True, help="WSS URI of the peer/server to connect to")
parser.add_argument("--ca-cert", required=True, help="Path to ca-cert.pem")
parser.add_argument("--my-cert", required=True, help="Path to agent's cert.pem")
parser.add_argument("--my-key", required=True, help="Path to agent's key.pem")
args = parser.parse_args()

AGENT_ID = args.id
AGENT_PORT = args.port
AGENT_LISTEN_URI = f"wss://0.0.0.0:{AGENT_PORT}" # For server part
AGENT_ADVERTISE_URI = f"wss://<YOUR_AGENT_HOSTNAME_OR_IP>:{AGENT_PORT}" # IMPORTANT: Use reachable address
PEER_URI = args.peer_uri
CA_CERT = args.ca_cert
MY_CERT = args.my_cert
MY_KEY = args.my_key

# Global state (simplify for example)
active_connections = {} # peer_id -> websocket
peer_capabilities = {}
active_sessions = {} # session_id -> state

# --- SSL Context ---
def create_ssl_context(for_server: bool):
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER if for_server else ssl.PROTOCOL_TLS_CLIENT)
    try:
        context.load_cert_chain(certfile=MY_CERT, keyfile=MY_KEY)
        context.load_verify_locations(cafile=CA_CERT)
        context.verify_mode = ssl.CERT_REQUIRED
        # Disable hostname check for P2P mTLS where CN is the identity
        context.check_hostname = False
        logger.info(f"SSL Context created for {'server' if for_server else 'client'}")
        return context
    except ssl.SSLError as e:
        logger.error(f"SSL Error creating context: {e}. Check certificate paths and permissions.")
        raise
    except FileNotFoundError as e:
        logger.error(f"Certificate file not found: {e}. Check paths.")
        raise

server_ssl_context = create_ssl_context(for_server=True)
client_ssl_context = create_ssl_context(for_server=False)

# --- Message Helpers ---
def create_message(dest_agent_id, msg_type, payload=None, respuesta_a=None, id_sesion=None, num_secuencia=None, requiere_ack=False):
    # (Implementation from main example)
    msg = {
        "tipo": msg_type,
        "id_mensaje": str(uuid.uuid4()),
        "origen": AGENT_ID,
        "destino": dest_agent_id,
        "respuesta_a": respuesta_a,
        "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "id_sesion": id_sesion,
        "numero_secuencia": num_secuencia,
        "requiere_ack": requiere_ack,
        "datos": payload
    }
    return json.dumps(msg)

# --- Core Logic ---
async def process_message(websocket, message_str):
    peer_id = "?" # Determine from message or connection context
    try:
        message = json.loads(message_str)
        peer_id = message.get("origen", peer_id)
        msg_type = message.get("tipo")
        logger.info(f"Received message type '{msg_type}' from {peer_id}")

        # --- Handle REGISTRO ---
        if msg_type == "REGISTRO":
            peer_uri = message.get("datos", {}).get("uri")
            if peer_uri:
                active_connections[peer_id] = websocket # Store active connection
                logger.info(f"Agent {peer_id} registered from {peer_uri}")
                # Send ACK_REGISTRO
                ack_msg = create_message(peer_id, "ACK_REGISTRO", respuesta_a=message["id_mensaje"])
                await websocket.send(ack_msg)
                # Send CAPABILITY_ANNOUNCE
                caps_msg = create_message(peer_id, "CAPABILITY_ANNOUNCE", payload={
                    "version_protocolo": "1.1", "capacidades": ["basic_python_task"]
                })
                await websocket.send(caps_msg)
            else:
                logger.warning(f"REGISTRO from {peer_id} missing URI in datos.")

        # --- Handle ACK_REGISTRO ---
        elif msg_type == "ACK_REGISTRO":
             logger.info(f"Registration acknowledged by {peer_id}")
             # We might already be sending capabilities upon connection success

        # --- Handle CAPABILITY_ANNOUNCE ---
        elif msg_type == "CAPABILITY_ANNOUNCE":
            peer_capabilities[peer_id] = message.get("datos", {})
            logger.info(f"Received capabilities from {peer_id}: {peer_capabilities[peer_id]}")
            # Send ACK
            ack_caps = create_message(peer_id, "CAPABILITY_ACK", respuesta_a=message["id_mensaje"])
            await websocket.send(ack_caps)

        # --- Handle CAPABILITY_ACK ---
        elif msg_type == "CAPABILITY_ACK":
            logger.info(f"Capabilities acknowledged by {peer_id}")

        # --- Handle SESSION_INIT ---
        elif msg_type == "SESSION_INIT":
            session_id = message.get("id_sesion")
            # Basic acceptance logic
            logger.info(f"Received SESSION_INIT ({session_id}) from {peer_id}. Accepting.")
            active_sessions[session_id] = {"state": "active", "peer": peer_id} # Store session state
            accept_msg = create_message(peer_id, "SESSION_ACCEPT", id_sesion=session_id, respuesta_a=message["id_mensaje"])
            await websocket.send(accept_msg)
            # Send ACK if required
            if message.get("requiere_ack"):
                ack = create_message(peer_id, "MESSAGE_ACK", respuesta_a=message["id_mensaje"], id_sesion=session_id)
                await websocket.send(ack)

        # --- Handle SOLICITUD_TAREA ---
        elif msg_type == "SOLICITUD_TAREA":
            session_id = message.get("id_sesion")
            if session_id in active_sessions and active_sessions[session_id]["state"] == "active":
                # Send ACK first
                if message.get("requiere_ack"):
                     ack = create_message(peer_id, "MESSAGE_ACK", respuesta_a=message["id_mensaje"], id_sesion=session_id, num_secuencia=message.get("numero_secuencia"))
                     await websocket.send(ack)
                # Process task (dummy)
                logger.info(f"Processing task '{message['datos'].get('descripcion_tarea')}' for session {session_id}")
                await asyncio.sleep(1) # Simulate work
                # Send response
                resp_msg = create_message(peer_id, "RESPUESTA_TAREA", id_sesion=session_id, respuesta_a=message["id_mensaje"],
                                          num_secuencia=1, # Should manage sequence numbers properly
                                          payload={"estado": "exito", "resultado": "Python task done!"})
                await websocket.send(resp_msg)
            else:
                 logger.warning(f"Task request received for inactive/unknown session {session_id}")
                 # Send ERROR message (implementation omitted for brevity)

        # --- Handle RESPUESTA_TAREA ---
        elif msg_type == "RESPUESTA_TAREA":
             logger.info(f"Received task response from {peer_id}: {message.get('datos')}")
             # Match with original request, potentially close session

        # --- Handle SESSION_CLOSE ---
        elif msg_type == "SESSION_CLOSE":
             session_id = message.get("id_sesion")
             if session_id in active_sessions:
                 logger.info(f"Closing session {session_id} requested by {peer_id}")
                 del active_sessions[session_id]
                 # Send ACK if required
                 if message.get("requiere_ack"):
                    ack = create_message(peer_id, "MESSAGE_ACK", respuesta_a=message["id_mensaje"], id_sesion=session_id)
                    await websocket.send(ack)

        # --- Handle MESSAGE_ACK ---
        elif msg_type == "MESSAGE_ACK":
             logger.info(f"Received MESSAGE_ACK from {peer_id} for msg {message.get('respuesta_a')}")
             # Clear pending timeout state for that message

        # ... handle other message types ...

    except json.JSONDecodeError:
        logger.error("Failed to decode JSON message.")
    except Exception as e:
        logger.error(f"Error processing message from {peer_id}: {e}", exc_info=True)
        # Potentially send ERROR message back

# --- Connection Handlers ---
async def handle_incoming_connection(websocket, path):
    peer_name = "unknown"
    try:
        # mTLS already happened. Get peer id from REGISTRO.
        async for message in websocket:
            await process_message(websocket, message)
    except websockets.exceptions.ConnectionClosedError:
        logger.info(f"Incoming connection closed by peer.")
    except Exception as e:
        logger.error(f"Error in incoming connection handler: {e}", exc_info=True)
    finally:
        # Clean up resources associated with this connection/peer
        # Find peer_id associated with websocket and remove from active_connections
        peer_id_to_remove = None
        for pid, ws in active_connections.items():
            if ws == websocket:
                peer_id_to_remove = pid
                break
        if peer_id_to_remove:
            logger.info(f"Cleaning up connection state for disconnected peer {peer_id_to_remove}")
            del active_connections[peer_id_to_remove]
            # Also potentially clean up sessions associated with this peer

async def connect_to_peer(peer_uri):
    peer_id = "peer" # Should derive from URI or config
    while True: # Basic reconnect loop
        try:
            async with websockets.connect(peer_uri, ssl=client_ssl_context) as websocket:
                logger.info(f"Connected to peer: {peer_uri}")
                active_connections[peer_id] = websocket # Assume fixed peer ID for simplicity

                # 1. Send REGISTRO
                reg_msg = create_message(peer_id, "REGISTRO", payload={"uri": AGENT_ADVERTISE_URI})
                await websocket.send(reg_msg)
                logger.info("Sent REGISTRO")

                # --- Example: Initiate a task after connection ---
                await asyncio.sleep(2) # Wait for registration/caps exchange to settle
                logger.info("Attempting to initiate session and task...")
                session_id = str(uuid.uuid4())
                init_msg = create_message(peer_id, "SESSION_INIT", id_sesion=session_id, requiere_ack=True)
                await websocket.send(init_msg)
                # (Need logic to wait for SESSION_ACCEPT before sending task)
                # Placeholder: Assume session accepted after short delay
                await asyncio.sleep(1)
                task_msg = create_message(peer_id, "SOLICITUD_TAREA", id_sesion=session_id, num_secuencia=1, requiere_ack=True,
                                          payload={"descripcion_tarea": "Process data from Python"})
                await websocket.send(task_msg)
                logger.info("Sent SESSION_INIT and SOLICITUD_TAREA")
                # --- End Example ---

                # Listen for incoming messages on this connection
                async for message in websocket:
                    await process_message(websocket, message)

        except (websockets.exceptions.ConnectionClosedError, OSError, ssl.SSLError) as e:
            logger.warning(f"Connection to peer {peer_uri} lost or failed: {e}. Reconnecting in 5s...")
            if peer_id in active_connections: del active_connections[peer_id] # Clear stale connection
            await asyncio.sleep(5)
        except Exception as e:
             logger.error(f"Unexpected error connecting to peer {peer_uri}: {e}. Retrying in 10s...", exc_info=True)
             if peer_id in active_connections: del active_connections[peer_id]
             await asyncio.sleep(10)


async def main():
    # Start server to listen for incoming connections
    server = await websockets.serve(
        handle_incoming_connection,
        "0.0.0.0",
        AGENT_PORT,
        ssl=server_ssl_context
    )
    logger.info(f"Agent {AGENT_ID} listening on wss://0.0.0.0:{AGENT_PORT}")

    # Start task to connect to the initial peer
    connect_task = asyncio.create_task(connect_to_peer(PEER_URI))

    await asyncio.gather(server.wait_closed(), connect_task) # Keep running

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Agent shutting down.")
    except Exception as e:
        logger.critical(f"Unhandled exception in main: {e}", exc_info=True)
Use code with caution.
Markdown
5. Running the Agent
Save the code above as agent_py.py (or similar).

Generate the necessary certificates (ca-cert.pem, my_agent_id-cert.pem, my_agent_id-key.pem).

Run the agent from your terminal, providing the correct arguments:

python agent_py.py \
  --id "agente_py" \
  --port 8765 \
  --peer-uri "wss://<PEER_HOSTNAME_OR_IP>:8766" \
  --ca-cert ./ca-cert.pem \
  --my-cert ./agente_py-cert.pem \
  --my-key ./agente_py-key.pem
Use code with caution.
Bash
(Replace <PEER_HOSTNAME_OR_IP> and port 8766 with the actual address of the Ruby agent or ACPaaS server).

Observe the logs for connection status, registration, capability exchange, and any task processing messages.

6. Next Steps
Flesh out the process_message function to handle all defined protocol messages.

Implement proper state management for sessions and sequence numbers.

Add robust error handling and potentially retry logic for ACKs.

Integrate your specific agent logic (e.g., using Langroid) to perform actual tasks.

Refer to the full examples provided in the main ACPaaS project repository.
