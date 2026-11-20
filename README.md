# Cisco IP cameras with ZoneMinder

Guides for integrating Cisco CIVS IP cameras with ZoneMinder and deploying
ZoneMinder on a K3s cluster. Camera documentation covers CIVS-IPC-2621V,
CIVS-IPC-6000P, and CIVS-IPC-6400E models.

This project is independent of Cisco and ZoneMinder. Results depend on camera
firmware, model variants, and ZoneMinder/FFmpeg versions. Keep cameras on a
restricted network and do not expose camera administration, RTSP, or SSH ports
to the public Internet.

## Guides

- [CIVS-IPC-2621V](docs/civs-ipc-2621v.md): RTSP setup, stream settings,
  ONVIF limitations, and experimental optical zoom/focus control.
- [CIVS-IPC-6000P](docs/civs-ipc-6000p.md): FFmpeg/RTSP monitor setup, stream
  selection, ONVIF, and configuration guidance.
- [CIVS-IPC-6400E](docs/civs-ipc-6400e.md): FFmpeg/RTSP and ONVIF notes.
- [ZoneMinder setup](docs/zoneminder.md): monitor settings, credentials, and
  controller installation.
- [K3s deployment](docs/k3s.md): a generic ZoneMinder and MariaDB deployment.
- [Firmware guidance](docs/firmware.md): version selection and update practices.

The deployable Kubernetes resources are in [`k8s/`](k8s/). Follow the
[deployment guide](docs/k3s.md) to create the database Secret and install them.

## K3s quick setup

You need a working K3s cluster, `kubectl` pointed at that cluster, persistent
storage (the manifests use K3s's `local-path` class), and network access from
ZoneMinder to your cameras. Follow the [full setup guide](docs/k3s.md) to create
the database credentials, then deploy and wait for the application and monitor
templates:

```sh
kubectl apply -k k8s/
kubectl -n zoneminder rollout status statefulset/zoneminder-db --timeout=10m
kubectl -n zoneminder rollout status deployment/zoneminder --timeout=15m
kubectl -n zoneminder wait --for=condition=complete job/zoneminder-monitor-templates --timeout=15m
kubectl -n zoneminder port-forward service/zoneminder 8080:80
```

Open `http://localhost:8080/zm/`. The install creates inactive FFmpeg monitor
templates for the CIVS-IPC-2621V, CIVS-IPC-6000P, and CIVS-IPC-6400E. They start
with no camera address or credentials and **Capturing** set to **None**, so no
stream is attempted on first install. In ZoneMinder, edit each monitor's Source
Path to replace `CAMERA_HOST`, enter the camera's username and password, then
set **General → Capturing** to **Always** to start its stream. Wait for the
monitor-template Job to complete before enabling ZoneMinder authentication;
the initial setup uses the API while authentication is disabled.

## System requirements and planning capacity

The table gives **planning estimates**, not benchmark results or guaranteed
limits. It assumes a dedicated worker node for this ZoneMinder deployment,
H.264 camera streams without transcoding, and motion analysis configured at
about 2–5 frames per second per camera. The monitor templates start with
capture, analysis, and recording disabled; the estimates describe an activated
system after you configure its monitors.

| Tier | Worker node resources for ZoneMinder and MariaDB | Starting workload | Expected use |
|---|---|---|---|
| Low | 4 CPU cores, 8 GiB RAM | 1–2 cameras at 720p or 1080p, 5–10 capture FPS | Basic live viewing and event recording; use 2–3 analysis FPS per camera. |
| Mid | 8 CPU cores, 16 GiB RAM | 3–6 cameras at 1080p, around 10 capture FPS | Typical small installation; use 2–5 analysis FPS per camera. |
| High | 16 CPU cores, 32 GiB RAM | 6–12 cameras at 1080p, around 10–15 capture FPS | Larger installation with event recording; monitor CPU, memory, and disk load as cameras are added. |

These estimates can drop with higher resolutions or frame rates, full-colour
analysis, continuous recording, transcoding, multiple live viewers, or other
workloads sharing the node. ZoneMinder's documentation notes that motion
analysis is CPU intensive and that lowering its analysis FPS can allow more
cameras; for many scenes, analysis does not need to run at the camera's full
capture rate. See the [analysis settings guide](https://zoneminder.readthedocs.io/en/stable/userguide/definemonitor/definemonitor_analysis.html)
and [memory planning FAQ](https://zoneminder.readthedocs.io/en/latest/faq.html).

The example manifests request 500 millicores and 1 GiB for ZoneMinder, plus
250 millicores and 512 MiB for MariaDB; ZoneMinder has a 4 GiB memory limit.
Adjust those pod resources and the 1 GiB shared-memory volume to suit the node
and workload. The event PVC starts at 50 GiB and the MariaDB PVC at 10 GiB;
increase them to meet the desired recording retention. Check actual CPU, RAM,
frame capture, and disk usage after enabling each monitor, and scale before
adding more cameras if the system begins dropping frames or falling behind.

## Quick RTSP examples

Replace `CAMERA_HOST`, `CAMERA_USER`, and `URL_ENCODED_PASSWORD` with values for
your own camera. Prefer configuring the source path through ZoneMinder rather
than saving a populated URL in a shared file.

```text
# CIVS-IPC-2621V primary H.264 stream with audio
rtsp://CAMERA_HOST:554/img/h264media.sav

# CIVS-IPC-6000P / CIVS-IPC-6400E primary stream
rtsp://CAMERA_USER:URL_ENCODED_PASSWORD@CAMERA_HOST:554/StreamingSetting?version=1.0&action=getRTSPStream&ChannelID=1&ChannelName=Channel1
```

The 2621V accepts RTSP credentials when prompted by a client. The 6000-series
example embeds credentials in the URL; reserve characters must be percent
encoded. Never commit a real username, password, camera address, certificate,
or ZoneMinder monitor export.

## License and trademarks

This project is available under the MIT License. Cisco, CIVS, and ZoneMinder are
trademarks of their respective owners. This project is not affiliated with or
endorsed by those organizations.
