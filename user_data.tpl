#!/bin/bash
# Enable error logging
exec > >(tee -i /var/log/user_data.log)
exec 2>&1
set -x

# Update and install Docker
apt update
apt upgrade -y
apt install -y docker.io
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create Nextcloud directory and docker-compose file
mkdir -p /home/ubuntu/nextcloud
cat << EOT > /home/ubuntu/nextcloud/docker-compose.yml
version: '3'
services:
  db:
    image: mariadb:10.6
    command: --transaction-isolation=READ-COMMITTED --binlog-format=ROW
    restart: always
    volumes:
      - db:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=${mysql_root_password}
      - MYSQL_PASSWORD=${mysql_password}
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
  app:
    image: nextcloud:${nextcloud_version}
    restart: always
    volumes:
      - nextcloud:/var/www/html
    environment:
      - MYSQL_PASSWORD=${mysql_password}
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_HOST=db
      - NEXTCLOUD_ADMIN_USER=admin
      - NEXTCLOUD_ADMIN_PASSWORD=your_secure_password
      - NEXTCLOUD_TRUSTED_DOMAINS=${subdomain}.${domain_name}
  web:
    image: nginx:alpine
    restart: always
    ports:
      - 80:80
      - 443:443
    volumes:
      - /home/ubuntu/nextcloud/nextcloud.conf:/etc/nginx/conf.d/default.conf
      - /etc/letsencrypt:/etc/letsencrypt:ro
    depends_on:
      - app
volumes:
  nextcloud:
  db:
EOT

# Create the Nginx configuration file
cat << EOT > /home/ubuntu/nextcloud/nextcloud.conf
server {
    listen 80;
    listen [::]:80;
    server_name ${subdomain}.${domain_name};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${subdomain}.${domain_name};

    ssl_certificate /etc/letsencrypt/live/${subdomain}.${domain_name}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${subdomain}.${domain_name}/privkey.pem;

    location / {
        proxy_pass http://app:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOT

# Start Nextcloud
cd /home/ubuntu/nextcloud
docker-compose up -d

# Install Certbot and obtain SSL certificate
snap install core
snap refresh core
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

# Stop Nextcloud container
docker-compose stop web

# Obtain and install SSL certificate
certbot certonly --standalone -d ${subdomain}.${domain_name} --non-interactive --agree-tos --email ${email}

# Restart Nextcloud with the new configuration
docker-compose up -d

# Wait for Nextcloud to be ready
sleep 30

# Create the guest user
docker exec -u www-data $(docker ps -qf "name=app") php occ user:add --password-from-env --display-name="Guest User" guest --password your_guest_password

# Create update script
cat << EOT > /home/ubuntu/nextcloud/update-nextcloud.sh
#!/bin/bash
cd /home/ubuntu/nextcloud
docker-compose pull
docker-compose up -d
docker image prune -f
certbot renew --quiet
docker-compose restart web
EOT
chmod +x /home/ubuntu/nextcloud/update-nextcloud.sh

# Set up cron job for updates
(crontab -l 2>/dev/null; echo "0 2 * * 0 /home/ubuntu/nextcloud/update-nextcloud.sh") | crontab -
