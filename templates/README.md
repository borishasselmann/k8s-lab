# Application Templates

Templates for creating new applications in this k8s-lab environment.

## Quick Start

```bash
# Create a new application
./templates/create-app.sh myapp -i nginx -t 1.25 -p 80

# Create without ingress (e.g., for databases)
./templates/create-app.sh redis -i redis -t 7-alpine -p 6379 --no-ingress

# Push to Git
git add . && git commit -m "Add myapp" && git push
```

## Script Options

```text
./templates/create-app.sh <app-name> [options]

Options:
  -n, --namespace   Kubernetes namespace (default: same as app-name)
  -i, --image       Container image (default: nginx)
  -t, --tag         Image tag (default: latest)
  -p, --port        Container port (default: 80)
  --no-ingress      Skip ingress.yaml
  -h, --help        Show help
```

## Template Structure

```text
templates/
├── README.md
├── create-app.sh           # App creation script
├── argocd/
│   └── APP_NAME-app.yaml   # ArgoCD Application
└── apps/
    └── APP_NAME/
        ├── app.yaml        # ServiceAccount + Deployment + Service (core)
        ├── ingress.yaml    # Ingress (optional, created by default)
        ├── policies.yaml   # NetworkPolicy + PDB (optional)
        └── config.yaml     # ConfigMap + Secret + PVC (optional)
```

Generated app structure:

```text
apps/myapp/
├── app.yaml                # ServiceAccount + Deployment + Service
└── ingress.yaml            # Ingress (if --no-ingress not set)
```

## Placeholders

| Placeholder | Description                  | Example   |
| ----------- | ---------------------------- | --------- |
| `APP_NAME`  | Application name (lowercase) | `myapp`   |
| `NAMESPACE` | Kubernetes namespace         | `default` |
| `IMAGE`     | Container image              | `nginx`   |
| `TAG`       | Image tag                    | `1.25`    |
| `PORT`      | Container port               | `8080`    |

## Kubernetes Best Practices

The templates follow security and operational best practices:

### Security Context

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
    - securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
```

### ServiceAccount

Dedicated ServiceAccount with token mounting disabled:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp
automountServiceAccountToken: false
```

### Resource Limits

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "128Mi"
    cpu: "100m"
```

### Health Probes

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

### Named Ports

```yaml
ports:
  - name: http
    containerPort: 8080
```

## Optional Files

Copy from `templates/apps/APP_NAME/` when needed:

### policies.yaml

NetworkPolicy (Zero Trust) + PodDisruptionBudget (HA):

```bash
cp templates/apps/APP_NAME/policies.yaml apps/myapp/
# Then replace APP_NAME and NAMESPACE
```

### config.yaml

ConfigMap + Secret + PVC:

```bash
cp templates/apps/APP_NAME/config.yaml apps/myapp/
# Then replace APP_NAME and NAMESPACE
```

## Examples

### Web Application

```bash
./templates/create-app.sh webapp -i nginx -t 1.25 -p 80
# Access: http://webapp.localhost
```

### Database (no Ingress)

```bash
./templates/create-app.sh redis -i redis -t 7-alpine -p 6379 --no-ingress
# Internal: redis.redis.svc.cluster.local:6379
```

## Manual Adjustments

After running the script, you may need to:

1. **Adjust health probes** if your app doesn't have `/health` endpoint
2. **Add writable directories** if app needs to write files:

   ```yaml
   volumeMounts:
     - name: tmp
       mountPath: /tmp
   volumes:
     - name: tmp
       emptyDir: {}
   ```

3. **Disable runAsNonRoot** if image requires root (not recommended)
4. **Copy policies.yaml** for NetworkPolicy and PodDisruptionBudget
5. **Copy config.yaml** for ConfigMap, Secret, or PVC
6. **Adjust resource limits** based on app requirements

## Production Enhancements

For production workloads, consider adding these features:

### Version Label

Track deployed version for debugging and rollbacks:

```yaml
metadata:
  labels:
    app.kubernetes.io/version: "1.2.3"
```

### Topology Spread Constraints

Distribute pods across nodes/zones for high availability:

```yaml
spec:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels:
          app.kubernetes.io/name: myapp
```

### Priority Class

Ensure critical apps get scheduled first:

```yaml
spec:
  priorityClassName: high-priority
```

### Startup Probe

For slow-starting applications (JVM, etc.):

```yaml
startupProbe:
  httpGet:
    path: /health
    port: http
  failureThreshold: 30
  periodSeconds: 10
```

### Graceful Shutdown

Allow connections to drain before termination:

```yaml
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "sleep 10"]
```

### Prometheus Metrics

Enable scraping if app exposes metrics:

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
```

ArgoCD will automatically detect and deploy the new application after `git push`.
