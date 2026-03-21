# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A GitOps-based Kubernetes learning environment using ArgoCD, Kustomize, and k3d or kind. All changes flow through Git and are automatically synced to the cluster by ArgoCD.

## Commands

### Cluster Setup (k3d)

```bash
./bootstrap.sh
```

Kubeconfig is written to `~/.kube/config-k3d-dev` (picked up automatically via `KUBECONFIG` glob).

### Cluster Setup (kind)

```bash
./bootstrap-kind.sh
```

Kubeconfig is written to `~/.kube/config-kind-dev`. Traefik is installed via Helm.

### Teardown (k3d)

```bash
k3d cluster delete dev
rm -f ~/.kube/config-k3d-dev
```

### Teardown (kind)

```bash
kind delete cluster --name dev
rm -f ~/.kube/config-kind-dev
```

### Create New Application
```bash
./templates/create-app.sh <app-name> [-i image] [-t tag] [-p port] [--no-ingress]
# Example: ./templates/create-app.sh myapp -i nginx -t 1.25 -p 80
```

### Linting
```bash
pre-commit run --all-files
```

### Get ArgoCD Password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

## Architecture

### GitOps Flow
```
Git Push → ArgoCD detects changes → Syncs to Kubernetes cluster
```

### App-of-Apps Pattern
- [argocd/apps.yaml](argocd/apps.yaml) is the root application that manages all other ArgoCD Applications
- Individual apps are defined in `argocd/<app-name>-app.yaml`
- Apps automatically sync with self-healing and pruning enabled

### ArgoCD Self-Management
ArgoCD manages its own configuration via GitOps:
- [argocd/argocd-app.yaml](argocd/argocd-app.yaml) points to [infrastructure/argocd/](infrastructure/argocd/)
- Never modify ArgoCD directly with kubectl - change Git instead

### Directory Structure
| Directory | Purpose |
|-----------|---------|
| `argocd/` | ArgoCD Application definitions (what to deploy) |
| `apps/<name>/` | Kubernetes manifests / Helm values for each application |
| `infrastructure/argocd/` | ArgoCD's own Kustomize overlay |
| `infrastructure/kind/` | kind cluster config and Traefik Helm values |
| `templates/` | Scaffolding templates for new applications |

### Kustomize Patching
Upstream manifests are never modified directly. Use Kustomize overlays in `infrastructure/` to patch them. Example in [infrastructure/argocd/kustomization.yaml](infrastructure/argocd/kustomization.yaml).

## Namespaces
| Namespace | Components |
|-----------|------------|
| `argocd` | ArgoCD |
| `kube-prometheus` | kube-prometheus-stack (Prometheus, Grafana, Alertmanager) |
| `traefik` | Traefik ingress controller (kind only, installed via Helm) |

## Adding/Updating Applications

1. **New app**: Use `./templates/create-app.sh` or manually create manifests in `apps/` and ArgoCD definition in `argocd/`
2. **Update app**: Modify manifests in `apps/<name>/`, commit and push
3. **Helm apps**: Use ArgoCD multi-source pattern with values files in the repo (see [argocd/kube-prometheus-stack-app.yaml](argocd/kube-prometheus-stack-app.yaml))

## Local Access URLs
- ArgoCD: http://argocd.localhost
- Grafana: http://grafana-stack.localhost (admin/admin)
- Prometheus: http://prometheus-stack.localhost
- Alertmanager: http://alertmanager.localhost
