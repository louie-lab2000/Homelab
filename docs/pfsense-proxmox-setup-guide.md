# pfSense on Proxmox - Network Configuration Guide

## Overview
This guide documents the network configuration for running pfSense virtualized on Proxmox with dual WAN connections, VLAN segmentation, and a dedicated emergency access port.

## Hardware Configuration

### Motherboard: IMB-V2000M
- **enp1s0**: Realtek 2.5GbE NIC (WAN1 - Xfinity Cable)
- **enp2s0f0**: Realtek 1GbE NIC (WAN2 - T-Mobile 5G)
- **Intel X520 Dual-Port SFP+ Card**:
  - **enp3s0f0**: SFP+ Port 0 → LAN Trunk (SFP+ AOC fiber to managed switch)
  - **enp3s0f1**: SFP+ Port 1 → Emergency/Rescue Access (RJ45 transceiver)

### Physical Connections
```
Internet
├── Xfinity Cable Modem ──── [enp1s0 / vmbr1] ──┐
└── T-Mobile 5G Modem ────── [enp2s0f0 / vmbr2] ┘
                                                 │
                                        ┌────────┴────────┐
                                        │  Proxmox Host   │
                                        │   pfSense VM    │
                                        └────────┬────────┘
                                                 │
                    Managed Switch ◄─── [enp3s0f0 / vmbr0] (LAN Trunk - ALL VLANs)
                         │
                    Emergency ──────── [enp3s0f1 / vmbr3] (192.168.99.0/24)
```

---

## Step 0: Install Proxmox VE

Install Proxmox VE normally using the standard installer:
- **Management Interface**: Use `enp2s0f0` (1GbE Realtek) during installation
- **Storage**: ZFS single drive
- Complete the installation and reboot

**Note**: The Realtek NICs will not work properly until the drivers are installed in Step 1.

---

## Step 1: Install Realtek Drivers (Proxmox Host)

The built-in Realtek NICs (enp1s0 and enp2s0f0) require proper drivers. We'll use the **Awesometic DKMS package**, which automatically rebuilds the driver when Proxmox kernel updates are installed.

### What is DKMS?

DKMS (Dynamic Kernel Module Support) automatically recompiles kernel modules when you upgrade to a new kernel. This means the Realtek driver will continue working after Proxmox updates without manual intervention.

### Install the Realtek r8125 Driver

1. Install DKMS and build dependencies:
```bash
apt update
apt install -y dkms build-essential
```

2. Download the Awesometic DKMS package:
```bash
cd /tmp
wget https://github.com/awesometic/realtek-r8125-dkms/releases/download/9.016.01-1/realtek-r8125-dkms_9.016.01-1_amd64.deb
```

3. Install the package:
```bash
dpkg -i realtek-r8125-dkms_9.016.01-1_amd64.deb
```

4. Verify installation:
```bash
# Check DKMS status
dkms status

# Should show: realtek-r8125/9.016.01, <kernel>, x86_64: installed

# Check loaded module
lsmod | grep r81

# Should show both r8125 and r8169
```

5. Verify driver info:
```bash
modinfo r8125
```

You should see:
```
filename:       /lib/modules/.../updates/dkms/r8125.ko
version:        9.016.01-NAPI
description:    Realtek r8125 Ethernet controller driver
```

6. **IMPORTANT**: Do NOT blacklist the r8169 driver. Both r8125 and r8169 can coexist. Blacklisting r8169 will cause enp2s0f0 (1GbE) to stop working.

7. Reboot to ensure drivers load properly:
```bash
reboot
```

8. After reboot, verify NICs are working:
```bash
ip addr show enp1s0
ip addr show enp2s0f0
```

---

## Step 2: Configure Proxmox Networking

---

## Step 2: Configure Proxmox Networking

### Create `/etc/network/interfaces`

```bash
nano /etc/network/interfaces
```

Paste the following configuration:

