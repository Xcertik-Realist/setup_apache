#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Define emojis
EMOJIS=("🚀" "💻" "🎉" "👍" "🔥")

# Update package lists
echo -e "${RED}${EMOJIS[0]} Updating package lists...${RESET}"
sudo apt update

# Upgrade packages
echo -e "${GREEN}${EMOJIS[1]} Upgrading packages...${RESET}"
sudo apt upgrade -y

# Install Apache
echo -e "${YELLOW}${EMOJIS[2]} Installing Apache...${RESET}"
sudo apt install apache2 -y

# Install PHP
echo -e "${BLUE}${EMOJIS[3]} Installing PHP...${RESET}"
sudo apt install php libapache2-mod-php -y

# Install jq for parsing cloudflare response
echo -e "${MAGENTA}${EMOJIS[4]} Installing jq...${RESET}"
sudo apt install jq -y

# Install putty tools for converting ssh key files
echo -e "${CYAN}${EMOJIS[0]} Installing putty tools...${RESET}"
sudo apt install putty-tools -y

# Ask the user for the domain name
read -p "Enter your domain name (e.g., example.com): " domain_name

# Create an Apache virtual host configuration
cat <<EOF | sudo tee /etc/apache2/sites-available/$domain_name.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    ServerName $domain_name
    DocumentRoot /var/www/html

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Enable the virtual host
sudo a2ensite $domain_name.conf

# Reload Apache
sudo systemctl reload apache2

# Add the domain to /etc/hosts
echo "127.0.0.1 $domain_name" | sudo tee -a /etc/hosts

# Inform the user
echo -e "${RED}${EMOJIS[1]} Apache installed and configured for domain: $domain_name"
echo -e "${GREEN}${EMOJIS[2]} You can access your website at http://$domain_name/"

# Ask the user for Cloudflare API key
read -p "Enter your Cloudflare API key: " cloudflare_api_key

# Fetch Zone ID via Cloudflare API
zone_id=$(curl -sX GET "https://api.cloudflare.com/client/v4/zones" \
     -H "Authorization: Bearer $cloudflare_api_key" \
     -H "Content-Type: application/json" | jq -r '.result[0].id')

# Use the retrieved Zone ID for further operations
echo -e "${YELLOW}${EMOJIS[3]} Zone ID for $domain_name: $zone_id"

# Create A record for main domain
echo -e "${BLUE}${EMOJIS[4]} Creating A record for $domain_name"
read -p "Enter the IP address for $domain_name: " server_ip
curl -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
     -H "Authorization: Bearer $cloudflare_api_key" \
     -H "Content-Type: application/json" \
     --data '{"type": "A", "name": "'"$domain_name"'", "content": "'"$server_ip"'", "proxied": false}'

# Create wildcard CNAME record for main domain
echo -e "${MAGENTA}${EMOJIS[0]} Creating wildcard CNAME record for $domain_name"
curl -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
     -H "Authorization: Bearer $cloudflare_api_key" \
     -H "Content-Type: application/json" \
     --data '{"type": "CNAME", "name": "'"$domain_name"'", "content": "'"$domain_name"'", "proxied": true}'

# Ask the user for subdomains
read -p "Enter subdomain names (comma-separated): " subdomain_names
IFS=',' read -ra subdomain_array <<< "$subdomain_names"
for subdomain in "${subdomain_array[@]}"; do
    # Create A record for subdomain
    echo -e "${CYAN}${EMOJIS[1]} Creating A record for $subdomain.$domain_name"
    read -p "Enter the IP address for $subdomain.$domain_name: " server_ip
    curl -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
         -H "Authorization: Bearer $cloudflare_api_key" \
         -H "Content-Type: application/json" \
         --data '{"type": "A", "name": "'"$subdomain.$domain_name"'", "content": "'"$server_ip"'", "proxied": false}'

    # Create wildcard CNAME record for subdomain
    echo -e "${RED}${EMOJIS[2]} Creating wildcard CNAME record for $subdomain.$domain_name"
    curl -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
         -H "Authorization: Bearer $cloudflare_api_key" \
         -H "Content-Type: application/json" \
         --data '{"type": "CNAME", "name": "'"$subdomain.$domain_name"'", "content": "'"$domain_name"'", "proxied": true}'
done

echo -e "${GREEN}${EMOJIS[3]} Main domain and subdomains DNS records created."

# Clean up
echo -e "${YELLOW}${EMOJIS[4]} Cleaning up..."
sudo apt autoremove -y
