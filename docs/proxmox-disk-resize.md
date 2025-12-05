# Proxmox Virtual Machine Disk Resize

## Overview

This procedure expands a virtual disk in Proxmox VE and extends the filesystem within the guest OS to use the additional space. The process involves increasing the virtual disk size at the hypervisor level, then expanding the partition and filesystem inside the VM.

Two methods are covered: command-line tools for simple cases, and a graphical approach using GParted for complex partition layouts (such as when swap partitions block expansion).

## Prerequisites

- Proxmox VE host with the target VM
- Root/sudo access to both Proxmox host and guest VM
- VM backup (strongly recommended before any disk operations)
- For complex layouts: GParted Live ISO or similar partitioning tool

## Procedure: Simple Expansion (No Swap in the Way)

Use this method when the partition to expand is at the end of the disk with no other partitions after it.

### Step 1: Increase Virtual Disk Size in Proxmox

#### Via Web Interface

1. Select the VM in Proxmox (VM must be stopped or running—live resize works for virtio and SCSI disks)
2. Navigate to **Hardware**
3. Select the disk to resize (e.g., `scsi0`, `virtio0`)
4. Click **Disk Action** → **Resize**
5. Enter the amount to add (e.g., `+10G` to add 10GB)
6. Click **Resize disk**

#### Via Command Line

```bash
qm resize <vmid> <disk> <size>
```

Example to add 5GB to virtio0 on VM 100:

```bash
qm resize 100 virtio0 +5G
```

### Step 2: Extend the Partition Inside the VM

SSH into the VM or access its console.

#### Identify the Disk and Partition

```bash
lsblk
```

Example output:
```
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0   30G  0 disk
├─sda1   8:1    0   29G  0 part /
└─sda2   8:2    0    1G  0 part [SWAP]
```

#### Using parted (Recommended for GPT disks)

Start parted on the disk:

```bash
sudo parted /dev/sda
```

View current partition layout:

```
(parted) print
```

Resize the target partition to use all available space:

```
(parted) resizepart 1 100%
```

If prompted about the partition being in use, confirm with `Yes`.

Exit parted:

```
(parted) quit
```

#### Using fdisk (Alternative for MBR disks)

For MBR partition tables, you may need to delete and recreate the partition:

```bash
sudo fdisk /dev/sda
```

1. Press `p` to print partition table (note the start sector)
2. Press `d` to delete the partition
3. Press `n` to create new partition
4. Accept defaults (same start sector, maximum end sector)
5. Press `w` to write changes

**Warning:** Be careful not to change the start sector, or data loss will occur.

### Step 3: Extend the Filesystem

#### For ext4 Filesystems

```bash
sudo resize2fs /dev/sda1
```

The filesystem will automatically expand to fill the partition.

#### For XFS Filesystems

XFS requires the filesystem to be mounted:

```bash
sudo xfs_growfs /
```

### Step 4: Verify the Expansion

Check the new filesystem size:

```bash
df -h
```

The root filesystem should now show the expanded size.

## Procedure: Complex Expansion (Using GParted)

Use this method when swap partitions or extended partitions block the expansion, or when you need to move partitions around.

### Step 1: Obtain GParted Live ISO

Download GParted Live or use any live Linux distribution with GParted:
- GParted Live ISO
- SystemRescue
- Parted Magic (commercial but feature-rich)

### Step 2: Upload ISO to Proxmox

1. In Proxmox, navigate to your storage (e.g., `local`)
2. Select **ISO Images**
3. Click **Upload** and select the GParted ISO
4. Wait for upload to complete

### Step 3: Increase Virtual Disk Size

Follow the same process as Step 1 in the Simple Expansion section above.

### Step 4: Configure VM to Boot from ISO

1. Select the VM in Proxmox
2. Navigate to **Hardware**
3. Click **Add** → **CD/DVD Drive**
4. Select your ISO storage and the GParted ISO image
5. Navigate to **Options** → **Boot Order**
6. Edit and move the CD-ROM to first position
7. Click **OK**

### Step 5: Boot into GParted

1. Start the VM
2. Access the console (noVNC or SPICE)
3. GParted Live will boot—accept defaults for keyboard and language
4. GParted will launch automatically and show your disk

### Step 6: Modify Partitions as Needed

Common scenarios:

#### Move Swap Partition to End of Disk

1. Right-click the swap partition
2. Select **Swapoff** to deactivate it
3. Right-click again and select **Resize/Move**
4. Drag the partition to the right end of the disk
5. Click **Resize/Move**

#### Extend Root Partition

1. Right-click the root partition
2. Select **Resize/Move**
3. Drag the right edge to fill available space
4. Click **Resize/Move**

#### Apply Changes

1. Click the green checkmark to apply all pending operations
2. Wait for operations to complete
3. Close GParted when finished

### Step 7: Shutdown and Remove Boot Media

1. Shut down the VM from within GParted (or use Proxmox console)
2. In Proxmox, select the VM → **Hardware**
3. Select the CD/DVD drive and click **Remove**
4. Navigate to **Options** → **Boot Order**
5. Restore hard disk to first position

### Step 8: Boot and Verify

1. Start the VM
2. Log in and verify disk size:
   ```bash
   df -h
   ```
3. Verify swap is active:
   ```bash
   free -h
   ```

## Verification

Confirm the expansion was successful:

```bash
# Check partition sizes
lsblk

# Check filesystem usage
df -h

# Check for any filesystem errors
sudo dmesg | grep -i error
```

## Troubleshooting

**Cannot resize disk in Proxmox:**
- VM may need to be stopped for some disk types
- Ensure disk isn't part of a snapshot (remove snapshots first)
- Check available storage space on the Proxmox storage backend

**Partition resize fails:**
- Boot from GParted to perform offline resize
- Check for filesystem errors: `sudo fsck -f /dev/sda1`
- Ensure partition isn't mounted (or use GParted live environment)

**Filesystem won't expand:**
- For ext4, ensure the partition was expanded first
- For XFS, the filesystem must be mounted
- Check for filesystem errors before expanding

**Swap partition missing after reboot:**
- Verify swap partition UUID matches /etc/fstab
- Update fstab if UUID changed: `blkid /dev/sda2`
- Reactivate swap: `sudo swapon -a`

**VM won't boot after changes:**
- Boot from GParted and verify partition table is intact
- Check boot flag is set on correct partition
- For UEFI, verify EFI system partition is intact

**Data loss or corruption:**
- Restore from backup
- This is why backups before disk operations are critical

## Notes

- Always backup VMs before disk operations
- Live resize works for virtio-scsi and virtio-blk disks in most cases
- LVM-based guests require additional steps to extend logical volumes
- For shrinking disks, the process is reversed but more complex and risky
- ZFS and Btrfs have their own expansion methods
- Snapshots may prevent resize operations—delete them first if needed
- Cloud-init enabled VMs may auto-expand on boot with proper configuration
