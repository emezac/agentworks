#!/bin/bash

# This script generates a private key, CSR, and signed certificate for an agent,
# including Subject Alternative Names (SAN) for localhost and 127.0.0.1.

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <agent_name>"
    exit 1
fi

AGENT_NAME=$1
AGENT_KEY="${AGENT_NAME}-key.pem"
AGENT_CSR="${AGENT_NAME}-csr.pem"
AGENT_CERT="${AGENT_NAME}-cert.pem"
CA_KEY="ca-key.pem"
CA_CERT="ca-cert.pem"

SAN_CONFIG_FILE=$(mktemp)


# Check if CA files exist
if [ ! -f "$CA_KEY" ] || [ ! -f "$CA_CERT" ]; then
    echo "CA key or certificate not found. Please ensure $CA_KEY and $CA_CERT are in the current directory."
    rm -f $SAN_CONFIG_FILE # Limpiar archivo temporal
    exit 1
fi

# Generate the agent's private key
openssl genrsa -out $AGENT_KEY 2048

# Generate the CSR
openssl req -new -key $AGENT_KEY -out $AGENT_CSR -subj "/CN=$AGENT_NAME"

cat > $SAN_CONFIG_FILE <<EOF
[ req ]
req_extensions = v3_req

[ v3_req ]
# Extensiones básicas y KeyUsage
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
# Definir los nombres alternativos
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = localhost
IP.1 = 127.0.0.1
# Opcional: Añadir el propio nombre del agente si también se usa para conectar
# DNS.2 = $AGENT_NAME
EOF
# -----------------------------------------------------

# Sign the CSR with the CA to create the agent's certificate
echo "Signing certificate with SANs..."
openssl x509 -req -in $AGENT_CSR -CA $CA_CERT -CAkey $CA_KEY \
  -CAcreateserial -out $AGENT_CERT -days 365 -sha256 \
  -extfile $SAN_CONFIG_FILE -extensions v3_req # <--- Añadir estas opciones

if [ $? -ne 0 ]; then
    echo "Error signing the certificate."
    rm -f $SAN_CONFIG_FILE # Limpiar archivo temporal
    exit 1
fi

rm -f $SAN_CONFIG_FILE

echo "Agent key, CSR, and certificate (with SAN for localhost) have been generated:"
echo "  Key: $AGENT_KEY"
echo "  CSR: $AGENT_CSR"
echo "  Certificate: $AGENT_CERT"

echo "Verifying SANs in the generated certificate:"
openssl x509 -in $AGENT_CERT -noout -text | grep -A 1 'Subject Alternative Name'