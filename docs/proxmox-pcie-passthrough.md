# Proxmox PCIe Passthrough Configuration

## Overview

PCIe passthrough allows a virtual machine to have direct access to physical hardware, such as a GPU, network card, or storage controller. This is useful when you need near-native performance or when the guest OS requires direct hardware access (e.g., GPU computing, dedicated NIC for pfSense).

This procedure configures IOMMU (Input-Output Memory Management Unit) on the Proxmox host and prepares the system to pass through PCIe devices to VMs.

## Prerequisites

- Proxmox VE installed and operational
- CPU with IOMMU support (Intel VT-d or AMD-Vi)
- IOMMU enabled in BIOS/UEFI (typically under CPU or chipset settings)
- Root/sudo access to the Proxmox host
- Knowledge of which PCIe device you intend to pass through

## Procedure

### Step 1: Determine Boot Mode

Check whether your system uses legacy GRUB or EFI boot:

```bash
ls /sys/firmware/efi
```

If this directory exists, you're using EFI boot. If not, you're using legacy GRUB boot.

### Step 2: Enable IOMMU Support

#### For EFI Boot Systems (most modern installations)

Edit the kernel command line:

```bash
nano /etc/kernel/cmdline
```

Add the appropriate IOMMU parameter to the existing line:

For Intel CPUs:
```
intel_iommu=on
```

For AMD CPUs:
```
amd_iommu=on
```

Save the file and refresh the boot configuration:

```bash
proxmox-boot-tool refresh
```

#### For Legacy GRUB Boot Systems

Edit the GRUB configuration:

```bash
nano /etc/default/grub
```

Modify the `GRUB_CMDLINE_LINUX_DEFAULT` line:

For Intel CPUs:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"
```

For AMD CPUs:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on"
```

Save the file and update GRUB:

```bash
update-grub
```

### Step 3: Load VFIO Modules at Boot

Edit the modules file to ensure VFIO modules load at boot:

```bash
nano /etc/modules
```

Add the following lines:

```
vfio
vfio_iommu_type1
vfio_pci
```

Note: `vfio_virqfd` was merged into the `vfio` module in newer kernels and is no longer needed as a separate entry.

### Step 4: Configure IOMMU Interrupt Remapping (Optional but Recommended)

Create a configuration file to allow unsafe interrupts if needed (required for some older hardware):

```bash
echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/iommu_unsafe_interrupts.conf
```

Configure KVM to ignore certain MSRs (helps with GPU passthrough stability):

```bash
echo "options kvm ignore_msrs=1" > /etc/modprobe.d/kvm.conf
```

### Step 5: Blacklist Graphics Drivers (For GPU Passthrough Only)

If passing through a GPU, prevent the host from loading graphics drivers:

```bash
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf
echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf
echo "blacklist amdgpu" >> /etc/modprobe.d/blacklist.conf
```

### Step 6: Identify the PCIe Device

List all PCIe devices to find your target device:

```bash
lspci
```

Note the device address (e.g., `82:00.0` for a device on bus 82, slot 00, function 0).

Get detailed information including vendor and device IDs:

```bash
lspci -n -s 82:00 -v
```

The output will show hex values in the format `vendor:device` (e.g., `10de:1b81` for an NVIDIA GPU).

### Step 7: Bind Device to VFIO-PCI Driver

Configure VFIO to claim the device at boot. Replace the hex values with your device's IDs:

```bash
echo "options vfio-pci ids=10de:1b81,10de:10f0 disable_vga=1" > /etc/modprobe.d/vfio.conf
```

Note: If your device has multiple functions (e.g., GPU with audio controller), include all relevant IDs separated by commas.

### Step 8: Apply Changes

Update the initramfs to include all configuration changes:

```bash
update-initramfs -u -k all
```

### Step 9: Reboot

Reboot the Proxmox host to apply all changes:

```bash
reboot
```

## Verification

After reboot, verify the configuration:

Check IOMMU is enabled:
```bash
dmesg | grep -i iommu
```

You should see messages indicating IOMMU groups are being set up.

Verify VFIO driver is bound to your device:
```bash
lspci -k -s 82:00
```

The `Kernel driver in use` should show `vfio-pci`.

List IOMMU groups to ensure your device is isolated:
```bash
find /sys/kernel/iommu_groups/ -type l
```

## Troubleshooting

**IOMMU not detected:**
- Verify IOMMU (VT-d/AMD-Vi) is enabled in BIOS
- Check for BIOS updates that may improve IOMMU support
- Some consumer motherboards have limited or buggy IOMMU implementations

**Device not in its own IOMMU group:**
- Some devices share IOMMU groups and cannot be passed through individually
- ACS override patch may help but introduces security considerations
- Consider using a different PCIe slot

**VM fails to start with passed-through device:**
- Check Proxmox logs: `journalctl -xe`
- Verify device IDs in vfio.conf match your hardware
- Ensure no other driver has claimed the device

**GPU passthrough black screen:**
- Some NVIDIA GPUs require hiding the hypervisor (add `cpu: host,hidden=1` to VM config)
- May need to pass through the GPU's audio device as well
- ROM file may be required for some cards

## Notes

- IOMMU groupings are determined by hardware and cannot be changed through software alone
- PCIe devices in the same IOMMU group must all be passed through together or not at all
- After passing through a device, it is no longer available to the Proxmox host
- Some devices (particularly GPUs) may require additional configuration in the VM settings
