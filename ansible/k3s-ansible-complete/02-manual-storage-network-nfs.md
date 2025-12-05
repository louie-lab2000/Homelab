# Adding Storage Network and NFS to K3s

## Learning Document 2: Second NICs and NFS Storage

This document shows how to add a dedicated storage network to your K3s nodes and install the NFS CSI driver for shared storage.

**Purpose:** Understanding multi-homed networking and Kubernetes storage provisioners.

---

## Overview

### Why a Separate Storage Network?

| Benefit | Explanation |
|---------|-------------|
| **Isolation** | Storage traffic doesn't compete with application traffic |
| **Security** | NAS isn't exposed to your DMZ/application VLAN |
| **Performance** | Dedicated bandwidth for storage I/O |

### Network Layout

```
                    ┌─────────────────────────────────────────┐
                    │              K3s Node                   │
                    │                                         │
    Application     │   ens18 ◄──────────────────────────────┼──► 192.168.50.x (K3s, Ingress)
    Traffic         │                                         │
                    │                                         │
    Storage         │   ens19 ◄──────────────────────────────┼──► 192.168.3.x (NFS, Storage)
    Traffic         │                                         │
                    └─────────────────────────────────────────┘
```

---

## Phase 1: Add Second NIC in Proxmox

**Do this in Proxmox UI for each VM (node-1, node-2, node-3)**

### 1.1 Add Network Device

1. Select VM → **Hardware** → **Add** → **Network Device**
2. Configure:
   - **Bridge:** `vmbr0`
   - **VLAN Tag:** `3` (your storage VLAN)
   - **Model:** `VirtIO (paravirtualized)`
3. Click **Add**

**Note:** You can add the NIC while the VM is running. The interface appears immediately but isn't configured yet.

### 1.2 Verify NIC Appears in Linux

```bash
# SSH to each node and check
ip link show

# You should see ens19 (or similar) in the list
# It will show "state DOWN" because it's not configured yet
```

---

## Phase 2: Configure Static IPs on Storage Interface

**Run on each node (adjust IP for each)**

### 2.1 Check Interface Name

```bash
# The new NIC is usually ens19, but verify
ip link show

# Look for the interface that's DOWN and unconfigured
# Example output:
# 3: ens19: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN ...
```

### 2.2 Create Interface Configuration (Debian)

On **node-1**:
```bash
cat <<EOF | sudo tee /etc/network/interfaces.d/ens19-storage
# Storage VLAN interface for NFS access
auto ens19
iface ens19 inet static
    address 192.168.3.41
    netmask 255.255.255.0
    # No gateway - storage network only, main gateway on ens18
EOF
```

On **node-2**:
```bash
cat <<EOF | sudo tee /etc/network/interfaces.d/ens19-storage
auto ens19
iface ens19 inet static
    address 192.168.3.42
    netmask 255.255.255.0
EOF
```

On **node-3**:
```bash
cat <<EOF | sudo tee /etc/network/interfaces.d/ens19-storage
auto ens19
iface ens19 inet static
    address 192.168.3.43
    netmask 255.255.255.0
EOF
```

**Why no gateway?**
- Each network interface can only have one default gateway
- The main gateway is on ens18 (for internet/general traffic)
- Storage traffic to 192.168.3.x will automatically use ens19 (same subnet)

### 2.3 Bring Up the Interface

```bash
# Method 1: Use ifup
sudo ifup ens19

# Method 2: If ifup doesn't work, use ip commands
sudo ip addr add 192.168.3.41/24 dev ens19  # adjust IP per node
sudo ip link set ens19 up
```

### 2.4 Verify Configuration

```bash
# Check the interface has an IP
ip addr show ens19

# Expected output (example for node-1):
# 3: ens19: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ...
#     inet 192.168.3.41/24 brd 192.168.3.255 scope global ens19

# Test connectivity to NAS
ping -c 3 192.168.3.3  # Your Synology IP
```

