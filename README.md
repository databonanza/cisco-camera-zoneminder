# Cisco cameras with ZoneMinder

Deployment manifests and setup guides for running ZoneMinder on K3s and
connecting supported Cisco CIVS cameras.

## Documentation

- [K3s deployment](docs/k3s/): Install ZoneMinder on K3s and configure storage,
  networking, and optional HTTPS access.
- [ZoneMinder](docs/zoneminder/): Set up monitors, credentials, and the 2621V
  lens controller.
- [Cisco cameras](docs/cisco-cameras/): Model-specific RTSP paths, stream
  settings, ONVIF details, and firmware guidance.
- [WireGuard VPN](docs/wireguard/): Deploy WireGuard on K3s and configure
  remote clients to reach cameras through the VPN.

This project is independent of Cisco and ZoneMinder. Keep camera management
and streaming services on trusted networks; do not expose camera ports directly
to the public Internet.

## License

MIT. Cisco, CIVS, and ZoneMinder are trademarks of their respective owners.
This project is not affiliated with or endorsed by those organizations.
