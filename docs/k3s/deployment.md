# Deploy ZoneMinder on K3s

This deployment runs the official ZoneMinder container and MariaDB in a K3s
cluster. It stores the database and recordings in persistent volume claims and
keeps the web service private by default. The manifests use K3s's `local-path`
storage class and the upstream ZoneMinder 1.38.6 image. Review the sizing and
image versions before applying them to a production cluster.

K3s includes a local-path storage provider and, by default, Traefik for Ingress.
Local-path volumes reside on a node and bind the pod to that node; use a
replicated CSI storage class if workloads must move between nodes. See the
[K3s storage guide](https://docs.k3s.io/add-ons/storage) and
[K3s networking guide](https://docs.k3s.io/networking/networking-services).

## Requirements

- A working K3s cluster and a `kubectl` context with permission to create a
  namespace, StatefulSet, Deployment, Services, PVCs, NetworkPolicies, and
  Secrets.
- A default or explicit storage class that supports `ReadWriteOnce` claims.
- Network routes and firewall rules that allow the ZoneMinder pod to reach the
  cameras' RTSP streams. Allow other camera services only when needed.
- Enough memory for ZoneMinder plus the shared-memory frame buffers. Increase
  the manifest requests and limits as camera count, resolution, or frame rate
  grows.

Run the command examples below from the repository root.

## System requirements and planning capacity

These are planning estimates, not benchmark results or guaranteed limits. They
assume a dedicated worker node for ZoneMinder and MariaDB, H.264 camera streams
without transcoding, and motion analysis configured at about 2–5 frames per
second per camera. The monitor templates start with capture, analysis, and
recording disabled; the estimates describe an activated system after monitor
configuration.

| Tier | Worker node resources for ZoneMinder and MariaDB | Starting workload | Expected use |
|---|---|---|---|
| Low | 4 CPU cores, 8 GiB RAM | 1–2 cameras at 720p or 1080p, 5–10 capture FPS | Basic live viewing and event recording; use 2–3 analysis FPS per camera. |
| Mid | 8 CPU cores, 16 GiB RAM | 3–6 cameras at 1080p, around 10 capture FPS | Typical small installation; use 2–5 analysis FPS per camera. |
| High | 16 CPU cores, 32 GiB RAM | 6–12 cameras at 1080p, around 10–15 capture FPS | Larger installation with event recording; monitor CPU, memory, and disk load as cameras are added. |

Capacity can be lower with higher resolutions or frame rates, full-colour
analysis, continuous recording, transcoding, multiple live viewers, or other
workloads sharing the node. ZoneMinder's documentation notes that motion
analysis is CPU intensive and that lowering its analysis FPS can allow more
cameras; many scenes do not need analysis at the camera's full capture rate.
See the [analysis settings guide](https://zoneminder.readthedocs.io/en/stable/userguide/definemonitor/definemonitor_analysis.html)
and [memory planning FAQ](https://zoneminder.readthedocs.io/en/latest/faq.html).

The base manifests request 500 millicores and 1 GiB for ZoneMinder, plus 250
millicores and 512 MiB for MariaDB; ZoneMinder has a 4 GiB memory limit and a
1 GiB shared-memory volume. The event PVC starts at 50 GiB and MariaDB at 10
GiB. Increase resources and storage for your workload and retention target.
The optional WireGuard pod requests 100 millicores and 128 MiB, with limits of
500 millicores and 512 MiB.

## Create database credentials

Create the namespace and enter unique passwords without putting them in a
manifest or shell history:

```bash
kubectl apply -f k8s/namespace.yaml
read -r -s -p 'MariaDB application password: ' ZM_DB_PASSWORD
printf '\n'
read -r -s -p 'MariaDB root password: ' MARIADB_ROOT_PASSWORD
printf '\n'
kubectl create secret generic zoneminder-db \
  --namespace zoneminder \
  --from-literal=MARIADB_PASSWORD="$ZM_DB_PASSWORD" \
  --from-literal=MARIADB_ROOT_PASSWORD="$MARIADB_ROOT_PASSWORD"
unset ZM_DB_PASSWORD MARIADB_ROOT_PASSWORD
```

Store both values in a password manager before clearing the terminal. Kubernetes
Secrets are base64 encoded and are not encrypted by that encoding. Restrict
Secret access with RBAC and enable encryption at rest in the cluster. See
[Kubernetes Secret guidance](https://kubernetes.io/docs/concepts/security/secrets-good-practices/).

## Deploy the application

Review `k8s/zoneminder.yaml` and `k8s/mariadb.yaml`. Increase storage for the
event PVC to fit the required retention period. If the cluster uses a storage
class other than `local-path`, update both PVC specifications.

Apply the manifests and wait for the pods:

```sh
kubectl apply -k k8s/
kubectl -n zoneminder rollout status statefulset/zoneminder-db --timeout=10m
kubectl -n zoneminder rollout status deployment/zoneminder --timeout=15m
kubectl -n zoneminder wait --for=condition=complete job/zoneminder-monitor-templates --timeout=15m
kubectl -n zoneminder get pods,pvc,services
```

Access the web interface through a local port forward:

```sh
kubectl -n zoneminder port-forward service/zoneminder 8080:80
```

Open `http://localhost:8080/zm/`. ZoneMinder 1.38 starts with authentication
disabled. Before exposing it to other networks, enable authentication under
**Options → Authentication**, sign in with the initial `admin` account, and
change its password under **Options → Users**. Complete the first-run usage
statistics prompt.

## Optional HTTPS Ingress

K3s enables Traefik by default. To expose the UI through an existing DNS name,
edit `k8s/ingress.example.yaml` and replace `zm.example.com` with a hostname you
control. Create the referenced `zoneminder-tls` Secret in the `zoneminder`
namespace, then apply the file:

```sh
kubectl apply -f k8s/ingress.example.yaml
```

Point the hostname to the Ingress controller's reachable address. If the
cluster uses a different Ingress controller, change `ingressClassName` and
adjust the TLS setup for that controller. Do not expose the unauthenticated
first-run page to a public network.

## Camera connectivity and ZoneMinder setup

The Kustomize deployment creates inactive FFmpeg monitor templates for the
CIVS-IPC-2621V, CIVS-IPC-6000P, and CIVS-IPC-6400E. Each uses the RTSP path and
starting resolution from its model guide; no camera address or credentials are
included. The templates are inactive so ZoneMinder does not repeatedly try to
connect to the example host.

In **Console → Monitors**, edit the monitor for each camera you have. Replace
`CAMERA_HOST` in **Source Path** with the camera's address, enter the camera
username and password in the FFmpeg source fields, and save. Then set
**General → Capturing** to **Always** to start the stream. Review the resolution
and probe the source before enabling recording. If you have multiple cameras
of one model, duplicate that model's monitor and give each copy a unique name.

The setup Job runs once during the initial deployment. It skips monitor names
that already exist, so reapplying the manifests does not overwrite your edits.
Wait for this Job to complete before enabling ZoneMinder authentication; it
uses the API while a fresh installation still has authentication disabled.
If you delete the templates and need to recreate them, delete the completed
`zoneminder-monitor-templates` Job and reapply `k8s/`.

The ZoneMinder pod needs network reachability to each camera address and its
configured RTSP port. ONVIF discovery also needs the relevant discovery and
service ports allowed across the camera network boundary.

The deployment does not expose RTSP or ONVIF services from the cluster. Only
the web UI is reachable through the Service or optional Ingress.

For remote access to cameras on the private camera network, use the optional
[WireGuard deployment and setup guide](../wireguard/README.md). Its manifests
are separate because each installation needs its own public endpoint and
camera-network routes.

## Storage, backups, and upgrades

- ZoneMinder stores recordings and image cache under `/var/cache/zoneminder`.
  Size the PVC for the desired retention period and configure event filters in
  ZoneMinder to manage retention.
- MariaDB data uses a separate persistent volume claim created by the
  StatefulSet.
- Back up both the MariaDB database and the ZoneMinder event PVC before
  upgrading. A PVC alone is not a backup.
- Before an upgrade, change the image tag in `k8s/zoneminder.yaml` to the
  selected release, then apply the manifests and monitor the rollout.
- Pin image digests in production if you require immutable deployments. The
  example uses the upstream `1.38.6` tag; the official project publishes images
  for amd64 and arm64 through Docker Hub and GHCR. See the
  [ZoneMinder Docker guide](https://zoneminder.readthedocs.io/en/latest/installationguide/docker.html).
