# lib/server_async.rb
require 'async'
require 'async/http/endpoint'
require 'async/http/server'
require 'async/websocket' # ¡Importante! Antes del patch
require 'async/io'
require 'uri'
require 'openssl'
require 'protocol/websocket/error' # Para capturar ClosedError

# --- Monkey Patch para Async::WebSocket::Server ---
# Objetivo: Ver si el método 'call' del middleware se ejecuta y qué devuelve.
begin
  module Async
    module WebSocket
      class Server
        # Guardar el método original si no lo hemos hecho ya
        unless method_defined?(:original_call_for_debug)
          alias_method :original_call_for_debug, :call
        end

        # Redefinir 'call'
        def call(request)
          puts "[PATCHED Server#call] Middleware received request for path: #{request.path}"
          response = nil
          begin
            # Llamar al método original guardado
            response = original_call_for_debug(request)
            # El método original debería devolver nil si hace hijack, o una respuesta HTTP
            puts "[PATCHED Server#call] Original call returned: #{response.inspect} (#{response.class})"
            # Aquí es donde el bloque @block debería ser llamado internamente por original_call_for_debug
            # si el handshake tuvo éxito. No podemos verlo directamente aquí.
          rescue => e
            puts "[PATCHED Server#call] ERROR raised in original call: #{e.class}: #{e.message}"
            # Podríamos querer devolver una respuesta 500 aquí o relanzar
            # Relanzamos para que el servidor HTTP principal lo maneje
            raise e
          end
          # Devolver la respuesta original (o nil si hubo hijack)
          response
        end
      end
      puts "[Monkey Patch] Applied to Async::WebSocket::Server#call"
    end
  end
rescue NameError => e
   puts "[Monkey Patch] FAILED: Could not apply patch - #{e.message}. Is async-websocket loaded?"
rescue => e
   puts "[Monkey Patch] FAILED: Unexpected error applying patch - #{e.class}: #{e.message}"
end
# --- Fin Monkey Patch ---


# --- SSL Context (mTLS Completo) ---
puts "[Async Server] Setting up SSL Context..."
ssl_context = OpenSSL::SSL::SSLContext.new
begin
  ssl_context.cert = OpenSSL::X509::Certificate.new(File.read('scripts/agente_py-cert.pem'))
  ssl_context.key = OpenSSL::PKey::RSA.new(File.read('scripts/agente_py-key.pem'))
  ssl_context.ca_file = 'scripts/ca-cert.pem'
  ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
  puts "[Async Server] SSL Context OK."
rescue => e
  puts "[Async Server] FATAL: Error setting up SSL context: #{e.message}"
  exit(1)
end

# --- Endpoint ---
server_uri = URI.parse("wss://0.0.0.0:8080/")
endpoint = Async::HTTP::Endpoint.new(server_uri, ssl_context: ssl_context)
puts "[Async Server] Defined Endpoint: #{endpoint.url}"

# --- Lógica del Handler WebSocket ---
websocket_handler_block = lambda do |connection|
  # 'connection' aquí debería ser Async::WebSocket::Connection
  remote_addr = begin connection.io.remote_address.ip_address rescue "unknown" end
  puts "[Async WS Handler] >>> Connection established from #{remote_addr}" # Log más claro

  begin
    # Bucle de lectura
    while message = connection.read
      puts "[Async WS Handler] Received from #{remote_addr}: #{message}"
      connection.write(message)
      connection.flush # Asegurar envío
      puts "[Async WS Handler] Echoed back to #{remote_addr}"
    end
    # Si salimos del bucle porque read devolvió nil
    puts "[Async WS Handler] Client #{remote_addr} finished or disconnected (read returned nil)."

  rescue Async::TimeoutError
    # Esto puede ocurrir si connection.read tiene un timeout configurado
    puts "[Async WS Handler] Timeout waiting for message from #{remote_addr}."
  rescue ::Protocol::WebSocket::ClosedError => e
     # Capturar cierre limpio iniciado por el peer
     puts "[Async WS Handler] WebSocket closed gracefully by peer #{remote_addr}: #{e.message}"
  rescue Errno::ECONNRESET, Errno::EPIPE, EOFError, IOError => e
    # Errores comunes de conexión/IO
    puts "[Async WS Handler] Connection error for #{remote_addr}: #{e.class} - #{e.message}"
  rescue => e
    # Otros errores inesperados durante la comunicación
    puts "[Async WS Handler] Unexpected error for #{remote_addr}: #{e.class} - #{e.message}"
    puts e.backtrace.take(5).join("\n")
  ensure
    # Asegurarse de cerrar la conexión al salir del bloque o en caso de error
    puts "[Async WS Handler] <<< Closing connection for #{remote_addr}."
    connection.close unless connection.closed?
  end
end

# --- Middleware WebSocket ---
begin
  # Asegurarse de pasar el bloque correctamente
  websocket_app = Async::WebSocket::Server.new(websocket_handler_block)
  puts "[Async Server] Created WebSocket Middleware."
rescue => e
  puts "[Async Server] FATAL: Error creating WebSocket Middleware: #{e.class} - #{e.message}"
  exit(1)
end


# --- Servidor HTTP ---
begin
  # Pasar el middleware y el endpoint
  http_server = Async::HTTP::Server.new(websocket_app, endpoint)
  puts "[Async Server] Created HTTP Server with WS Middleware."
rescue => e
  puts "[Async Server] FATAL: Error creating HTTP Server: #{e.class} - #{e.message}"
  exit(1)
end


# --- Ejecutar el Servidor ---
Async do |task|
  puts "[Async Server] Starting server run loop..."
  begin
    # Iniciar el servidor para aceptar conexiones
    http_server.run
    # Si run termina sin excepción, es inesperado
    puts "[Async Server] Server run loop finished unexpectedly."
  rescue Interrupt # Capturar Ctrl+C
     puts "\n[Async Server] Interrupt signal received, stopping server..."
     # Considerar llamar a http_server.close aquí si existe y es necesario
  rescue OpenSSL::SSL::SSLError => e
     # Errores específicos de SSL durante la aceptación/handshake del servidor
     puts "[Async Server] SSL ERROR accepting connection: #{e.message}"
     # Imprimir detalles puede ser útil
     # puts e.backtrace.join("\n")
  rescue => e
    # Otros errores críticos durante la ejecución del servidor
    puts "[Async Server] CRITICAL ERROR running server: #{e.class}: #{e.message}"
    puts e.backtrace.join("\n")
  ensure
    # Este bloque se ejecuta siempre, incluso con Ctrl+C o errores
    puts "[Async Server] Server shutdown sequence initiated."
    # Aquí podrías añadir lógica para cerrar conexiones activas si tuvieras una lista
  end
end

puts "[Async Server] Main script finished (Async block running)."