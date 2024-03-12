#!/bin/bash

# Update package lists
sudo apt update

# Upgrade packages
sudo apt upgrade -y

# Install Apache
sudo apt install apache2 -y

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
echo "Apache installed and configured for domain: $domain_name"
echo "You can access your website at http://$domain_name/"

# Ask the user for Cloudflare API key
read -p "Enter your Cloudflare API key: " cloudflare_api_key

# Fetch Zone ID via Cloudflare API
zone_id=$(curl -sX GET "https://api.cloudflare.com/client/v4/zones" \
     -H "Authorization: Bearer $cloudflare_api_key" \
     -H "Content-Type: application/json" | jq -r '.result[0].id')

# Use the retrieved Zone ID for further operations
echo "Zone ID for $domain_name: $zone_id"

# Ask the user for subdomains
read -p "Enter subdomain names (comma-separated): " subdomain_names
IFS=',' read -ra subdomain_array <<< "$subdomain_names"
for subdomain in "${subdomain_array[@]}"; do
    # Create A record for subdomain
    echo "Creating A record for $subdomain"
    # Ask the user for the server IP address
    read -p "Enter the IP address for $subdomain: " server_ip
    curl -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
         -H "Authorization: Bearer $cloudflare_api_key" \
         -H "Content-Type: application/json" \
         --data '{"type": "A", "name": "'"$subdomain"'", "content": "'"$server_ip"'", "proxied": false}'

    # Create wildcard CNAME record for subdomain
    echo "Creating wildcard CNAME record for $subdomain"
    curl -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
         -H "Authorization: Bearer $cloudflare_api_key" \
         -H "Content-Type: application/json" \
         --data '{"type": "CNAME", "name": "'"$subdomain"'", "content": "'"$domain_name"'", "proxied": true}'
done

echo "Subdomains and DNS records created."

# Clean up
sudo apt autoremove -y

