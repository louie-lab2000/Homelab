# Complete NUT UPS Configuration Guide for Proxmox VE
## Automatic UPS Shutdown with Power Restoration

**System:** Proxmox VE with CyberPower CP850PFCLCD UPS  
**Goal:** Automatically shutdown all systems on extended power loss, power down the UPS, and auto-restart when mains power returns

---

## Table of Contents
1. [Installation](#installation)
2. [Configuration Files](#configuration-files)
3. [Permissions Setup](#permissions-setup)
4. [Testing](#testing)
5. [Troubleshooting](#troubleshooting)

---

## Installation

### Install NUT on Primary Server (PVE-01)

```bash
apt update
apt install nut
```

---

## Configuration Files

### 1. `/etc/nut/ups.conf`

Configure the UPS driver and connection:

```ini
[ups]
    driver = usbhid-ups
    port = auto
    desc = "CyberPower CP850PFCLCD"
    pollinterval = 2
    offdelay = 20
```

**Key settings:**
- `offdelay = 20`: Wait 20 seconds after receiving shutdown command before powering off
- `pollinterval = 2`: Check UPS status every 2 seconds

---

### 2. `/etc/nut/upsd.conf`

Configure the NUT server:

```ini
LISTEN 0.0.0.0 3493
LISTEN :: 3493
```

This allows other systems on your network to connect to the UPS server.

---

### 3. `/etc/nut/upsd.users`

Define users and permissions:

```ini
[admin]
    password = secret
    actions = SET FSD
    instcmds = ALL
    upsmon master

[monuser]
    password = secret
    upsmon slave
```

**Important:** 
- Change `secret` to a strong password
- `actions = SET FSD` is required for shutdown commands
- `instcmds = ALL` allows all UPS commands including `shutdown.return`

---

### 4. `/etc/nut/upsmon.conf`

Configure the monitoring daemon:

```ini
MONITOR ups@localhost 1 admin secret master

MINSUPPLIES 1
SHUTDOWNCMD "/usr/local/bin/nut-shutdown-with-ups"
NOTIFYCMD /usr/sbin/upssched
POLLFREQ 5
POLLFREQALERT 5
HOSTSYNC 15
DEADTIME 15
POWERDOWNFLAG /etc/killpower
NOTIFYMSG ONLINE    "UPS %s on line power"
NOTIFYMSG ONBATT    "UPS %s on battery"
NOTIFYMSG LOWBATT   "UPS %s battery is low"
NOTIFYMSG FSD       "UPS %s: forced shutdown in progress"
NOTIFYMSG COMMOK    "Communications with UPS %s established"
NOTIFYMSG COMMBAD   "Communications with UPS %s lost"
NOTIFYMSG SHUTDOWN  "Auto logout and shutdown proceeding"
NOTIFYMSG REPLBATT  "UPS %s battery needs to be replaced"
NOTIFYMSG NOCOMM    "UPS %s is unavailable"
NOTIFYMSG NOPARENT  "upsmon parent process died - shutdown impossible"

NOTIFYFLAG ONBATT   SYSLOG+WALL+EXEC
NOTIFYFLAG LOWBATT  SYSLOG+WALL+EXEC
NOTIFYFLAG ONLINE   SYSLOG+WALL+EXEC
NOTIFYFLAG COMMBAD  SYSLOG+WALL+EXEC
NOTIFYFLAG COMMOK   SYSLOG+WALL+EXEC
NOTIFYFLAG SHUTDOWN SYSLOG+WALL+EXEC
NOTIFYFLAG REPLBATT SYSLOG+WALL+EXEC
NOTIFYFLAG NOCOMM   SYSLOG+WALL+EXEC
NOTIFYFLAG FSD      SYSLOG+WALL+EXEC
NOTIFYFLAG NOPARENT SYSLOG+WALL
```

**Key settings:**
- `MONITOR ups@localhost 1 admin secret master`: Monitor local UPS as master
- `SHUTDOWNCMD`: Custom script that shutdowns both system and UPS
- `NOTIFYCMD /usr/sbin/upssched`: Use upssched for timed events
- `NOTIFYFLAG ONBATT SYSLOG+WALL+EXEC`: Execute upssched on battery events

---

### 5. `/etc/nut/upssched.conf`

Configure timed shutdown events:

```ini
CMDSCRIPT /etc/nut/upssched-cmd
PIPEFN /var/run/nut/upssched.pipe
LOCKFN /var/run/nut/upssched.lock

# When on battery for 2 minutes (120 seconds), trigger early-shutdown
AT ONBATT * START-TIMER early-shutdown 120

# Cancel if power returns
AT ONLINE * CANCEL-TIMER early-shutdown

# Only trigger LOWBATT shutdown if we're still on battery
AT LOWBATT * EXECUTE check-lowbatt
```

**Key settings:**
- `AT ONBATT * START-TIMER early-shutdown 120`: Wait 2 minutes on battery before shutdown
- `AT ONLINE * CANCEL-TIMER early-shutdown`: Cancel shutdown if power returns
- `AT LOWBATT * EXECUTE check-lowbatt`: Smart LOWBATT handling (ignore if on mains)

---

### 6. `/etc/nut/upssched-cmd`

Script to handle timed events:

```bash
#!/bin/bash

case $1 in
    early-shutdown)
        logger -t upssched "UPS has been on battery for 2 minutes - initiating shutdown"
        /usr/sbin/upsmon -c fsd
        ;;
    check-lowbatt)
        # Check if UPS is actually on battery before forcing shutdown
        UPS_STATUS=$(/usr/bin/upsc ups ups.status 2>/dev/null)
        if echo "$UPS_STATUS" | grep -q "OB"; then
            logger -t upssched "UPS battery critically low AND on battery - forcing immediate shutdown"
            /usr/sbin/upsmon -c fsd
        else
            logger -t upssched "UPS battery low but on mains power - ignoring LOWBATT"
        fi
        ;;
    early-shutdown-cancelled)
        logger -t upssched "Power restored - shutdown cancelled"
        ;;
    *)
        logger -t upssched "Unrecognized command: $1"
        ;;
esac
```

Make it executable:

```bash
chmod +x /etc/nut/upssched-cmd
```

**Features:**
- `early-shutdown`: Triggered after 2 minutes on battery
- `check-lowbatt`: Smart handler that ignores LOWBATT if on mains power (prevents boot loops)

---

### 7. `/usr/local/bin/nut-shutdown-with-ups`

Custom shutdown script that powers down the UPS:

```bash
#!/bin/bash

# Log that we're starting the shutdown
logger -t nut-shutdown "Starting system and UPS shutdown sequence"

# Send the shutdown command to the UPS first
logger -t nut-shutdown "Sending shutdown.return command to UPS"
/usr/bin/upscmd -u admin -p secret ups shutdown.return 2>&1 | logger -t nut-shutdown

# Now shutdown the system
logger -t nut-shutdown "Initiating system shutdown"
/sbin/shutdown -h now

exit 0
```

**Important:** Replace `secret` with your actual admin password from `/etc/nut/upsd.users`

Make it executable:

```bash
chmod +x /usr/local/bin/nut-shutdown-with-ups
```

**What it does:**
1. Sends `shutdown.return` command to UPS (tells it to power off, then turn back on when mains returns)
2. Initiates system shutdown
3. UPS waits 20 seconds (offdelay), then powers off
4. When AC power returns, UPS automatically powers back on

---

### 8. `/etc/nut/nut.conf`

Set the NUT mode:

```ini
MODE=netserver
```

This allows other systems to connect as clients.

---

## Permissions Setup

### 1. Create udev Rules for USB Permissions

Create `/etc/udev/rules.d/90-nut-ups.rules`:

```bash
SUBSYSTEM=="usb", ATTR{idVendor}=="0764", ATTR{idProduct}=="0601", MODE="0660", GROUP="nut", OWNER="nut"
```

**Note:** The idProduct `0601` is for CyberPower UPS models. Verify yours with `lsusb | grep -i cyber`

Reload udev rules:

```bash
udevadm control --reload-rules
udevadm trigger
```

---

### 2. Create upssched Directory

```bash
mkdir -p /var/run/nut
chown nut:nut /var/run/nut
chmod 770 /var/run/nut
```

---

## Service Management

### Start and Enable Services

```bash
# Start services in order
systemctl start nut-driver@ups
systemctl start nut-server
systemctl start nut-monitor

# Enable services to start on boot
systemctl enable nut-driver@ups
systemctl enable nut-server
systemctl enable nut-monitor
```

### Check Service Status

```bash
systemctl status nut-driver@ups
systemctl status nut-server
systemctl status nut-monitor
```

---

## Testing

### 1. Verify UPS Detection

```bash
upsc ups
```

You should see all UPS parameters including:
- `battery.charge`
- `ups.status` (should show `OL` when on line power)
- `ups.load`

---

### 2. Test Battery Detection (Quick Test)

Unplug the UPS from wall power for 10-15 seconds, then plug back in.

Watch the logs:

```bash
journalctl -u nut-monitor -f
```

You should see:
- "UPS on battery" message
- "UPS on line power" message when plugged back in
- **No shutdown** because it was less than 2 minutes

---

### 3. Available UPS Commands

List all commands your UPS supports:

```bash
upscmd -l ups
```

For CyberPower, you should see:
- `shutdown.return` - Turn off, return when power restored (this is what we use)
- `shutdown.stayoff` - Turn off and stay off
- `load.off` - Turn off load immediately
- `test.battery.start` - Start battery test

---

### 4. Test Manual UPS Shutdown Command (Optional)

**WARNING:** This will immediately shut down the UPS!

```bash
upscmd -u admin -p secret ups shutdown.return
```

The UPS should:
1. Wait 20 seconds (offdelay)
2. Power off
3. Automatically power back on (since you didn't lose power)

---

## How It Works

### Normal Operation
1. System monitors UPS every 2 seconds
2. If UPS status is `OL` (online), no action taken

### Power Failure Sequence
1. **Power lost** → UPS switches to battery
2. **T+0 seconds**: nut-monitor detects `ONBATT` event
3. **T+0 seconds**: upssched starts 120-second timer
4. **If power returns before 2 minutes**: Timer cancelled, normal operation resumes
5. **T+120 seconds**: Timer expires, `early-shutdown` triggered
6. **T+120 seconds**: upsmon sends FSD (Forced Shutdown) signal
7. **System shutdown sequence**:
   - Proxmox shuts down all VMs cleanly
   - System services stop
   - During shutdown, `/usr/local/bin/nut-shutdown-with-ups` is called
   - Script sends `shutdown.return` to UPS
   - System completes shutdown
8. **T+20 seconds after shutdown complete**: UPS powers off (offdelay)
9. **When AC power returns**: UPS automatically powers back on
10. **All systems auto-boot** (if configured in BIOS to power on after AC loss)

### Low Battery Special Handling
- If LOWBATT is triggered **while on battery**: Immediate shutdown
- If LOWBATT is triggered **while on mains**: Ignored (prevents false shutdown after power restoration)

---

## Monitoring and Logs

### View Real-Time NUT Logs

```bash
journalctl -u nut-monitor -f
```

### View upssched Activity

```bash
journalctl | grep upssched
```

### View UPS Shutdown Activity

```bash
journalctl | grep nut-shutdown
```

### Check Last Shutdown Logs

```bash
journalctl -b -1 | grep -E "nut-shutdown|upssched|UPS"
```

---

## Client Configuration (Other Proxmox Nodes)

For secondary Proxmox nodes or other systems that should also shutdown:

### 1. Install NUT Client

```bash
apt update
apt install nut-client
```

### 2. Configure `/etc/nut/nut.conf`

```ini
MODE=netclient
```

### 3. Configure `/etc/nut/upsmon.conf`

```ini
MONITOR ups@192.168.3.4 1 monuser secret slave

MINSUPPLIES 1
SHUTDOWNCMD "/sbin/shutdown -h now"
POLLFREQ 5
POLLFREQALERT 5
HOSTSYNC 15
DEADTIME 15

NOTIFYFLAG ONBATT   SYSLOG+WALL
NOTIFYFLAG LOWBATT  SYSLOG+WALL
NOTIFYFLAG ONLINE   SYSLOG+WALL
NOTIFYFLAG COMMBAD  SYSLOG+WALL
NOTIFYFLAG COMMOK   SYSLOG+WALL
NOTIFYFLAG SHUTDOWN SYSLOG+WALL
NOTIFYFLAG REPLBATT SYSLOG+WALL
NOTIFYFLAG NOCOMM   SYSLOG+WALL
NOTIFYFLAG FSD      SYSLOG+WALL
```

**Replace:** `192.168.3.4` with the IP of your primary NUT server (PVE-01)

### 4. Start Client Service

```bash
systemctl start nut-monitor
systemctl enable nut-monitor
```

---

## Synology NAS Configuration

Synology has built-in NUT client support:

1. Go to **Control Panel** → **Hardware & Power** → **UPS**
2. Click **Enable UPS support**
3. Select **Network UPS**
4. Enter:
   - **Server address**: IP of PVE-01 (e.g., `192.168.3.4`)
   - **UPS name**: `ups`
5. Under **Shutdown settings**:
   - Check **Enter Safe Mode when UPS is on battery power**
   - Set time as desired (or leave default)
6. Click **Apply**

**Note:** Synology will enter Safe Mode (stop services, unmount volumes) but will NOT fully power off. This is normal and actually safer for a NAS. When the UPS powers back on, Synology automatically resumes from Safe Mode.

---

## Troubleshooting

### Issue: Permission Denied on USB Device

**Symptoms:** Driver can't connect to UPS

**Solution:**
1. Check USB permissions:
   ```bash
   lsusb | grep -i cyber
   # Note the Bus and Device numbers, e.g., "Bus 003 Device 002"
   ls -l /dev/bus/usb/003/002
   ```

2. Should show owner `nut:nut`. If not, check udev rules and reload:
   ```bash
   cat /etc/udev/rules.d/90-nut-ups.rules
   udevadm control --reload-rules
   udevadm trigger
   ```

3. Restart driver:
   ```bash
   systemctl restart nut-driver@ups
   ```

---

### Issue: upssched Not Running

**Symptoms:** No timer events, immediate shutdown on battery

**Solution:**
1. Verify upssched directory exists:
   ```bash
   ls -ld /var/run/nut
   mkdir -p /var/run/nut
   chown nut:nut /var/run/nut
   chmod 770 /var/run/nut
   ```

2. Verify upssched-cmd is executable:
   ```bash
   ls -l /etc/nut/upssched-cmd
   chmod +x /etc/nut/upssched-cmd
   ```

3. Check for syntax errors:
   ```bash
   bash -n /etc/nut/upssched-cmd
   ```

4. Restart monitor:
   ```bash
   systemctl restart nut-monitor
   ```

---

### Issue: Access Denied on shutdown.return Command

**Symptoms:** `ERR ACCESS-DENIED` in logs during shutdown

**Solution:**
1. Verify admin user has correct permissions in `/etc/nut/upsd.users`:
   ```ini
   [admin]
       password = secret
       actions = SET FSD
       instcmds = ALL
       upsmon master
   ```

2. Verify password in `/usr/local/bin/nut-shutdown-with-ups` matches

3. Restart services:
   ```bash
   systemctl restart nut-server
   systemctl restart nut-monitor
   ```

4. Test command:
   ```bash
   upscmd -u admin -p secret ups shutdown.return
   ```
   Should return `OK` (WARNING: This will shutdown UPS!)

---

### Issue: System Shuts Down Immediately on LOWBATT

**Symptoms:** System reboots after power restoration due to LOWBATT flag persisting

**Solution:** The `check-lowbatt` handler in `/etc/nut/upssched-cmd` prevents this by checking if UPS is actually on battery before initiating shutdown. Verify this handler exists in your config.

---

### Issue: UPS Doesn't Power Off After System Shutdown

**Symptoms:** UPS stays on after system shutdown

**Possible causes:**
1. `shutdown.return` command failed (check for ACCESS-DENIED error)
2. `offdelay` too short (increase in `/etc/nut/ups.conf`)
3. `/usr/local/bin/nut-shutdown-with-ups` script not being called

**Solution:**
1. Check logs from previous boot:
   ```bash
   journalctl -b -1 | grep nut-shutdown
   ```

2. Look for "Sending shutdown.return command to UPS" and any errors

3. Verify SHUTDOWNCMD in `/etc/nut/upsmon.conf` points to correct script

---

### Issue: UPS Doesn't Automatically Power Back On

**Symptoms:** UPS stays off when AC power returns

**Solution:**
1. Verify you're using `shutdown.return` and NOT `shutdown.stayoff`
2. Some UPS models require BIOS setting "Restore on AC loss" or similar
3. Check if your UPS supports automatic power-on:
   ```bash
   upscmd -l ups | grep shutdown
   ```

---

## Important Notes

1. **Test Your Configuration:** Do a full test during a maintenance window to ensure everything works as expected.

2. **Battery Runtime:** With a 2-minute delay, ensure your UPS has enough battery capacity to:
   - Run for 2 minutes
   - Plus time to shut down all VMs
   - Plus time to shut down the system
   - Recommended: At least 5-10 minutes of runtime

3. **Network-Dependent Systems:** If you have systems that require network access to shut down properly, ensure they complete shutdown before the network goes down.

4. **BIOS Settings:** Configure all systems to "Power On after AC Loss" or similar in BIOS so they auto-boot when UPS powers back on.

5. **Password Security:** Change the default `secret` password in `/etc/nut/upsd.users` to something secure.

6. **Firewall Rules:** If using a firewall, allow port 3493/tcp for NUT communication between systems.

---

## File Permissions Summary

```bash
# Configuration files
chmod 640 /etc/nut/ups.conf
chmod 640 /etc/nut/upsd.conf
chmod 640 /etc/nut/upsd.users
chmod 640 /etc/nut/upsmon.conf
chmod 640 /etc/nut/upssched.conf

# Executable scripts
chmod 755 /etc/nut/upssched-cmd
chmod 755 /usr/local/bin/nut-shutdown-with-ups

# Directories
chmod 770 /var/run/nut
chown nut:nut /var/run/nut

# Set ownership
chown root:nut /etc/nut/*.conf
chown root:nut /etc/nut/upsd.users
```

---

## Quick Reference Commands

### Check UPS Status
```bash
upsc ups
upsc ups ups.status
upsc ups battery.charge
```

### List Available Commands
```bash
upscmd -l ups
```

### Manual Tests (Use Carefully!)
```bash
# Test battery detection (safe)
# Unplug UPS from wall for 15 seconds, plug back in

# Test shutdown command (DANGEROUS - will shutdown UPS!)
# upscmd -u admin -p secret ups shutdown.return
```

### View Logs
```bash
# Real-time monitoring
journalctl -u nut-monitor -f

# View upssched events
journalctl | grep upssched

# View shutdown sequence
journalctl -b -1 | grep -E "nut-shutdown|upssched|shutdown"
```

### Restart Services
```bash
systemctl restart nut-driver@ups
systemctl restart nut-server
systemctl restart nut-monitor
```

---

## Configuration Checklist

- [ ] NUT installed on primary server
- [ ] `/etc/nut/ups.conf` configured with correct driver and offdelay
- [ ] `/etc/nut/upsd.conf` listening on network
- [ ] `/etc/nut/upsd.users` with admin user having `actions = SET FSD` and `instcmds = ALL`
- [ ] `/etc/nut/upsmon.conf` configured with MONITOR, SHUTDOWNCMD, and NOTIFYCMD
- [ ] `/etc/nut/upssched.conf` with 2-minute timer and LOWBATT handler
- [ ] `/etc/nut/upssched-cmd` script created and executable
- [ ] `/usr/local/bin/nut-shutdown-with-ups` script created with correct password
- [ ] `/etc/nut/nut.conf` set to `MODE=netserver`
- [ ] udev rules created for USB permissions
- [ ] `/var/run/nut` directory created with correct permissions
- [ ] All services started and enabled
- [ ] UPS detected with `upsc ups`
- [ ] Battery detection tested (10-second unplug test)
- [ ] Client systems configured (if applicable)
- [ ] BIOS set to power on after AC loss on all systems
- [ ] Full shutdown test completed successfully

---

## Summary

This configuration provides a robust, automatic UPS shutdown system that:
- Waits 2 minutes on battery before initiating shutdown (allows for brief power blips)
- Cleanly shuts down all VMs and services
- Powers down the UPS after system shutdown
- Automatically powers back on when mains power returns
- Ignores false LOWBATT signals when on mains power
- Supports multiple client systems via network monitoring

The system is designed to be "set and forget" - once configured, it will automatically handle power failures without manual intervention, and will bring your entire infrastructure back online when power is restored.

---

**Document Version:** 1.0  
**Last Updated:** November 2, 2025  
**Tested On:** Proxmox VE 8.x with CyberPower CP850PFCLCD UPS
