#!/usr/bin/env bash
# Remove the lab workloads. Deletes the kind cluster when CONTEXT is kind-module6.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
kubectl delete -f "$ROOT/k8s" --ignore-not-found

if [[ "$(kubectl config current-context 2>/dev/null || true)" == "kind-module6" ]]; then
  kind delete cluster --name module6
fi
