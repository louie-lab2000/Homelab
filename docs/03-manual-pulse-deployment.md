# Deploying an Application to Kubernetes

## Learning Document 3: Manual Pulse Deployment

This document shows how to manually deploy Pulse (a Proxmox monitoring app) to your K3s cluster using kubectl and YAML manifests.

**Purpose:** Understanding Kubernetes resources: Deployments, Services, PVCs, and how they work together.

---

## Overview

### What We're Deploying

**Pulse** is a monitoring dashboard for Proxmox. It needs:
- A place to run (Pod/Deployment)
- Persistent storage for its database (PVC)
- A way to access it from the network (Service)

### Kubernetes Resources We'll Create

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Namespace: pulse                            │
│                                                                     │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────────────┐  │
│   │   Service   │────►│ Deployment  │────►│  Pod                │  │
│   │   (LB)      │     │             │     │  ┌───────────────┐  │  │
│   │ :80 → :7655 │     │ replicas: 1 │     │  │   Container   │  │  │
│   └─────────────┘     └─────────────┘     │  │   pulse:7655  │  │  │
│         │                                  │  └───────────────┘  │  │
│         │                                  │         │           │  │
│         ▼                                  │         ▼           │  │
│   192.168.50.62                            │  ┌───────────────┐  │  │
│   (MetalLB)                                │  │ Volume Mount  │  │  │
│                                            │  │   /data       │  │  │
│                                            │  └───────┬───────┘  │  │
│                                            └──────────┼──────────┘  │
│                                                       │             │
│                                            ┌──────────▼──────────┐  │
│                                            │        PVC          │  │
│                                            │    pulse-data       │  │
│                                            │   (Longhorn 1Gi)    │  │
│                                            └─────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Step 1: Create a Namespace

### What is a Namespace?

Namespaces are virtual clusters within your cluster. They provide:
- **Isolation:** Resources in different namespaces don't collide
- **Organization:** Group related resources together
- **Access control:** Apply permissions per namespace

### Create the Namespace

```bash
kubectl create namespace pulse
```

Or with YAML:
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: pulse
EOF
```

### Verify

```bash
kubectl get namespaces

# You'll see default namespaces plus yours:
# NAME              STATUS   AGE
# default           Active   1d
# kube-system       Active   1d
# pulse             Active   5s
# ...
```

---

## Step 2: Create a PersistentVolumeClaim (PVC)

### What is a PVC?

A PVC is a **request for storage**. It says:
- "I need X amount of storage"
- "I need it from this StorageClass"
- "I need these access modes"

The StorageClass (Longhorn) then provisions the actual storage.

### Understanding the YAML

```yaml
apiVersion: v1                    # Core API version
kind: PersistentVolumeClaim       # Resource type
metadata:
  name: pulse-data                # Name of this PVC
  namespace: pulse                # Which namespace
spec:
  storageClassName: longhorn      # Which StorageClass to use
  accessModes:
    - ReadWriteOnce               # Only one pod can mount read-write
  resources:
    requests:
      storage: 1Gi                # How much storage
```

### Create the PVC

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pulse-data
  namespace: pulse
spec:
  storageClassName: longhorn
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
```

### Verify

```bash
# Check PVC status
kubectl get pvc -n pulse

# Expected output:
# NAME         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# pulse-data   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   1Gi        RWO            longhorn       10s

# "Bound" means Longhorn created the storage and it's ready
```

**What happened:**
1. You created a PVC requesting 1Gi from Longhorn
2. Longhorn's provisioner saw the request
3. Longhorn created a replicated volume across your nodes
4. Longhorn created a PV (PersistentVolume) object
5. The PVC was bound to the PV

---

## Step 3: Create a Deployment

### What is a Deployment?

A Deployment manages Pods. It ensures:
- The right number of pods are running
- Pods are recreated if they die
- Rolling updates when you change the image

### Understanding the YAML

```yaml
apiVersion: apps/v1               # API version for Deployments
kind: Deployment
metadata:
  name: pulse                     # Deployment name
  namespace: pulse
  labels:
    app: pulse                    # Labels for organization
spec:
  replicas: 1                     # How many pods to run
  selector:
    matchLabels:
      app: pulse                  # How to find pods this Deployment owns
  template:                       # Pod template
    metadata:
      labels:
        app: pulse                # Pods get this label (must match selector)
    spec:
      containers:
        - name: pulse             # Container name
          image: rcourtman/pulse:latest
          ports:
            - containerPort: 7655
              name: http
          env:                    # Environment variables
            - name: DISCOVERY_SUBNET
              value: "192.168.10.0/24"
          volumeMounts:           # Where to mount volumes in container
            - name: pulse-data
              mountPath: /data
          resources:              # Resource requests/limits
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          livenessProbe:          # Is the container alive?
            httpGet:
              path: /api/health
              port: 7655
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:         # Is the container ready for traffic?
            httpGet:
              path: /api/health
              port: 7655
            initialDelaySeconds: 5
            periodSeconds: 10
      volumes:                    # Define volumes
        - name: pulse-data
          persistentVolumeClaim:
            claimName: pulse-data # Reference the PVC we created
```

