# lib/server_async_manual_hijack.rb
require 'async'
require 'async/http/endpoint'
require 'async/http/server'
require 'async/websocket/connection' # Usaremos la conexión directamente
require 'async/io'
require 'uri'
require 'openssl'
require 'protocol/http/response'    # Para respuestas HTTP
require 'protocol/websocket/error'  # Para errores WS

# --- SSL Context (mTLS Completo - sin cambios) ---
puts "[Async Server Manual] Setting up SSL Context..."
ssl_context = OpenSSL::SSL::SSLContext.new
begin
  ssl_context.cert = OpenSSL::X509::Certificate.new(File.read('scripts/agente_py-cert.pem'))
  ssl_context.key = OpenSSL::PKey::RSA.new(File.read('scripts/agente_py-key.pem'))
  ssl_context.ca_file = 'scripts/ca-cert.pem'
  ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
  puts "[Async Server Manual] SSL Context OK."
rescue => e
  puts "[Async Server Manual] FATAL: Error setting up SSL context: #{e.message}"
  exit(1)
end

# --- Endpoint (sin cambios) ---
server_uri = URI.parse("wss://0.0.0.0:8080/")
endpoint = Async::HTTP::Endpoint.new(server_uri, ssl_context: ssl_context)
puts "[Async Server Manual] Defined Endpoint: #{endpoint.url}"

# --- Lógica del Handler WebSocket (sin cambios en el bloque interno) ---
websocket_handler_logic = lambda do |connection|
  # 'connection' aquí será Async::WebSocket::Connection
  remote_addr = begin connection.io.remote_address.ip_address rescue "unknown" end
  task_id = Async::Task.current.object_id # Identificador único para esta conexión
  puts "[Async WS Handler-#{task_id}] >>> Connection established from #{remote_addr}"

  begin
    while message = connection.read
      puts "[Async WS Handler-#{task_id}] Received from #{remote_addr}: #{message}"
      connection.write(message)
      connection.flush
      puts "[Async WS Handler-#{task_id}] Echoed back to #{remote_addr}"
    end
    puts "[Async WS Handler-#{task_id}] Client #{remote_addr} finished or disconnected."
  rescue Async::TimeoutError
    puts "[Async WS Handler-#{task_id}] Timeout for #{remote_addr}."
  rescue ::Protocol::WebSocket::ClosedError => e
     puts "[Async WS Handler-#{task_id}] WebSocket closed gracefully by peer #{remote_addr}: #{e.message}"
  rescue Errno::ECONNRESET, Errno::EPIPE, EOFError, IOError => e
    puts "[Async WS Handler-#{task_id}] Connection error for #{remote_addr}: #{e.class} - #{e.message}"
  rescue => e
    puts "[Async WS Handler-#{task_id}] Unexpected error for #{remote_addr}: #{e.class} - #{e.message}"
    puts e.backtrace.take(5).join("\n")
  ensure
    puts "[Async WS Handler-#{task_id}] <<< Closing connection for #{remote_addr}."
    connection.close unless connection.closed?
  end
end

