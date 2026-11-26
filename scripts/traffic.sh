#!/usr/bin/env bash
# Send N requests to a Service from inside the cluster and summarise which version answered and how many failed.
# Usage: scripts/traffic.sh <service> <namespace> [requests] [delay-seconds]
set -euo pipefail
SVC="$1"; NS="$2"; N="${3:-50}"; DELAY="${4:-0.1}"
POD="traffic-$RANDOM"

kubectl -n "$NS" run "$POD" --restart=Never --image=busybox:1.36 --command -- sh -c "
  for i in \$(seq 1 $N); do
    out=\$(wget -q -T 2 -O- http://$SVC/ 2>/dev/null) || out='FAILED'
    echo \"\$out\" | grep -o '\"version\":\"[^\"]*\"' || echo FAILED
    sleep $DELAY
  done" >/dev/null
kubectl -n "$NS" wait --for=jsonpath='{.status.phase}'=Succeeded "pod/$POD" --timeout=300s >/dev/null
echo "Requests: $N  (service $SVC, namespace $NS)"
kubectl -n "$NS" logs "$POD" | sort | uniq -c
kubectl -n "$NS" delete pod "$POD" --wait=false >/dev/null
