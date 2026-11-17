#!/usr/bin/env bash
set -euo pipefail

SATELLITE_IP="${1:?Usage: $0 <current-rbs850-ip> [new-lan-ip/cidr]}"
NEW_LAN_IP="${2:-192.168.1.1/24}"

echo "[*] Converting RBS850 at ${SATELLITE_IP} into standalone router (Port 1 = WAN, Ports 2-4 = LAN @ ${NEW_LAN_IP})..."

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@${SATELLITE_IP}" "
  sed -i '/netgear,rbs850)/,+2 s/ucidef_set_interface_lan \"lan1 lan2 lan3 lan4\" \"dhcp\"/ucidef_set_interfaces_lan_wan \"lan2 lan3 lan4\" \"lan1\"/' /etc/board.d/02_network

  uci del network.@device[0].ports
  uci add_list network.@device[0].ports='lan2'
  uci add_list network.@device[0].ports='lan3'
  uci add_list network.@device[0].ports='lan4'

  uci delete network.lan6 2>/dev/null || true
  uci set network.lan.proto='static'
  uci del network.lan.ipaddr 2>/dev/null || true
  uci add_list network.lan.ipaddr='${NEW_LAN_IP}'
  uci set network.lan.ip6assign='60'

  uci set network.wan=interface
  uci set network.wan.device='lan1'
  uci set network.wan.proto='dhcp'

  uci set network.wan6=interface
  uci set network.wan6.device='lan1'
  uci set network.wan6.proto='dhcpv6'

  uci set dhcp.lan.ra='server'
  uci set dhcp.lan.dhcpv4='server'
  uci set dhcp.lan.dhcpv6='server'

  uci commit network
  uci commit dhcp
  echo 'CONFIG_APPLIED_OK'
  (sleep 1; /etc/init.d/network restart; /etc/init.d/dnsmasq restart; /etc/init.d/odhcpd restart) </dev/null >/dev/null 2>&1 &
"

echo "[+] Conversion complete! Unplug any LAN-to-LAN cable to another 192.168.1.1 router and connect to Ports 2-4."