```
auto lo
iface lo inet loopback


# ===== LAN Trunk (X520 Port 0) =====
auto enp3s0f0
iface enp3s0f0 inet manual

auto vmbr0
iface vmbr0 inet manual
        bridge-ports enp3s0f0
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 2-4092

# Primary Proxmox management on VLAN 100 (tagged on vmbr0)
auto vmbr0.100
iface vmbr0.100 inet static
        address 192.168.10.6/24
        gateway 192.168.10.1

# Proxmox host on VLAN 3 (Storage VLAN, non-routed)
auto vmbr0.3
iface vmbr0.3 inet static
        address 192.168.3.10/24


# ===== Emergency / Rescue Management (X520 Port 1) =====
# Dedicated bridge on the second port with a private subnet and NO gateway.
# Plug your laptop or an isolated switch into enp3s0f1 and set your laptop to 192.168.99.10/24
auto enp3s0f1
iface enp3s0f1 inet manual

auto vmbr3
iface vmbr3 inet static
        address 192.168.99.6/24
        bridge-ports enp3s0f1
        bridge-stp off
        bridge-fd 0
        # no 'gateway' here by design


# ===== WAN1 (Realtek 2.5G) =====
auto enp1s0
iface enp1s0 inet manual

auto vmbr1
iface vmbr1 inet manual
        bridge-ports enp1s0
        bridge-stp off
        bridge-fd 0


# ===== WAN2 (Realtek 1G) =====
auto enp2s0f0
iface enp2s0f0 inet manual

auto vmbr2
iface vmbr2 inet manual
        bridge-ports enp2s0f0
        bridge-stp off
        bridge-fd 0


source /etc/network/interfaces.d/*
```

### Apply Network Configuration

**Option 1: Reboot (Safest)**
```bash
reboot
```

**Option 2: Reload without reboot (Advanced)**
```bash
ifreload -a
```

### Verify Network Configuration

```bash
# Check all interfaces
ip addr

# Check bridge configuration
brctl show

# Check VLAN interfaces
ip -d link show vmbr0.100
ip -d link show vmbr0.3
```

You should see:
- `vmbr0.100` with IP `192.168.10.6/24` (Management)
- `vmbr0.3` with IP `192.168.3.10/24` (Storage)
- `vmbr3` with IP `192.168.99.6/24` (Emergency)

---

## Step 3: Initial Access Methods

### Method 1: Emergency Access Port (Recommended for Initial Setup)

**Before pfSense is configured**, you cannot access Proxmox through the LAN trunk. Use the emergency port:

