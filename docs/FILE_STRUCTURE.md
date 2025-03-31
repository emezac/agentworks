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
├── bin/                  # Utilities and executable scripts
│   └── ...               # (Contents of the bin directory)
│
├── docs/                 # Project documentation
│   └── ...
│
└── tests/                # Tests (could have subdirs for backend, lib, examples)
    └── ... ```