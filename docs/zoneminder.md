# ZoneMinder setup

## Configure an RTSP monitor

1. Create a monitor and select **FFmpeg** as the source type.
2. Select **TCP** for transport when the camera supports RTSP-over-TCP.
3. Paste the model-specific RTSP path from its guide. Replace example host and
   credential values in the ZoneMinder UI only. Percent-encode reserved URL
   characters in embedded credentials.
4. Set capture resolution to the camera's configured stream resolution.
5. Probe the monitor and confirm video, audio, frame rate, and timestamps before
   relying on recording.

Replace all example host and credential values with values for your own
network. Do not commit real camera addresses, usernames, passwords, certificate
fingerprints, or monitor database exports.

## Install the 2621V lens controller

Copy `controller/Cisco2621Lens.pm` into ZoneMinder's Perl control-module
directory. Package paths vary; common package paths include
`/usr/share/perl5/ZoneMinder/Control/` and `/usr/lib/zoneminder/cgi-bin/Control/`.
Restart the ZoneMinder services or container after installation.

In the monitor's **Control** tab, choose `Cisco2621Lens`. Set **Control Device**
to the SHA-256 fingerprint of the camera's HTTPS certificate. To calculate it
from a certificate file:

```sh
openssl x509 -in camera-certificate.pem -noout -fingerprint -sha256
```

The controller reads the host, username, and password from the monitor's RTSP
source path. It rejects a missing credential, a non-IPv4 host, or a malformed
fingerprint. It uses the fingerprint to authenticate the HTTPS peer while
disabling hostname checks; do not leave the fingerprint blank or reuse a
fingerprint from another camera.

## Protect credentials

- Create a dedicated camera account with view and lens-control permissions only.
- Restrict camera access to the recorder and trusted administration hosts.
- Do not expose RTSP, HTTP, HTTPS, Telnet, FTP, or SSH to the Internet.
- Store monitor credentials in ZoneMinder, not in shell history or repository
  files. Restrict database and backup access because monitor URLs can contain
  credentials.
- Use HTTPS certificate fingerprint pinning for the 2621V lens controller.
  Its legacy TLS compatibility settings are not suitable for an untrusted
  network.
