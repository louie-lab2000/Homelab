
#!/bin/bash
set -e

CONTAINER_NAME="portainer"
IMAGE_NAME="portainer/portainer-ce:lts"

# Check if command was successful
check_success() {
    if [[ $? -ne 0 ]]; then
        echo "✗ Error encountered. Exiting."
        exit 1
    fi
}

# Detect existing port mappings
detect_ports() {
    local PORT_8000=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "8000/tcp") 0).HostPort}}' $CONTAINER_NAME 2>/dev/null || echo "8000")
    local PORT_9443=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "9443/tcp") 0).HostPort}}' $CONTAINER_NAME 2>/dev/null || echo "9443")
    echo "$PORT_8000:$PORT_9443"
}

# Remove existing container
remove_container() {
    echo "→ Stopping existing Portainer container..."
    docker stop $CONTAINER_NAME
    check_success

    echo "→ Removing existing Portainer container..."
    docker rm $CONTAINER_NAME
    check_success
}

# Update Portainer
update_portainer() {
    local PORTS=$1
    local PORT_8000=$(echo $PORTS | cut -d: -f1)
    local PORT_9443=$(echo $PORTS | cut -d: -f2)

    echo "→ Pulling latest Portainer CE LTS image..."
    docker pull $IMAGE_NAME
    check_success

    echo "→ Starting new Portainer container..."
    echo "  Ports: $PORT_8000:8000, $PORT_9443:9443"
    docker run -d \
        -p $PORT_8000:8000 \
        -p $PORT_9443:9443 \
        --name=$CONTAINER_NAME \
        --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        $IMAGE_NAME
    check_success
}

# Main script
echo "=== Portainer CE LTS Update Script ==="
echo

read -p "This will stop, remove, and recreate your Portainer container. Continue? (y/n) " -n 1 -r
echo
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Update canceled."
    exit 0
fi

# Detect ports from existing container if it exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    PORTS=$(detect_ports)
    echo "→ Detected existing port mappings: $PORTS"
    remove_container
else
    echo "→ No existing container found, using default ports"
    PORTS="8000:9443"
fi

update_portainer $PORTS

echo
echo "✓ Portainer updated successfully!"
echo "  Access at: https://localhost:$(echo $PORTS | cut -d: -f2)"
echo
docker ps -a | grep $CONTAINER_NAME
