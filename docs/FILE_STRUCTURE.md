```acpaas/
├── .gitignore
├── LICENSE
├── README.md
│
├── acpaas_backend/       # Core SaaS Platform (FastAPI)
│   └── ...               # (Contents as before)
│
├── acpaas_agent_lib/     # <<< NEW: Reusable Agent Library/SDK >>>
│   ├── python/           # Python agent library code
│   │   ├── __init__.py
│   │   └── agent_base.py # <<< Core Python Agent class/logic >>>
│   │   └── exceptions.py # (Optional: Custom exceptions)
│   │   └── utils.py      # (Optional: Helpers for messages, SSL)
│   │   └── requirements.txt # Dependencies ONLY for the base lib itself
│   │   └── setup.py      # (Optional: If packaging as a Python package)
│   │
│   └── ruby/             # Ruby agent library code
│       ├── lib/
│       │   ├── acpaas_agent_lib.rb # Main entry point for `require`
│       │   └── acpaas_agent_lib/
│       │       ├── agent_base.rb   # <<< Core Ruby Agent class/module >>>
│       │       ├── exceptions.rb # (Optional)
│       │       ├── utils.rb      # (Optional)
│       │       └── version.rb
│       ├── acpaas_agent_lib.gemspec # For packaging as a Ruby gem
│       └── Gemfile           # Dependencies ONLY for the base lib itself
│
├── examples/             # Agent implementations USING the library
│   ├── python_agent/
│   │   ├── agent_py.py   # <<< IMPORTS/USES ../acpaas_agent_lib/python >>>
│   │   └── requirements.txt # Lists dependencies + potentially the local python lib path
│   ├── ruby_agent/
│   │   ├── agent_rb.rb   # <<< REQUIRES ../acpaas_agent_lib/ruby/lib >>>
│   │   └── Gemfile       # Lists dependencies + potentially the local ruby lib path
│   └── ...               # (Other examples as before)
│
├── scripts/              # Helper scripts (cert generation)
│   └── ...
│
├── docs/                 # Project documentation
│   └── ...
│
└── tests/                # Tests (could have subdirs for backend, lib, examples)
    └── ... ```
Use code with caution.
Explanation and Purpose:

acpaas_agent_lib/: This new top-level directory houses the reusable foundation for building ACPaaS agents. It's structured like a standard library or SDK.

acpaas_agent_lib/python/agent_base.py: This file contains the core Python AgentBase class (or equivalent module structure). It implements all the common ACPaaS protocol logic:

WSS connection/reconnection logic (client/server roles).

mTLS context setup.

Parsing/building standard protocol messages.

Handling the state machine for registration, capability exchange, session management, ACKs, sequence numbers, flow control, and error reporting.

It likely defines abstract methods or hooks (like _handle_task_request(payload, session_id)) that specific agent implementations must override to add their unique business logic.

acpaas_agent_lib/ruby/lib/acpaas_agent_lib/agent_base.rb: This file serves the same purpose as its Python counterpart but for Ruby. It contains the core AcpaasAgentLib::AgentBase class or module providing the reusable protocol implementation.

examples/: This directory now contains specific implementations that demonstrate how to use the acpaas_agent_lib.

examples/python_agent/agent_py.py: This script is now much simpler. It would typically:

Import AgentBase from acpaas_agent_lib.python.agent_base.

Subclass AgentBase.

Implement the required application-specific methods (e.g., overriding _handle_task_request to define what this specific agent does when it gets a task).

Handle configuration loading (ports, cert paths, peer URI).

Instantiate its custom agent class.

Call a start() or run() method provided by AgentBase to begin the connection and processing loop.

examples/ruby_agent/agent_rb.rb: Similarly, this script would require 'acpaas_agent_lib' (or the specific path) and use the AcpaasAgentLib::AgentBase class/module, implementing only the logic unique to this example Ruby agent.

Why this structure is correct:

Separation of Concerns: Clearly separates the reusable protocol library from specific examples and the backend platform.

Reusability (DRY): Developers creating new agents don't need to copy-paste the complex protocol logic; they just import/require and extend the base implementation.

Maintainability: Bug fixes or updates to the protocol logic only need to happen in one place (acpaas_agent_lib).

Testability: The base library can be tested independently of specific agent implementations.

Packagability: The acpaas_agent_lib directories are structured correctly to be easily packaged as installable Python packages (pip) or Ruby gems (gem) in the future.