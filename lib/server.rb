require 'async'
require 'async/websocket'
require 'async/io'
require 'openssl'
require_relative 'ssl_endpoint_extension'

def start_server
  Async do |task|
    begin
      tcp_endpoint = Async::IO::Endpoint.tcp('0.0.0.0', 8080)
      
      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.cert = OpenSSL::X509::Certificate.new(File.read('scripts/agente_py-cert.pem'))
      ssl_context.key = OpenSSL::PKey::RSA.new(File.read('scripts/agente_py-key.pem'))
      ssl_context.ca_file = 'scripts/ca-cert.pem'
      ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
      
      ssl_endpoint = Async::IO::SSLEndpoint.new(tcp_endpoint, ssl_context: ssl_context)
      
      puts "Server starting on wss://#{ssl_endpoint.authority}"
      
      server = ssl_endpoint.accept do |socket|
        Async::WebSocket::Server.open(socket) do |connection|
          puts "Client connected"
          connection.each do |message|
            puts "Received message: #{message}"
            connection.send(message)
          end
          puts "Client disconnected"
        end
      end
      
      Signal.trap("INT") do
        puts "Shutting down server..."
        server.close
        task.stop
      end
      
      task.sleep
    rescue Async::Stop
      puts "Servidor detenido de manera ordenada."
    end
  end
end

