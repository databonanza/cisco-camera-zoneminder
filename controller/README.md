# CIVS-IPC-2621V lens controller

`Cisco2621Lens.pm` is a ZoneMinder control module for the fixed dome camera's
motorized optical zoom and focus lens. It provides relative zoom/focus and
autofocus commands through Cisco's HTTPS CGI interface.

## Requirements and configuration

- ZoneMinder with Perl support and the `LWP::UserAgent`, `URI`, and
  `IO::Socket::SSL` Perl modules.
- An RTSP source path containing the camera host and dedicated camera account.
- The SHA-256 fingerprint of that camera's HTTPS certificate in the monitor's
  **Control Device** field.

Choose `Cisco2621Lens` in the monitor's **Control** tab. See the
[installation and security steps](../docs/zoneminder.md).

The module currently accepts IPv4 addresses only. It pins the certificate
fingerprint and does not trust the certificate's hostname. It also enables
legacy TLS compatibility needed by old camera firmware. Keep this traffic on a
trusted, isolated network. Do not replace the fingerprint check with disabled
certificate verification.

This controller supports lens zoom and focus only; it does not provide
pan/tilt. It is validated with CIVS-IPC-2621V firmware V4.4.2-2. Confirm lens
movement on the target camera before relying on automated control.
