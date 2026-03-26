#!/bin/bash
set -euo pipefail

# k3d — no official devcontainer feature available
K3D_VERSION="v5.8.3"
echo "Installing k3d ${K3D_VERSION}..."
curl -fsSL "https://raw.githubusercontent.com/k3d-io/k3d/${K3D_VERSION}/install.sh" | TAG="${K3D_VERSION}" bash

# kind
KIND_VERSION="v0.31.0"
echo "Installing kind ${KIND_VERSION}..."
curl -fsSL -o /tmp/kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
chmod +x /tmp/kind
sudo mv /tmp/kind /usr/local/bin/kind

# Set up KUBECONFIG glob so both k3d and kind kubeconfigs are discovered
KUBECONFIG_LINE='export KUBECONFIG=$(ls ~/.kube/config-* 2>/dev/null | tr "\n" ":")'
if ! grep -qF 'KUBECONFIG' ~/.bashrc 2>/dev/null; then
  echo "${KUBECONFIG_LINE}" >> ~/.bashrc
fi

# pre-commit
echo "Installing pre-commit..."
pipx install pre-commit
pre-commit install

echo ""
echo "Dev container setup complete."
echo "Start a cluster with: ./bootstrap.sh --codespaces  OR  ./bootstrap-kind.sh --codespaces"
