#!/usr/bin/env bash
set -Eeuo pipefail

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
kubectl kustomize k8s/ > "$workdir/base.yaml"
kubectl kustomize k8s/wireguard/overlays/example/ > "$workdir/wireguard.yaml"
kubeconform -strict -summary "$workdir/base.yaml" "$workdir/wireguard.yaml"
python3 scripts/check-markdown-links.py
bash -n scripts/zm-backup.sh scripts/zm-restore.sh scripts/validate-manifests.sh
