# Manual K3s HA Cluster Setup Guide

## Learning Document 1: Building the Cluster from Scratch

This document shows every command needed to manually build a 3-node K3s HA cluster with KubeVIP, MetalLB, Longhorn, and Rancher. No Ansible, no scripts - just terminal commands.

**Purpose:** Understanding what happens "under the hood" when the Ansible playbook runs.

---

## Prerequisites

### Your Environment
- 3 Debian 13 VMs (node-1, node-2, node-3)
- Each VM has: 192.168.50.41, .42, .43
- Each VM has a second 200GB disk for Longhorn
- User `ansible` with passwordless sudo on all nodes
- Network interface: `ens18`

### IP Plan
| IP | Purpose |
|----|---------|
| 192.168.50.41-43 | Node IPs |
| 192.168.50.50 | KubeVIP (API server HA) |
| 192.168.50.60 | Longhorn UI |
| 192.168.50.61 | Ingress Controller |
| 192.168.50.62-100 | Available for apps |

---

## Phase 1: Prepare All Nodes

**Run these commands on ALL THREE nodes (node-1, node-2, node-3)**

### 1.1 Update System and Install Packages

```bash
# Update package lists and upgrade existing packages
sudo apt update && sudo apt upgrade -y

# Install required packages
# - curl, wget: downloading files
# - open-iscsi: required by Longhorn for block storage
# - nfs-common: NFS client support
# - jq: JSON parsing (useful for kubectl output)
# - parted: disk partitioning
sudo apt install -y curl wget apt-transport-https ca-certificates \
    gnupg lsb-release open-iscsi nfs-common util-linux jq parted
```

**Why these packages?**
- `open-iscsi`: Longhorn uses iSCSI internally to present volumes to pods
- `nfs-common`: For NFS storage support later
- `parted`: To partition the Longhorn disk

### 1.2 Load Required Kernel Modules

```bash
# Load modules immediately
sudo modprobe br_netfilter    # Bridge netfilter (required for iptables to see bridged traffic)
sudo modprobe overlay          # OverlayFS (container filesystem)
sudo modprobe ip_vs            # IP Virtual Server (load balancing)
sudo modprobe ip_vs_rr         # Round-robin scheduling
sudo modprobe ip_vs_wrr        # Weighted round-robin
sudo modprobe ip_vs_sh         # Source hashing
sudo modprobe iscsi_tcp        # iSCSI over TCP (for Longhorn)

# Make modules load on boot
cat <<EOF | sudo tee /etc/modules-load.d/k3s.conf
br_netfilter
overlay
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
iscsi_tcp
EOF
```

**Why these modules?**
- `br_netfilter`: Kubernetes networking requires iptables to see traffic crossing bridges
- `overlay`: Container runtimes use overlay filesystems
- `ip_vs_*`: IPVS is a high-performance load balancer used by kube-proxy

### 1.3 Configure Kernel Parameters (sysctl)

```bash
# Create sysctl configuration for Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes.conf
# Allow iptables to see bridged traffic
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1

# Enable IP forwarding (required for pod networking)
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Increase inotify limits (for watching many files)
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
EOF

# Apply immediately
sudo sysctl --system
```

**Why these settings?**
- IP forwarding: Pods need to send traffic through the node
- Bridge netfilter: iptables rules must apply to bridged (container) traffic
- inotify: Kubernetes watches many files; defaults are too low

### 1.4 Disable Swap

```bash
# Disable swap immediately
sudo swapoff -a

# Prevent swap from coming back on reboot
# This comments out any swap entries in /etc/fstab
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

**Why disable swap?**
Kubernetes (kubelet) refuses to run if swap is enabled. Memory management in containers assumes no swap.

### 1.5 Start iSCSI Service

```bash
# Enable and start iscsid (required for Longhorn)
sudo systemctl enable iscsid
sudo systemctl start iscsid
```

---

## Phase 2: Install K3s on First Master (node-1)

**Run these commands ONLY on node-1**

### 2.1 Install K3s with Cluster Initialization

```bash
# Download and run K3s installer
curl -sfL https://get.k3s.io | sh -s - server \
    --cluster-init \
    --disable servicelb \
    --disable traefik \
    --write-kubeconfig-mode 644 \
    --tls-san 192.168.50.50 \
    --node-name node-1.louielab.cc
