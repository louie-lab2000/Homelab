# Proxmox Power Management and Optimization

## Overview

This procedure configures CPU power management on Proxmox VE hosts to reduce power consumption and heat output. By default, Proxmox may run CPUs at higher performance states than necessary for typical homelab workloads. Switching to more conservative power governors and enabling additional power-saving features can significantly reduce idle power draw—often by 10-30 watts or more depending on hardware.

## Prerequisites

- Proxmox VE installed and operational
- Root/sudo access to Proxmox host
- (Optional) Kill-a-Watt or similar power meter to measure actual consumption

## Procedure

### Step 1: Check Current CPU Governor

Open a shell on your Proxmox node (either via SSH or the web console) and check the current CPU frequency scaling governor:

```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

Common governors include:
- **performance:** CPU runs at maximum frequency (highest power use)
- **powersave:** CPU runs at minimum frequency (lowest power use)
- **ondemand:** Scales frequency based on load (balanced)
- **schedutil:** Kernel scheduler-driven scaling (modern default)

### Step 2: List Available Governors

Check which governors are available on your system:

```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
```

Typical output: `performance powersave`

Modern Intel CPUs with the `intel_pstate` driver usually only offer `performance` and `powersave`. The `powersave` governor still allows the CPU to scale up under load—it just prefers lower frequencies when possible.

### Step 3: Set CPU Governor to Powersave

Apply the powersave governor to all CPU cores:

```bash
echo "powersave" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

Verify the change:

```bash
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

All cores should now show `powersave`.

### Step 4: Install PowerTOP (Optional but Recommended)

PowerTOP is an Intel tool that identifies power-hungry processes and can automatically tune various kernel and device settings for lower power consumption:

```bash
apt update
apt install powertop
```

Run PowerTOP in interactive mode to see current power estimates:

```bash
powertop
```

Use the Tab key to navigate between screens. The "Tunables" tab shows optimization opportunities.

### Step 5: Apply PowerTOP Auto-Tune

Apply all recommended power-saving settings:

```bash
powertop --auto-tune
```

This adjusts settings such as:
- USB autosuspend
- SATA link power management
- PCI device runtime power management
- Audio codec power management
- Network interface settings

**Note:** Some of these settings may cause issues with specific hardware. Test thoroughly before making them permanent.

### Step 6: Make Settings Persistent Across Reboots

Create a cron job to apply these settings at boot:

```bash
crontab -e
```

Add the following lines at the end of the file:

```cron
@reboot echo "powersave" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1
@reboot /usr/sbin/powertop --auto-tune >/dev/null 2>&1
```

Alternatively, create a systemd service for cleaner management:

```bash
nano /etc/systemd/system/powersave.service
```

Add the following content:

```ini
[Unit]
Description=Power Saving Settings
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo powersave | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
ExecStart=/usr/sbin/powertop --auto-tune
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Enable the service:

```bash
systemctl enable powersave.service
```

### Step 7: Additional BIOS/UEFI Settings

For maximum power savings, also review your system's BIOS settings:

- **C-States:** Enable all available C-states (C1E, C3, C6, etc.) to allow deeper CPU sleep
- **Package C-State Limit:** Set to the deepest available state
- **Intel SpeedStep/AMD Cool'n'Quiet:** Ensure enabled
- **PCIe ASPM:** Enable Active State Power Management
- **USB Legacy Support:** Disable if not needed
- **Unused Onboard Devices:** Disable unused controllers (serial ports, parallel ports, etc.)

### Step 8: Configure VM Power Settings

For VMs that don't need maximum performance, you can also limit their CPU allocation:

1. In the Proxmox web interface, select the VM
2. Go to **Hardware** → **Processors**
3. Set **CPU units** lower (default is 1024; lower values give less priority)
4. Consider limiting **CPU cores** to actual needs
5. For idle VMs, consider using **ballooning** to reduce memory footprint

## Verification

### Check Current CPU Frequency

View real-time CPU frequency for all cores:

```bash
watch -n1 "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq"
```

In powersave mode, idle frequencies should be at or near the minimum (often 800MHz or lower).

### Monitor Power Usage

If you have a power meter, compare before and after readings at idle. Typical savings range from 10-30 watts on desktop-class hardware.

Without a physical meter, you can estimate using CPU-reported values:

```bash
turbostat --Summary --quiet --show PkgWatt,RAMWatt --interval 5
```

(Requires `linux-tools-generic` package on some systems)

### Run PowerTOP Report

Generate an HTML report for detailed analysis:

```bash
powertop --html=powertop-report.html
```

Open the report in a browser to review power consumption breakdown and remaining optimization opportunities.

## Troubleshooting

**Governor resets after reboot:**
- Verify the cron job or systemd service is properly configured
- Check for conflicting services that might be setting the governor
- Some systems have `cpufrequtils` or `thermald` that may override settings

**USB devices not working after auto-tune:**
- PowerTOP may enable aggressive USB autosuspend
- Disable specific tunables: `echo 'on' > /sys/bus/usb/devices/X-X/power/control`
- Or skip powertop auto-tune and apply settings selectively

**Network performance degraded:**
- Some network adapters don't handle power management well
- Disable specific adapter power management if needed
- Check for `Energy Efficient Ethernet` settings that may add latency

**VMs experiencing latency:**
- The powersave governor may introduce slight latency as CPUs scale up
- For latency-sensitive VMs, consider pinning them to specific cores
- Or use `schedutil` governor if available for more responsive scaling

**System feels sluggish:**
- The powersave governor may be too aggressive for your workload
- Try `ondemand` or `schedutil` governors for better balance
- Monitor CPU frequency during typical workloads to ensure it's scaling up

## Notes

- Power savings vary significantly by hardware; newer CPUs tend to have better power management
- These settings affect all VMs and containers on the host
- For production workloads where latency matters, test thoroughly before deploying
- Consider separate nodes for power-sensitive vs. performance-sensitive workloads
- ECC memory typically uses slightly more power than non-ECC
- NVMe drives use more power than SATA SSDs at idle
- HDDs can be spun down for significant savings if not accessed frequently (configure via `hdparm`)
