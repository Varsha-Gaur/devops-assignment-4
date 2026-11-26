#!/usr/bin/env bash
# Restore: recreate the stack from Git manifests and load the Redis snapshot from a backup.
# Usage: scripts/restore.sh <backup-dir> [namespace]
set -euo pipefail
BACKUP="$1"; NS="${2:-lab4-dr}"
START=$(date +%s)

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" apply -f k8s/dr/redis.yaml
kubectl -n "$NS" rollout status deployment/redis --timeout=120s

POD=$(kubectl -n "$NS" get pod -l app=redis -o jsonpath='{.items[0].metadata.name}')
kubectl -n "$NS" cp "$BACKUP/dump.rdb" "$POD:/data/dump.rdb" >/dev/null
# stop Redis WITHOUT saving so it reloads the restored dump.rdb when the container restarts
kubectl -n "$NS" exec "$POD" -- redis-cli SHUTDOWN NOSAVE >/dev/null 2>&1 || true
kubectl -n "$NS" wait --for=condition=Ready "pod/$POD" --timeout=120s

kubectl -n "$NS" apply -f k8s/dr/app.yaml
kubectl -n "$NS" rollout status deployment/notes-app --timeout=120s

echo "Restore finished in $(( $(date +%s) - START )) seconds (RTO)"
