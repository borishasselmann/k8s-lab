#!/bin/bash
set -e  # Exit on error

CLUSTER_NAME="dev"
KUBECONFIG_FILE="$HOME/.kube/config-kind-dev"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
KIND_CONFIG="${SCRIPT_DIR}/infrastructure/kind/cluster-config.yaml"
if [[ "$1" == "--codespaces" ]]; then
  KIND_CONFIG="${SCRIPT_DIR}/infrastructure/kind/cluster-config-codespaces.yaml"
fi

# Write to dedicated kubeconfig file instead of ~/.kube/config
export KUBECONFIG="${KUBECONFIG_FILE}"

# Create kind cluster if it doesn't exist
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "Creating kind cluster '${CLUSTER_NAME}'..."
  kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG}" --kubeconfig "${KUBECONFIG_FILE}"
else
  echo "Cluster '${CLUSTER_NAME}' already exists, writing kubeconfig..."
  kind get kubeconfig --name "${CLUSTER_NAME}" > "${KUBECONFIG_FILE}"
fi

# Install Traefik as ingress controller (kind does not include one)
echo "Installing Traefik ingress controller..."
helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true
helm repo update traefik
helm upgrade --install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --values "${SCRIPT_DIR}/infrastructure/kind/traefik-values.yaml" \
  --wait

echo "Waiting for Traefik deployment..."
kubectl rollout status deployment/traefik -n traefik --timeout=120s

# Install ArgoCD with Kustomize (includes --insecure patch and ingress)
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -k apps/argocd/ --server-side

# Wait for deployment to be ready
echo "Waiting for ArgoCD deployment..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

# Apply apps
kubectl apply -f bootstrap/app-of-apps.yaml

# Wait for admin secret to be generated
echo "Waiting for admin secret..."
until kubectl -n argocd get secret argocd-initial-admin-secret &>/dev/null; do
  sleep 2
done

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

echo ""
echo "Kubeconfig: ${KUBECONFIG_FILE}"
echo "Runtime: kind (Traefik installed via Helm)"

if [[ "$1" == "--codespaces" ]]; then
  # In Codespaces *.localhost does not work, start port-forwards in background
  echo "Starting port-forwards for Codespaces..."
  kubectl port-forward svc/argocd-server -n argocd 8080:80 &>/dev/null &
  kubectl port-forward svc/kube-prometheus-stack-grafana -n kube-prometheus 8081:80 &>/dev/null &
  kubectl port-forward svc/kube-prometheus-stack-prometheus -n kube-prometheus 8082:9090 &>/dev/null &
  kubectl port-forward svc/kube-prometheus-stack-alertmanager -n kube-prometheus 8083:9093 &>/dev/null &
  echo ""
  echo "Done! Open via Ports tab:"
  echo "  ArgoCD:       port 8080  (admin / ${ARGOCD_PASSWORD})"
  echo "  Grafana:      port 8081  (admin / admin)"
  echo "  Prometheus:   port 8082"
  echo "  Alertmanager: port 8083"
else
  echo ""
  echo "Done!"
  echo "  ArgoCD:       http://argocd.localhost         (admin / ${ARGOCD_PASSWORD})"
  echo "  Grafana:      http://grafana-stack.localhost   (admin / admin)"
  echo "  Prometheus:   http://prometheus-stack.localhost"
  echo "  Alertmanager: http://alertmanager.localhost"
fi
