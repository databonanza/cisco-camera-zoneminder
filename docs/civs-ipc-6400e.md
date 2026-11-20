# Cisco CIVS-IPC-6400E

## ZoneMinder stream

Use an **FFmpeg** monitor with **TCP** transport and the primary RTSP URL:

```text
rtsp://CAMERA_USER:URL_ENCODED_PASSWORD@CAMERA_HOST:554/StreamingSetting?version=1.0&action=getRTSPStream&ChannelID=1&ChannelName=Channel1
```

Firmware 2.0.3-27 provides H.264 at 30 fps and G.711 A-law audio. A validated
starting profile is 1920 × 1080, 4 Mb/s, and a two-second keyframe interval.
ZoneMinder captures at approximately 29 fps with this profile. Enable the
secondary stream in camera settings before selecting it in ZoneMinder. Treat
these as starting values; encoder limits depend on firmware and stream mode.

## ONVIF findings

The CIVS-IPC-6400E advertises ONVIF 2.0 Device, Media, Events, and Device I/O
services. The four profiles are fixed; only one provides full-HD video and
G.711 audio. PTZ and Imaging requests are unsupported in firmware 2.0.3-27.
Event properties include Device/Network/Lost; verify event ingestion with
ZoneMinder's ONVIF probe.

Some snapshot URIs return an invalid channel error. Use the primary RTSP feed
for capture unless the snapshot path is verified on the installed firmware.

Keep credentials out of URLs stored in shared files. Use a dedicated read-only
camera account and isolate the camera network.