```

**Breaking down the flags:**

| Flag | Purpose |
|------|---------|
| `--cluster-init` | Initialize embedded etcd for HA (instead of SQLite) |
| `--disable servicelb` | Don't use K3s built-in load balancer (we'll use MetalLB) |
| `--disable traefik` | Don't install Traefik (we'll use ingress-nginx) |
| `--write-kubeconfig-mode 644` | Make kubeconfig readable (for non-root kubectl) |
| `--tls-san 192.168.50.50` | Add VIP to API server certificate (for KubeVIP) |
| `--node-name` | FQDN hostname for the node |

### 2.2 Wait for K3s to Start

```bash
# Check K3s service status
sudo systemctl status k3s

# Wait for node to be ready
sudo kubectl get nodes
# Should show: node-1.louielab.cc   Ready   control-plane,master   ...
```

### 2.3 Get the Join Token

```bash
# This token is needed for other nodes to join
sudo cat /var/lib/rancher/k3s/server/node-token
# Save this value - you'll need it for node-2 and node-3
```

### 2.4 Set Up kubectl for Non-Root User

```bash
# Create .kube directory
mkdir -p ~/.kube

# Copy kubeconfig
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# Fix ownership
sudo chown $(id -u):$(id -g) ~/.kube/config

# Test it works
kubectl get nodes
```

---

## Phase 3: Deploy KubeVIP (node-1)

KubeVIP provides a virtual IP for the Kubernetes API server. Without it, if node-1 dies, you can't reach the API.

**Run on node-1**

### 3.1 Set Environment Variables

```bash
# KubeVIP configuration
export VIP=192.168.50.50
export INTERFACE=ens18
export KVVERSION=v1.0.2
```

### 3.2 Generate KubeVIP Manifest

```bash
# Create the static pod manifest directory if it doesn't exist
sudo mkdir -p /var/lib/rancher/k3s/server/manifests

# Pull the KubeVIP image and generate manifest
sudo ctr image pull ghcr.io/kube-vip/kube-vip:$KVVERSION

# Generate the DaemonSet manifest
sudo ctr run --rm --net-host \
    ghcr.io/kube-vip/kube-vip:$KVVERSION vip /kube-vip manifest daemonset \
    --interface $INTERFACE \
    --address $VIP \
    --inCluster \
    --taint \
    --controlplane \
    --arp \
    --leaderElection | sudo tee /var/lib/rancher/k3s/server/manifests/kube-vip.yaml
```

**What this creates:**
- A DaemonSet that runs on all control plane nodes
- Uses ARP to announce the VIP on the network
- Leader election ensures only one node holds the VIP at a time
- If the leader dies, another node takes over

### 3.3 Verify KubeVIP is Running

```bash
# Wait a moment, then check
kubectl get pods -n kube-system | grep kube-vip

# Test the VIP responds
curl -k https://192.168.50.50:6443/healthz
# Should return "ok" or a 401 (both mean API is up)

# Ping the VIP
ping -c 3 192.168.50.50
```

---

## Phase 4: Join Additional Masters (node-2 and node-3)

**Run on node-2 and node-3**

### 4.1 Install K3s and Join Cluster

```bash
# Set the token (from node-1's /var/lib/rancher/k3s/server/node-token)
TOKEN="YOUR_TOKEN_HERE"

# Set this node's name (change for each node)
NODE_NAME="node-2.louielab.cc"  # or node-3.louielab.cc

# Install and join
curl -sfL https://get.k3s.io | sh -s - server \
    --server https://192.168.50.50:6443 \
    --token $TOKEN \
    --disable servicelb \
    --disable traefik \
    --write-kubeconfig-mode 644 \
    --tls-san 192.168.50.50 \
    --node-name $NODE_NAME
```

**Key difference:** `--server` instead of `--cluster-init`
- Points to the VIP (not node-1's IP directly)
- Token authenticates this node to join the cluster

### 4.2 Verify Node Joined

```bash
# On any node
kubectl get nodes

