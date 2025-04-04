require 'async'
require 'async/websocket/client'
require 'async/rspec'
require 'async/io'
require 'openssl'
require_relative '../lib/ssl_endpoint_extension'
require 'logger'

module Async
  def self.logger
    @logger ||= Logger.new(File::NULL)
  end
end

Async.logger.level = Logger::FATAL


RSpec.describe 'WebSocket Server' do
  include_context Async::RSpec::Reactor
  
  let(:port) { 8080 }
  let(:tcp_endpoint) { Async::IO::Endpoint.tcp('localhost', port) }
  let(:ssl_context) do
    context = OpenSSL::SSL::SSLContext.new
    context.cert = OpenSSL::X509::Certificate.new(File.read('scripts/agente_py-cert.pem'))
    context.key = OpenSSL::PKey::RSA.new(File.read('scripts/agente_py-key.pem'))
    context.ca_file = 'scripts/ca-cert.pem'
    context.verify_mode = OpenSSL::SSL::VERIFY_PEER
    context
  end
  
  it 'accepts a WebSocket connection' do
    server_pid = Process.fork do
      begin
        require_relative '../lib/server'
        sleep
      rescue Async::Stop

      ensure

        Process.exit!(0)
      end
    end
    
    
    sleep(2)
    
    begin
      ssl_endpoint = Async::IO::SSLEndpoint.new(tcp_endpoint, ssl_context: ssl_context)
      
      expect(ssl_endpoint.protocol).to eq('wss')
      expect(ssl_endpoint.scheme).to eq('wss')
      expect(ssl_endpoint.authority).to include('8080')
      expect(ssl_endpoint.path).to eq('/')
      
      Async do
        Async::Task.current.with_timeout(5) do
          begin
            socket = ssl_endpoint.connect
            
            Async::WebSocket::Client.open(socket, 'wss://localhost:8080/') do |connection|
              puts "Client connected"
              connection.write({text: "Hello, server!"})
              message = connection.read
              puts "Received message: #{message.inspect}"
              expect(message.to_str).to eq("Hello, server!")
              connection.close
              puts "Client disconnected"
            end
          rescue => e
            puts "Error al conectar: #{e.message}"
            puts e.backtrace
            fail(e)
          end
        end
      end
      
    ensure
      if server_pid
        Process.kill('TERM', server_pid) rescue nil
        Process.waitpid(server_pid) rescue nil
      end
    end
  end
end

