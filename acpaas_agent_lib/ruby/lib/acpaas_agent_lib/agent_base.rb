require 'securerandom'
require 'time'
require 'json'

def create_message(tipo:, origen:, destino:, id_mensaje: nil, respuesta_a: nil, id_sesion: nil, numero_secuencia: nil, requiere_ack: false, datos: {})
  # Generate a new UUID if id_mensaje is not provided
  id_mensaje ||= SecureRandom.uuid

  # Create the message hash
  message = {
    "tipo" => tipo,
    "id_mensaje" => id_mensaje,
    "origen" => origen,
    "destino" => destino,
    "respuesta_a" => respuesta_a,
    "timestamp" => Time.now.utc.iso8601,  # ISO 8601 format
    "id_sesion" => id_sesion,
    "numero_secuencia" => numero_secuencia,
    "requiere_ack" => requiere_ack,
    "datos" => datos
  }

  message
end

def parse_message(json_str)
  begin
    # Parse the JSON string
    message = JSON.parse(json_str)
  rescue JSON::ParserError => e
    raise ArgumentError, "Invalid JSON: #{e.message}"
  end

  # Define required fields
  required_fields = ["tipo", "id_mensaje", "origen", "destino", "timestamp"]

  # Check for required fields
  missing_fields = required_fields.select { |field| !message.key?(field) }
  unless missing_fields.empty?
    raise ArgumentError, "Missing required fields: #{missing_fields.join(', ')}"
  end

  message
end 