# config.ru
require 'websocket/driver'
require 'rack'
require 'socket' # Para Socket.unpack_sockaddr_in

# Función auxiliar para obtener IP (mejorada)
def get_remote_ip(env)
  remote_addr = env['REMOTE_ADDR']
  peeraddr = env['rack.peeraddr']
  remote_addr || (peeraddr ? peeraddr[1] : 'unknown')
rescue => e
  puts "[Server] Error getting remote IP: #{e.message}"
  'unknown'
end

App = lambda do |env|
  # Comprobar si es una solicitud de upgrade a WebSocket
  unless ::WebSocket::Driver.websocket?(env)
    # No es WebSocket, devuelve 404
    # puts "[Server] Non-WebSocket request for #{env['PATH_INFO']}"
    next [404, { 'Content-Type' => 'text/plain' }, ['Not found']]
  end

  # Verificar si el servidor soporta hijack (Puma debería)
  unless env['rack.hijack']
    puts "[Server] ERROR: WebSocket request but server does not support hijack!"
    next [500, { 'Content-Type' => 'text/plain' }, ['Server does not support hijack']]
  end

  remote_ip = get_remote_ip(env)
  puts "[Server] WebSocket upgrade request detected from #{remote_ip}. Attempting hijack..."

  # --- Realizar el Hijack ---
  io = nil
  begin
    env['rack.hijack'].call # Llama al proc de hijack de Puma/Rack
    io = env['rack.hijack_io'] # Obtener el socket subyacente (debería ser Puma::MiniSSL::Socket)
  rescue => e
    puts "[Server] ERROR during hijack call: #{e.class} - #{e.message}"
    next [500, { 'Content-Type' => 'text/plain' }, ['Server error during hijack']]
  end

  unless io
    puts "[Server] ERROR: rack.hijack did not provide an IO object!"
    next [500, { 'Content-Type' => 'text/plain' }, ['Server error obtaining IO after hijack']]
  end

  puts "[Server] Hijack successful, got IO object: #{io.class}"

  # --- Definir variables fuera del begin para que estén disponibles en ensure ---
  driver = nil

  begin
    # --- Inicializar WebSocket Driver (Modo Servidor) ---
    driver = ::WebSocket::Driver.server(io, { max_length: 10 * 1024 * 1024 })

    # --- Definir método 'write' en la instancia 'io' ---
    # ¡¡¡ HACER ESTO ANTES DE LLAMAR A driver.start() !!!
    io.define_singleton_method(:write) do |data_to_write|
      begin
        # Escribir de forma bloqueante por simplicidad
        bytes_written = io.write(data_to_write) # Llama al método write original del socket
        # puts "[Server IO Wrapper] Wrote #{bytes_written} bytes for #{remote_ip}."
      rescue EOFError, Errno::ECONNRESET, Errno::EPIPE => e
        puts "[Server IO Wrapper] Write Error (connection closed) for #{remote_ip}: #{e.class}"
        driver.close rescue nil # Intentar cerrar el driver si la escritura falla
        # No cerramos io aquí para permitir que el bucle principal lo detecte
      rescue => e
        puts "[Server IO Wrapper] Write Error for #{remote_ip}: #{e.class} - #{e.message}"
        driver.close rescue nil
      end
    end
    puts "[Server] Defined .write method on IO object for #{remote_ip}."
    # --- Fin definición de .write ---


    # --- Callbacks del Driver ---
    driver.on(:connect) do |event|
      # Este evento se dispara cuando el driver está listo para el handshake
      # (después de parsear la solicitud inicial del cliente)
      # if driver.ready_to_start? # Esta comprobación puede no ser necesaria aquí
          puts "[WS Driver Server] Ready for handshake with #{remote_ip}."
          # El handshake real se completa llamando a driver.start() más abajo
      # else
      #     puts "[WS Driver Server] Driver closed before connect event for #{remote_ip}."
      #     io.close rescue nil # Asegurar cierre del socket
      # end
    end

    driver.on(:open) do |event|
      puts "[WS Driver Server] Connection opened for #{remote_ip}."
      # Aquí podrías iniciar pings periódicos si quisieras
    end

    driver.on(:message) do |event|
      puts "[WS Driver Server] Received from #{remote_ip}: #{event.data}"
      # Echo
      puts "[WS Driver Server] Echoing back to #{remote_ip}..."
      driver.text(event.data) # Esto llamará al método :write adjunto
    end

    driver.on(:close) do |event|
      puts "[WS Driver Server] Closed connection for #{remote_ip}: #{event.code} #{event.reason}"
      # El bucle de lectura debería detenerse por EOF o error
    end

    driver.on(:error) do |event|
      puts "[WS Driver Server] Protocol Error for #{remote_ip}: #{event.message}"
      # El bucle de lectura debería detenerse por error
    end

    # --- PASO 1: Procesar la Solicitud HTTP Inicial ---
    # El driver necesita parsear la solicitud HTTP de upgrade que envió el cliente.
    puts "[Server] Reading initial HTTP request data for #{remote_ip}..."
    # Leemos del socket y se lo pasamos al driver.
    # Usamos un bucle pequeño aquí por si la solicitud inicial es > 4k (improbable)
    loop do
      begin
        # Leer un fragmento sin bloquear demasiado si es posible (pero sigue siendo bloqueante)
        chunk = io.read_nonblock(4096)
        puts "[Server] Passing #{chunk.bytesize} bytes to driver parser for #{remote_ip}."
        driver.parse(chunk)
        # Salir del bucle si ya no necesitamos más datos para el handshake
        # (El driver sabe cuándo ha terminado de parsear la solicitud HTTP)
        # Esta condición es difícil de determinar sin mirar el estado interno del driver.
        # Por simplicidad, asumimos que una lectura es suficiente para el handshake.
        break # Salir después de la primera lectura exitosa
      rescue IO::WaitReadable
        # Esperar un poquito si no hay nada que leer inmediatamente (mala práctica, solo ejemplo)
        puts "[Server] Waiting for initial client data..."
        sleep 0.1
      rescue EOFError, Errno::ECONNRESET, Errno::EPIPE => e
        puts "[Server] Connection closed by #{remote_ip} during initial read: #{e.class}"
        raise # Re-lanzar para que el rescue principal lo capture
      rescue => e
        puts "[Server] Error reading initial HTTP request for #{remote_ip}: #{e.class}"
        raise # Re-lanzar
      end
    end

    # En este punto, el driver debería haber parseado la solicitud y disparado :connect

    # --- PASO 2: Enviar la Respuesta del Handshake ---
    # driver.start genera la respuesta (101 Switching Protocols) y la pone
    # en el buffer de escritura interno o llama a `write`.
    puts "[Server] Starting driver (generates and sends handshake response) for #{remote_ip}..."
    driver.start # Llama a io.write() adjunto con la respuesta 101

    # --- PASO 3: Intentar leer UN mensaje del cliente ---
    # ¡Bucle bloqueante MUY simplificado para prueba!
    puts "[Server] Attempting to read one message from client #{remote_ip}..."
    data = nil
    begin
      # Esperar por el "Hello..." del cliente
      data = io.readpartial(4096) # Bloqueante
      if data && !data.empty?
        puts "[Server] Read #{data.bytesize} bytes, parsing..."
        driver.parse(data) # Esto debería disparar on(:message) -> echo
      else
        puts "[Server] Read empty data or nil, client likely disconnected."
      end
    rescue EOFError, Errno::ECONNRESET, Errno::EPIPE
      puts "[Server] Client #{remote_ip} disconnected before sending message."
    rescue => e
      puts "[Server] Error reading first message for #{remote_ip}: #{e.class} - #{e.message}"
    end

    # --- PASO 4: Esperar un poco para que el cliente reciba el eco (HACK) ---
    puts "[Server] Waiting briefly for potential echo processing..."
    sleep 1 # ¡Muy malo, solo para diagnóstico!

    # --- PASO 5: Cerrar ---
    puts "[Server] Closing connection for #{remote_ip} after test."
    # Enviar frame de cierre si el driver todavía existe y está abierto
    if driver && driver.state == :open
        driver.close(1000, "Server test finished") rescue nil # Intenta cierre limpio
    end


  rescue => e # Capturar errores durante el setup/handshake inicial
      puts "[Server] Unexpected error during setup/handshake for #{remote_ip}: #{e.class} - #{e.message}"
      puts e.backtrace.take(10).join("\n")
      # No intentar devolver 500 aquí, simplemente cerrar
  ensure
      # Asegurarse de cerrar el IO en caso de cualquier error o finalización
      puts "[Server] Cleaning up IO for #{remote_ip}."
      io.close if io && !io.closed? rescue nil
  end


  # --- Indicar a Puma que el hijack fue exitoso ---
  # Devolvemos -1 para que Puma no intente enviar una respuesta HTTP.
  [-1, {}, []]

end

run App