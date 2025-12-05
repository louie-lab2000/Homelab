# Synology DSM Let's Encrypt Certificate with DNS Challenge

## Overview

This procedure configures a Let's Encrypt SSL certificate on a Synology NAS using DNS challenge validation. This method is ideal when your Synology device is not accessible from the public internet on ports 80/443, which is the typical homelab scenario.

The DNS challenge works by proving domain ownership through DNS TXT records rather than HTTP validation. The acme.sh script automates this process by using your DNS provider's API to create the required validation records.

## Prerequisites

- Synology NAS running DSM 7.x or later
- A domain name registered with a DNS provider that has API access (Cloudflare, GoDaddy, Route53, etc.)
- API credentials from your DNS provider
- SSH access enabled on the Synology
- Basic familiarity with command-line operations

## Procedure

### Step 1: Obtain DNS Provider API Credentials

#### For Cloudflare

1. Log into the Cloudflare dashboard
2. Navigate to your domain's Overview page
3. Note your **Zone ID** from the right sidebar
4. Click **Get your API token**
5. Create a new token with the following permissions:
   - Zone / Zone / Read
   - Zone / DNS / Edit
6. Set Zone Resources to your specific domain
7. Create the token and copy it immediately (it won't be shown again)

#### For GoDaddy

1. Log into the GoDaddy Developer Portal
2. Generate a new Production API key
3. Copy both the Key and Secret before closing the window

### Step 2: Create a Certificate Admin User on Synology

1. Log into DSM web interface
2. Open **Control Panel** → **User & Group**
3. Click **Create** and configure the new user:
   - Username: `certadmin` (or your preference)
   - Password: Use a strong password (avoid the `$` character as it can cause script issues)
4. Assign group memberships:
   - **administrators** (required for SSH access)
   - **http** (required for certificate deployment)
5. Set folder permissions:
   - Read/Write access to **homes** folder only
6. Deny access to all applications (this is a service account)

### Step 3: Enable SSH on Synology

1. Open **Control Panel** → **Terminal & SNMP**
2. Check **Enable SSH service**
3. Click **Apply**

### Step 4: Download and Install acme.sh

SSH into the Synology as the certadmin user:

```bash
ssh certadmin@your-synology-ip
```

Download and extract the acme.sh script:

```bash
wget -O /tmp/acme.sh.zip https://github.com/acmesh-official/acme.sh/archive/master.zip
sudo 7z x -o/usr/local/share /tmp/acme.sh.zip
sudo mv /usr/local/share/acme.sh-master/ /usr/local/share/acme.sh
sudo chown -R certadmin /usr/local/share/acme.sh/
cd /usr/local/share/acme.sh
```

### Step 5: Configure Environment Variables

Set the required environment variables for your DNS provider and Synology credentials.

#### For Cloudflare

```bash
export CF_Token="your-cloudflare-api-token"
export CF_Zone_ID="your-zone-id"
export SYNO_USERNAME="certadmin"
export SYNO_PASSWORD="your-certadmin-password"
export SYNO_CERTIFICATE="Let's Encrypt"
export SYNO_CREATE=1
```

#### For GoDaddy

```bash
export GD_Key="your-godaddy-key"
export GD_Secret="your-godaddy-secret"
export SYNO_USERNAME="certadmin"
export SYNO_PASSWORD="your-certadmin-password"
export SYNO_CERTIFICATE="Let's Encrypt"
export SYNO_CREATE=1
```

### Step 6: Issue the Certificate

Request the certificate using the appropriate DNS plugin.

#### For Cloudflare (wildcard certificate)

```bash
./acme.sh --server letsencrypt --issue -d "*.yourdomain.com" --dns dns_cf --home $PWD
```

#### For GoDaddy (wildcard certificate)

```bash
./acme.sh --server letsencrypt --issue -d "*.yourdomain.com" --dns dns_gd --home $PWD
```

The process takes approximately 1-2 minutes while it creates DNS records and waits for propagation.

**Note:** If you receive Error 5598, add `--keylength 2048` to the command. This forces RSA keys instead of ECC, which some DSM versions handle better.

### Step 7: Deploy the Certificate to Synology

Deploy the certificate to DSM:

```bash
./acme.sh -d "*.yourdomain.com" --deploy --deploy-hook synology_dsm --home $PWD
```

This command logs into DSM, uploads the certificate, and restarts the web server automatically.

#### If Using Non-Standard Ports

If you've changed DSM's default ports from 5000/5001:

```bash
export SYNO_SCHEME="https"
export SYNO_PORT="5001"
./acme.sh -d "*.yourdomain.com" --insecure --deploy --deploy-hook synology_dsm --home $PWD
```

### Step 8: Configure Automatic Renewal

1. Open **Control Panel** → **Task Scheduler**
2. Click **Create** → **Scheduled Task** → **User-defined Script**
3. Configure the task:
   - **Task name:** Certificate Renewal
   - **User:** certadmin
   - **Schedule:** Daily (acme.sh will only renew when needed)
4. In the **Task Settings** tab, enter the script:

```bash
/usr/local/share/acme.sh/acme.sh --renew -d "*.yourdomain.com" --home /usr/local/share/acme.sh --server letsencrypt
```

### Step 9: Set the Certificate as Default

1. Open **Control Panel** → **Security** → **Certificate**
2. Select the new Let's Encrypt certificate
3. Click **Settings** and assign it as the default for all services
4. Click **Apply**

### Step 10: Enable HTTPS Redirect (Optional)

1. Open **Control Panel** → **Login Portal**
2. Check **Automatically redirect HTTP connections to HTTPS for DSM desktop**
3. Click **Save**

### Step 11: Disable SSH (Recommended)

Once configuration is complete:

1. Open **Control Panel** → **Terminal & SNMP**
2. Uncheck **Enable SSH service**
3. Click **Apply**

## Verification

Test the certificate in your browser by navigating to your Synology using the domain name (e.g., `https://nas.yourdomain.com`).

Check the certificate details:
- Issuer should be "Let's Encrypt"
- Expiration should be approximately 90 days out
- No browser warnings should appear

## Troubleshooting

**"Failed to authenticate, no such account or incorrect password":**
- Verify the certadmin password doesn't contain special characters like `$`
- Ensure certadmin is in both administrators and http groups
- Check that SYNO_USERNAME and SYNO_PASSWORD are set correctly (case-sensitive)

**Error connecting to localhost:5000:**
- You've changed the default DSM ports
- Set SYNO_SCHEME and SYNO_PORT environment variables as shown above

**DNS validation fails:**
- Verify API credentials are correct
- Check that the API token has proper permissions for the zone
- Wait a few minutes and retry (DNS propagation can be slow)

**Certificate not applying to all services:**
- Go to Control Panel → Security → Certificate → Settings
- Manually assign the certificate to each service

**Two-Factor Authentication issues:**
- If 2FA is enabled for certadmin, you may need to set `SYNO_Device_Name="CertRenewal"` and complete initial 2FA setup manually
- Alternatively, disable 2FA for the certadmin service account

## Notes

- Let's Encrypt certificates are valid for 90 days
- The acme.sh script will attempt renewal when certificates are within 30 days of expiration
- Running the renewal task daily ensures certificates never expire even if renewal fails occasionally
- The script stores credentials in its configuration files for automated renewal
- Wildcard certificates cover all subdomains (e.g., `*.yourdomain.com` covers `nas.yourdomain.com`, `photos.yourdomain.com`, etc.)