---

## Phase 3: Configure NFS Share on Synology

**Do this in Synology DSM web interface**

### 3.1 Enable NFS Service

1. **Control Panel** → **File Services** → **NFS**
2. Enable NFS service
3. Maximum NFS protocol: **NFSv4.1**

### 3.2 Create Shared Folder

1. **Control Panel** → **Shared Folder** → **Create**
2. Name: `kubestor`
3. Location: Select your volume
4. Click through wizard

### 3.3 Set NFS Permissions

1. Select `kubestor` → **Edit** → **NFS Permissions**
2. Click **Create**
3. Configure:

| Setting | Value |
|---------|-------|
| Hostname or IP | `192.168.3.0/24` (or individual IPs) |
| Privilege | Read/Write |
| Squash | **No mapping** |
| Security | sys |
| Enable async | ✅ |
| Allow connections from non-privileged ports | ✅ |
| Allow users to access mounted subfolders | ✅ |

**Why "No mapping" (no_root_squash)?**
- Kubernetes pods often run as root
- CSI driver needs root access to create directories
- Without this, permission errors occur

### 3.4 Note the Export Path

Your export path will be: `/volume1/kubestor`

---

## Phase 4: Test NFS Access from Nodes

**Run on any K3s node**

### 4.1 Install NFS Client (if not already)

```bash
sudo apt install -y nfs-common
```

### 4.2 Check NFS Exports

```bash
# Query the NFS server for available exports
showmount -e 192.168.3.3

# Expected output:
# Export list for 192.168.3.3:
# /volume1/kubestor 192.168.3.0/24
```

### 4.3 Test Manual Mount

```bash
# Create test mount point
sudo mkdir -p /tmp/nfs-test

# Mount the share
sudo mount -t nfs 192.168.3.3:/volume1/kubestor /tmp/nfs-test

# Test write access
sudo touch /tmp/nfs-test/.write-test
sudo rm /tmp/nfs-test/.write-test

# Unmount
sudo umount /tmp/nfs-test
sudo rmdir /tmp/nfs-test

echo "NFS access verified!"
```

---

## Phase 5: Install NFS CSI Driver

**Run on node-1 (or any node with kubectl/helm)**

### 5.1 Understanding CSI

**What is CSI?**
- Container Storage Interface
- Standard API for storage providers
- Allows Kubernetes to dynamically provision storage

**What does the NFS CSI driver do?**
1. Watches for PersistentVolumeClaims requesting NFS storage
2. Creates a subdirectory on the NFS share
3. Creates a PersistentVolume pointing to that subdirectory
4. Binds the PVC to the PV

### 5.2 Add Helm Repository

```bash
# Add the NFS provisioner repo
helm repo add nfs-subdir-external-provisioner \
    https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

# Update repo cache
helm repo update
```

### 5.3 Create Namespace

```bash
kubectl create namespace nfs-provisioner
```

### 5.4 Install the Provisioner

```bash
helm install nfs-synology nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --namespace nfs-provisioner \
    --set nfs.server=192.168.3.3 \
    --set nfs.path=/volume1/kubestor \
    --set storageClass.name=nfs-synology \
    --set storageClass.defaultClass=false \
    --set storageClass.accessModes=ReadWriteMany \
    --set storageClass.reclaimPolicy=Retain \
    --set storageClass.volumeBindingMode=Immediate \
    --set nfs.mountOptions[0]=nfsvers=4.1 \
    --set nfs.mountOptions[1]=hard \
    --set nfs.mountOptions[2]=intr
```

**Breaking down the flags:**

| Flag | Purpose |
|------|---------|
| `nfs.server` | IP of your NFS server |
| `nfs.path` | Export path on the server |
| `storageClass.name` | Name you'll use in PVCs |
| `storageClass.defaultClass=false` | Don't make this the default (Longhorn is default) |
| `storageClass.accessModes=ReadWriteMany` | Multiple pods can mount simultaneously |
| `storageClass.reclaimPolicy=Retain` | Keep data when PVC is deleted |
| `nfs.mountOptions` | NFS mount options for performance/reliability |

