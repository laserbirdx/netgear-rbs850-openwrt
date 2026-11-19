# Netgear Orbi RBS850 Satellite (AX6000) OpenWrt Guide & Router Conversion

![Netgear Orbi OpenWrt Banner](./assets/banner.jpg)

<p align="center">
  <a href="https://downloads.openwrt.org/snapshots/targets/qualcommax/ipq807x/"><img src="https://img.shields.io/badge/OpenWrt-SNAPSHOT%20%28qualcommax%2Fipq807x%29-blue" alt="OpenWrt Support" /></a>
  <a href="https://github.com/jclehner/nmrpflash"><img src="https://img.shields.io/badge/Verified%20On-macOS%20%28Apple%20Silicon%29-success" alt="Verified on macOS" /></a>
  <a href="https://github.com/laserbirdx/netgear-rbr850-openwrt"><img src="https://img.shields.io/badge/Companion%20Repo-Netgear%20RBR850%20Router-orange" alt="Companion Repo: RBR850" /></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT" /></a>
</p>

A complete, battle-tested guide for flashing mainline **OpenWrt** onto the **Netgear Orbi RBS850** Wi-Fi 6 Tri-Band Mesh Satellite (`RBK852` / `RBK853` / `RBK854` kits) using `nmrpflash`, installing the **LuCI** web interface, and optionally **converting any RBS850 Satellite into a full standalone OpenWrt Router** (using Port 1 as WAN and Ports 2–4 as LAN with a DHCP server).

Tested and verified on **macOS** (MacBook Air + USB Gigabit Ethernet adapter) across multiple RBS850 satellite units.