### Key Concepts Explained

**Labels and Selectors:**
- Labels are key-value pairs attached to resources
- Selectors find resources by their labels
- The Deployment uses `selector.matchLabels` to find its pods
- The Service (next step) uses the same labels to find pods to send traffic to

**Resources:**
- `requests`: Minimum resources guaranteed to the container
- `limits`: Maximum resources the container can use
- `100m` CPU = 0.1 CPU cores
- `128Mi` memory = 128 mebibytes

**Probes:**
- `livenessProbe`: If this fails, Kubernetes restarts the container
- `readinessProbe`: If this fails, traffic stops being sent to this pod
- Both hit `/api/health` endpoint that Pulse provides

**Volume Mounts:**
- `volumes`: Defines what volumes exist for this pod
- `volumeMounts`: Where in the container filesystem to attach them

### Create the Deployment

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pulse
  namespace: pulse
  labels:
    app: pulse
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pulse
  template:
    metadata:
      labels:
        app: pulse
    spec:
      containers:
        - name: pulse
          image: rcourtman/pulse:latest
          ports:
            - containerPort: 7655
              name: http
          env:
            - name: DISCOVERY_SUBNET
              value: "192.168.10.0/24"
          volumeMounts:
            - name: pulse-data
              mountPath: /data
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /api/health
              port: 7655
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /api/health
              port: 7655
            initialDelaySeconds: 5
            periodSeconds: 10
      volumes:
        - name: pulse-data
          persistentVolumeClaim:
            claimName: pulse-data
EOF
```

### Verify

```bash
# Watch the deployment roll out
kubectl rollout status deployment/pulse -n pulse

# Check pods
kubectl get pods -n pulse

# Expected:
# NAME                     READY   STATUS    RESTARTS   AGE
# pulse-xxxxxxxxxx-xxxxx   1/1     Running   0          30s

# If STATUS is not Running, check logs:
kubectl logs -n pulse -l app=pulse

# Or describe the pod for events:
kubectl describe pod -n pulse -l app=pulse
```

---

## Step 4: Create a Service

### What is a Service?

A Service provides a stable network endpoint for pods. Pods come and go, but the Service IP stays constant.

**Service Types:**
| Type | Description |
|------|-------------|
| `ClusterIP` | Internal only, accessible within cluster |
| `NodePort` | Exposes on each node's IP at a static port |
| `LoadBalancer` | Gets external IP from MetalLB |

We'll use `LoadBalancer` to get an external IP.

### Understanding the YAML

```yaml
apiVersion: v1
kind: Service
metadata:
  name: pulse                     # Service name
  namespace: pulse
  labels:
    app: pulse
spec:
  type: LoadBalancer              # Service type
  loadBalancerIP: 192.168.50.62   # Request specific IP from MetalLB
  ports:
    - port: 80                    # External port
      targetPort: 7655            # Container port
      protocol: TCP
      name: http
  selector:
    app: pulse                    # Find pods with this label
```

**How it works:**
1. Traffic arrives at 192.168.50.62:80
2. Service finds pods with label `app: pulse`
3. Service forwards traffic to pod port 7655
4. If multiple pods exist, Service load-balances between them

### Create the Service

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: pulse
  namespace: pulse
  labels:
    app: pulse
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.50.62
  ports:
    - port: 80
      targetPort: 7655
      protocol: TCP
      name: http
  selector:
    app: pulse
EOF
```

### Verify

```bash
# Check the service
kubectl get svc -n pulse

# Expected:
# NAME    TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)        AGE
# pulse   LoadBalancer   10.43.xxx.xxx   192.168.50.62   80:xxxxx/TCP   10s

# EXTERNAL-IP should show 192.168.50.62 (from MetalLB)
```

**What happened:**
1. You created a LoadBalancer Service
2. MetalLB saw the request for `192.168.50.62`
3. MetalLB assigned that IP from its pool
4. MetalLB uses ARP to announce the IP on your network
5. Traffic to that IP is now routed to your Pulse pod

---

## Step 5: Access Pulse

Open in your browser: **http://192.168.50.62**

You should see the Pulse setup wizard.

---

## Alternative: Using an Ingress Instead

If you wanted to use the ingress controller instead of a direct LoadBalancer IP, you'd:

### 5.1 Change Service to ClusterIP

