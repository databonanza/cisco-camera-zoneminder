# Cisco CIVS-IPC-6000P

## ZoneMinder RTSP monitor

Create an **FFmpeg** monitor, set transport to **TCP**, and use the primary
stream URL:

```text
rtsp://CAMERA_USER:URL_ENCODED_PASSWORD@CAMERA_HOST:554/StreamingSetting?version=1.0&action=getRTSPStream&ChannelID=1&ChannelName=Channel1
```

The secondary stream uses channel 3:

```text
rtsp://CAMERA_USER:URL_ENCODED_PASSWORD@CAMERA_HOST:554/StreamingSetting?version=1.0&action=getRTSPStream&ChannelID=3&ChannelName=Channel3
```

Enable the secondary encoder in the camera settings before using this path.
Verify playback after selecting a channel and resolution supported by the
installed firmware.
URL-encode reserved characters in credentials. Avoid placing real credentials
in documentation, issue reports, or committed monitor exports.

## Configuration and capabilities

Firmware 2.5.0-10 provides an H.264 primary stream with G.711 A-law audio. A
validated starting profile is 1920 × 1080 at 10 fps, 6 Mb/s, with a
two-second keyframe interval. Adjust these values to match the camera, network,
and recording requirements.

Cisco documents H.264 and MJPEG, adjustable frame rate/bitrate, day/night
switching, and ONVIF 2.0 for the 6000 series. The CIVS-IPC-6000P supports ONVIF
Device and Media services; PTZ and Imaging controls are not available in the
validated configuration. Use ZoneMinder's ONVIF probe to check service and
profile support on the installed firmware.

Cisco's model-specific [RTSP instructions](https://community.cisco.com/t5/physical-security/ipc-6000p-camera-rtsp-stream/m-p/2427905/highlight/true),
[6000-series data sheet](https://www.cisco.com/c/en/us/products/collateral/physical-security/video-surveillance-6000-series-ip-cameras/datasheet-c78-728703.html),
and [firmware 2.5 release notes](https://www.cisco.com/c/en/us/td/docs/security/physical_security/video_surveillance/ip_camera/release_notes/firmware-hd-2-5-0/rn-2-5-0.html)
provide model and version details.

## Security notes

Keep the camera on a restricted network. Disable unused services, change all
factory credentials, use a dedicated view-only account for recording, and
permit only the NVR and administration hosts to reach the camera.
