#!/usr/bin/env bash
set -euo pipefail

SATELLITE_IP="${1:-192.168.1.146}"
WIFI_IF="${2:-en0}"

echo "[*] Resolving downloads.openwrt.org via ${WIFI_IF}..."
WIFI_IP=$(ifconfig "$WIFI_IF" | awk '/inet / {print $2; exit}')
OPENWRT_IP=$(dig @1.1.1.1 -b "$WIFI_IP" downloads.openwrt.org +short | tail -n1)

if [[ -z "$OPENWRT_IP" ]]; then
  echo "[!] Could not resolve downloads.openwrt.org via ${WIFI_IF}"
  exit 1
fi
echo "[*] Resolved downloads.openwrt.org -> ${OPENWRT_IP}"

PROXY_SCRIPT=$(mktemp /tmp/openwrt_proxy.XXXXXX.py)
cat <<EOF > "$PROXY_SCRIPT"
import http.server
import subprocess

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        url = f"https://downloads.openwrt.org{self.path}"
        proc = subprocess.run(
            [
                "curl", "--interface", "${WIFI_IF}", "-4",
                "--resolve", "downloads.openwrt.org:443:${OPENWRT_IP}",
                "-sL", "-w", "\n%{http_code}", url
            ],
            capture_output=True
        )
        out = proc.stdout
        idx = out.rfind(b"\n")
        body = out[:idx] if idx != -1 else out
        code_str = out[idx+1:].decode("ascii", errors="ignore").strip() if idx != -1 else "500"
        code = int(code_str) if code_str.isdigit() else 502
        self.send_response(code)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass

if __name__ == "__main__":
    server = http.server.HTTPServer(("127.0.0.1", 8888), ProxyHandler)
    server.serve_forever()
EOF

python3 "$PROXY_SCRIPT" &
PROXY_PID=$!
trap 'kill $PROXY_PID 2>/dev/null || true; rm -f "$PROXY_SCRIPT"' EXIT
sleep 1

echo "[*] Installing LuCI on root@${SATELLITE_IP} over SSH reverse tunnel..."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -R 8888:127.0.0.1:8888 "root@${SATELLITE_IP}" '
  [ -f /tmp/distfeeds.list.bak ] || cp /etc/apk/repositories.d/distfeeds.list /tmp/distfeeds.list.bak
  sed -i "s|https://downloads.openwrt.org|http://127.0.0.1:8888|g" /etc/apk/repositories.d/distfeeds.list
  apk update && apk add luci
  mv /tmp/distfeeds.list.bak /etc/apk/repositories.d/distfeeds.list
  /etc/init.d/uhttpd status || /etc/init.d/uhttpd start
'

echo "[+] Done! LuCI is now accessible at http://${SATELLITE_IP}"
