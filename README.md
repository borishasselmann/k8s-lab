# k8s-lab

A GitOps-based Kubernetes learning environment using ArgoCD and Kustomize.

## Prerequisites

| Tool | Required |
|------|----------|
| Docker | Yes |
| k3d | Yes |
| kubectl | Yes |

**Platform Support:**
- macOS: Full support
- Linux: Full support
- Windows: Requires WSL2

**Note:** Port 80 must be available (no other webserver running).

## Quick Start

```bash
# Create cluster and deploy everything
k3d cluster create dev -p "80:80@loadbalancer"
./bootstrap.sh
```

**Access:**
- ArgoCD: http://argocd.localhost (admin / password from bootstrap output)
- Grafana: http://grafana.localhost (admin / admin)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Git Repository                        │
├─────────────────────────────────────────────────────────────┤
│  argocd/                    │  infrastructure/argocd/        │
│  ├── apps.yaml (App of Apps)│  ├── kustomization.yaml        │
│  ├── argocd-app.yaml        │  └── ingress.yaml              │
│  └── grafana-app.yaml       │                                │
├─────────────────────────────────────────────────────────────┤
│  apps/grafana/                                               │
│  ├── deployment.yaml                                         │
│  ├── service.yaml                                            │
│  └── ingress.yaml                                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     ArgoCD (Self-Managed)                    │
│  Syncs all applications from Git automatically               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   argocd    │  │  monitoring │  │    ...      │          │
│  │  namespace  │  │  namespace  │  │  namespace  │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
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
├── bootstrap.sh                 # Initial cluster setup
├── argocd/                      # ArgoCD Application definitions
│   ├── apps.yaml                # App of Apps (root application)
│   ├── argocd-app.yaml          # ArgoCD self-management
│   └── grafana-app.yaml         # Grafana application
├── infrastructure/              # Infrastructure components
│   └── argocd/
│       ├── kustomization.yaml   # Kustomize overlay
│       └── ingress.yaml         # ArgoCD ingress
└── apps/                        # Application manifests
    └── grafana/
        ├── deployment.yaml
        ├── service.yaml
        └── ingress.yaml
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

```bash
k3d cluster delete dev
```

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