**Mount options explained:**
- `nfsvers=4.1`: Use NFSv4.1 protocol
- `hard`: Retry NFS requests forever (vs `soft` which gives up)
- `intr`: Allow interruption of hung NFS operations

### 5.5 Verify Installation

```bash
# Check the provisioner pod
kubectl get pods -n nfs-provisioner

# Expected: nfs-synology-nfs-subdir-external-provisioner-xxxxx   Running

# Check the StorageClass was created
kubectl get storageclass

# Expected output shows both:
# longhorn (default)   driver.longhorn.io   ...
# nfs-synology         cluster.local/nfs-synology-nfs-subdir-external-provisioner   ...
```

---

## Phase 6: Test NFS Provisioning

### 6.1 Create a Test PVC

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-test-pvc
  namespace: default
spec:
  storageClassName: nfs-synology
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Mi
EOF
```

### 6.2 Check PVC Status

```bash
# Watch the PVC
kubectl get pvc nfs-test-pvc

# Should show:
# NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# nfs-test-pvc   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   100Mi      RWX            nfs-synology   5s
```

**What happened behind the scenes:**
1. You created a PVC requesting `nfs-synology` storage
2. The NFS provisioner saw the request
3. It created a directory on Synology: `/volume1/kubestor/default-nfs-test-pvc-pvc-xxxxx`
4. It created a PV pointing to that directory
5. It bound the PVC to the PV

### 6.3 Verify on Synology

If you SSH to your Synology or browse via File Station, you'll see:
```
/volume1/kubestor/
└── default-nfs-test-pvc-pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/
```

### 6.4 Clean Up Test

```bash
kubectl delete pvc nfs-test-pvc

# Note: Because reclaimPolicy=Retain, the directory on Synology remains
# You'd need to manually delete it if you want it gone
```

---

## Summary: Storage Options

You now have two storage classes:

| StorageClass | Type | Access Modes | Use Case |
|--------------|------|--------------|----------|
| `longhorn` | Block (replicated) | ReadWriteOnce | Databases, single-pod apps |
| `nfs-synology` | NFS (shared) | ReadWriteMany | Shared files, multi-pod access |

### When to Use Which

**Use Longhorn when:**
- App needs fast local storage
- Data should be replicated across nodes
- Single pod accesses the volume
- Examples: databases, stateful apps

**Use NFS when:**
- Multiple pods need same data
- Sharing files between pods
- Large media files
- Backup storage
- Examples: media servers, shared configs

### Example PVC for Each

**Longhorn (default):**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-database-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  # storageClassName not needed - longhorn is default
```

**NFS:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-shared-files-pvc
spec:
  storageClassName: nfs-synology
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 50Gi
```

---

## Key Concepts Learned

### 1. Multi-Homed Networking
Nodes can have multiple network interfaces for different purposes. No routing needed between them - traffic goes out the right interface based on destination subnet.

### 2. NFS Permissions
`no_root_squash` is essential for Kubernetes. Without it, the CSI driver can't create directories or set permissions.

### 3. CSI Drivers
CSI is a plugin system for storage. The NFS provisioner is just one example. Others exist for:
- Cloud storage (AWS EBS, GCP PD, Azure Disk)
- Local storage
- Ceph, GlusterFS
- And many more

### 4. Storage Classes
StorageClasses abstract storage providers. Apps don't need to know if storage is NFS, Longhorn, or anything else - they just request a class.

### 5. Access Modes
- `ReadWriteOnce (RWO)`: One pod can mount read-write
- `ReadOnlyMany (ROX)`: Many pods can mount read-only
- `ReadWriteMany (RWX)`: Many pods can mount read-write

NFS supports RWX, which Longhorn doesn't (for block volumes).