# Should show all three:
# node-1.louielab.cc   Ready   control-plane,master   ...
# node-2.louielab.cc   Ready   control-plane,master   ...
# node-3.louielab.cc   Ready   control-plane,master   ...
```

---

## Phase 5: Install MetalLB

MetalLB provides LoadBalancer service type for bare metal clusters. Without it, `type: LoadBalancer` services would stay in "Pending" forever.

**Run on node-1 (or any node with kubectl)**

### 5.1 Apply MetalLB Manifest

```bash
# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml

# Wait for MetalLB pods to be ready
kubectl wait --namespace metallb-system \
    --for=condition=ready pod \
    --selector=app=metallb \
    --timeout=120s
```

### 5.2 Configure IP Address Pool

```bash
# Create the IP pool configuration
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.50.60-192.168.50.100
EOF
```

**What this does:** Tells MetalLB which IPs it can hand out to LoadBalancer services.

### 5.3 Configure L2 Advertisement

```bash
# Tell MetalLB to use Layer 2 mode (ARP)
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
    - default-pool
EOF
```

**Why L2 mode?**
- Simple - uses ARP to announce IPs
- Works on any network (no BGP routers needed)
- Perfect for home labs

### 5.4 Verify MetalLB

```bash
kubectl get pods -n metallb-system
# Should show controller and speaker pods running
```

---

## Phase 6: Prepare Longhorn Disks

**Run on ALL THREE nodes**

### 6.1 Identify the Storage Disk

```bash
# List all disks
lsblk

# Look for your 200GB disk (probably /dev/sdb or /dev/vdb)
# The output shows disk sizes to help identify the right one
```

### 6.2 Partition and Format the Disk

```bash
# Set your disk (adjust if different)
DISK=/dev/sdb

# Create GPT partition table
sudo parted -s $DISK mklabel gpt

# Create a single partition using 100% of the disk
sudo parted -s $DISK mkpart primary ext4 0% 100%

# Wait for partition to appear
sleep 2

# Format with ext4
sudo mkfs.ext4 ${DISK}1
```

### 6.3 Create Mount Point and Mount

```bash
# Create the Longhorn directory
sudo mkdir -p /var/lib/longhorn

# Get the partition UUID (stable across reboots)
UUID=$(sudo blkid -s UUID -o value ${DISK}1)
echo "Partition UUID: $UUID"

# Add to fstab for persistent mounting
echo "UUID=$UUID /var/lib/longhorn ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

# Mount it now
sudo mount /var/lib/longhorn

# Verify
df -h /var/lib/longhorn
```

**Why UUID instead of /dev/sdb1?**
Device names can change between reboots. UUIDs are stable.

---

## Phase 7: Install Longhorn

**Run on node-1**

### 7.1 Apply Longhorn Manifest

```bash
# Install Longhorn
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.7.2/deploy/longhorn.yaml

# Wait for Longhorn to be ready (this takes a few minutes)
kubectl -n longhorn-system rollout status deployment/longhorn-driver-deployer
```

### 7.2 Verify Longhorn Installation

```bash
# Check all pods
kubectl get pods -n longhorn-system

# All pods should eventually show Running or Completed
# This may take 2-3 minutes
```

### 7.3 Set Longhorn as Default StorageClass

```bash
# Check current storage classes
kubectl get storageclass

# If Longhorn isn't default, make it default
kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### 7.4 Expose Longhorn UI (Optional)

```bash
# Create a LoadBalancer service for the UI
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: longhorn-frontend-lb
  namespace: longhorn-system
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.50.60
  selector:
    app: longhorn-ui
  ports:
    - port: 80
      targetPort: 8000
EOF
```

Access Longhorn UI at: http://192.168.50.60

---

## Phase 8: Install Ingress-NGINX

**Run on node-1**

### 8.1 Add Helm Repository

```bash
# Install Helm if not present
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Add ingress-nginx repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

### 8.2 Install Ingress-NGINX

```bash
# Install with a specific LoadBalancer IP
helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.service.loadBalancerIP=192.168.50.61
```

### 8.3 Verify Installation

```bash
# Check the service got the IP
kubectl get svc -n ingress-nginx

