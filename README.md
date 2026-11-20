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
