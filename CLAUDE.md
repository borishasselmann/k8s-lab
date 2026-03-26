# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A GitOps-based Kubernetes learning environment using ArgoCD, Kustomize, and k3d or kind. All changes flow through Git and are automatically synced to the cluster by ArgoCD.

## Commands

### Cluster Setup (k3d)

```bash
./bootstrap.sh              # local
./bootstrap.sh --codespaces # GitHub Codespaces
```

Kubeconfig is written to `~/.kube/config-k3d-dev` (picked up automatically via `KUBECONFIG` glob).

### Cluster Setup (kind)

```bash
./bootstrap-kind.sh              # local
./bootstrap-kind.sh --codespaces # GitHub Codespaces
```

Kubeconfig is written to `~/.kube/config-kind-dev`. Traefik is installed via Helm.

### Port Forwarding (Codespaces only)

```bash
./port-forward.sh
```

Starts port-forwards for all available services. Re-run after ArgoCD syncs new apps. Automatically detects the active kubeconfig.

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

```text
Git Push → ArgoCD detects changes → Syncs to Kubernetes cluster
```

### App-of-Apps Pattern

- [bootstrap/app-of-apps.yaml](bootstrap/app-of-apps.yaml) is the root application that manages all other ArgoCD Applications
- [apps/kustomization.yaml](apps/kustomization.yaml) is the master-switch that controls which apps are active
- Each app has its own directory under `apps/` with an `application.yaml` and related files
- Apps automatically sync with self-healing and pruning enabled

### ArgoCD Self-Management

ArgoCD manages its own configuration via GitOps:

- [apps/argocd/application.yaml](apps/argocd/application.yaml) points to [apps/argocd/](apps/argocd/)
- Never modify ArgoCD directly with kubectl - change Git instead

### Directory Structure

| Directory              | Purpose                                                  |
| ---------------------- | -------------------------------------------------------- |
| `bootstrap/`           | App-of-Apps root application (initial cluster setup)     |
| `apps/<name>/`         | ArgoCD Application definitions + manifests / Helm values |
| `infrastructure/kind/` | kind cluster config and Traefik Helm values              |
| `templates/`           | Scaffolding templates for new applications               |

### Kustomize Patching

Upstream manifests are never modified directly. Use Kustomize overlays to patch them. Example in [apps/argocd/kustomization.yaml](apps/argocd/kustomization.yaml).

## Namespaces

| Namespace          | Components                                                 |
| ------------------ | ---------------------------------------------------------- |
| `argocd`           | ArgoCD                                                     |
| `kube-prometheus`  | kube-prometheus-stack (Prometheus, Grafana, Alertmanager)   |
| `traefik`          | Traefik ingress controller (kind only, installed via Helm) |

## Adding/Updating Applications

1. **New app**: Use `./templates/create-app.sh` or manually create `apps/<name>/application.yaml`, then add it to `apps/kustomization.yaml`
2. **Update app**: Modify manifests in `apps/<name>/`, commit and push
3. **Helm apps**: Use ArgoCD multi-source pattern with values files in the repo (see [apps/kube-prometheus-stack/application.yaml](apps/kube-prometheus-stack/application.yaml))

## Access URLs

### Local (k3d / kind)

- ArgoCD: <http://argocd.localhost>
- Grafana: <http://grafana-stack.localhost> (admin/admin)
- Prometheus: <http://prometheus-stack.localhost>
- Alertmanager: <http://alertmanager.localhost>

### GitHub Codespaces

Run `./port-forward.sh` after bootstrap, then open ports via the Ports tab:

| Port | Service      | Credentials            |
| ---- | ------------ | ---------------------- |
| 8080 | ArgoCD       | admin / (shown in terminal) |
| 8081 | Grafana      | admin / admin          |
| 8082 | Prometheus   | —                      |
| 8083 | Alertmanager | —                      |
