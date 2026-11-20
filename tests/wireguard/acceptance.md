# WireGuard network acceptance test

Run this procedure against a disposable K3s cluster and an isolated test network before relying on the VPN. Do not change production camera routes or firewall state to perform the test.

## Test topology

Prepare two reachable test services on separate addresses:

- **Allowed target:** a disposable HTTP service with an address inside the configured `CAMERA_NETWORK` CIDR. It represents a camera endpoint.
- **Denied target:** a disposable HTTP service on a different private subnet that is reachable from the K3s node, but outside `CAMERA_NETWORK`.

Record both addresses and HTTP ports. Ensure that neither subnet overlaps the K3s pod/service CIDRs or the test client's local network. In the private WireGuard overlay, set `CAMERA_NETWORK` to the allowed target's narrowest suitable CIDR and `ALLOWEDIPS` to include the VPN server address and allowed service address only. Deploy using the WireGuard guide.

## Checks

1. Import a generated peer configuration into a disposable client and connect.
2. Confirm a recent handshake and nonzero transfer counters with `kubectl exec -n wireguard wireguard-0 -- wg show`.
3. From the client, request the allowed service URL. It must respond.
4. From the same client, request the denied service URL. It must time out or be rejected. Confirm the denied host is otherwise reachable from the K3s node so this result exercises the WireGuard forwarding rule.
5. Restart the WireGuard pod with `kubectl -n wireguard delete pod wireguard-0`, wait for the StatefulSet rollout, and reconnect the same peer. A fresh handshake must appear, the allowed service must respond, and the denied service must remain blocked.
6. Disconnect the peer and verify ordinary internet traffic from the client still uses its normal route (split-tunnel behavior).

Record the K3s version, CNI, node OS, test CIDRs, and pass/fail results with the release or deployment change. Remove the disposable services, peer config, and test overlay when finished. Never commit private keys or real camera addresses and credentials.
