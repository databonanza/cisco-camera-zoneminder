#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/new-backup-directory" >&2
  exit 2
fi
backup_dir=${1%/}
if [[ -z "$backup_dir" || -e "$backup_dir" ]]; then
  echo "Choose a backup directory that does not already exist." >&2
  exit 2
fi
umask 077
mkdir -p -- "$backup_dir"
chmod 700 -- "$backup_dir"

namespace=zoneminder
app=deployment/zoneminder
db_pod=zoneminder-db-0
helper_file=k8s/backup/event-volume-helper.yaml
original_replicas=$(kubectl -n "$namespace" get "$app" -o jsonpath='{.spec.replicas}')
: "${original_replicas:=1}"
helper_created=0
restore_app() {
  if (( helper_created )); then
    kubectl -n "$namespace" delete pod zoneminder-events-backup --ignore-not-found --wait=true >/dev/null || true
  fi
  kubectl -n "$namespace" scale "$app" --replicas="$original_replicas" >/dev/null || true
}
trap restore_app EXIT

kubectl -n "$namespace" rollout status statefulset/zoneminder-db --timeout=10m
kubectl -n "$namespace" scale "$app" --replicas=0
while [[ -n "$(kubectl -n "$namespace" get pods -l app.kubernetes.io/name=zoneminder -o name)" ]]; do
  sleep 2
done

kubectl -n "$namespace" exec "$db_pod" -- sh -ec \
  'exec mariadb-dump --user=root --password="$MARIADB_ROOT_PASSWORD" --single-transaction --routines --events --triggers --databases "$MARIADB_DATABASE"' \
  > "$backup_dir/mariadb.sql"

kubectl apply -f "$helper_file"
helper_created=1
kubectl -n "$namespace" wait --for=condition=Ready pod/zoneminder-events-backup --timeout=10m
kubectl -n "$namespace" exec zoneminder-events-backup -- tar -czf - -C /data . > "$backup_dir/events.tar.gz"
cat > "$backup_dir/metadata.txt" <<META
created_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
namespace=$namespace
zoneminder_image=$(kubectl -n "$namespace" get "$app" -o jsonpath='{.spec.template.spec.containers[?(@.name=="zoneminder")].image}')
mariadb_image=$(kubectl -n "$namespace" get statefulset/zoneminder-db -o jsonpath='{.spec.template.spec.containers[?(@.name=="mariadb")].image}')
META
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$backup_dir" && sha256sum mariadb.sql events.tar.gz metadata.txt > SHA256SUMS)
else
  (cd "$backup_dir" && shasum -a 256 mariadb.sql events.tar.gz metadata.txt > SHA256SUMS)
fi
chmod 600 "$backup_dir"/*
echo "Backup written to $backup_dir. Keep it off the K3s node and store the database Secret separately."
