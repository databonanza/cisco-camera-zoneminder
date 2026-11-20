# Remote camera access with WireGuard

This optional K3s add-on provides split-tunnel VPN access to a configured camera network. Public traffic reaches only the WireGuard UDP port; camera RTSP, web, and ONVIF services remain on the private network. Server-side firewall rules limit VPN forwarding to the configured camera-network CIDR.

The deployment uses the maintained [LinuxServer WireGuard image](https://docs.linuxserver.io/images/docker-wireguard/), pinned to `1.0.20260223-r0-ls129`. Review and deliberately update that tag when adopting a newer upstream release. Site-specific endpoint and network settings live in a Kustomize overlay so the base stays generic.

## Requirements

- A working K3s cluster with a Linux node whose network can reach the camera network.
- A K3s node kernel with WireGuard support. Load the module on the node before deploying if it is not already available: `sudo modprobe wireguard`.
- An internet-reachable public IP address or DNS name and a router/firewall where you can forward one UDP port to a K3s node. If the internet connection uses carrier-grade NAT, ordinary inbound port forwarding will not work.
- A camera-network CIDR and confirmation that the chosen WireGuard subnet does not overlap the camera LAN, K3s networks, or networks from which clients connect.
- `kubectl` access to create a namespace, StatefulSet, Services, and PVCs.

## 1. Create a private settings overlay

From the repository root, copy the example into the ignored local directory:

```sh
mkdir -p k8s/wireguard/overlays
cp -R k8s/wireguard/overlays/example k8s/wireguard/overlays/local
```

Edit `k8s/wireguard/overlays/local/settings.yaml`. Set `SERVERURL` to the public DNS name or static public IP clients will use. Set `PEERS` to a unique alphanumeric name for each device, using one peer per phone, laptop, or tablet. Set `CAMERA_NETWORK` to the subnet containing the cameras. This is the server-side firewall boundary: use an individual `/32` if only one camera should be reachable. Set `ALLOWEDIPS` to the camera IP addresses clients should route through the VPN, for example:

```yaml
            - name: ALLOWEDIPS
              value: 10.13.13.1/32,192.0.2.40/32,192.0.2.41/32
            - name: CAMERA_NETWORK
              value: 192.0.2.0/24
```

Replace documentation-only `192.0.2.x` addresses with your camera addresses. Keep the VPN server address in `ALLOWEDIPS`. If `10.13.13.0/24` overlaps any local, K3s, or camera network, change `INTERNAL_SUBNET` and the matching server address in `ALLOWEDIPS`.

`local/` is ignored by Git to help keep personal network settings out of the repository. Treat the resulting peer configurations as secrets and keep them out of source control.

## 2. Deploy the VPN

Apply the local overlay and wait for the pod:

```sh
kubectl apply -k k8s/wireguard/overlays/local/
kubectl -n wireguard rollout status statefulset/wireguard --timeout=10m
kubectl -n wireguard get pod wireguard-0 -o wide
kubectl -n wireguard get services,pvc
```

The overlay creates a dedicated namespace, persistent storage for server and peer keys, and a UDP NodePort Service. It adds the `NET_ADMIN` capability needed to create the tunnel and forwarding rules; the container is not privileged. The namespace's Pod Security Admission label permits that capability in this isolated namespace. Keep unrelated workloads out of it. `LOG_CONFS` is disabled so generated client configurations and QR codes are not written to container logs.

If the pod cannot start the tunnel, check node kernel support, namespace permissions for `NET_ADMIN`, and whether UDP 31820 is blocked. The container also enables IPv4 forwarding inside its network namespace and applies a camera-network-only forwarding rule.

## 3. Forward the WireGuard UDP port

The preceding command shows the node hosting the pod. Because the Service uses `externalTrafficPolicy: Local` to preserve client endpoint addresses, forward traffic to that node's LAN address. Create an A/AAAA record for the public VPN name if you use DNS. On the router, forward **UDP 51820** from the WAN to the node at **UDP 31820**. Allow UDP 31820 through the node firewall if needed. Do not forward camera ports such as RTSP 554, HTTP 80, or HTTPS 443 from the WAN.

`SERVERPORT` is the public-side port and `nodePort` is the Kubernetes-side port. Keep the public endpoint, Service, and router rule consistent if you change either. `SERVERURL` must resolve to the public endpoint while clients are away from home.

The WireGuard PVC uses node-local storage and remains bound to its node. If that node is replaced, restore the VPN configuration and update the router's port-forward target.

## 4. Export each client configuration securely

After the pod is ready, retrieve the configuration for a peer. For example, to save the `phone` peer configuration locally:

```sh
kubectl exec -n wireguard wireguard-0 -- cat /config/peer_phone/peer_phone.conf > phone.conf
chmod 600 phone.conf
```

The file contains a private key. Treat it like a password: import it directly into the WireGuard app, keep it out of source control and chat, and remove temporary copies after import. Do not use `kubectl logs` to retrieve client configurations. Create a separate peer for every device.

## 5. Configure the clients

Install the official [WireGuard app](https://www.wireguard.com/install/) on each device. Transfer that device's `.conf` file using a trusted local method. In the app, import the configuration file, name the tunnel, and save it. On a phone, use **Import from file or archive**; on desktop, choose **Import tunnel(s) from file**. Enable the tunnel when away from the camera network.

The generated client configuration uses split tunneling: only the VPN endpoint and configured camera addresses use the VPN. Ordinary internet traffic stays on the client's normal connection. If the client's current network overlaps the camera network, that route may prevent camera access.

## 6. Verify the connection

On the server, inspect the peer handshake and transfer counters:

```sh
kubectl exec -n wireguard wireguard-0 -- wg show
```

From the connected client, open a camera's private IP in its web interface or use a viewer with the camera's RTSP path. ICMP may be disabled, so a failed ping alone does not prove the VPN is down. Camera access remains subject to each camera's own login credentials.

For a fuller acceptance check in a disposable K3s environment, use the [WireGuard network test procedure](../../tests/wireguard/acceptance.md). It checks access to an allowed camera-side target, denial outside the configured camera CIDR, and peer recovery after a pod restart.

## Add or revoke a device

To add a device, add a unique alphanumeric name to `PEERS` in `k8s/wireguard/overlays/local/settings.yaml`, apply the local overlay again, and wait for the StatefulSet rollout. Export the peer's config from `/config/peer_<name>/peer_<name>.conf`.

To revoke a device, remove its name from `PEERS`, apply the overlay, and wait for the rollout. Remove its saved config from the device. Keep a secure backup of the `/config` PVC; it holds the server key and all peer credentials. If you change `CAMERA_NETWORK`, update `ALLOWEDIPS`, apply the overlay, and restart the StatefulSet so the firewall and client routes are regenerated.

## Network model and limitations

WireGuard clients connect through the public UDP endpoint to the NodePort Service. The VPN pod forwards and source-NATs client traffic toward the configured camera network. The K3s node route and firewall must permit pod egress to that network. Different CNI plugins or custom egress policies may need additional routes or firewall configuration.

This setup does not provide public addresses for cameras, does not expose the ZoneMinder web interface through the VPN, and does not bypass carrier-grade NAT. It provides private camera-network access only from authenticated WireGuard peers.