# Should show EXTERNAL-IP as 192.168.50.61
```

---

## Phase 9: Install cert-manager

**Run on node-1**

### 9.1 Add Helm Repository

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

### 9.2 Install cert-manager

```bash
helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --version v1.17.4 \
    --set crds.enabled=true \
    --set startupapicheck.enabled=false
```

**Why `startupapicheck.enabled=false`?**
The startup check can timeout in slower environments. Disabling it avoids that issue.

### 9.3 Verify Installation

```bash
kubectl get pods -n cert-manager
# Should show cert-manager, cert-manager-webhook, and cert-manager-cainjector
```

---

## Phase 10: Install Rancher

**Run on node-1**

### 10.1 Add Helm Repository

```bash
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update
```

### 10.2 Create Namespace

```bash
kubectl create namespace cattle-system
```

### 10.3 Install Rancher

```bash
helm install rancher rancher-stable/rancher \
    --namespace cattle-system \
    --set hostname=rancher.louielab.cc \
    --set bootstrapPassword=admin \
    --set ingress.tls.source=rancher \
    --set ingress.ingressClassName=nginx
```

### 10.4 Wait for Rancher

```bash
# Watch the deployment
kubectl rollout status deployment/rancher -n cattle-system --timeout=300s

# Check pods
kubectl get pods -n cattle-system
```

### 10.5 Access Rancher

1. Add DNS entry: `rancher.louielab.cc → 192.168.50.61`
2. Open https://rancher.louielab.cc
3. Login with bootstrap password: `admin`
4. Set your permanent password

---

## Summary: What We Built

```
                         ┌─────────────────────────────┐
                         │    VIP: 192.168.50.50       │
                         │        (KubeVIP)            │
                         └──────────────┬──────────────┘
                                        │
         ┌──────────────────────────────┼──────────────────────────────┐
         │                              │                              │
         ▼                              ▼                              ▼
   ┌───────────┐                 ┌───────────┐                 ┌───────────┐
   │  node-1   │                 │  node-2   │                 │  node-3   │
   │  .50.41   │                 │  .50.42   │                 │  .50.43   │
   ├───────────┤                 ├───────────┤                 ├───────────┤
   │ K3s Server│                 │ K3s Server│                 │ K3s Server│
   │ etcd      │◄───────────────►│ etcd      │◄───────────────►│ etcd      │
   │ KubeVIP   │                 │ KubeVIP   │                 │ KubeVIP   │
   │ Longhorn  │                 │ Longhorn  │                 │ Longhorn  │
   └───────────┘                 └───────────┘                 └───────────┘

   MetalLB IP Pool: 192.168.50.60 - 192.168.50.100
   ├── 192.168.50.60 = Longhorn UI
   └── 192.168.50.61 = Ingress Controller (Rancher)
```

### Components Installed

| Component | Purpose | Access |
|-----------|---------|--------|
| K3s | Kubernetes distribution | API on port 6443 |
| KubeVIP | API server HA | VIP 192.168.50.50 |
| MetalLB | LoadBalancer services | Assigns IPs from pool |
| Longhorn | Distributed storage | http://192.168.50.60 |
| ingress-nginx | Reverse proxy | 192.168.50.61 |
| cert-manager | TLS certificates | Internal |
| Rancher | Cluster management | https://rancher.louielab.cc |

---

## Key Concepts Learned

### 1. HA Control Plane
Three nodes all run the control plane. etcd (the database) replicates across all three. If one node dies, the cluster keeps running.

### 2. KubeVIP
Provides a single IP that always points to a healthy API server. Uses leader election - only one node "owns" the VIP at a time.

### 3. MetalLB
Makes `type: LoadBalancer` work on bare metal. In cloud, the cloud provider assigns IPs. On bare metal, MetalLB does it.

### 4. Longhorn
Replicates storage across nodes. If a node dies, your data is still on the other nodes. Each node contributes its /dev/sdb to the storage pool.

### 5. Ingress
One IP (192.168.50.61) handles many services. Routes based on hostname in the HTTP request.
