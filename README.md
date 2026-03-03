# k8s-lab

A production-ready GitOps-based Kubernetes learning environment using ArgoCD and Kustomize.

## What You'll Learn

This lab provides hands-on experience with:

- **GitOps Workflows** - Declarative configuration management with ArgoCD
- **Kubernetes Core Concepts** - Deployments, Services, Ingress, ConfigMaps
- **Observability Stack** - Full monitoring, logging, and tracing setup
- **Infrastructure as Code** - Kustomize overlays and patching strategies
- **Continuous Delivery** - Automated sync with self-healing capabilities
- **Real-World Patterns** - App-of-Apps, self-management, and best practices

All components mirror production setups, making this an ideal environment for learning Kubernetes operations.

## Prerequisites

| Tool | Required |
|------|----------|
| Docker | Yes |
| k3d or kind | Yes (one of them) |
| kubectl | Yes |
| helm | Only for kind bootstrap |

**Platform Support:**
- macOS: Full support
- Linux: Full support
- Windows: Requires WSL2

**Note:** Port 80 must be available (no other webserver running).

## Quick Start

### Local Development (k3d)

```bash
./bootstrap.sh
```

Kubeconfig is written to `~/.kube/config-k3d-dev` (picked up automatically via `KUBECONFIG` glob).

### Local Development (kind)

```bash
./bootstrap-kind.sh
```

Kubeconfig is written to `~/.kube/config-kind-dev`. Traefik is installed via Helm to match the ingress controller built into k3d.

**Access:**

- ArgoCD: <http://argocd.localhost> (admin / password from bootstrap output)
- Grafana: <http://grafana-stack.localhost> (admin / admin)
- Prometheus: <http://prometheus-stack.localhost>
- Alertmanager: <http://alertmanager.localhost>
- Elasticsearch: <http://elasticsearch.localhost>
- Kibana: <http://kibana.localhost>
- Jaeger: <http://jaeger.localhost>
- Nginx Demo: <http://nginx.localhost>

### GitHub Codespaces

For running this lab in GitHub Codespaces, see [CODESPACES_SETUP.md](CODESPACES_SETUP.md).

## Components

| Component             | Purpose                                        | Namespace       |
| --------------------- | ---------------------------------------------- | --------------- |
| ArgoCD                | GitOps continuous delivery                     | argocd          |
| kube-prometheus-stack | Prometheus, Grafana, Alertmanager (Helm)       | kube-prometheus |
| Elasticsearch         | Search & analytics engine, log storage (Helm)  | logging         |
| Kibana                | Log visualization (bundled with Elasticsearch) | logging         |
| Jaeger                | Distributed tracing (Helm)                     | tracing         |
| Traefik               | Ingress controller (kind only, via Helm)       | traefik         |
| Nginx                 | Demo application                               | nginx           |

### Grafana Dashboards

Pre-configured dashboards from [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack):

| Dashboard                       | Description                              |
| ------------------------------- | ---------------------------------------- |
| Kubernetes / Cluster            | Cluster-wide resource overview           |
| Kubernetes / Kubelet            | Kubelet operations, pod starts, PLEG     |
| Kubernetes / Nodes              | Node CPU, memory, disk, network          |
| Kubernetes / Networking / Pod   | Per-pod network bandwidth and packets    |
| Kubernetes / Persistent Volumes | PVC space and inode usage                |
| Prometheus / Overview           | Prometheus self-monitoring               |
| K8s Node Metrics                | Detailed node-exporter metrics           |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Git Repository                       │
├─────────────────────────────────────────────────────────────┤
│  argocd/                    │  infrastructure/argocd/       │
│  ├── apps.yaml (App of Apps)│  ├── kustomization.yaml       │
│  ├── argocd-app.yaml        │  └── ingress.yaml             │
│  ├── nginx-app.yaml         │                               │
│  └── kube-prometheus-...    │  apps/nginx/                  │
│                             │  ├── deployment.yaml          │
│  apps/kube-prometheus-stack/│  ├── service.yaml             │
│  └── values.yaml (Helm)     │  └── ingress.yaml             │
├─────────────────────────────────────────────────────────────┤
│                     ArgoCD (Self-Managed)                   │
│          Syncs all applications from Git automatically      │
├─────────────────────────────────────────────────────────────┤
│                  Kubernetes Cluster (k3d/kind)              │
│  ┌──────────┐ ┌───────────────┐ ┌─────────┐ ┌───────────┐   │
│  │ argocd   │ │kube-prometheus│ │ logging │ │  tracing  │   │
│  └──────────┘ └───────────────┘ └─────────┘ └───────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Key Concepts

### App of Apps Pattern

A single ArgoCD Application (`apps.yaml`) manages all other Applications:

