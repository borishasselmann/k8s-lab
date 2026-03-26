#!/bin/bash
set -euo pipefail

# This script runs once when the container is created.
# In Codespaces with prebuilds, this step is cached.

# k3d
K3D_VERSION="v5.8.3"
echo "Installing k3d ${K3D_VERSION}..."
curl -fsSL "https://raw.githubusercontent.com/k3d-io/k3d/${K3D_VERSION}/install.sh" | TAG="${K3D_VERSION}" bash

# kind
KIND_VERSION="v0.31.0"
echo "Installing kind ${KIND_VERSION}..."
curl -fsSL -o /tmp/kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
chmod +x /tmp/kind
sudo mv /tmp/kind /usr/local/bin/kind

# kustomize
KUSTOMIZE_VERSION="v5.8.1"
echo "Installing kustomize ${KUSTOMIZE_VERSION}..."
curl -fsSL "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash -s -- "${KUSTOMIZE_VERSION#v}" /tmp
sudo mv /tmp/kustomize /usr/local/bin/kustomize

# k9s
K9S_VERSION="v0.50.18"
echo "Installing k9s ${K9S_VERSION}..."
curl -fsSL -o /tmp/k9s.tar.gz "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz"
tar -xzf /tmp/k9s.tar.gz -C /tmp k9s
sudo mv /tmp/k9s /usr/local/bin/k9s
rm -f /tmp/k9s.tar.gz

echo "Tool installation complete."
