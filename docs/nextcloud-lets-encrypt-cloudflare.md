# NextCloud Let's Encrypt Certificate with Cloudflare DNS

## Overview

This procedure configures a Let's Encrypt SSL certificate for a NextCloud installation using DNS challenge validation via Cloudflare. This method works regardless of whether your NextCloud server is publicly accessible, making it ideal for internal-only deployments or those behind a firewall without ports 80/443 exposed.

The procedure uses Certbot with the Cloudflare DNS plugin to automatically create DNS TXT records for domain validation.

## Prerequisites

- NextCloud installed and running on a Debian-based system
- Apache web server (procedure can be adapted for nginx)
- A domain name with DNS managed by Cloudflare
- Cloudflare API token with appropriate permissions
- Root or sudo access to the server
- pfSense or other local DNS resolver (for internal resolution)

## Procedure

### Step 1: Configure Cloudflare DNS

1. Log into the Cloudflare dashboard
2. Select your domain
3. Navigate to **DNS** → **Records**
4. Create an **A record** for your NextCloud subdomain:
   - Type: A
   - Name: `cloud` (or your preferred subdomain)
   - IPv4 address: Your server's **private** IP address
   - Proxy status: **DNS only** (grey cloud, not orange)
   - TTL: 1 minute (for testing; increase later)

### Step 2: Create Cloudflare API Token

1. In Cloudflare, navigate to **My Profile** → **API Tokens**
2. Click **Create Token**
3. Click **Create Custom Token**
4. Configure the token:
   - Token name: `Certbot` or `NextCloud-LetsEncrypt`
   - Permissions:
     - Zone / Zone / Read
     - Zone / DNS / Edit
   - Zone Resources: Include → Specific zone → Select your domain
5. Click **Continue to summary** → **Create Token**
6. **Copy the token immediately**—it won't be shown again
7. Store the token securely (password manager recommended)

Also note your **Zone ID** from the domain's Overview page in Cloudflare.

### Step 3: Configure Local DNS Resolution (pfSense)

If your NextCloud server is only accessible internally, configure your local DNS resolver to resolve the domain to the internal IP.

#### pfSense DNS Resolver Configuration

1. Log into pfSense
2. Navigate to **System** → **General Setup**
3. Set your domain name if not already configured

4. Navigate to **Services** → **DNS Resolver** → **General Settings**
5. Enable DNS Resolver if not already active
6. Enable these options:
   - **Register DHCP leases in the DNS Resolver**
   - **Register DHCP static mappings in the DNS Resolver**

7. For NextCloud specifically, add a host override:
   - Navigate to **Services** → **DNS Resolver** → **Host Overrides**
   - Click **Add**
   - Host: `cloud` (your subdomain)
   - Domain: `yourdomain.com`
   - IP Address: Your NextCloud server's internal IP
   - Description: NextCloud server

8. Click **Save** and **Apply Changes**

### Step 4: Install Certbot and Dependencies

Update the package list:

```bash
sudo apt update
```

Install snapd (if not already installed):

```bash
sudo apt install snapd
```

Ensure snapd is up to date:

```bash
sudo snap install core
sudo snap refresh core
```

Remove any existing certbot packages to avoid conflicts:

```bash
sudo apt remove certbot
```

Install Certbot via snap:

```bash
sudo snap install --classic certbot
```

Create symlink for easy command access:

```bash
sudo ln -s /snap/bin/certbot /usr/bin/certbot
```

### Step 5: Install Cloudflare DNS Plugin

Trust the Certbot plugin installation:

```bash
sudo snap set certbot trust-plugin-with-root=ok
```

Install the Cloudflare plugin:

```bash
sudo snap install certbot-dns-cloudflare
```

### Step 6: Configure Cloudflare Credentials

Create the credentials directory:

```bash
mkdir -p ~/.secrets/certbot
```

Create the credentials file:

```bash
nano ~/.secrets/certbot/cloudflare.ini
```

Add your Cloudflare API token:

```ini
# Cloudflare API token used by Certbot
dns_cloudflare_api_token = your-api-token-here
```

Secure the credentials file:

```bash
chmod 600 ~/.secrets/certbot/cloudflare.ini
```

### Step 7: Obtain the Certificate

Request a certificate for your NextCloud domain:

```bash
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini \
  -d cloud.yourdomain.com
```

For a wildcard certificate (covers all subdomains):

```bash
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini \
  -d "*.yourdomain.com"
```

