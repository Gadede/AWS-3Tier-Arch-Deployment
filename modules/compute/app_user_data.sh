#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y python3

# Minimal app-tier service. Responds 200 on /health for the internal ALB
# health check and echoes a response on any other path.
mkdir -p /opt/app
cat > /opt/app/server.py <<'PY'
from http.server import BaseHTTPRequestHandler, HTTPServer
import os

PORT = int(os.environ.get("APP_PORT", "8080"))


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")
        else:
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"app tier response")


HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
PY

cat > /etc/systemd/system/app.service <<SERVICE
[Unit]
Description=App Tier Service
After=network.target

[Service]
Environment=APP_PORT=${app_port}
Environment=DB_ENDPOINT=${db_endpoint}
Environment=DB_PORT=${db_port}
Environment=DB_NAME=${db_name}
ExecStart=/usr/bin/python3 /opt/app/server.py
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable app.service
systemctl start app.service