# Raspberry Pi NAS with OpenMediaVault

## Overview

This procedure builds a network-attached storage (NAS) device using a Raspberry Pi and OpenMediaVault (OMV). The resulting system provides SMB/CIFS file sharing, automated local backups using rsync, and optional cloud backup using rclone to services like AWS S3.

This is an excellent low-power, low-cost solution for home file storage and backup, though it's limited by the Pi's USB-attached storage (no RAID support) and ethernet performance.

## Prerequisites

- Raspberry Pi 4 (4GB or 8GB recommended) or newer
- MicroSD card (16GB+ Class 10 or better)
- External USB hard drive(s) for storage
- Ethernet connection (required for initial setup)
- Power supply appropriate for Pi model (3A for Pi 4)
- Another computer with SD card reader for imaging
- Raspberry Pi Imager software

## Procedure

### Step 1: Image the Raspberry Pi OS

1. Download and install Raspberry Pi Imager on your computer
2. Insert the microSD card into your card reader
3. Open Raspberry Pi Imager and configure:
   - **Operating System:** Raspberry Pi OS Lite (64-bit) - choose the headless version without desktop
   - **Storage:** Select your microSD card

4. Press **Ctrl+Shift+X** to open advanced settings and configure:
   - Set hostname (e.g., `naspi`)
   - Enable SSH with password authentication
   - Set username and password
   - Configure locale and keyboard layout
   - **Do NOT configure WiFi** - use ethernet for NAS reliability

5. Click **Write** and wait for imaging to complete
6. Remove the SD card and insert it into the Raspberry Pi
7. Connect ethernet cable and power on the Pi

### Step 2: Initial System Configuration

SSH into the Raspberry Pi:

```bash
ssh pi@naspi.local
# or use the IP address if hostname doesn't resolve
ssh pi@192.168.1.xxx
```

Update the system:

```bash
sudo apt update && sudo apt upgrade -y
```

### Step 3: Install OpenMediaVault

Download and run the OMV installation script:

```bash
wget -O - https://raw.githubusercontent.com/OpenMediaVault-Plugin-Developers/installScript/master/install | sudo bash
```

This process takes 15-30 minutes. The system will reboot automatically when complete.

### Step 4: Connect Storage Drives

1. Shut down the Pi: `sudo shutdown now`
2. Connect your USB hard drive(s)
3. Power on the Pi and wait for it to boot

### Step 5: Access OpenMediaVault Web Interface

1. Open a web browser and navigate to the Pi's IP address
2. Log in with default credentials:
   - Username: `admin`
   - Password: `openmediavault`
3. **Immediately change the admin password** via User Settings

### Step 6: Configure Storage

#### Mount the Hard Drive(s)

1. Navigate to **Storage** → **Disks**
2. Verify your USB drives are detected
3. Navigate to **Storage** → **File Systems**
4. Click **Create** (or **Mount** if already formatted)
5. Select the disk and choose filesystem type (ext4 recommended)
6. Click **Save** and then **Mount**
7. Apply the pending configuration changes

#### Create Shared Folders

1. Navigate to **Storage** → **Shared Folders**
2. Click **Create** and configure:
   - Name: A descriptive name (e.g., `Media`, `Backups`, `Documents`)
   - Device: Select your mounted filesystem
   - Path: Will be auto-generated based on name
   - Permissions: Set appropriate defaults
3. Create additional shared folders as needed (e.g., a separate folder for rsync backups)

### Step 7: Configure SMB/CIFS Sharing

1. Navigate to **Services** → **SMB/CIFS** → **Settings**
2. Enable the service
3. Configure workgroup name if needed (default: WORKGROUP)
4. Click **Save** and apply changes

5. Navigate to **Services** → **SMB/CIFS** → **Shares**
6. Click **Create** and configure:
   - Enable: Yes
   - Shared Folder: Select the folder created earlier
   - Public: No (unless you want unauthenticated access)
   - Guest Access: Set based on security preference
7. Repeat for each shared folder you want accessible via SMB

### Step 8: Create Users

1. Navigate to **Users** → **Users**
2. Click **Create** and configure:
   - Name: Username for network access
   - Password: Strong password
   - Shell: /usr/sbin/nologin (for share-only access)
   - Groups: Add to `users` group
3. Apply changes
4. Navigate to **Storage** → **Shared Folders**
5. Select a folder and click **Privileges**
6. Set Read/Write permissions for appropriate users

### Step 9: Set Static IP Address

1. Navigate to **Network** → **Interfaces**
2. Select the ethernet interface and click **Edit**
3. Change from DHCP to Static
4. Configure:
   - Address: Your desired static IP
   - Netmask: Typically 255.255.255.0 (or /24)
   - Gateway: Your router's IP address
   - DNS: Your preferred DNS servers
