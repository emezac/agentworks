import unittest
from acpaas_agent_lib.python.agent_base import create_message, parse_message
from datetime import datetime
import uuid

class TestCreateMessage(unittest.TestCase):

    def test_create_message_with_defaults(self):
        message = create_message(tipo="INIT", origen="agent1", destino="agent2")
        
        # Check if all required fields are present
        self.assertIn("tipo", message)
        self.assertIn("id_mensaje", message)
        self.assertIn("origen", message)
        self.assertIn("destino", message)
        self.assertIn("timestamp", message)
        self.assertIn("requiere_ack", message)
        self.assertIn("datos", message)

        # Check default values
        self.assertFalse(message["requiere_ack"])
        self.assertEqual(message["datos"], {})

        # Check if id_mensaje is a valid UUID
        self.assertTrue(uuid.UUID(message["id_mensaje"]))

        # Check if timestamp is in ISO 8601 format
        try:
            datetime.fromisoformat(message["timestamp"].replace('Z', '+00:00'))
        except ValueError:
            self.fail("Timestamp is not in ISO 8601 format")

    def test_create_message_with_custom_values(self):
        custom_id = str(uuid.uuid4())
        custom_data = {"key": "value"}
        message = create_message(
            tipo="ACK",
            origen="agent1",
            destino="agent2",
            id_mensaje=custom_id,
            requiere_ack=True,
            datos=custom_data
        )

        # Check custom values
        self.assertEqual(message["id_mensaje"], custom_id)
        self.assertTrue(message["requiere_ack"])
        self.assertEqual(message["datos"], custom_data)

    def test_create_message_with_all_fields(self):
        custom_id = str(uuid.uuid4())
        custom_data = {"key": "value"}
        message = create_message(
            tipo="ACK",
            origen="agent1",
            destino="agent2",
            id_mensaje=custom_id,
            respuesta_a="some_uuid",
            id_sesion="session_uuid",
            numero_secuencia=1,
            requiere_ack=True,
            datos=custom_data
        )

        # Check all fields
        self.assertEqual(message["respuesta_a"], "some_uuid")
        self.assertEqual(message["id_sesion"], "session_uuid")
        self.assertEqual(message["numero_secuencia"], 1)

class TestParseMessage(unittest.TestCase):

    def test_parse_message_valid(self):
        json_str = '{"tipo": "INIT", "id_mensaje": "1234", "origen": "agent1", "destino": "agent2", "timestamp": "2023-11-16T12:00:00Z"}'
        message = parse_message(json_str)
        self.assertEqual(message["tipo"], "INIT")
        self.assertEqual(message["id_mensaje"], "1234")

    def test_parse_message_invalid_json(self):
        json_str = '{"tipo": "INIT", "id_mensaje": "1234", "origen": "agent1", "destino": "agent2", "timestamp": "2023-11-16T12:00:00Z"'
        with self.assertRaises(ValueError):
            parse_message(json_str)

    def test_parse_message_missing_fields(self):
        json_str = '{"tipo": "INIT", "id_mensaje": "1234", "origen": "agent1"}'
        with self.assertRaises(ValueError):
            parse_message(json_str)

if __name__ == '__main__':
    unittest.main() 