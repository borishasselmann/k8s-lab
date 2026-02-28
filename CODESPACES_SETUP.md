# K8s Lab in GitHub Codespaces

Run a complete Kubernetes learning environment directly in your browser - no local setup required.

## What This Environment Provides

- **Full GitOps Stack** - ArgoCD managing all applications
- **Complete Observability** - Prometheus, Grafana, Elasticsearch, Kibana, Jaeger
- **Zero Local Dependencies** - Everything runs in GitHub Codespaces
- **Production Patterns** - Learn real-world Kubernetes best practices

Perfect for learning Kubernetes without installing Docker, k3d, or kubectl locally.

## Setup

1. **Bootstrap Cluster & ArgoCD**

   Using k3d (default):
   ```bash
   ./bootstrap.sh --codespaces
   ```

   Using kind (alternative, requires `helm`):
   ```bash
   ./bootstrap-kind.sh --codespaces
   ```

   **Note:** In Codespaces, Ingress doesn't work with dynamic URLs. Use port-forwarding instead (see below).

## Accessing Apps in Browser

GitHub Codespaces uses dynamic URLs, so Ingress-based routing with `.localhost` domains doesn't work directly.

**Solution: Use Port-Forwarding**

```bash
# ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:80 > /dev/null 2>&1 &

# Nginx
kubectl port-forward -n nginx svc/nginx 8081:80 > /dev/null 2>&1 &

# Grafana
kubectl port-forward -n kube-prometheus svc/kube-prometheus-stack-grafana 8082:80 > /dev/null 2>&1 &

# Prometheus
kubectl port-forward -n kube-prometheus svc/kube-prometheus-stack-prometheus 8083:9090 > /dev/null 2>&1 &

# Alertmanager
kubectl port-forward -n kube-prometheus svc/kube-prometheus-stack-alertmanager 8086:9093 > /dev/null 2>&1 &

# Kibana
kubectl port-forward -n logging svc/elasticsearch-kibana 8084:5601 > /dev/null 2>&1 &

# Jaeger
kubectl port-forward -n tracing svc/jaeger 8085:16686 > /dev/null 2>&1 &
```

URLs will automatically appear in the **PORTS Tab** in VSCode and can be opened directly in the browser.

## Login-Credentials

**ArgoCD:**
- Username: `admin`
- Password:
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
  ```

**Grafana:**
- Username: `admin`
- Password:
  ```bash
  kubectl get secret -n kube-prometheus kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d && echo
  ```