5. Apply changes

**Important:** Make note of the new IP before applying—you'll need it to reconnect to the web interface.

### Step 10: Configure Local Backup with Rsync

If you have two drives and want to mirror data from one to the other:

1. Navigate to **Services** → **Rsync** → **Tasks**
2. Click **Create** and configure:
   - Type: Local
   - Source Shared Folder: Your primary data folder
   - Destination Shared Folder: Your backup folder
   - Minute: `0`
   - Hour: `*/4` (every 4 hours)
   - Day of month: `*`
   - Month: `*`
   - Day of week: `*`
3. Under **Options**, enable appropriate settings:
   - Archive mode
   - Delete (to mirror deletions—use with caution)
4. Click **Save** and apply changes

**Cron Format Reference:** `0 */4 * * *` runs at minute 0 of every 4th hour.

### Step 11: Configure Cloud Backup with Rclone (Optional)

#### Install Rclone

SSH into the Pi as a regular user (not admin):

```bash
ssh yourusername@naspi-ip-address
```

Install rclone:

```bash
sudo -v ; curl https://rclone.org/install.sh | sudo bash
```

#### Configure Rclone Remote

Run the configuration wizard:

```bash
rclone config
```

Follow the prompts to create a new remote:

1. Type `n` for new remote
2. Enter a name (e.g., `mycloud`)
3. Select your provider number (e.g., AWS S3)
4. Enter credentials when prompted:
   - For AWS S3: Access Key ID and Secret Access Key
5. Select default region
6. Select storage class (Standard, Glacier, etc.)
7. Accept defaults for remaining options
8. Confirm configuration

#### Create Cloud Backup Scheduled Task

1. In OMV, navigate to **System** → **Scheduled Tasks**
2. Click **Create** and configure:
   - Enable: Yes
   - Execution time: `0 3 * * *` (daily at 3 AM)
   - User: The user who configured rclone
   - Command:
   ```bash
   rclone copy --create-empty-src-dirs /srv/dev-disk-by-uuid-xxxxx/ShareName/ mycloud:bucket-name
   ```
3. Replace the source path with your actual mount point and share name
4. Replace `mycloud:bucket-name` with your remote name and destination bucket

To find your mount path:
```bash
ls -la /srv/
```

### Step 12: Test Network Access

From a Windows computer:

1. Open File Explorer
2. Enter `\\naspi` or `\\ip-address` in the address bar
3. Enter credentials when prompted
4. Map network drives as desired

From a Mac:

1. Open Finder
2. Press **Cmd+K** or select **Go** → **Connect to Server**
3. Enter `smb://naspi` or `smb://ip-address`
4. Enter credentials when prompted

## Verification

### Verify SMB Shares

From another computer, ensure you can:
- Connect to the share
- Create, modify, and delete files
- Access only folders you have permission for

### Verify Rsync Backup

Check the backup destination folder for expected files:

```bash
ls -la /path/to/backup/folder
```

View rsync task logs in OMV under **Diagnostics** → **System Logs**.

### Verify Cloud Backup

List files in your cloud bucket:

```bash
rclone ls mycloud:bucket-name
```

Check for recent uploads:

```bash
rclone lsl mycloud:bucket-name --max-depth 1
```

## Troubleshooting

**Cannot access shares from Windows:**
- Verify SMB service is running
- Check Windows credentials manager for cached incorrect passwords
- Ensure firewall isn't blocking SMB (port 445)
- Try accessing by IP address instead of hostname

**Slow transfer speeds:**
- Raspberry Pi USB and ethernet share bandwidth
- Typical max throughput is ~35-40 MB/s
- Use USB 3.0 drives and ports
- Consider Pi 5 for improved performance

**Rsync not running:**
- Check task is enabled
- Verify cron syntax in scheduled tasks
- Check logs for permission errors

**Rclone authentication failures:**
- Re-run `rclone config` to verify credentials
- For AWS, ensure IAM user has S3 permissions
- Check for API key expiration

**Drives not detected:**
- Verify power supply is adequate (Pi 4 needs 3A)
- Try a powered USB hub
- Check `lsblk` output via SSH

## Notes

- USB drives cannot be configured in RAID on the Pi—use rsync for redundancy instead
- Consider a UPS for data protection during power outages
- OMV updates are managed through the web interface
- For larger storage needs, consider a dedicated NAS like Synology
- The Pi's microSD card can wear out; consider USB boot for reliability
- Glacier storage classes significantly reduce cloud storage costs for archival data
