#!/bin/bash
set -euo pipefail

# This script runs after the container is created and the repo is cloned.
# Repo-specific setup that depends on the workspace.

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