> 🔗 **Flashing the Main RBR850 Router First?**
> Check out our companion repository **[laserbirdx/netgear-rbr850-openwrt](https://github.com/laserbirdx/netgear-rbr850-openwrt)** for the **Netgear Orbi RBR850 Router** installation guide. We strongly recommend flashing the RBR850 first so it can act as the DHCP server for your RBS850 satellites on their first boot!

---

## 1. RBS850 (Satellite) vs. RBR850 (Router): Key Differences

While the **RBS850 Satellite** and **[RBR850 Router](https://github.com/laserbirdx/netgear-rbr850-openwrt)** share the same quad-core Qualcomm IPQ8074A SoC, 1 GiB DDR4 RAM, and 12-stream Tri-Band AX6000 radios, they differ in physical ports, NAND flash layout, and default OpenWrt network configuration:

| Feature | **Netgear RBS850 (Satellite)** *(This Repo)* | **[Netgear RBR850 (Router)](https://github.com/laserbirdx/netgear-rbr850-openwrt)** |
| :--- | :--- | :--- |
| **Board ID** | `U12H403T00_NETGEAR` | `U12H404T00_NETGEAR` |
| **SoC & RAM** | Qualcomm IPQ8074A (4x 2.2 GHz) + 1 GiB RAM | Qualcomm IPQ8074A (4x 2.2 GHz) + 1 GiB RAM |
| **Wi-Fi Radios** | Tri-Band AX6000 (QCN5024 + 2x QCN5054) | Tri-Band AX6000 (QCN5024 + 2x QCN5054) |
| **WAN Port** | **None natively** *(Port 1 `lan1` can be configured as WAN)* | **1x 2.5 GbE WAN** (`QCA8081` PHY on `uniphy1`) |
| **LAN Ports** | 4x 1 GbE (`lan1`–`lan4` via `QCA8075` PHY) | 4x 1 GbE (`lan1`–`lan4` via `QCA8075` PHY) |
| **NAND Flash** | 256 MiB / 512 MiB (rootfs `@ 0x3e80000`) | 512 MiB (`W29N04GZ`, rootfs `@ 0x11c00000`) |
| **Default OpenWrt Role** | **Bridged DHCP Client** (`proto 'dhcp'` on `br-lan`) | **Router + DHCP Server** (`192.168.1.1/24`) |
| **First-Boot Access** | Waits for an upstream DHCP server to assign an IP | Immediately reachable at `192.168.1.1` |

---

## 2. Detailed Hardware Specifications (RBS850)

| Component | Specification |
| :--- | :--- |
| **Model** | Netgear Orbi RBS850 (Satellite) |
| **Board ID** | `U12H403T00_NETGEAR` |
| **OpenWrt Target** | `qualcommax/ipq807x` (`aarch64_cortex-a53`) |
| **SoC** | Qualcomm IPQ8074A (Quad-Core ARM Cortex-A53 @ 2.2 GHz) |
| **RAM** | 1 GiB DDR4 (2x Samsung `4A4G165WE-BCRC`) |
| **Flash** | 256 MiB NAND (Winbond `W29N02GZ`) / 512 MiB NAND |
| **Wi-Fi 2.4 GHz** | Qualcomm QCN5024 4x4:4 802.11b/g/n/ax (`ath11k`, BDF `Netgear-RBK850`) |
| **Wi-Fi 5 GHz Low** | Qualcomm QCN5054 4x4:4 802.11a/n/ac/ax (Channels 36–64, 5180–5320 MHz) |
| **Wi-Fi 5 GHz High** | Qualcomm QCN5054 4x4:4 802.11a/n/ac/ax (Channels 100–140, 5500–5700 MHz) |
| **Ethernet Ports** | 4x 1 GbE RJ45 (`lan1`–`lan4` via Qualcomm QCA8075 PHY & `qca-ppe`/`qca-edma` DSA) |
| **Serial / UART** | 3.3V TTL `115200-8-N-1` (`Bottom <- RX, TX, GND, 3.3V (do not connect) -> Top`) |

---

## 3. Firmware Downloads

Official support was merged into OpenWrt mainline via [PR #24906](https://github.com/openwrt/openwrt/pull/24906).

* **Initial Installation Image (`factory.chk` for `nmrpflash`):**
  [`openwrt-qualcommax-ipq807x-netgear_rbs850-squashfs-factory.chk`](https://downloads.openwrt.org/snapshots/targets/qualcommax/ipq807x/openwrt-qualcommax-ipq807x-netgear_rbs850-squashfs-factory.chk)
* **Upgrade Image (`sysupgrade.bin` for upgrading from within OpenWrt):**
  [`openwrt-qualcommax-ipq807x-netgear_rbs850-squashfs-sysupgrade.bin`](https://downloads.openwrt.org/snapshots/targets/qualcommax/ipq807x/openwrt-qualcommax-ipq807x-netgear_rbs850-squashfs-sysupgrade.bin)
* **OpenWrt Firmware Selector (Custom Builds with Pre-Installed LuCI):**
  [https://firmware-selector.openwrt.org/?version=SNAPSHOT&target=qualcommax%2Fipq807x&id=netgear_rbs850](https://firmware-selector.openwrt.org/?version=SNAPSHOT&target=qualcommax%2Fipq807x&id=netgear_rbs850)

---

## 4. Step-by-Step Flashing Instructions (Verified on macOS & Linux)

The OpenWrt `factory.chk` image embeds a U-Boot script (`netgear_rbx750_850.bootscript`) executed automatically during NMRP flashing that writes OpenWrt to the RBS850 NAND partition and updates `bootcmd` so unsigned OpenWrt images boot without opening the case.

1. Install **[nmrpflash](https://github.com/jclehner/nmrpflash)** on your Mac or PC.
2. Download [`openwrt-qualcommax-ipq807x-netgear_rbs850-squashfs-factory.chk`](https://downloads.openwrt.org/snapshots/targets/qualcommax/ipq807x/openwrt-qualcommax-ipq807x-netgear_rbs850-squashfs-factory.chk).
3. **Power off** (unplug) the RBS850 and connect an Ethernet cable from your computer to any port (`1`–`4`) on the RBS850.
4. Check your Ethernet interface name (`./nmrpflash -L`, e.g., `en10` on macOS) and start `nmrpflash`:
   ```bash
   sudo ./nmrpflash -i en10 -f openwrt-qualcommax-ipq807x-netgear_rbs850-squashfs-factory.chk
   ```
5. **Plug in the power cable** on the RBS850.
6. Below is the exact terminal output from a successful flash on **macOS**:
   ```text
   ok-Air Downloads % sudo ./nmrpflash -i en10 -f openwrt-qualcommax-ipq807x-netgear_rbs850-squashfs-factory.chk
   Advertising NMRP server on en10 ... - 
   Received configuration request from xx:xx:xx:xx:xx:xx.
   Sending configuration: 10.164.183.253/24.
   Received upload request: filename 'firmware'.
   Uploading openwrt-qualcommax-ipq807x-netgear_rbs850-squashfs-factory.chk ...  OK
   Waiting for remote to respond.
   Received upload request: filename 'firmware'.
   Uploading openwrt-qualcommax-ipq807x-netgear_rbs850-squashfs-factory.chk ... Connection closed by remote while waiting for ACK(0).
   Received late close request.
   ```
   > **Note:** `Connection closed by remote while waiting for ACK(0)` followed by `Received late close request` on the second upload request is **completely normal**—it means the RBS850 finished erasing/writing NAND and closed the NMRP session.

7. Once the rear Power LED **blinks amber/orange**, **unplug the power cord and plug it back in**.

---

## 5. ⚠️ Important: First Boot IP & DHCP Client Behavior

Unlike the [RBR850 Router](https://github.com/laserbirdx/netgear-rbr850-openwrt), the **RBS850 Satellite** is configured in OpenWrt (`/etc/board.d/02_network`) as a **DHCP Client** by default:
```sh
netgear,rbs850)
    ucidef_set_interface_lan "lan1 lan2 lan3 lan4" "dhcp"
    ;;
```
This means:
* **The RBS850 will NOT hand out IP addresses to your computer on first boot, nor does it listen on `192.168.1.1`.**
* Instead, all 4 ports (`lan1`–`lan4`) are bridged (`br-lan`) and wait to receive an IP address from an upstream DHCP server.

### How to Connect on First Boot (30-Second Method):
1. Plug an Ethernet cable from your **[RBR850 Router](https://github.com/laserbirdx/netgear-rbr850-openwrt)** (or any LAN router) into **any port on the RBS850**.
2. Plug your computer's Ethernet cable into **another port on the RBS850** (since all 4 ports act as a switch).
3. Both your computer and the RBS850 will receive `192.168.1.x` IP addresses from the RBR850!
4. Find the RBS850's IP in your router's DHCP leases (e.g., `192.168.1.146`, `192.168.1.117`, or `192.168.1.132`) and connect via SSH:
   ```bash
   ssh root@192.168.1.146
   ```

---

## 6. Installing the LuCI Web Interface

### Option A: Upstream Router Has Internet Access
```bash
ssh root@192.168.1.146 "apk update && apk add luci"
```

### Option B: Offline Setup on macOS (Using Your Mac's Wi-Fi via SSH Reverse Tunnel)
If your test network has no WAN internet connection, use the included script to tunnel `apk` repositories over SSH from your Mac's Wi-Fi interface (`en0`):
```bash
./scripts/install-luci-offline.sh 192.168.1.146 en0
```

---

## 7. Converting RBS850 into a Full Standalone Router (Port 1 = WAN, DHCP Enabled)

Because the RBS850 has the exact same quad-core IPQ8074A SoC, 1 GiB RAM, `qca-edma`/`qca-ppe` hardware switch, and Tri-Band AX6000 radios as the RBR850, you can easily turn any RBS850 satellite into a **standalone router**:
* **Port 1 (`lan1`)** becomes the **WAN** port (`dhcp` + `dhcpv6`).
* **Ports 2, 3, 4 (`lan2`, `lan3`, `lan4`)** remain bridged as **LAN** (`br-lan`).
* **LAN IP** is set to `192.168.1.1/24` with **DHCPv4 & DHCPv6 server enabled**.

### Automated Conversion Script
Run the included script against your RBS850's current DHCP IP:
```bash
./scripts/convert-to-router.sh 192.168.1.146
```

### Manual UCI Commands (Run via SSH on RBS850)
```bash
# Persist layout in /etc/board.d/02_network
sed -i '/netgear,rbs850)/,+2 s/ucidef_set_interface_lan "lan1 lan2 lan3 lan4" "dhcp"/ucidef_set_interfaces_lan_wan "lan2 lan3 lan4" "lan1"/' /etc/board.d/02_network

# Bridge only lan2, lan3, lan4 into br-lan
uci del network.@device[0].ports
uci add_list network.@device[0].ports="lan2"
uci add_list network.@device[0].ports="lan3"
uci add_list network.@device[0].ports="lan4"

# Configure static LAN IP 192.168.1.1/24
uci delete network.lan6 2>/dev/null || true
uci set network.lan.proto="static"
uci del network.lan.ipaddr 2>/dev/null || true
uci add_list network.lan.ipaddr="192.168.1.1/24"
uci set network.lan.ip6assign="60"

# Configure Port 1 (lan1) as WAN / WAN6
uci set network.wan=interface
uci set network.wan.device="lan1"
uci set network.wan.proto="dhcp"
uci set network.wan6=interface
uci set network.wan6.device="lan1"
uci set network.wan6.proto="dhcpv6"

# Enable DHCPv4, DHCPv6, and Router Advertisements on LAN
uci set dhcp.lan.ra="server"
uci set dhcp.lan.dhcpv4="server"
uci set dhcp.lan.dhcpv6="server"

uci commit network
uci commit dhcp
/etc/init.d/network restart && /etc/init.d/dnsmasq restart && /etc/init.d/odhcpd restart
```
> **Note:** Once converted, unplug the LAN-to-LAN cable from your main router so the two `192.168.1.1` DHCP servers do not conflict. Connect your upstream internet cable to **Port 1** and your LAN devices to **Ports 2–4**.

---

## 8. Reverting to Netgear Stock Firmware *(Not Tested)*

> ⚠️ **UNVERIFIED / NOT TESTED:** Reverting from OpenWrt back to Netgear stock firmware has **NOT been personally tested** by us. The steps below are taken from the upstream OpenWrt PR commit notes—proceed at your own risk!
>
> ⚠️ **CRITICAL WARNING:** Before flashing stock Netgear firmware, you **MUST** restore `bootcmd` to `bootipq` from within OpenWrt, otherwise the bootloader will fail signature verification and get stuck in a red-LED recovery loop.

1. Run inside OpenWrt via SSH:
   ```bash
   fw_setenv bootcmd bootipq
   ```
2. Flash the stock Netgear `RBS850-V...img` file using `nmrpflash`:
   ```bash
   sudo ./nmrpflash -i en10 -f RBS850-V7.2.6.31.img
   ```

---

## Related Projects & References
* Companion Router Guide: **[laserbirdx/netgear-rbr850-openwrt](https://github.com/laserbirdx/netgear-rbr850-openwrt)** (Netgear Orbi RBR850 Router OpenWrt Installation & Configuration Guide)
* Device support authored by **Michael Lotz** (`@mmlr`) and adapted/merged by **Piotr Szczepanik** (`@piter75`) in [openwrt/openwrt#24906](https://github.com/openwrt/openwrt/pull/24906).
* [OpenWrt Forum Thread: Anyone working on Netgear RBR850?](https://forum.openwrt.org/t/anyone-working-on-netgear-rbr850/127999)

## License
Released under the [MIT License](./LICENSE).