```yaml
apiVersion: v1
kind: Service
metadata:
  name: pulse
  namespace: pulse
spec:
  type: ClusterIP        # Internal only
  ports:
    - port: 80
      targetPort: 7655
  selector:
    app: pulse
```

### 5.2 Create an Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: pulse
  namespace: pulse
spec:
  ingressClassName: nginx              # Use ingress-nginx controller
  rules:
    - host: pulse.louielab.cc          # Hostname to match
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: pulse            # Send to this Service
                port:
                  number: 80
```

**Then:**
- Add DNS: `pulse.louielab.cc → 192.168.50.61` (ingress IP)
- Access via: `http://pulse.louielab.cc`

**Trade-offs:**

| Approach | Pros | Cons |
|----------|------|------|
| LoadBalancer | Simple, direct IP | Uses an IP per service |
| Ingress | One IP for many services, hostname routing | Extra hop, HTTP only |

---

## Putting It All Together: Single Manifest File

You can combine all resources into one file separated by `---`:

```yaml
# pulse-all.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: pulse
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pulse-data
  namespace: pulse
spec:
  storageClassName: longhorn
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pulse
  namespace: pulse
  labels:
    app: pulse
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pulse
  template:
    metadata:
      labels:
        app: pulse
    spec:
      containers:
        - name: pulse
          image: rcourtman/pulse:latest
          ports:
            - containerPort: 7655
          env:
            - name: DISCOVERY_SUBNET
              value: "192.168.10.0/24"
          volumeMounts:
            - name: pulse-data
              mountPath: /data
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
      volumes:
        - name: pulse-data
          persistentVolumeClaim:
            claimName: pulse-data
---
apiVersion: v1
kind: Service
metadata:
  name: pulse
  namespace: pulse
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.50.62
  ports:
    - port: 80
      targetPort: 7655
  selector:
    app: pulse
```

**Deploy with one command:**
```bash
kubectl apply -f pulse-all.yaml
```

**Delete everything:**
```bash
kubectl delete -f pulse-all.yaml
```

---

## Useful kubectl Commands

### Viewing Resources

```bash
# Get all resources in namespace
kubectl get all -n pulse

# Get specific resource types
kubectl get pods -n pulse
kubectl get svc -n pulse
kubectl get pvc -n pulse
kubectl get deployment -n pulse

# Wide output (more details)
kubectl get pods -n pulse -o wide

# Watch for changes (live updates)
kubectl get pods -n pulse -w
```

### Debugging

```bash
# View pod logs
kubectl logs -n pulse -l app=pulse

# Follow logs (like tail -f)
kubectl logs -n pulse -l app=pulse -f

# Describe resource (shows events, status)
kubectl describe pod -n pulse -l app=pulse
kubectl describe svc -n pulse pulse

# Execute command in pod
kubectl exec -n pulse -it <pod-name> -- /bin/sh

# Port forward (access without Service/Ingress)
kubectl port-forward -n pulse svc/pulse 8080:80
# Then access: http://localhost:8080
```

### Modifying Resources

```bash
# Edit resource (opens in editor)
kubectl edit deployment pulse -n pulse

# Scale deployment
kubectl scale deployment pulse -n pulse --replicas=2

# Restart deployment (rolling restart)
kubectl rollout restart deployment pulse -n pulse

# Update image
kubectl set image deployment/pulse pulse=rcourtman/pulse:v2.0.0 -n pulse
```

### Deleting Resources

```bash
# Delete specific resource
kubectl delete pod <pod-name> -n pulse
kubectl delete svc pulse -n pulse

# Delete by label
kubectl delete pods -n pulse -l app=pulse

# Delete entire namespace (and everything in it!)
kubectl delete namespace pulse
```

---

## Key Concepts Learned

### 1. Declarative Configuration
You describe the **desired state** in YAML. Kubernetes figures out how to get there. If a pod dies, Kubernetes recreates it to match the desired state.

### 2. Labels and Selectors
Labels are how Kubernetes connects resources:
- Deployments find their pods via labels
- Services find pods to send traffic to via labels
- You can select resources via labels: `-l app=pulse`

### 3. Service Discovery
Within the cluster, services can be reached by name:
- `pulse.pulse.svc.cluster.local` (full name)
- `pulse.pulse` (from other namespaces)
- `pulse` (from same namespace)

### 4. Persistent Storage
PVCs abstract storage. Your app doesn't care if storage is Longhorn, NFS, or cloud storage. It just mounts the volume.

### 5. Resource Separation
Namespaces keep things organized:
- `pulse` namespace for Pulse
- `longhorn-system` for Longhorn
- `ingress-nginx` for ingress controller
- Each app in its own namespace is a good practice
