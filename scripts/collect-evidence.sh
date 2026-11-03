#!/usr/bin/env bash
# Run the three lab demonstrations and save terminal evidence.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NS=module6
OUT="$ROOT/evidence"
mkdir -p "$OUT"

save() {
  local file="$1"
  shift
  {
    echo "\$ $*"
    "$@"
  } | tee "$OUT/$file"
  echo
}

echo "==> 1. Both replicas running, Service name, traffic to more than one Pod"
save 01-pods-and-service.txt kubectl get pods,svc -n "$NS" -o wide

sleep 8
save 02-client-log.txt kubectl logs -n "$NS" deployment/inventory-client --tail=40
save 03-burst-both-replicas.txt kubectl exec -n "$NS" deployment/inventory-client -- env REQUESTS=30 BURST_LABEL="replica counts" MIN_PODS=2 python /app/burst.py

PODS=()
while IFS= read -r name; do
  [[ -n "$name" ]] && PODS+=("$name")
done < <(kubectl get pods -n "$NS" -l app=inventory -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
if [[ "${#PODS[@]}" -lt 2 ]]; then
  echo "Expected 2 inventory pods, found ${#PODS[@]}" >&2
  exit 1
fi
TARGET="${PODS[0]}"
OTHER="${PODS[1]}"
{
  echo "Unready target: ${TARGET}"
  echo "Stays ready:    ${OTHER}"
} | tee "$OUT/04-readiness-target.txt"

echo "==> 2. Fail readiness on ${TARGET}"
kubectl exec -n "$NS" "$TARGET" -- python -c "import os; os.path.exists('/tmp/ready') and os.remove('/tmp/ready')"
sleep 10

save 05-readiness-failed-pods.txt kubectl get pods -n "$NS" -l app=inventory \
  -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount,IP:.status.podIP'
save 06-readiness-failed-endpoints.txt kubectl get endpoints inventory -n "$NS" -o yaml
save 07-client-during-readiness-failure.txt kubectl exec -n "$NS" deployment/inventory-client -- env REQUESTS=16 BURST_LABEL="replica counts while one pod is unready" MIN_PODS=1 python /app/burst.py

if grep -q "pod=${TARGET}" "$OUT/07-client-during-readiness-failure.txt"; then
  echo "Unready pod ${TARGET} still received Service traffic" >&2
  exit 1
fi
if ! grep -q "pod=${OTHER}" "$OUT/07-client-during-readiness-failure.txt"; then
  echo "Ready pod ${OTHER} did not receive Service traffic" >&2
  exit 1
fi

echo "==> Restoring readiness on ${TARGET}"
kubectl exec -n "$NS" "$TARGET" -- python -c "open('/tmp/ready','a').close()"
sleep 8

save 08-readiness-restored-pods.txt kubectl get pods -n "$NS" -l app=inventory \
  -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount,IP:.status.podIP'
save 09-client-after-readiness-restored.txt kubectl exec -n "$NS" deployment/inventory-client -- env REQUESTS=30 BURST_LABEL="replica counts after readiness restored" MIN_PODS=2 python /app/burst.py

echo "==> 3. Delete one Inventory Pod and watch replacement"
DELETE_POD="$(kubectl get pods -n "$NS" -l app=inventory -o jsonpath='{.items[0].metadata.name}')"
{
  echo "\$ kubectl get pods -n ${NS} -l app=inventory --no-headers"
  kubectl get pods -n "$NS" -l app=inventory --no-headers
  echo
  echo "\$ kubectl delete pod -n ${NS} ${DELETE_POD}"
  kubectl delete pod -n "$NS" "$DELETE_POD"
} | tee "$OUT/10-pod-deleted.txt"

kubectl rollout status deployment/inventory -n "$NS" --timeout=180s
kubectl wait --for=condition=Ready pod -n "$NS" -l app=inventory --timeout=180s

{
  echo "deleted pod: ${DELETE_POD}"
  echo
  echo "\$ kubectl get pods -n ${NS} -o wide"
  kubectl get pods -n "$NS" -o wide
  echo
  echo "\$ kubectl get svc inventory -n ${NS}"
  kubectl get svc inventory -n "$NS"
} | tee "$OUT/11-replacement-pod-and-service.txt"

if kubectl get pods -n "$NS" -l app=inventory -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep -qx "$DELETE_POD"; then
  echo "Deleted pod ${DELETE_POD} is still present" >&2
  exit 1
fi

sleep 6
save 12-client-after-pod-replacement.txt kubectl logs -n "$NS" deployment/inventory-client --tail=30

echo "Evidence written to ${OUT}"
