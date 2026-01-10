#!/bin/bash
kubectl apply -f infrastructure/argocd/namespace.yaml
kubectl apply -n argocd -f infrastructure/argocd/install.yaml
echo "Waiting for ArgoCD deployment to be created..."
until kubectl -n argocd get deployment argocd-server &>/dev/null; do
  sleep 2
done
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
kubectl patch deployment argocd-server -n argocd --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]'
kubectl apply -f infrastructure/argocd/ingress.yaml
kubectl apply -f argocd/apps.yaml
echo "Done! ArgoCD: http://argocd.localhost"
echo "Waiting for admin secret..."
until kubectl -n argocd get secret argocd-initial-admin-secret &>/dev/null; do
  sleep 2
done
echo "Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"