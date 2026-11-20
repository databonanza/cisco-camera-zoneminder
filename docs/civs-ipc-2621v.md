# Cisco CIVS-IPC-2621V

## RTSP stream

Enable the RTSP port in the camera's Advanced Setup and select a streaming mode
that includes an H.264 primary stream. Cisco's guide gives these paths:

```text
rtsp://CAMERA_USER:URL_ENCODED_PASSWORD@CAMERA_HOST:554/img/h264media.sav
rtsp://CAMERA_USER:URL_ENCODED_PASSWORD@CAMERA_HOST:554/img/h264video.sav
rtsp://CAMERA_USER:URL_ENCODED_PASSWORD@CAMERA_HOST:554/img/h264media2.sav
```

The first path provides the primary H.264 stream with audio. The second provides
video only. The third is the secondary H.264 stream and requires a dual-H.264
streaming mode. RTSP port 554 is the default; use the port configured on the
camera. Use a dedicated view-only user and URL-encode reserved characters in
the credentials. See the
[2621V user guide mirror](https://manualsdump.com/en/manuals/cisco_systems-civs-ipc-2621v/212353/93)
and the [ZoneMinder Cisco camera notes](https://wiki.zoneminder.com/Cisco).

In ZoneMinder, start with an **FFmpeg** source and **TCP** transport. Probe the
stream with FFmpeg before creating a production monitor. Set capture resolution
to the camera's configured output size. A validated H.264 profile is
720 × 480, 30 fps, and 4 Mb/s. Other stream modes and firmware may differ.

## Imaging and day/night

The camera's day/night control can be set to automatic in its web interface.
Configure the camera's local time zone and NTP server so its clock and schedule
are correct. Verify the clock after saving.

Firmware V4.4.2-2 did not provide an ONVIF media service. Use the RTSP URL
directly. The model has a motorized lens, but its zoom and focus functions use
Cisco-specific web endpoints rather than ONVIF PTZ.

## ZoneMinder zoom and focus controller

The experimental [`Cisco2621Lens.pm`](../controller/Cisco2621Lens.pm) module
implements relative zoom, relative focus, and autofocus. It uses the camera's
HTTPS interface and pins the camera's SHA-256 certificate fingerprint. See
[ZoneMinder setup](zoneminder.md) for installation and settings.

The controller was exercised on a CIVS-IPC-2621V running firmware V4.4.2-2.
Other firmware releases may have different endpoints or TLS behavior. The
module uses legacy TLS settings to communicate with old camera firmware. Use it
only on a trusted, segmented camera network and do not disable fingerprint
validation.
