# config/puma.rb

# Especifica el host y puerto
# 'ssl://0.0.0.0:8080' activa SSL en el puerto 8080 para todas las interfaces
# Puedes cambiar '0.0.0.0' a 'localhost' si solo quieres acceso local
bind 'ssl://0.0.0.0:8080?key=scripts/agente_py-key.pem&cert=scripts/agente_py-cert.pem&ca=scripts/ca-cert.pem&verify_mode=peer&fail_if_no_peer_cert=true'

# Opciones alternativas más explícitas (equivalentes a la línea 'bind' de arriba):
# host = '0.0.0.0'
# port = 8080
# ssl_bind host, port, {
#   key: 'scripts/agente_py-key.pem',
#   cert: 'scripts/agente_py-cert.pem',
#   ca: 'scripts/ca-cert.pem',
#   verify_mode: 'peer',                # Equivalente a VERIFY_PEER
#   fail_if_no_peer_cert: true          # Equivalente a VERIFY_FAIL_IF_NO_PEER_CERT
# }

# Número de workers (ajusta según tu CPU, 0 para modo single)
workers Integer(ENV.fetch("WEB_CONCURRENCY") { 0 })

# Hilos por worker
threads_count = Integer(ENV.fetch("RAILS_MAX_THREADS") { 5 })
threads threads_count, threads_count

# Entorno (production, development, etc.)
environment ENV.fetch("RACK_ENV") { "development" }

# Especifica el archivo rackup (usaremos config.ru por defecto)
# rackup DefaultRackup

# Opcional: PID file y state path
# pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }
# state_path "tmp/pids/puma.state"

# Permite que puma se reinicie con `touch tmp/restart.txt`
plugin :tmp_restart
