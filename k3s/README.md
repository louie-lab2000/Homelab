# K3s

Kubernetes manifests for the K3s cluster.

## Current Status

Manifests are deployed via Rancher UI or `kubectl apply`. This directory is reserved for future GitOps workflow.

## Planned Structure

```
├── namespaces/       # Namespace definitions
├── deployments/      # Application deployments
├── services/         # Service definitions
└── storage/          # PVCs and storage classes
```

## Cluster Details

See `docs/k3s-cluster-context.md` for current cluster configuration.

## Deployment

Currently deployed via:
- Rancher UI for workloads
- Ansible playbooks for cluster components (see `ansible/k3s-ansible-complete/`)

## Future

GitOps with Flux or ArgoCD for declarative deployments.
