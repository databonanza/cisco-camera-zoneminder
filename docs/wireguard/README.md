# Remote camera access with WireGuard

This optional K3s add-on provides split-tunnel VPN access to a configured
camera network. Public traffic reaches only the WireGuard UDP port; camera
RTSP, web, and ONVIF services remain on the private network. A server-side
firewall rule limits VPN forwarding to the configured camera-network CIDR.

The deployment uses the maintained [LinuxServer WireGuard image](https://docs.linuxserver.io/images/docker-wireguard/)
and an optional Kustomize overlay in `k8s/wireguard/`. It is separate from the
ZoneMinder base deployment because each installation must set its own public
endpoint and camera-network addresses.

## Requirements

- A working K3s cluster with a Linux node whose network can reach the camera
  network.
- A K3s node kernel with WireGuard support. Load the module on the node before
  deploying if it is not already available: `sudo modprobe wireguard`.
- An internet-reachable public IP address or DNS name and a router/firewall
  where you can forward one UDP port to a K3s node. If the internet connection
  uses carrier-grade NAT, ordinary inbound port forwarding will not work.
- A camera-network CIDR or the individual camera IP addresses, and confirmation
  that the chosen WireGuard subnet does not overlap the camera LAN, K3s networks,
  or the networks from which clients will connect.
- `kubectl` access to create a namespace, StatefulSet, Services, and PVCs.

## 1. Set the VPN endpoint, peers, and camera routes

Edit `k8s/wireguard/wireguard.yaml` before applying it. Set `SERVERURL` to the
public DNS name or static public IP clients will use. Configure `PEERS` with a
unique alphanumeric name for each client device; use one peer per phone,
laptop, or tablet. The example peer names are `phone,laptop`.

Set `CAMERA_NETWORK` to the subnet containing the cameras. This CIDR is the
server-side firewall boundary: if it covers a whole camera VLAN, VPN clients
can reach any host on that VLAN. For one camera, a `/32` limits forwarding to
that address. The example `192.0.2.0/24` is a documentation-only placeholder
and must be replaced. Set `ALLOWEDIPS` to the camera addresses clients should
route through the VPN, for example:

```yaml
- name: ALLOWEDIPS
  value: 10.13.13.1/32,192.0.2.40/32,192.0.2.41/32
- name: CAMERA_NETWORK
  value: 192.0.2.0/24
```

For this example, replace the documentation addresses with the real camera
addresses and set `CAMERA_NETWORK` to their actual LAN subnet. Keep
`10.13.13.1/32` in `ALLOWEDIPS` so the client can reach the VPN endpoint. If
`10.13.13.0/24` overlaps any local, K3s, or camera network, change
`INTERNAL_SUBNET` and the matching server address in `ALLOWEDIPS`.

The server forwarding rules allow traffic only to `CAMERA_NETWORK`; they do not
allow general access to other K3s or LAN services. The server uses source NAT
for return traffic, so camera devices do not need a route back to the VPN
subnet. The K3s node hosting the VPN pod must still be able to reach the camera
network, and its firewall must allow that traffic.

## 2. Deploy the VPN

From the repository root, apply the optional overlay and wait for the pod:

```sh
kubectl apply -k k8s/wireguard/
kubectl -n wireguard rollout status statefulset/wireguard --timeout=10m
kubectl -n wireguard get pod wireguard-0 -o wide
kubectl -n wireguard get services,pvc
```

The overlay creates a dedicated `wireguard` namespace, persistent storage for
server and peer keys, and a UDP NodePort Service. It adds the `NET_ADMIN`
capability needed to create its tunnel and forwarding rules; the container is
not configured as privileged. The namespace's Pod Security
Admission label permits that capability in this isolated namespace. Keep other
workloads out of it. The `LOG_CONFS` setting is off so generated client configs
and QR codes are not written to the container log.

If the pod cannot start the tunnel, check that the node kernel supports the
WireGuard module, the cluster permits `NET_ADMIN` in the `wireguard` namespace,
and UDP 31820 is not blocked. The container also enables IPv4 forwarding inside
its network namespace and applies a camera-network-only egress rule.

## 3. Forward the WireGuard UDP port

The previous command shows the node hosting the WireGuard pod. Because the
Service uses `externalTrafficPolicy: Local` to preserve client endpoint
addresses, forward traffic to that node's LAN address. Create an A/AAAA record
for the public VPN name if you use DNS. On the internet router, forward **UDP
51820** from the WAN to the pod's node at **UDP 31820**. Allow UDP 31820 through
that node's firewall if it filters NodePort traffic. Do not forward camera
ports such as RTSP 554, HTTP 80, or HTTPS 443 from the WAN.

`SERVERPORT` is the public-side port and defaults to 51820; `nodePort` is the
Kubernetes-side port and defaults to 31820. If you change either value, keep
the public endpoint, Service, and router rule consistent. `SERVERURL` should
resolve to the public endpoint while the client is away from home.

The WireGuard PVC uses node-local storage, so it remains bound to the node where
the pod was scheduled. If that node is replaced, restore the VPN configuration
and update the router's port-forward target as needed.

## 4. Export each client configuration securely

After the pod is ready, retrieve the configuration for a peer. For example, to
save the `phone` peer configuration to a local file:

```sh
kubectl exec -n wireguard wireguard-0 -- \
  cat /config/peer_phone/peer_phone.conf > phone.conf
chmod 600 phone.conf
```

The configuration contains a private key. Treat it like a password: import it
directly into the WireGuard app, keep it out of source control and chat, and
remove temporary copies after import. Do not use `kubectl logs` to retrieve
client configuration. A separate peer configuration should be used for every
device.

## 5. Configure the clients

Install the official [WireGuard app](https://www.wireguard.com/install/) on
each device. Transfer that device's `.conf` file using a trusted local method.
In the app, add or import a tunnel from the configuration file, name it, and
save it. On a phone, use the app's **Import from file or archive** action; on
desktop, choose **Import tunnel(s) from file**. Enable the tunnel when away
from the camera network.

The generated client configuration uses split tunneling: only the VPN endpoint
and configured camera addresses use the VPN. Ordinary internet traffic stays
on the client's normal connection. If a phone or laptop's current network uses
the same IP range as the camera network, that overlapping route may prevent
camera access; choose non-overlapping network ranges where possible.

## 6. Verify the connection

On the server, check that a client has completed a handshake:

```sh
kubectl exec -n wireguard wireguard-0 -- wg show
```

From the connected client, open a camera's private IP in its web interface or
use a camera viewer with that camera's RTSP path. ICMP ping may be disabled by
the camera, so a failed ping alone does not mean the VPN is down. Verify that
the client can reach a camera service you expect to use. Camera access remains
subject to each camera's own login credentials.

## Add or revoke a device

To add a device, add a unique alphanumeric name to `PEERS` in
`k8s/wireguard/wireguard.yaml`, apply the overlay again, and wait for the
StatefulSet rollout. Then export that peer's new config from
`/config/peer_<name>/peer_<name>.conf`.

To revoke a device, remove its name from `PEERS`, apply the overlay, and wait
for the rollout. This regenerates the server peer list without that device.
Then remove its saved config from the server PVC and delete the configuration
from the device. Keep a secure backup of the `/config` PVC; it holds the server
key and all peer credentials. If you change `CAMERA_NETWORK`, update
`ALLOWEDIPS` to match, apply the overlay, and restart the StatefulSet so the
server firewall and client routes are regenerated.

## Network model and limitations

WireGuard clients connect through the public UDP endpoint to the NodePort
Service. The VPN pod forwards and source-NATs client traffic toward the
configured camera network. The default K3s node route and firewall must permit
the pod's egress to that network. Different CNI plugins or custom egress
policies may need additional routing or firewall configuration.

This setup does not provide a public address for each camera, does not make the
ZoneMinder web interface available through the VPN, and does not bypass carrier
grade NAT. It provides private camera-network access only from authenticated
WireGuard peers.
