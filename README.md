# Homelab

Infrastructure-as-code for my homelab environment. Docker Compose files, Ansible playbooks, K3s manifests, and documentation.

## Structure

```
├── docker/       # Docker Compose stacks with sanitized configs
├── ansible/      # Ansible playbooks and roles
├── k3s/          # Kubernetes manifests
├── scripts/      # Utility scripts
└── docs/         # Architecture, runbooks, and other documentation
```

## Secrets Management

All sensitive values (passwords, API keys, tokens) are stored in `.env` files outside this repository. Compose files reference these via `${VARIABLE}` syntax.

See individual service READMEs for the corresponding `.env` file location and required variables.

## Usage

Each service directory contains:
- `docker-compose.yml` — sanitized compose file with variable references
- `README.md` — service documentation and required environment variables
