# Apache Setup and Cloudflare DNS Configuration Script

This Bash script automates the process of setting up an Apache server and configuring DNS records on Cloudflare for a domain and its subdomains.

## Prerequisites

- A Linux system with `sudo` privileges.
- `curl` and `jq` installed on your system.
- A Cloudflare account with the domain added.

## Usage

1. Open a terminal.
2. bash -c "$(curl -fsSL https://raw.githubusercontent.com/Xcertik-Realist/setup_apache/main/setup_apache.sh)"
3. When prompted, enter your domain name.
4. The script will install Apache and php configure a virtual host for your domain.
5. Next, enter your Cloudflare API key when prompted.
6. The script will fetch the Zone ID for your domain from Cloudflare.
7. Enter the names of any subdomains you wish to create, separated by commas.
8. For each subdomain, enter the IP address when prompted.
9. The script will create A records for each subdomain and a wildcard CNAME record pointing to your domain.
10. Finally, the script will clean up any unnecessary packages.

After running this script, your Apache server will be set up and your domain and subdomains will be configured on Cloudflare.

**Note:** This script should be run on the server where you want to install Apache.




