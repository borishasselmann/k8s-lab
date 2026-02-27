#!/bin/bash
set -e  # Exit on error

KUBECONFIG_FILE="$HOME/.kube/config-k3d-dev"

# Parse arguments
K3D_ARGS=(-p "80:80@loadbalancer")
if [[ "$1" == "--codespaces" ]]; then
  K3D_ARGS=()
fi

# Write to dedicated kubeconfig file instead of ~/.kube/config
export KUBECONFIG="${KUBECONFIG_FILE}"

# Create k3d cluster if it doesn't exist
if ! k3d cluster list | grep -q "^dev "; then
  echo "Creating k3d cluster 'dev'..."
  k3d cluster create dev "${K3D_ARGS[@]}"
else
  echo "Cluster 'dev' already exists, writing kubeconfig..."
  k3d kubeconfig get dev > "${KUBECONFIG_FILE}"
fi

# Install ArgoCD with Kustomize (includes --insecure patch and ingress)
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -k infrastructure/argocd/ --server-side

# Wait for deployment to be ready
echo "Waiting for ArgoCD deployment..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

# Apply apps
kubectl apply -f argocd/apps.yaml

# Wait for admin secret to be generated
echo "Waiting for admin secret..."
until kubectl -n argocd get secret argocd-initial-admin-secret &>/dev/null; do
  sleep 2
done

echo ""
echo "Done! ArgoCD: http://argocd.localhost"
echo "Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo ""
echo "Kubeconfig: ${KUBECONFIG_FILE}"
