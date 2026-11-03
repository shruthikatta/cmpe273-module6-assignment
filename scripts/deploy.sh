#!/usr/bin/env bash
# Build the local images, load them into the cluster, and deploy the lab.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-module6}"
NS=module6

cd "$ROOT"

echo "==> Building images"
docker build --provenance=false -t inventory:1.0 "$ROOT/inventory"
docker build --provenance=false -t inventory-client:1.0 "$ROOT/client"

CONTEXT="$(kubectl config current-context 2>/dev/null || true)"
echo "==> Current context: ${CONTEXT:-<none>}"

if [[ "$CONTEXT" == "kind-${CLUSTER_NAME}" ]] || [[ "$CONTEXT" == kind-* ]]; then
  ACTIVE_KIND="${CONTEXT#kind-}"
  echo "==> Loading images into kind cluster ${ACTIVE_KIND}"
  kind load docker-image inventory:1.0 --name "$ACTIVE_KIND"
  kind load docker-image inventory-client:1.0 --name "$ACTIVE_KIND"
elif command -v minikube >/dev/null 2>&1 && minikube status >/dev/null 2>&1; then
  echo "==> Loading images into minikube"
  minikube image load inventory:1.0
  minikube image load inventory-client:1.0
else
  echo "==> Using the local Docker image store (Docker Desktop Kubernetes)"
fi

echo "==> Applying manifests"
kubectl apply -f "$ROOT/k8s/namespace.yaml"
kubectl apply -f "$ROOT/k8s/inventory-deployment.yaml"
kubectl apply -f "$ROOT/k8s/inventory-service.yaml"
kubectl apply -f "$ROOT/k8s/client-deployment.yaml"

echo "==> Waiting for rollouts"
kubectl rollout status "deployment/inventory" -n "$NS" --timeout=180s
kubectl rollout status "deployment/inventory-client" -n "$NS" --timeout=180s

echo "==> Workloads"
kubectl get pods,svc -n "$NS" -o wide
