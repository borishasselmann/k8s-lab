#!/bin/bash
set -e  # Exit on error

KUBECONFIG_FILE="$HOME/.kube/config-k3d-dev"

# Parse arguments
K3D_ARGS=(-p "80:80@loadbalancer")
if [[ "$1" == "--codespaces" ]]; then
  K3D_ARGS=()
fi

# Create k3d cluster if it doesn't exist
# --kubeconfig-update-default=false prevents k3d from managing the default kubeconfig,
# avoiding warnings on deletion when KUBECONFIG contains multiple files
if ! k3d cluster list | grep -q "^dev "; then
  echo "Creating k3d cluster 'dev'..."
  k3d cluster create dev "${K3D_ARGS[@]}" --kubeconfig-update-default=false
fi

# Write kubeconfig to dedicated file instead of ~/.kube/config
k3d kubeconfig get dev > "${KUBECONFIG_FILE}"
export KUBECONFIG="${KUBECONFIG_FILE}"

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
