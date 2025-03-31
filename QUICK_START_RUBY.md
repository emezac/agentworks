# ACPaaS Quick Start Guide: Ruby Agent

**Version:** 1.0
**Date:** 2023-11-16

---

## 1. Introduction

This guide provides instructions to set up and run a basic Ruby agent that can connect to the ACPaaS system (or another ACPaaS-compliant agent) using the defined protocol over WSS with mTLS authentication. This example uses the `async` suite of gems.

## 2. Prerequisites

*   **Ruby:** Version 2.7 or higher recommended.
*   **Gems:** Install the necessary gems:
    ```bash
    gem install async async-websocket async-io async-ssl json logger securerandom openssl
    ```
*   **Certificates:** You MUST have the required certificate files generated as described in `AUTHENTICATION.md`:
    *   `ca-cert.pem` (The public CA certificate)
    *   `<your_agent_id>-key.pem` (Your agent's private key)
    *   `<your_agent_id>-cert.pem` (Your agent's public certificate)
*   **ACPaaS Server/Peer:** An ACPaaS-compliant server or peer agent must be running and accessible (e.g., the FastAPI backend or another agent). Know its WSS URI (e.g., `wss://acpaas.example.com:443` or `wss://peer_agent:8765`).

## 3. Agent Configuration

Your agent script will need configuration. You can use environment variables, command-line arguments (e.g., using `OptionParser`), or a config file. Key parameters include:

*   `AGENT_ID`: Your agent's unique identifier (must match the CN in your certificate).
*   `AGENT_PORT`: The port this agent will listen on for incoming connections.
*   `PEER_WSS_URI`: The WSS URI of the server or initial peer to connect to.
*   `CA_CERT_PATH`: Path to `ca-cert.pem`.
*   `MY_CERT_PATH`: Path to `<your_agent_id>-cert.pem`.
*   `MY_KEY_PATH`: Path to `<your_agent_id>-key.pem`.

## 4. Basic Agent Implementation (`agent_rb.rb` Example)

Below is a simplified structure based on the `async` gems. Adapt this using the full implementation provided in the main project examples.

```ruby
require 'async'
require 'async/websocket/client'
require 'async/websocket/server'
require 'async/io/endpoint'
require 'async/ssl'
require 'json'
require 'securerandom'
require 'openssl'
require 'logger'
require 'optparse' # Example for config

# --- Configuration ---
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: agent_rb.rb [options]"
  opts.on("--id AGENT_ID", "Unique Agent ID (matches cert CN)") { |v| options[:agent_id] = v }
  opts.on("--port PORT", Integer, "Port for this agent to listen on") { |v| options[:port] = v }
  opts.on("--peer-uri URI", "WSS URI of the peer/server") { |v| options[:peer_uri] = v }
  opts.on("--ca-cert PATH", "Path to ca-cert.pem") { |v| options[:ca_cert] = v }
  opts.on("--my-cert PATH", "Path to agent's cert.pem") { |v| options[:my_cert] = v }
  opts.on("--my-key PATH", "Path to agent's key.pem") { |v| options[:my_key] = v }
end.parse!

AGENT_ID = options[:agent_id] || raise("Missing --id")
AGENT_PORT = options[:port] || raise("Missing --port")
PEER_URI_STR = options[:peer_uri] || raise("Missing --peer-uri")
CA_CERT_PATH = options[:ca_cert] || raise("Missing --ca-cert")
MY_CERT_PATH = options[:my_cert] || raise("Missing --my-cert")
MY_KEY_PATH = options[:my_key] || raise("Missing --my-key")

AGENT_LISTEN_URI = "wss://0.0.0.0:#{AGENT_PORT}" # For server part
# IMPORTANT: Use reachable address/hostname for advertising
AGENT_ADVERTISE_URI = "wss://<YOUR_AGENT_HOSTNAME_OR_IP>:#{AGENT_PORT}"

$logger = Logger.new($stdout)
$logger.level = Logger::INFO
$logger.formatter = proc { |sev, datetime, _, msg| "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} #{sev}: #{msg}\n" }

# Global state (simplify for example)
$active_connections = {} # peer_id => connection object
$peer_capabilities = {}
$active_sessions = {} # session_id => state

# --- SSL Context ---
def create_ssl_context
  context = OpenSSL::SSL::SSLContext.new
  begin
    context.cert = OpenSSL::X509::Certificate.new(File.read(MY_CERT_PATH))
    context.key = OpenSSL::PKey::RSA.new(File.read(MY_KEY_PATH))
    context.ca_file = CA_CERT_PATH
    # VERIFY_PEER: Request client cert. VERIFY_FAIL_IF_NO_PEER_CERT: Fail if client doesn't provide one.
    context.verify_mode = OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
    $logger.info("SSL Context created.")
    return context
  rescue Errno::ENOENT => e
    $logger.error("Certificate file not found: #{e.message}. Check paths.")
    raise
  rescue OpenSSL::SSL::SSLError => e
    $logger.error("SSL Error creating context: #{e.message}. Check certificate files.")
    raise
  end
end

# --- Message Helpers ---
def create_message(dest_agent_id, msg_type, payload = nil, respuesta_a = nil, id_sesion = nil, num_secuencia = nil, requiere_ack = false)
  # (Implementation from main example)
   {
    tipo: msg_type,
    id_mensaje: SecureRandom.uuid,
    origen: AGENT_ID,
    destino: dest_agent_id,
    respuesta_a: respuesta_a,
    timestamp: Time.now.utc.iso8601,
    id_sesion: id_sesion,
    numero_secuencia: num_secuencia,
    requiere_ack: requiere_ack,
    datos: payload
  }.to_json
end

# --- Core Logic ---
def process_message(connection, message_str)
  peer_id = "?" # Determine from message or connection context
  begin
    message = JSON.parse(message_str)
    peer_id = message['origen'] || peer_id
    msg_type = message['tipo']
    $logger.info("Received message type '#{msg_type}' from #{peer_id}")

    # --- Handle REGISTRO ---
    if msg_type == 'REGISTRO'
      peer_uri = message.dig('datos', 'uri')
      if peer_uri
        $active_connections[peer_id] = connection # Store active connection
        $logger.info("Agent #{peer_id} registered from #{peer_uri}")
        # Send ACK_REGISTRO
        ack_msg = create_message(peer_id, 'ACK_REGISTRO', respuesta_a: message['id_mensaje'])
        connection.write(ack_msg); connection.flush
        # Send CAPABILITY_ANNOUNCE
        caps_msg = create_message(peer_id, 'CAPABILITY_ANNOUNCE', payload: {
          version_protocolo: "1.1", capacidades: ["basic_ruby_task"]
        })
        connection.write(caps_msg); connection.flush
      else
         $logger.warn("REGISTRO from #{peer_id} missing URI in datos.")
      end

    # --- Handle ACK_REGISTRO ---
    elsif msg_type == 'ACK_REGISTRO'
      $logger.info("Registration acknowledged by #{peer_id}")

    # --- Handle CAPABILITY_ANNOUNCE ---
    elsif msg_type == 'CAPABILITY_ANNOUNCE'
      $peer_capabilities[peer_id] = message['datos'] || {}
      $logger.info("Received capabilities from #{peer_id}: #{$peer_capabilities[peer_id]}")
      # Send ACK
      ack_caps = create_message(peer_id, 'CAPABILITY_ACK', respuesta_a: message['id_mensaje'])
      connection.write(ack_caps); connection.flush

    # --- Handle CAPABILITY_ACK ---
    elsif msg_type == 'CAPABILITY_ACK'
      $logger.info("Capabilities acknowledged by #{peer_id}")

    # --- Handle SESSION_INIT ---
    elsif msg_type == 'SESSION_INIT'
      session_id = message['id_sesion']
      # Basic acceptance logic
      $logger.info("Received SESSION_INIT (#{session_id}) from #{peer_id}. Accepting.")
      $active_sessions[session_id] = {state: 'active', peer: peer_id} # Store session state
      accept_msg = create_message(peer_id, 'SESSION_ACCEPT', id_sesion: session_id, respuesta_a: message['id_mensaje'])
      connection.write(accept_msg); connection.flush
      # Send ACK if required
      if message['requiere_ack']
          ack = create_message(peer_id, 'MESSAGE_ACK', respuesta_a: message['id_mensaje'], id_sesion: session_id)
          connection.write(ack); connection.flush
      end

    # --- Handle SOLICITUD_TAREA ---
    elsif msg_type == 'SOLICITUD_TAREA'
      session_id = message['id_sesion']
      if $active_sessions[session_id] && $active_sessions[session_id][:state] == 'active'
        # Send ACK first
        if message['requiere_ack']
            ack = create_message(peer_id, 'MESSAGE_ACK', respuesta_a: message['id_mensaje'], id_sesion: session_id, num_secuencia: message['numero_secuencia'])
            connection.write(ack); connection.flush
        end
        # Process task (dummy, run async)
        Async do |task|
           task.annotate("Task processing for session #{session_id}")
           $logger.info("Processing task '#{message.dig('datos', 'descripcion_tarea')}' for session #{session_id}")
           task.sleep(1.5) # Simulate work
           # Send response
           resp_msg = create_message(peer_id, 'RESPUESTA_TAREA', id_sesion: session_id, respuesta_a: message['id_mensaje'],
                                     num_secuencia: 1, # Should manage sequence numbers properly
                                     payload: {estado: 'exito', resultado: 'Ruby task done!'})
           connection.write(resp_msg); connection.flush
        end
      else
           $logger.warn("Task request received for inactive/unknown session #{session_id}")
           # Send ERROR message (implementation omitted for brevity)
      end

    # --- Handle RESPUESTA_TAREA ---
    elsif msg_type == 'RESPUESTA_TAREA'
      $logger.info("Received task response from #{peer_id}: #{message['datos']}")
      # Match with original request, potentially close session

    # --- Handle SESSION_CLOSE ---
    elsif msg_type == 'SESSION_CLOSE'
      session_id = message['id_sesion']
      if $active_sessions[session_id]
        $logger.info("Closing session #{session_id} requested by #{peer_id}")
        $active_sessions.delete(session_id)
        # Send ACK if required
        if message['requiere_ack']
           ack = create_message(peer_id, 'MESSAGE_ACK', respuesta_a: message['id_mensaje'], id_sesion: session_id)
           connection.write(ack); connection.flush
        end
      end

    # --- Handle MESSAGE_ACK ---
    elsif msg_type == 'MESSAGE_ACK'
      $logger.info("Received MESSAGE_ACK from #{peer_id} for msg #{message['respuesta_a']}")
      # Clear pending timeout state for that message

    # ... handle other message types ...

    end

  rescue JSON::ParserError
    $logger.error("Failed to decode JSON message.")
  rescue => e
    $logger.error("Error processing message from #{peer_id}: #{e.message}", backtrace: e.backtrace)
    # Potentially send ERROR message back
  end
end

# --- Connection Handlers ---
# Handle incoming connections
def handle_incoming_connection(connection)
  peer_name = "unknown_incoming"
  begin
    $logger.info "Incoming connection established."
    # mTLS handled by server setup. Get peer id from REGISTRO.
    while message = connection.read # Blocking read within the connection's task
      process_message(connection, message)
    end
  rescue EOFError, Errno::ECONNRESET, Async::Wrapper::Cancelled, OpenSSL::SSL::SSLError => e
    $logger.info("Incoming connection closed: #{e.class.name}")
  rescue => e
    $logger.error("Error in incoming connection handler: #{e.message}", backtrace: e.backtrace)
  ensure
    $logger.info("Cleaning up incoming connection state.")
    # Clean up resources associated with this connection/peer
    peer_id_to_remove = $active_connections.key(connection)
    if peer_id_to_remove
        $logger.info("Removing connection state for disconnected peer #{peer_id_to_remove}")
        $active_connections.delete(peer_id_to_remove)
        # Also potentially clean up sessions associated with this peer
    end
    connection.close unless connection.closed?
  end
end

# Connect to the peer/server
def connect_to_peer(peer_uri_str, ssl_context)
    peer_uri = URI.parse(peer_uri_str)
    # Use URI components to create endpoint
    host = peer_uri.host
    port = peer_uri.port
    peer_id = "peer_#{host}" # Derive peer ID simply

    endpoint = Async::IO::Endpoint.tcp(host, port)
    ssl_endpoint = Async::SSL::Endpoint.new(endpoint, ssl_context: ssl_context)

    Async do |task|
        task.annotate "Peer Connector to #{peer_uri_str}"
        loop do # Basic reconnect loop
            begin
                $logger.info "Attempting to connect to peer: #{peer_uri_str}"
                # Establish connection
                connection = Async::WebSocket::Client.connect(ssl_endpoint)
                $logger.info "Connected to peer: #{peer_uri_str}"
                $active_connections[peer_id] = connection

                # 1. Send REGISTRO
                reg_msg = create_message(peer_id, 'REGISTRO', payload: {uri: AGENT_ADVERTISE_URI})
                connection.write(reg_msg); connection.flush
                $logger.info "Sent REGISTRO"

                # --- Example: Initiate a task after connection ---
                task.sleep(2) # Wait for registration/caps exchange to settle
                $logger.info("Attempting to initiate session and task...")
                session_id = SecureRandom.uuid
                init_msg = create_message(peer_id, 'SESSION_INIT', id_sesion: session_id, requiere_ack: true)
                connection.write(init_msg); connection.flush
                # (Need logic to wait for SESSION_ACCEPT before sending task)
                # Placeholder: Assume session accepted after short delay
                task.sleep(1)
                task_msg = create_message(peer_id, 'SOLICITUD_TAREA', id_sesion: session_id, num_secuencia: 1, requiere_ack: true,
                                          payload: {descripcion_tarea: "Process data from Ruby"})
                connection.write(task_msg); connection.flush
                $logger.info("Sent SESSION_INIT and SOLICITUD_TAREA")
                # --- End Example ---

                # Listen for incoming messages on this specific connection
                while message = connection.read
                    process_message(connection, message)
                end

            rescue EOFError, Errno::ECONNRESET, Errno::EPIPE, Async::Wrapper::Cancelled, OpenSSL::SSL::SSLError => e
                $logger.warn("Connection to peer #{peer_uri_str} lost or failed: #{e.class.name}. Reconnecting in 5s...")
                $active_connections.delete(peer_id) # Clean up stale connection
                task.sleep(5)
            rescue => e
                $logger.error("Unexpected error connecting to peer #{peer_uri_str}: #{e.message}. Retrying in 10s...", backtrace: e.backtrace)
                $active_connections.delete(peer_id)
                task.sleep(10)
            ensure
                 connection&.close unless connection&.closed?
            end
        end
    end
end

# --- Main Execution ---
Async do |main_task|
  main_task.annotate "Agent #{AGENT_ID} Main Task"

  # Create SSL contexts
  server_ssl_context = create_ssl_context()
  client_ssl_context = create_ssl_context() # Same config often works for mTLS client/server in Ruby OpenSSL

  # Start server to listen for incoming connections
  server_endpoint = Async::IO::Endpoint.tcp('0.0.0.0', AGENT_PORT)
  ssl_server_endpoint = Async::SSL::Endpoint.new(server_endpoint, ssl_context: server_ssl_context)
  server = Async::WebSocket::Server.new(ssl_server_endpoint)

  main_task.async do |server_task|
      server_task.annotate "WSS Server Listener"
      $logger.info("Agent #{AGENT_ID} listening on #{AGENT_LISTEN_URI}")
      server.run do |connection|
          # Handle each incoming connection in its own async task
          Async do |conn_task|
             conn_task.annotate "Incoming Connection Handler"
             handle_incoming_connection(connection)
          end
      end
  end

  # Start task to connect to the initial peer
  connect_to_peer(PEER_URI_STR, client_ssl_context)

  $logger.info "Agent started successfully."

end # Main Async block finishes when all sub-tasks complete (which they won't normally)

$logger.info "Agent #{AGENT_ID} shutting down."
Use code with caution.
5. Running the Agent
Save the code above as agent_rb.rb (or similar).

Generate the necessary certificates (ca-cert.pem, my_agent_id-cert.pem, my_agent_id-key.pem).

Run the agent from your terminal, providing the correct arguments:

ruby agent_rb.rb \
  --id "agente_ruby" \
  --port 8766 \
  --peer-uri "wss://<PEER_HOSTNAME_OR_IP>:8765" \
  --ca-cert ./ca-cert.pem \
  --my-cert ./agente_ruby-cert.pem \
  --my-key ./agente_ruby-key.pem
Use code with caution.
Bash
(Replace <PEER_HOSTNAME_OR_IP> and port 8765 with the actual address of the Python agent or ACPaaS server).

Observe the logs for connection status, registration, capability exchange, and any task processing messages.

6. Next Steps
Flesh out the process_message function to handle all defined protocol messages.

Implement proper state management for sessions (using concurrent-ruby Hashes or similar) and sequence numbers.

Add robust error handling and potentially retry logic for ACKs.

Integrate your specific agent logic to perform actual tasks.

Refer to the full examples provided in the main ACPaaS project repository.