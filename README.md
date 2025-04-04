# ACPaaS - Agent Coordination Protocol SaaS

## Overview

Agent Coordination Protocol SaaS (ACPaaS) is a cloud-based platform designed to provide a standardized, robust, and secure protocol implementation for coordinating diverse software agents across different programming languages and environments.

## Features

- Secure communication using WebSockets Secure (WSS) with mutual TLS (mTLS).
- Supports Python and Ruby agents.
- Provides a standardized protocol for agent registration, capability exchange, session management, and task execution.

## Setup Instructions

### Prerequisites

- Ruby 3.x and Python 3.x installed.
- OpenSSL for certificate generation.
- RSpec for testing Ruby components.

### Installation

1. **Clone the Repository**

   ```bash
   git clone https://github.com/yourusername/acpaas.git
   cd acpaas
   ```

2. **Install Dependencies**

   For Ruby:
   ```bash
   bundle install
   ```

   For Python:
   ```bash
   pip install -r requirements.txt
   ```

3. **Generate Certificates**

   Use the provided scripts to generate the necessary certificates:

   ```bash
   cd scripts
   ./generate_ca.sh
   ./generate_agent_cert.sh agente_py
   ```

### Running the Server

To start the Ruby WebSocket server:

```bash
ruby server.rb
```

### Running Tests

To run the Ruby tests:

```bash
rspec spec/
```

To run the Python tests:

```bash
pytest tests/
```

## Documentation

- [Protocol Specification](docs/PROTOCOL_SPEC.md)
- [Authentication Setup](docs/AUTHENTICATION.md)
- [Quick Start Guide for Python Agents](docs/QUICK_START_PYTHON.md)
- [Quick Start Guide for Ruby Agents](docs/QUICK_START_RUBY.md)

## Contributing

Please read [CONTRIBUTING.md](docs/CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