```yaml
# argocd/apps.yaml - deploys all apps in argocd/ directory
spec:
  source:
    path: argocd
  syncPolicy:
    automated:
      selfHeal: true   # Auto-fix drift
      prune: true      # Remove deleted resources
```

### ArgoCD Self-Management

ArgoCD manages itself via GitOps. Changes to ArgoCD configuration are made in Git, not via kubectl:

```yaml
# argocd/argocd-app.yaml
spec:
  source:
    path: infrastructure/argocd  # Points to Kustomize overlay
```

### Kustomize for Patching

Instead of modifying upstream manifests, use Kustomize overlays:

```yaml
# infrastructure/argocd/kustomization.yaml
resources:
  - https://raw.githubusercontent.com/.../install.yaml  # Upstream
  - ingress.yaml                                         # Local additions

patches:
  - target:
      kind: Deployment
      name: argocd-server
    patch: |
      - op: add
        path: /spec/template/spec/containers/0/args/-
        value: --insecure
```

**Benefits:**
- Upstream stays untouched (easy updates)
- Patches are declarative and version-controlled
- No imperative `kubectl patch` commands

## Directory Structure

```
.
├── bootstrap.sh                     # Cluster setup with k3d
├── bootstrap-kind.sh                # Cluster setup with kind
├── argocd/                          # ArgoCD Application definitions
│   ├── apps.yaml                    # App of Apps (root application)
│   ├── argocd-app.yaml              # ArgoCD self-management
│   ├── nginx-app.yaml               # Demo application
│   ├── kube-prometheus-stack-app.yaml # Monitoring stack (Helm)
│   ├── elasticsearch-app.yaml       # Log storage (Helm)
│   ├── jaeger-app.yaml              # Distributed tracing (Helm)
│   └── disabled/                    # Deactivated applications
├── infrastructure/                  # Infrastructure components
│   ├── argocd/
│   │   ├── kustomization.yaml       # Kustomize overlay
│   │   └── ingress.yaml             # ArgoCD ingress
│   └── kind/                        # kind cluster configuration
│       ├── cluster-config.yaml      # Port mappings + node labels
│       ├── cluster-config-codespaces.yaml
│       └── traefik-values.yaml      # Traefik Helm values
├── apps/                            # Application manifests & Helm values
│   ├── nginx/                       # Kubernetes manifests
│   ├── kube-prometheus-stack/       # Helm values
│   ├── elasticsearch/               # Helm values (includes Kibana)
│   └── jaeger/                      # Helm values
└── templates/                       # Scaffolding templates for new applications
    ├── create-app.sh                # App creation script
    └── README.md                    # Template documentation
```

## Best Practices Applied

### Deployment Manifests

```yaml
spec:
  containers:
  - name: app
    image: grafana/grafana:latest  # Pin version in production
    resources:
      requests:                     # Scheduling guarantees
        memory: "128Mi"
        cpu: "100m"
      limits:                       # Resource boundaries
        memory: "256Mi"
        cpu: "200m"
    livenessProbe:                  # Restart on failure
      httpGet:
        path: /api/health
        port: 3000
    readinessProbe:                 # Traffic routing
      httpGet:
        path: /api/health
        port: 3000
```

### Ingress

```yaml
spec:
  ingressClassName: traefik        # Explicit ingress controller
  rules:
  - host: app.localhost
```

### Bootstrap Script

```bash
set -e                              # Exit on error
kubectl apply -k infrastructure/    # Declarative with Kustomize
kubectl rollout status deployment/  # Wait for ready state
```

## Workflow

### Adding a New Application

1. Create manifests in `apps/<app-name>/`
2. Create ArgoCD Application in `argocd/<app-name>-app.yaml`
3. Push to Git
4. ArgoCD auto-syncs (via App of Apps)

### Updating ArgoCD Configuration

1. Modify `infrastructure/argocd/kustomization.yaml`
2. Push to Git
3. ArgoCD self-heals to new state

### Updating an Application

1. Modify manifests in `apps/<app-name>/`
2. Push to Git
3. ArgoCD auto-syncs

## Teardown

### k3d

```bash
k3d cluster delete dev
rm -f ~/.kube/config-k3d-dev
```

### kind

```bash
kind delete cluster --name dev
rm -f ~/.kube/config-kind-dev
```

## Future Improvements

Potential enhancements for this learning environment:

| Feature | Description |
| ------- | ----------- |
| **Persistent Storage** | PersistentVolumes for Prometheus/Grafana data (survives pod restarts) |
| **Loki** | Log aggregation stack for centralized logging |
| **Network Policies** | Namespace isolation for improved security |
| **Resource Quotas** | Per-namespace resource limits |
| **Sealed Secrets** | GitOps-compatible secret management |

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
