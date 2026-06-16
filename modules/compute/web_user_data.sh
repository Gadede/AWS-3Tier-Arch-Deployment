#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx

# Landing page so the ALB health check on "/" returns HTTP 200.
cat > /var/www/html/index.html <<'HTML'
<!doctype html>
<html>
  <head><title>Web Tier</title></head>
  <body><h1>Web tier is healthy</h1></body>
</html>
HTML

# The internal ALB (app tier) endpoint is made available to the app code:
#   http://${internal_alb_dns}:${app_port}
echo "APP_ENDPOINT=http://${internal_alb_dns}:${app_port}" > /etc/web-tier.env

systemctl enable nginx
systemctl start nginx