1. Connect your laptop/workstation to **enp3s0f1** (via RJ45 transceiver in the X520's second port)

2. Configure your laptop with a static IP:
   - IP: `192.168.99.10`
   - Subnet: `255.255.255.0` (or `/24`)
   - Gateway: Leave blank
   - DNS: Leave blank

3. Access Proxmox web interface:
   ```
   https://192.168.99.6:8006
   ```

4. SSH to Proxmox:
   ```bash
   ssh root@192.168.99.6
   ```

### Method 2: Access via VLAN 100 (After pfSense Configuration)

Once pfSense is configured and routing VLAN 100:

1. Connect your laptop to a switch port configured for VLAN 100

2. Obtain DHCP or configure static IP in `192.168.10.0/24` range

3. Access Proxmox:
   ```
   https://192.168.10.6:8006
   ```

---

## Step 4: Create pfSense VM in Proxmox

### VM Configuration (ID: 1000)

1. In Proxmox web interface, click **Create VM**

2. **General Tab**:
   - VM ID: `1000`
   - Name: `pfsense`
   - Start at boot: ✓ Checked

3. **OS Tab**:
   - ISO: Select pfSense ISO from storage
   - Type: Other
   - Guest OS: Other

4. **System Tab**:
   - Machine: `q35`
   - BIOS: `OVMF (UEFI)`
   - Add EFI Disk: Yes
   - EFI Storage: `local-zfs`
   - SCSI Controller: `VirtIO SCSI single`

5. **Disks Tab**:
   - Bus/Device: `IDE` / `0`
   - Storage: `local-zfs`
   - Disk size: `64 GB`
   - Discard: ✓ Checked
   - SSD emulation: ✓ Checked

6. **CPU Tab**:
   - Sockets: `1`
   - Cores: `6`
   - Type: `host`
   - Enable NUMA: ✓ Checked

7. **Memory Tab**:
   - Memory: `4096 MB`
   - Minimum memory: `4096 MB` (set ballooning to 0)

8. **Network Tab** (Add first NIC during creation):
   - Bridge: `vmbr0`
   - Model: `VirtIO (paravirtualized)`
   - MAC address: `BC:24:11:E7:71:6D` (or auto)
   - Multiqueue: `2`

### Add Additional Network Interfaces

After VM creation, add two more NICs:

1. Select VM 1000 → **Hardware** → **Add** → **Network Device**

2. **WAN1 Interface**:
   - Bridge: `vmbr1`
   - Model: `VirtIO (paravirtualized)`
   - MAC address: `BC:24:11:F6:5F:AE` (or auto)
   - Multiqueue: `2`

3. **WAN2 Interface**:
   - Bridge: `vmbr2`
   - Model: `VirtIO (paravirtualized)`
   - MAC address: `BC:24:11:F1:9B:47` (or auto)
   - Multiqueue: `2`

### Final Hardware Settings

Edit **Hardware** → **Options** to match:
- **Start at boot**: Yes
- **Boot order**: `ide0`, `net0`

Your final `/etc/pve/qemu-server/1000.conf` should look like:
```
balloon: 0
bios: ovmf
boot: order=ide0;net0
cores: 6
cpu: host
efidisk0: local-zfs:vm-1000-disk-0,efitype=4m,size=1M
ide0: local-zfs:vm-1000-disk-1,discard=on,size=64G,ssd=1
machine: q35
memory: 4096
name: pfsense
net0: virtio=BC:24:11:E7:71:6D,bridge=vmbr0,queues=2
net1: virtio=BC:24:11:F6:5F:AE,bridge=vmbr1,queues=2
net2: virtio=BC:24:11:F1:9B:47,bridge=vmbr2,queues=2
numa: 0
onboot: 1
ostype: other
scsihw: virtio-scsi-single
sockets: 1
vga: qxl
```

---

## Step 5: pfSense Initial Network Configuration

### Boot pfSense and Assign Interfaces

1. Start the pfSense VM and open the console

2. Complete the installation (not covered in this guide)

3. After reboot, pfSense will detect interfaces. Assign as follows:
   - **WAN**: `vtnet1` (MAC: bc:24:11:f6:5f:ae) → Connected to vmbr1
   - **LAN**: `vtnet0` (MAC: bc:24:11:e7:71:6d) → Connected to vmbr0
   - **OPT1 (WAN2)**: `vtnet2` (MAC: bc:24:11:f1:9b:47) → Connected to vmbr2

4. Configure LAN IP address when prompted:
   ```
   LAN IP: 192.168.10.1
   Subnet: 24
   ```

5. Enable DHCP server on LAN when prompted: **Yes**
   - Start: `192.168.10.100`
   - End: `192.168.10.200`

### Access pfSense Web Interface

**Option A: Via Emergency Port**
1. Keep laptop connected to `192.168.99.6` (Proxmox emergency)
2. SSH into Proxmox: `ssh root@192.168.99.6`
3. Access pfSense console from Proxmox:
   ```bash
   qm terminal 1000
   ```
4. Make configuration changes via console

**Option B: Via Temporary Direct Connection**
1. Temporarily plug your laptop directly into the managed switch on an untagged port (native VLAN)
2. Set laptop to obtain DHCP
3. You should get an IP in `192.168.10.100-200` range
4. Access pfSense: `http://192.168.10.1` or `https://192.168.10.1`
5. Default credentials: `admin` / `pfsense`

---

## Step 6: Configure VLANs in pfSense

### Create VLAN Interfaces

1. Log into pfSense web interface
2. Navigate to **Interfaces → Assignments → VLANs**
3. Create each VLAN on parent interface `vtnet0` (LAN):

| VLAN Tag | Description | Purpose |
|----------|-------------|---------|
| 21 | IOT | IoT devices |
| 22 | Television | TV/Media devices |
| 50 | Server | Server infrastructure |
| 51 | Home | Home network |
| 52 | Guest | Guest network |
| 100 | Server_mgmt | Server management (Proxmox, etc.) |

**To add each VLAN:**
- Click **+ Add**
- Parent Interface: `vtnet0`
- VLAN Tag: (enter tag from table above)
- Description: (enter description from table above)
- Click **Save**

### Assign VLAN Interfaces

1. Go to **Interfaces → Assignments**
2. For each VLAN, select it from the **Available network ports** dropdown and click **+ Add**
3. After adding all VLANs, click on each interface name to configure:

#### IOT Interface (VLAN 21)
- Enable: ✓ Checked
- Description: `IOT`
- IPv4 Configuration Type: `Static IPv4`
- IPv4 Address: `192.168.21.1 / 24`
- Click **Save**

#### Television Interface (VLAN 22)
- Enable: ✓ Checked
- Description: `Television`
- IPv4 Configuration Type: `Static IPv4`
- IPv4 Address: `192.168.22.1 / 24`
- Click **Save**

#### Server Interface (VLAN 50)
- Enable: ✓ Checked
- Description: `Server`
- IPv4 Configuration Type: `Static IPv4`
- IPv4 Address: `192.168.50.1 / 24`
- Click **Save**

#### Home Interface (VLAN 51)
- Enable: ✓ Checked
- Description: `Home`
- IPv4 Configuration Type: `Static IPv4`
- IPv4 Address: `192.168.51.1 / 24`
- Click **Save**

#### Guest Interface (VLAN 52)
- Enable: ✓ Checked
- Description: `Guest`
- IPv4 Configuration Type: `Static IPv4`
- IPv4 Address: `192.168.52.1 / 24`
- Click **Save**

#### Server_mgmt Interface (VLAN 100)
- Enable: ✓ Checked
- Description: `Server_mgmt`
- IPv4 Configuration Type: `Static IPv4`
- IPv4 Address: `192.168.10.1 / 24`
- Click **Save**

4. **Apply Changes** after all interfaces are configured

---

## Step 7: Configure Managed Switch

Your managed switch must be configured to:
1. Trunk ALL VLANs to the port connected to pfSense (enp3s0f0)
2. Provide appropriate VLAN access to end devices

### Trunk Port to pfSense

Configure the switch port connected to your SFP+ AOC fiber:
- **Mode**: Trunk/Tagged
- **Allowed VLANs**: 21, 22, 50, 51, 52, 100, 3 (and any others)
- **Native/Untagged VLAN**: None (or VLAN 1 if required by switch)

### Access Ports for Devices

Configure individual ports based on what devices connect:

**Example VLAN Assignments:**
- **VLAN 21 (IOT)**: Smart home devices, cameras, sensors
- **VLAN 22 (Television)**: Smart TVs, streaming devices
- **VLAN 50 (Server)**: Servers, NAS (data access)
- **VLAN 51 (Home)**: Workstations, personal devices
- **VLAN 52 (Guest)**: Guest Wi-Fi APs
- **VLAN 100 (Server_mgmt)**: Proxmox management, server management interfaces
- **VLAN 3**: Storage (untagged for Proxmox and NAS storage traffic - NOT routed through pfSense)

### Storage VLAN (VLAN 3) - Special Case

VLAN 3 is configured on:
- Proxmox host: `vmbr0.3` → `192.168.3.10/24`
- Synology NAS: Should have `192.168.3.x/24`
- Managed switch: As a tagged VLAN

**Important**: VLAN 3 is NOT configured in pfSense. It's a non-routed, local storage network for direct NFS/iSCSI traffic between Proxmox and storage.

---

## Step 8: Configure WAN Failover (Gateway Groups)

### Configure WAN Interfaces

1. Go to **Interfaces → WAN**
   - IPv4 Configuration Type: `DHCP`
   - Save

2. Go to **Interfaces → WAN2** (OPT1)
   - Enable: ✓ Checked
   - Description: `WAN2`
   - IPv4 Configuration Type: `DHCP`
   - Save

### Create Gateway Groups

1. Navigate to **System → Routing → Gateway Groups**

2. Click **+ Add** to create failover group:
   - Group Name: `WAN_Failover`
   - **Gateway Priority**:
     - WAN_DHCP: `Tier 1`
     - WAN2_DHCP: `Tier 2`
   - Trigger Level: `Member Down`
   - Description: `WAN1 Primary, WAN2 Backup`
   - Click **Save**

3. Go to **Firewall → Rules → LAN** (and each VLAN)
   - Edit the default "Allow all" rule (or create new rules)
   - Advanced Options → Gateway: Select `WAN_Failover`
   - Save and Apply Changes

### Monitor Gateway Status

- Go to **Status → Gateways** to see current WAN status
- Go to **Status → Gateway Groups** to see failover group status

---

## Step 9: Verification and Testing

### Verify Proxmox Connectivity

1. From a device on VLAN 100 (Server_mgmt):
   ```bash
   ping 192.168.10.6    # Proxmox host management
   ping 192.168.10.1    # pfSense VLAN 100 gateway
   ```

2. Access Proxmox web interface:
   ```
   https://192.168.10.6:8006
   ```

### Verify VLAN Routing

1. From a device on VLAN 51 (Home):
   ```bash
   ping 192.168.51.1    # pfSense gateway for Home VLAN
   ping 8.8.8.8         # Internet connectivity
   ```

2. Verify inter-VLAN routing (if allowed by firewall rules):
   ```bash
   ping 192.168.50.1    # Server VLAN gateway
   ```

### Verify Storage VLAN

1. SSH into Proxmox:
   ```bash
   ping 192.168.3.x     # Your NAS storage IP on VLAN 3
   ```

2. Check NFS mount (if configured):
   ```bash
   df -h | grep Synology
   ```

### Verify WAN Failover

1. In pfSense, go to **Status → Gateways**
   - Verify WAN1 shows "Online" (primary)
   - Verify WAN2 shows "Online" (secondary)

2. Test failover:
   - Unplug WAN1 (Xfinity)
   - Refresh gateway status
   - WAN2 should become active
   - Test internet connectivity from a client

---

## Step 10: Updating the Realtek Driver

When a new version of the Realtek driver is released, you can update it manually after testing.

### Check Current Version

```bash
modinfo r8125 | grep version
dkms status
```

### Update Process

1. Check for new releases at:
   ```
   https://github.com/awesometic/realtek-r8125-dkms/releases
   ```

2. Download the new version:
```bash
cd /tmp
wget https://github.com/awesometic/realtek-r8125-dkms/releases/download/NEW_VERSION/realtek-r8125-dkms_NEW_VERSION_amd64.deb
```

3. Remove old version (optional, but recommended):
```bash
apt remove realtek-r8125-dkms -y
```

4. Install new version:
```bash
dpkg -i realtek-r8125-dkms_NEW_VERSION_amd64.deb
```

5. Verify installation:
```bash
dkms status
modinfo r8125 | grep version
```

6. Reboot to load the new driver:
```bash
reboot
```

7. After reboot, verify NICs are working:
```bash
ip addr
lsmod | grep r81
```

### If Update Fails

If the new driver causes issues:

1. Remove the problematic version:
```bash
apt remove realtek-r8125-dkms -y
dkms remove -m realtek-r8125 -v NEW_VERSION --all
```

2. Reinstall the known-good version (9.016.01-1):
```bash
cd /tmp
wget https://github.com/awesometic/realtek-r8125-dkms/releases/download/9.016.01-1/realtek-r8125-dkms_9.016.01-1_amd64.deb
dpkg -i realtek-r8125-dkms_9.016.01-1_amd64.deb
reboot
```

---

## Network Diagram

```
                                    Internet
                                       |
                    ┌──────────────────┴──────────────────┐
                    |                                      |
              Xfinity Cable                          T-Mobile 5G
              (WAN1 DHCP)                            (WAN2 DHCP)
                    |                                      |
                    |                                      |
            ┌───────┴────────────────────┬─────────────────┘
            │     Proxmox Host           │
            │   (192.168.10.6/24)        │
            │                            │
            │   ┌────────────────────┐   │
            │   │  pfSense VM 1000   │   │
            │   │                    │   │
            │   │  WAN:  vtnet1      │───┤ vmbr1 → enp1s0 (Realtek 2.5G)
            │   │  WAN2: vtnet2      │───┤ vmbr2 → enp2s0f0 (Realtek 1G)
            │   │  LAN:  vtnet0      │───┤ vmbr0 → enp3s0f0 (X520 SFP+)
            │   │                    │   │
            │   │  Gateway Groups:   │   │
            │   │  - WAN1 Tier 1     │   │
            │   │  - WAN2 Tier 2     │   │
            │   │                    │   │
            │   │  VLANs on vtnet0:  │   │
            │   │  - 21 IOT          │   │
            │   │  - 22 Television   │   │
            │   │  - 50 Server       │   │
            │   │  - 51 Home         │   │
            │   │  - 52 Guest        │   │
            │   │  - 100 Server_mgmt │   │
            │   └────────────────────┘   │
            └────────────┬───────────────┘
                         │
                    SFP+ Fiber
                (ALL VLANs Tagged)
                         │
                ┌────────┴────────┐
                │ Managed Switch  │
                │                 │
                │ Trunk: 21, 22,  │
                │  50, 51, 52,    │
                │  100, 3         │
                └────────┬────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    VLAN Access     VLAN Access     VLAN Access
      Ports           Ports           Ports
```

---

## Summary of Key Settings

### Proxmox Host
- **Management IP**: `192.168.10.6/24` (VLAN 100, tagged on vmbr0)
- **Storage IP**: `192.168.3.10/24` (VLAN 3, tagged on vmbr0, non-routed)
- **Emergency IP**: `192.168.99.6/24` (vmbr3, enp3s0f1 - no gateway)

### pfSense VM
- **VM ID**: 1000
- **CPU**: 6 cores (host type)
- **RAM**: 4096 MB
- **Disk**: 64 GB (local-zfs, SSD emulation)
- **WAN1** (vtnet1): DHCP from Xfinity (Primary)
- **WAN2** (vtnet2): DHCP from T-Mobile (Failover)
- **LAN** (vtnet0): 192.168.10.1/24 + VLANs

### VLAN Summary
| VLAN | Network | Gateway | Purpose | Routed? |
|------|---------|---------|---------|---------|
| 3 | 192.168.3.0/24 | N/A | Storage (Proxmox, NAS) | No |
| 21 | 192.168.21.0/24 | 192.168.21.1 | IOT | Yes |
| 22 | 192.168.22.0/24 | 192.168.22.1 | Television | Yes |
| 50 | 192.168.50.0/24 | 192.168.50.1 | Server | Yes |
| 51 | 192.168.51.0/24 | 192.168.51.1 | Home | Yes |
| 52 | 192.168.52.0/24 | 192.168.52.1 | Guest | Yes |
| 100 | 192.168.10.0/24 | 192.168.10.1 | Server_mgmt | Yes |

---

## Troubleshooting

### Cannot Access Proxmox
- Verify vmbr0.100 is up: `ip addr show vmbr0.100`
- Verify pfSense is routing VLAN 100
- Use emergency port (vmbr3 / 192.168.99.6)

### Realtek NICs Not Working
- Check driver loaded: `lsmod | grep r8125`
- Check dmesg for errors: `dmesg | grep -i realtek`
- Verify DKMS built module: `dkms status`
- **CRITICAL**: Do NOT blacklist r8169 driver - this causes enp2s0f0 (1GbE NIC) to fail
- Both r8125 and r8169 should be loaded simultaneously (this is normal and correct)
- Reboot after driver installation

### After Proxmox Kernel Update
- DKMS should automatically rebuild the driver for new kernels
- Verify with: `dkms status` (should show module for new kernel)
- If driver not rebuilt automatically: `dkms autoinstall`
- Check loaded module: `modinfo r8125`

### VLANs Not Working
- Verify vmbr0 has `bridge-vlan-aware yes`
- Verify switch trunk port configured correctly
- Check pfSense VLAN interface is enabled
- Verify pfSense has gateway IP on each VLAN

### WAN Failover Not Working
- Check **Status → Gateways** - both should be "Online"
- Verify gateway group configured correctly
- Ensure firewall rules use gateway group, not specific gateway
- Check gateway monitoring IPs are reachable

---

## Notes

- **Realtek Driver**: Using Awesometic's DKMS package (version 9.016.01-1)
- **DKMS**: Automatically rebuilds driver for new Proxmox kernels
- **Driver Source**: https://github.com/awesometic/realtek-r8125-dkms
- **r8169 Driver**: Do NOT blacklist - both r8125 and r8169 coexist normally
- **Hardware offloading**: Disabled in pfSense (not needed for VM)
- **VPN**: Tailscale configured separately (not covered in this guide)
- **Firewall rules**: Managed separately (not covered in this guide)
- **Proxmox Updates**: Driver automatically rebuilds via DKMS, no manual intervention needed
- **VLAN 3 (Storage)**: Intentionally NOT routed through pfSense for performance

---

**Document Version**: 2.0  
**Last Updated**: December 2025  
**pfSense Version**: Community Edition  
**Proxmox Version**: 8.x  
**Realtek Driver**: Awesometic r8125 DKMS 9.016.01-1
