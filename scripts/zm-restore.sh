#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/backup-directory" >&2
  exit 2
fi
backup_dir=${1%/}
for file in mariadb.sql events.tar.gz metadata.txt SHA256SUMS; do
  [[ -f "$backup_dir/$file" ]] || { echo "Missing backup file: $backup_dir/$file" >&2; exit 2; }
done
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$backup_dir" && sha256sum --check SHA256SUMS)
else
  (cd "$backup_dir" && shasum -a 256 --check SHA256SUMS)
fi
printf 'This will REPLACE the ZoneMinder database and event files in namespace zoneminder. Type RESTORE to continue: '
read -r confirmation
[[ "$confirmation" == RESTORE ]] || { echo "Restore cancelled."; exit 1; }

namespace=zoneminder
app=deployment/zoneminder
db_pod=zoneminder-db-0
helper_file=k8s/backup/event-volume-helper.yaml
original_replicas=$(kubectl -n "$namespace" get "$app" -o jsonpath='{.spec.replicas}')
: "${original_replicas:=1}"
restore_succeeded=0
helper_created=0
cleanup() {
  if (( helper_created )); then
    kubectl -n "$namespace" delete pod zoneminder-events-backup --ignore-not-found --wait=true >/dev/null || true
  fi
  if (( restore_succeeded )); then
    kubectl -n "$namespace" scale "$app" --replicas="$original_replicas" >/dev/null || true
  else
    echo "Restore did not complete; ZoneMinder remains scaled to zero for safety." >&2
  fi
}
trap cleanup EXIT

kubectl -n "$namespace" rollout status statefulset/zoneminder-db --timeout=10m
kubectl -n "$namespace" scale "$app" --replicas=0
while [[ -n "$(kubectl -n "$namespace" get pods -l app.kubernetes.io/name=zoneminder -o name)" ]]; do
  sleep 2
done

# Restore the database from a dump that includes CREATE DATABASE.
kubectl -n "$namespace" exec "$db_pod" -- sh -ec \
  'mariadb --user=root --password="$MARIADB_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS \`$MARIADB_DATABASE\`;"'
kubectl -n "$namespace" exec -i "$db_pod" -- sh -ec \
  'exec mariadb --user=root --password="$MARIADB_ROOT_PASSWORD"' < "$backup_dir/mariadb.sql"

kubectl apply -f "$helper_file"
helper_created=1
kubectl -n "$namespace" wait --for=condition=Ready pod/zoneminder-events-backup --timeout=10m
kubectl -n "$namespace" exec zoneminder-events-backup -- sh -ec \
  'for p in /data/* /data/.[!.]* /data/..?*; do [ -e "$p" ] || [ -L "$p" ] || continue; rm -rf -- "$p"; done'
kubectl -n "$namespace" exec -i zoneminder-events-backup -- tar -xzf - -C /data < "$backup_dir/events.tar.gz"
restore_succeeded=1
echo "Restore completed from $backup_dir. Check the ZoneMinder rollout and camera connectivity."
