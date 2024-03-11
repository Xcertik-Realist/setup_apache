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

# Clean up
sudo apt autoremove -y
