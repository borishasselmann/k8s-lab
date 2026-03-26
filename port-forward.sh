#!/bin/bash
set -euo pipefail

# Kill any existing port-forwards
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 1

echo "Starting port-forwards..."

# ArgoCD
if kubectl get svc argocd-server -n argocd &>/dev/null; then
  kubectl port-forward svc/argocd-server -n argocd 8080:80 &>/dev/null &
  echo "  ArgoCD:       port 8080  (admin / $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo 'n/a'))"
fi

# Grafana
if kubectl get svc kube-prometheus-stack-grafana -n kube-prometheus &>/dev/null; then
  kubectl port-forward svc/kube-prometheus-stack-grafana -n kube-prometheus 8081:80 &>/dev/null &
  echo "  Grafana:      port 8081  (admin / admin)"
fi

# Prometheus
if kubectl get svc kube-prometheus-stack-prometheus -n kube-prometheus &>/dev/null; then
  kubectl port-forward svc/kube-prometheus-stack-prometheus -n kube-prometheus 8082:9090 &>/dev/null &
  echo "  Prometheus:   port 8082"
fi

# Alertmanager
if kubectl get svc kube-prometheus-stack-alertmanager -n kube-prometheus &>/dev/null; then
  kubectl port-forward svc/kube-prometheus-stack-alertmanager -n kube-prometheus 8083:9093 &>/dev/null &
  echo "  Alertmanager: port 8083"
fi

echo ""
echo "Done. Re-run this script to restart all port-forwards."