Certbot will:
1. Create a DNS TXT record via the Cloudflare API
2. Wait for DNS propagation
3. Validate domain ownership
4. Download and store the certificate
5. Clean up the DNS record

### Step 8: Configure Apache to Use the Certificate

Edit your NextCloud Apache virtual host configuration:

```bash
sudo nano /etc/apache2/sites-available/nextcloud.conf
```

Update or create the SSL virtual host:

```apache
<VirtualHost *:443>
    ServerName cloud.yourdomain.com
    DocumentRoot /var/www/nextcloud

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/cloud.yourdomain.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/cloud.yourdomain.com/privkey.pem

    <Directory /var/www/nextcloud>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/nextcloud_error.log
    CustomLog ${APACHE_LOG_DIR}/nextcloud_access.log combined
</VirtualHost>

<VirtualHost *:80>
    ServerName cloud.yourdomain.com
    Redirect permanent / https://cloud.yourdomain.com/
</VirtualHost>
```

Enable required Apache modules:

```bash
sudo a2enmod ssl
sudo a2enmod rewrite
sudo a2enmod headers
```

Enable the site if not already enabled:

```bash
sudo a2ensite nextcloud.conf
```

Test the configuration:

```bash
sudo apache2ctl configtest
```

Reload Apache:

```bash
sudo systemctl reload apache2
```

### Step 9: Update NextCloud Trusted Domains

Edit the NextCloud configuration:

```bash
sudo nano /var/www/nextcloud/config/config.php
```

Ensure your domain is in the trusted_domains array:

```php
'trusted_domains' =>
array (
  0 => 'localhost',
  1 => 'cloud.yourdomain.com',
),
```

### Step 10: Configure Automatic Certificate Renewal

Certbot installs a systemd timer for automatic renewal. Verify it's active:

```bash
sudo systemctl status certbot.timer
```

Test the renewal process:

```bash
sudo certbot renew --dry-run
```

The renewal process will automatically reload Apache when certificates are updated.

### Step 11: Configure Automatic Apache Reload on Renewal

Create a renewal hook to reload Apache after certificate renewal:

```bash
sudo nano /etc/letsencrypt/renewal-hooks/deploy/reload-apache.sh
```

Add the following content:

```bash
#!/bin/bash
systemctl reload apache2
```

Make it executable:

```bash
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-apache.sh
```

## Verification

### Test HTTPS Access

1. Open a browser and navigate to `https://cloud.yourdomain.com`
2. Verify no certificate warnings appear
3. Click the padlock icon to inspect the certificate:
   - Issuer should be "Let's Encrypt"
   - Valid for approximately 90 days

### Test Certificate Details via Command Line

```bash
echo | openssl s_client -servername cloud.yourdomain.com -connect cloud.yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates
```

### Test Renewal Process

```bash
sudo certbot renew --dry-run
```

This simulates renewal without making changes.

## Troubleshooting

**DNS validation fails:**
- Verify API token has correct permissions (Zone/DNS/Edit)
- Check that Zone ID is correct
- Wait a few minutes for DNS propagation and retry
- Verify the A record exists in Cloudflare

**Cannot resolve domain internally:**
- Check pfSense host override configuration
- Verify DNS Resolver is enabled and clients are using pfSense for DNS
- Test resolution: `nslookup cloud.yourdomain.com`

**Certificate obtained but Apache won't start:**
- Check certificate paths in Apache config match actual locations
- Verify certificate files exist: `ls -la /etc/letsencrypt/live/cloud.yourdomain.com/`
- Check Apache error logs: `sudo tail -f /var/log/apache2/error.log`

**Browser still shows certificate warning:**
- Clear browser cache or try incognito mode
- Verify you're accessing via the correct domain name
- Check that both certificate and key files are readable by Apache

**Renewal fails:**
- Check Cloudflare API token hasn't expired
- Verify credentials file permissions (should be 600)
- Check certbot logs: `sudo journalctl -u certbot`

**NextCloud shows "Access through untrusted domain":**
- Add the domain to trusted_domains in config.php
- Clear NextCloud cache if needed

## Notes

- Let's Encrypt certificates are valid for 90 days and should auto-renew around 30 days before expiration
- The DNS challenge method works even if your server isn't publicly accessible
- Keep your Cloudflare API token secure—it can modify your DNS records
- For multiple servers/services, consider using a wildcard certificate
- Cloudflare's proxy (orange cloud) must be disabled for internal-only services
- The certbot snap package updates automatically, keeping security patches current
