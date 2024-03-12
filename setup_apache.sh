#!/bin/bash

# Update package lists
sudo apt update

# Upgrade packages
sudo apt upgrade -y

# Install Apache
sudo apt install apache2 -y
# Install jq for parsing cloudflare response
sudo apt install jq 
#install putty tools for coverting ssh key files
sudo apt install putty-tools

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

# Create A record for main domain
echo "Creating A record for $domain_name"
read -p "Enter the IP address for $domain_name: " server_ip
curl -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
     -H "Authorization: Bearer $cloudflare_api_key" \
     -H "Content-Type: application/json" \
     --data '{"type": "A", "name": "'"$domain_name"'", "content": "'"$server_ip"'", "proxied": false}'

# Create wildcard CNAME record for main domain
echo "Creating wildcard CNAME record for $domain_name"
curl -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
     -H "Authorization: Bearer $cloudflare_api_key" \
     -H "Content-Type: application/json" \
     --data '{"type": "CNAME", "name": "'"$domain_name"'", "content": "'"$domain_name"'", "proxied": true}'

# Ask the user for subdomains
read -p "Enter subdomain names (comma-separated): " subdomain_names
IFS=',' read -ra subdomain_array <<< "$subdomain_names"
for subdomain in "${subdomain_array[@]}"; do
    # Create A record for subdomain
    echo "Creating A record for $subdomain.$domain_name"
    read -p "Enter the IP address for $subdomain.$domain_name: " server_ip
    curl -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
         -H "Authorization: Bearer $cloudflare_api_key" \
         -H "Content-Type: application/json" \
         --data '{"type": "A", "name": "'"$subdomain.$domain_name"'", "content": "'"$server_ip"'", "proxied": false}'

    # Create wildcard CNAME record for subdomain
    echo "Creating wildcard CNAME record for $subdomain.$domain_name"
    curl -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
         -H "Authorization: Bearer $cloudflare_api_key" \
         -H "Content-Type: application/json" \
         --data '{"type": "CNAME", "name": "'"$subdomain.$domain_name"'", "content": "'"$domain_name"'", "proxied": true}'
done

echo "Main domain and subdomains DNS records created."

# Ask the user for SSH details
echo "Choose an SSH username:"
echo "1. root"
echo "2. ubuntu"
echo "3. Custom username"
read -p "Enter the number corresponding to your choice: " ssh_choice

case "$ssh_choice" in
    1)
        ssh_username="root"
        ;;
    2)
        ssh_username="ubuntu"
        ;;
    3)
        read -p "Enter a custom username: " ssh_username
        ;;
    *)
        echo "Invalid choice. Using default username 'ubuntu'."
        ssh_username="ubuntu"
        ;;
esac

read -p "Enter the server IP address: " server_ip
read -p "Enter the path to your SSH key file (e.g., /path/to/key.pem or /path/to/key.ppk): " ssh_key_file

# Convert .ppk to .pem if needed
if [[ "$ssh_key_file" == *.ppk ]]; then
    puttygen "$ssh_key_file" -O private-openssh -o "${ssh_key_file%.ppk}.pem"
    ssh_key_file="${ssh_key_file%.ppk}.pem"
fi

# SFTP the key file to the server
sftp "$ssh_username@$server_ip" <<EOF
put "$ssh_key_file"
EOF

# Set correct permissions for the key file
ssh "$ssh_username@$server_ip" "chmod 600 $ssh_key_file"

# Ask the user for the path to the website zip file
read -p "Enter the path to your website zip file (e.g., /path/to/website.zip): " website_zip_file

# Use scp to upload the website zip file to the server
scp "$website_zip_file" "$ssh_username@$server_ip:/var/www/html/"

# SSH into the server and unzip the website files
ssh "$ssh_username@$server_ip" "unzip /var/www/html/$(basename $website_zip_file) -d /var/www/html/"

# Clean up
sudo apt autoremove -y
