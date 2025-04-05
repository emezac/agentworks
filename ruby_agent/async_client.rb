require 'async'
require 'async/http/endpoint'
require 'async/websocket/client'
require 'uri'
require 'openssl'
require 'protocol/websocket/error' # Para ClosedError

# --- Configuración (sin cambios) ---
server_url_string = "wss://localhost:8080/"
client_cert_path = 'scripts/agente_py-cert.pem'
client_key_path = 'scripts/agente_py-key.pem'
ca_file_path = 'scripts/ca-cert.pem'

[client_cert_path, client_key_path, ca_file_path].each do |path|
  unless File.exist?(path)
    puts "[Async Client Config] ERROR: Certificate, key, or CA file not found at: #{path}"
    exit(1)
  end
end
puts "[Async Client Config] All certificate files found."

# --- Contexto SSL (sin cambios) ---
puts "[Async Client] Setting up SSL Context..."
ssl_context = OpenSSL::SSL::SSLContext.new
begin
  ssl_context.cert = OpenSSL::X509::Certificate.new(File.read(client_cert_path))
  ssl_context.key = OpenSSL::PKey::RSA.new(File.read(client_key_path))
  ssl_context.ca_file = ca_file_path
  ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
  puts "[Async Client] SSL Context OK."
rescue => e
  puts "[Async Client] FATAL: Error setting up SSL context: #{e.message}"
  exit(1)
end

# --- Endpoint (sin cambios) ---
begin
  server_uri = URI.parse(server_url_string)
  endpoint = Async::HTTP::Endpoint.new(server_uri, ssl_context: ssl_context)
  puts "[Async Client] Defined secure Endpoint: #{endpoint.url}"
rescue => e
  puts "[Async Client] FATAL: Error creating endpoint: #{e.message}"
  exit(1)
end


# --- Bucle Principal Async ---
Async do |task|
  puts "[Async Client] Task started. Attempting connection..."
  begin
    endpoint.connect do |connection|
      puts "[Async Client] WebSocket connection OPENED!"

      begin
        # Enviar mensaje
        message_to_send = "Hello mTLS world (via Async - Iteration)!"
        puts "[Async Client] Sending: #{message_to_send}"
        connection.write(message_to_send)
        connection.flush

        # --- USAR EL ITERADOR PARA RECIBIR MENSAJES ---
        puts "[Async Client] Waiting for messages..."
        received_count = 0
        # connection.each iterará hasta que la conexión se cierre
        # o haya un error irrecuperable.
        connection.each do |received_message|
          received_count += 1
          puts "[Async Client] Received message ##{received_count}: #{received_message}"

          # Lógica de ejemplo: esperar solo el primer mensaje (eco)
          if received_count == 1
            if received_message == message_to_send
              puts "[Async Client] Echo received successfully."
            else
              puts "[Async Client] WARN: Echo mismatch!"
            end
            # Después de recibir el eco, iniciar cierre limpio
            puts "[Async Client] Closing connection after first message..."
            connection.close(1000, "Client received echo")
            # 'break' saldrá del bucle 'each'
            break
          else
            # Si se reciben más mensajes inesperados
            puts "[Async Client] WARN: Received unexpected message ##{received_count}"
          end
        end # Fin de connection.each

        # Si el bucle 'each' termina sin recibir nada (ej. cierre inmediato)
        if received_count == 0
            puts "[Async Client] Connection closed before receiving any messages."
        end
        # -------------------------------------------

      # Los errores de conexión específicos (ClosedError, EPIPE, etc.)
      # a menudo harán que el bucle 'each' termine, por lo que
      # el rescue principal puede simplificarse un poco.
      rescue ::Protocol::WebSocket::ClosedError => e
         # Captura cierre iniciado por el peer durante la iteración
         puts "[Async Client] WebSocket closed by peer during iteration: #{e.message}"
      rescue Errno::ECONNRESET, Errno::EPIPE, EOFError, OpenSSL::SSL::SSLError => e
        # Errores de conexión/SSL que pueden ocurrir durante write/flush o la iteración
        puts "[Async Client] Connection error during read/write/iteration: #{e.class} - #{e.message}"
      rescue => e
        puts "[Async Client] Unexpected error during communication loop: #{e.class} - #{e.message}"
        puts e.backtrace.take(5).join("\n")
      # ensure ya no es estrictamente necesario aquí porque el bloque 'connect'
      # y la naturaleza de 'each' manejan el cierre.
      # ensure
      #   puts "[Async Client] Ensuring connection closure..."
      #   connection.close unless connection.closed?
      end
    end # Fin del bloque endpoint.connect

    puts "[Async Client] Connection block finished."

  # --- CORREGIR CAPTURA DE ERROR DE CONEXIÓN ---
  # Capturar el error correcto de async-io
  rescue Async::IO::Socket::ConnectError, Errno::ECONNREFUSED => e
      puts "[Async Client] TCP Connect ERROR: #{e.class} - #{e.message}"
  # ---------------------------------------------
  rescue OpenSSL::SSL::SSLError => e
    puts "[Async Client] SSL ERROR during connection: #{e.message}"
  rescue Async::WebSocket::ConnectError => e
      puts "[Async Client] WebSocket Handshake ERROR: #{e.message}"
  rescue => e
    puts "[Async Client] FATAL ERROR during connect: #{e.class}: #{e.message}"
    puts e.backtrace.take(10).join("\n")
  end # Fin del begin/rescue exterior

  puts "[Async Client] Task finished."
end # Fin del bloque Async do

puts "[Async Client] Main script finished."