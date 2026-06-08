# Bitcoin LXD Sandbox — Network Isolation Analysis

**Author:** Ioannis Alexander Konstas — IT Solutions USA

Analysis of a Bitcoin node running inside an LXD container (`bitcoin-sandbox`) on Ubuntu 24.04, confirming correct network isolation from the host LAN.

---

## Container Status

```
lxc list
+-----------------+---------+--------------------+-----------------------------------------------+
|      NAME       |  STATE  |        IPV4        |                     IPV6                      |
+-----------------+---------+--------------------+-----------------------------------------------+
| bitcoin-sandbox | RUNNING | 10.76.85.28 (eth0) | fd42:378b:51f4:dbd1:216:3eff:fea5:503c (eth0)|
+-----------------+---------+--------------------+-----------------------------------------------+
```

- Container is RUNNING with a private internal IP (`10.76.85.28`)
- IPv6 is a Unique Local Address (ULA) — not publicly routable

---

## Listening Ports

```
lxc exec bitcoin-sandbox -- ss -tuln
```

| Port | Protocol | Service |
|---|---|---|
| 8333 | TCP (0.0.0.0 + [::]) | Bitcoin P2P — accepts inbound connections |
| 8332 | TCP (127.0.0.1 only) | Bitcoin RPC — localhost only, not exposed externally |
| 8334 | TCP (127.0.0.1 only) | ZMQ / internal Bitcoin service |
| 22 | TCP | SSH — container management |
| 53 | UDP/TCP | Local DNS resolver |

**Key finding:** RPC (8332) is bound to `127.0.0.1` only — it cannot be reached from outside the container.

---

## LAN Isolation Test

```bash
lxc exec bitcoin-sandbox -- ping -c 3 192.168.1.1
# Result: 100% packet loss
```

The container **cannot reach your internal LAN**. Isolation is confirmed.

---

## LXD Bridge Configuration

```yaml
name: lxdbr0
config:
  ipv4.address: 10.76.85.1/24
  ipv4.nat: "true"
  ipv6.address: fd42:378b:51f4:dbd1::1/64
  ipv6.nat: "true"
```

- NAT is enabled on both IPv4 and IPv6
- The container **can reach the Internet** (Bitcoin P2P needs outbound connectivity)
- The container **cannot reach your private LAN** (192.168.x.x)
- Host machine routes traffic via `lxdbr0` bridge — full control

---

## Security Assessment

| Check | Result |
|---|---|
| Container isolated from LAN | ✅ Confirmed (100% packet loss to 192.168.1.1) |
| RPC port externally accessible | ✅ No — bound to 127.0.0.1 only |
| Only expected ports open | ✅ 8333 (P2P), 8332 (RPC local), 22 (SSH) |
| Internet access for P2P | ✅ Enabled via NAT |
| IPv6 ULA (not publicly routable) | ✅ fd42::/7 prefix — unique local only |

---

## Useful Commands

```bash
# Enter the container
lxc exec bitcoin-sandbox -- bash

# Check container network
lxc exec bitcoin-sandbox -- ip addr show eth0

# Monitor open ports
lxc exec bitcoin-sandbox -- ss -tuln

# Check Bitcoin node status from host
lxc exec bitcoin-sandbox -- bitcoin-cli getblockchaininfo

# Stop the container
lxc stop bitcoin-sandbox

# Start the container
lxc start bitcoin-sandbox
```

---

## Conclusion

The sandbox is operating correctly. Bitcoin P2P traffic flows through NAT to the Internet while the internal LAN remains fully protected. All RPC endpoints are localhost-only. The container cannot be used as a pivot point to reach internal network devices.

---

*© Ioannis Alexander Konstas — IT Solutions USA*