# --- Aplicación Principal del Servidor HTTP ---
# Este lambda se ejecuta para CADA solicitud HTTP entrante
app = lambda do |request|
  remote_addr = request.remote_address&.ip_address || "unknown"
  puts "[Async HTTP App] Received request from #{remote_addr} for #{request.path}"

  # --- PASO 1: Comprobar si la solicitud es WebSocket ---
  # ¡¡CRUCIAL!! Esto todavía necesita funcionar. Esperamos que al no usar
  # el middleware Server, el método se añada correctamente.
  unless request.respond_to?(:websocket?)
      puts "[Async HTTP App] FATAL: request object does not respond to .websocket? !"
      # Devolver un error interno del servidor
      next ::Protocol::HTTP::Response[500, {}, ["Server Configuration Error: WebSocket extensions not loaded."]]
  end

  unless request.websocket?
    # No es WebSocket, manejar como HTTP normal (ej. 404)
    puts "[Async HTTP App] Non-WebSocket request from #{remote_addr}."
    next ::Protocol::HTTP::Response[404, {}, ["Not Found"]]
  end

  # --- PASO 2: Realizar el Hijack ---
  # Si es una solicitud WebSocket, necesitamos tomar control del socket subyacente.
  puts "[Async HTTP App] WebSocket request detected from #{remote_addr}. Attempting hijack..."
  unless request.respond_to?(:hijack)
     puts "[Async HTTP App] FATAL: request object does not respond to .hijack!"
     next ::Protocol::HTTP::Response[500, {}, ["Server Configuration Error: Hijack not supported."]]
  end

  begin
    # request.hijack devuelve el stream/socket subyacente (debería ser Async::IO::Stream o similar)
    io_stream = request.hijack
    unless io_stream
        puts "[Async HTTP App] ERROR: Hijack call returned nil/false for #{remote_addr}."
        next ::Protocol::HTTP::Response[500, {}, ["Server Error: Hijack failed."]]
    end
    puts "[Async HTTP App] Hijack successful for #{remote_addr}, got IO: #{io_stream.class}"

    # --- PASO 3: Envolver el IO con Async::WebSocket::Connection ---
    # Creamos la conexión WebSocket sobre el stream secuestrado.
    # El 'true' indica que este es el lado del servidor.
    ws_connection = Async::WebSocket::Connection.new(io_stream, true)
    puts "[Async HTTP App] Created Async::WebSocket::Connection for #{remote_addr}."

    # --- PASO 4: Ejecutar la Lógica del Handler en una Tarea Separada ---
    # ¡IMPORTANTE! Lanzamos una nueva tarea Async para manejar esta conexión
    # WebSocket específica. Esto permite que el lambda 'app' retorne
    # inmediatamente (con 'nil') mientras la conexión WS sigue viva.
    Async do |handler_task|
      puts "[Async HTTP App] Starting handler task (ID: #{handler_task.object_id}) for #{remote_addr}."
      # Llamar a nuestro bloque de lógica pasándole la conexión WebSocket
      websocket_handler_logic.call(ws_connection)
      puts "[Async HTTP App] Handler task (ID: #{handler_task.object_id}) finished for #{remote_addr}."
    end

    # --- PASO 5: Indicar al Servidor HTTP que el Hijack tuvo éxito ---
    # Devolver nil le dice a Async::HTTP::Server que la respuesta ya fue
    # manejada (o será manejada) y que no debe enviar nada más.
    puts "[Async HTTP App] Hijack successful, returning nil to HTTP server for #{remote_addr}."
    nil

  rescue => e
    # Capturar errores durante el proceso de hijack/setup
    puts "[Async HTTP App] ERROR during hijack/setup for #{remote_addr}: #{e.class} - #{e.message}"
    puts e.backtrace.take(5).join("\n")
    # Devolver un error 500
    next ::Protocol::HTTP::Response[500, {}, ["Server Error during WebSocket setup."]]
  end
end

# --- Servidor HTTP (sin cambios en la creación) ---
http_server = Async::HTTP::Server.new(app, endpoint)
puts "[Async Server Manual] Created HTTP Server."

# --- Ejecutar el Servidor (sin cambios en el bucle) ---
Async do |task|
  # ... (bucle run con rescues igual que antes) ...
   puts "[Async Server Manual] Starting server run loop..."
   begin
     http_server.run
     puts "[Async Server Manual] Server run loop finished unexpectedly."
   rescue Interrupt
      puts "\n[Async Server Manual] Interrupt signal received, stopping server..."
   rescue OpenSSL::SSL::SSLError => e
      puts "[Async Server Manual] SSL ERROR accepting connection: #{e.message}"
   rescue => e
     puts "[Async Server Manual] CRITICAL ERROR running server: #{e.class}: #{e.message}"
     puts e.backtrace.join("\n")
   ensure
     puts "[Async Server Manual] Server shutdown sequence initiated."
   end
end

puts "[Async Server Manual] Main script finished (Async block running)."
