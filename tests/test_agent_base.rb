require 'minitest/autorun'
require_relative '../acpaas_agent_lib/ruby/lib/acpaas_agent_lib/agent_base'

class TestCreateMessage < Minitest::Test
  def test_create_message_with_defaults
    message = create_message(tipo: "INIT", origen: "agent1", destino: "agent2")

    # Check if all required fields are present
    assert_includes message, "tipo"
    assert_includes message, "id_mensaje"
    assert_includes message, "origen"
    assert_includes message, "destino"
    assert_includes message, "timestamp"
    assert_includes message, "requiere_ack"
    assert_includes message, "datos"

    # Check default values
    assert_equal false, message["requiere_ack"]
    assert_equal({}, message["datos"])

    # Check if id_mensaje is a valid UUID
    assert_match(/\A[\da-f]{8}-([\da-f]{4}-){3}[\da-f]{12}\z/, message["id_mensaje"])

    # Check if timestamp is in ISO 8601 format
    assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/, message["timestamp"])
  end

  def test_create_message_with_custom_values
    custom_id = SecureRandom.uuid
    custom_data = { "key" => "value" }
    message = create_message(
      tipo: "ACK",
      origen: "agent1",
      destino: "agent2",
      id_mensaje: custom_id,
      requiere_ack: true,
      datos: custom_data
    )

    # Check custom values
    assert_equal custom_id, message["id_mensaje"]
    assert_equal true, message["requiere_ack"]
    assert_equal custom_data, message["datos"]
  end

  def test_create_message_with_all_fields
    custom_id = SecureRandom.uuid
    custom_data = { "key" => "value" }
    message = create_message(
      tipo: "ACK",
      origen: "agent1",
      destino: "agent2",
      id_mensaje: custom_id,
      respuesta_a: "some_uuid",
      id_sesion: "session_uuid",
      numero_secuencia: 1,
      requiere_ack: true,
      datos: custom_data
    )

    # Check all fields
    assert_equal "some_uuid", message["respuesta_a"]
    assert_equal "session_uuid", message["id_sesion"]
    assert_equal 1, message["numero_secuencia"]
  end
end

class TestParseMessage < Minitest::Test

  def test_parse_message_valid
    json_str = '{"tipo": "INIT", "id_mensaje": "1234", "origen": "agent1", "destino": "agent2", "timestamp": "2023-11-16T12:00:00Z"}'
    message = parse_message(json_str)
    assert_equal "INIT", message["tipo"]
    assert_equal "1234", message["id_mensaje"]
  end

  def test_parse_message_invalid_json
    json_str = '{"tipo": "INIT", "id_mensaje": "1234", "origen": "agent1", "destino": "agent2", "timestamp": "2023-11-16T12:00:00Z"'
    assert_raises(ArgumentError) { parse_message(json_str) }
  end

  def test_parse_message_missing_fields
    json_str = '{"tipo": "INIT", "id_mensaje": "1234", "origen": "agent1"}'
    assert_raises(ArgumentError) { parse_message(json_str) }
  end
end 