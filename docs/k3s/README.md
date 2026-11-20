# K3s deployment

Deploy ZoneMinder and MariaDB to a K3s cluster with persistent storage. The
default manifests keep the web service internal and create inactive monitor
templates for the supported cameras.

Use the [deployment guide](deployment.md) for prerequisites, database Secret
creation, deployment, first-run authentication, ingress, storage, and upgrades.
The optional [WireGuard guide](../wireguard/README.md) explains remote camera
access over a VPN.
