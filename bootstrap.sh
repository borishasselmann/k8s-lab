#!/bin/bash
set -e  # Exit on error

# Install ArgoCD
kubectl apply -f infrastructure/argocd/namespace.yaml
kubectl apply -n argocd -f infrastructure/argocd/install.yaml

# Wait for deployment to be created
echo "Waiting for ArgoCD deployment to be created..."
until kubectl -n argocd get deployment argocd-server &>/dev/null; do
  sleep 2
done

# Patch before first rollout completes to avoid double restart
kubectl patch deployment argocd-server -n argocd --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]'

# Wait for patched deployment to be ready
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

# Apply ingress and apps
kubectl apply -f infrastructure/argocd/ingress.yaml
kubectl apply -f argocd/apps.yaml

# Wait for admin secret to be generated
echo "Waiting for admin secret..."
until kubectl -n argocd get secret argocd-initial-admin-secret &>/dev/null; do
  sleep 2
done

echo "Done! ArgoCD: http://argocd.localhost"
echo "Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
